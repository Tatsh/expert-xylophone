//
//  note_model.mm
//  REFLEC BEAT plus
//
//  A live play-field note (NoteModel). Reconstructed from Ghidra project rb458, program rb458.
//  @ghidraAddress values are relative to the program image base.
//

#include "note_model.h"

#include <cassert>

#include "Render/neRenderer.h"
#include "Render/s_vector3.h"
#include "Render/vectormath.h"
#include "deviceenvironment.h"
#include "engineglobals.h"
#include "gamesystem.h"
#include "note_effect_mgr.h"
#include "playtimer.h"
#include "rbffnoterecord.h"

// The near-lane slope and its negative, seeded by the play-field layout pass
// (ComputePlayfieldLayoutY) and read here and by the effect layers. Both are the ratio of the
// near-row offset to the field-centre row scale.
float g_flPlayfieldNearLaneSlope = {};    // @ghidraAddress 0x3ce95c
float g_flPlayfieldNearLaneSlopeNeg = {}; // @ghidraAddress 0x3ce960
float g_flPlayfieldFarLaneSlopeNeg = {};  // @ghidraAddress 0x3ce970

// The note lane-position table (@ghidraAddress 0x3de000), seeded once by InitNoteLaneTable and read
// by GetNoteLaneFraction. It holds the six across-field lane fractions (symmetric about the centre),
// a lane spread span, and the two wide-lane fractions for the alternate lane kind. The leading span
// is unused padding preceding the seeded fields.
NoteLaneTable g_noteLaneTable = {}; // @ghidraAddress 0x3de000

namespace {

// The band fractions of the play-field edge, indexed by band, and the count of bands. Band 4 is the
// centre line and produces no offset; bands 0 through 3 sit above it and 5 through 8 below.
// The per-band multiplier applied to the near-lane slope, from the binary's band switch. Bands 2,
// 4, and 6 contribute nothing; the outer bands ramp 0.10, 0.30, 0.38 out from the centre.
constexpr float kBandFractions[] = {0.38f, 0.30f, 0.0f, 0.10f, 0.0f, 0.10f, 0.0f, 0.30f, 0.38f};
constexpr int kBandCount = 9;
constexpr int kCenterBand = 4;

// The alternate lane kind whose two wide lanes use the wide-lane fractions, and its two lane indices.
constexpr int kWideLaneKind = 1;
constexpr int kWideLaneLeft = 1;
constexpr int kWideLaneRight = 2;

} // namespace

// The sub-entry seed values the constructor writes into every slot.
namespace {
constexpr int kSubEntryKindNone = 5;
constexpr int kSubEntryIndexNone = -1;
constexpr int kSubEntrySeed = 5;
} // namespace

/** @ghidraAddress 0x1319fc */
NoteModel::NoteModel(void *pSheet) {
    m_pSheet = pSheet;
    m_nNoteIndex = -1;
    // Seed every hold/slide segment slot to its empty state; the other fields stay zero-initialised.
    for (SubEntry &entry : m_aSubEntries) {
        entry.nKind = kSubEntryKindNone;
        entry.nIndex = kSubEntryIndexNone;
        entry.nSeedA = kSubEntrySeed;
        entry.nSeedD = kSubEntrySeed;
    }
    m_bFontVariant = IsPad();
}

/** @ghidraAddress 0x131aa8 */
void NoteModel::SetNoteIndex(int nIndex) {
    m_nNoteIndex = nIndex;
    // Refresh the record pointer from the owning manager's currently-bound chart.
    if (m_pSheet != nullptr) {
        m_pRecord = static_cast<NoteEffectMgr *>(m_pSheet)->GetActiveNoteRecord(nIndex);
    }
}

/** @ghidraAddress 0x131ad8 */
void NoteModel::ResetBinding() {
    m_nNoteIndex = -1;
    m_pRecord = nullptr;
}

/** @ghidraAddress 0x135e84 */
int NoteModel::IsSideFlipped() const {
    int nSide;
    if (m_pRecord == nullptr) {
        // A synthetic note (no chart record) mirrors by its own side flag; an unset flag is the
        // no-side sentinel.
        if (!m_bOwnSide) {
            return kNoSideSentinel;
        }
        nSide = 0;
    } else {
        nSide = m_pRecord->GetSide();
        // A record side outside the two play sides falls back to the own-side flag.
        if (nSide > 1) {
            return m_bOwnSide ? 0 : kNoSideSentinel;
        }
    }
    // The note is flipped when its side differs from the current play side.
    return GameSystem::GetGameSystem()->GetPlayColor() != nSide;
}

/** @ghidraAddress 0x134924 */
int NoteModel::IsOnPlaySide() const {
    int nSide;
    if (m_pRecord == nullptr) {
        // A synthetic note (no chart record) belongs to a side only when its own-side flag is set.
        if (!m_bOwnSide) {
            return kNoSideSentinel;
        }
        nSide = 0;
    } else {
        nSide = m_pRecord->GetSide();
        // A record side outside the two play sides is on the play side only when the own-side flag
        // is set (returning the no-side sentinel otherwise).
        if (nSide > 1) {
            return m_bOwnSide ? 1 : kNoSideSentinel;
        }
    }
    // The note is on the play side when its side matches the current play side.
    return GameSystem::GetGameSystem()->GetPlayColor() == nSide;
}

// The fixed lead time a synthetic note's hit time adds to its spawn time (@ghidraAddress 0x2fcf80).
static constexpr float kSyntheticHitLead = 3000.0f;

/** @ghidraAddress 0x13490c */
int NoteModel::GetStartTime() const {
    if (m_pRecord == nullptr) {
        return -1;
    }
    return m_pRecord->GetStartTime();
}

/** @ghidraAddress 0x13353c */
float NoteModel::GetHitTime() const {
    if (m_pRecord != nullptr) {
        return static_cast<float>(m_pRecord->GetTimeA() + m_pRecord->GetTimeB());
    }
    // A synthetic note times its hit from the spawn time plus a fixed lead.
    if (m_bOwnSide) {
        return m_flSpawnTime + kSyntheticHitLead;
    }
    return 0.0f;
}

/** @ghidraAddress 0x133a24 */
int NoteModel::GetSide() const {
    if (m_pRecord != nullptr) {
        return m_pRecord->GetSide();
    }
    // A synthetic note reports side 0 when its own-side flag is set, else the no-side sentinel.
    return m_bOwnSide ? 0 : kNoSideSentinel;
}

/** @ghidraAddress 0x1336c0 */
int NoteModel::GetType() const {
    if (m_pRecord != nullptr) {
        return m_pRecord->GetType();
    }
    // A synthetic note reports type 0 when its own-side flag is set, else the idle-kind sentinel.
    return m_bOwnSide ? 0 : kIdleTypeSentinel;
}

/** @ghidraAddress 0x136a20 */
int NoteModel::GetKind() const {
    if (m_pRecord != nullptr) {
        return m_pRecord->GetKind();
    }
    return -1;
}

/** @ghidraAddress 0x1369e8 */
int NoteModel::GetSlidePointCount() const {
    return m_pRecord->GetSlidePointCount();
}

/** @ghidraAddress 0x1369f4 */
int NoteModel::GetSlidePointJudge(int nIndex) const {
    // The miss sentinel for a slide point past the note's slide-point count.
    static constexpr int kSlidePointJudgeMiss = 5;
    if (nIndex < m_pRecord->GetSlidePointCount()) {
        return m_aSubEntries[nIndex].nSlidePointJudge;
    }
    return kSlidePointJudgeMiss;
}

/** @ghidraAddress 0x135310 */
float NoteModel::GetTargetLineY() const {
    // A synthetic note (no record) uses its own-side flag as the hold kind: own side is kind 0, the
    // other side is kind 3 (which selects no travel line).
    int nHoldKind;
    if (m_pRecord == nullptr) {
        nHoldKind = m_bOwnSide ? 0 : 3;
    } else {
        nHoldKind = m_pRecord->GetHoldKind();
    }

    float flFraction;
    if (nHoldKind == 1) {
        flFraction = g_flPlayfieldFarLaneSlopeNeg;
    } else if (nHoldKind == 0) {
        flFraction = g_flPlayfieldNearLaneSlopeNeg;
    } else {
        flFraction = 0.0f;
    }
    return flFraction * GameSystem::GetGameSystem()->GetSheetInsetHalfY();
}

/** @ghidraAddress 0x13609c */
void NoteModel::MarkTouched() {
    m_bTouched = true;
}

namespace {
// The waypoint interpolation scales the play time to the chart's hash range and offsets it by the
// lead-in (@ghidraAddress 0x2f8540 = 1000.0, 0x308b60 = -1500.0).
constexpr float kWaypointTimeScale = 1000.0f;
constexpr float kWaypointTimeOffset = -1500.0f;
// The fade-out step's per-frame decay divisor (negative, so the timer counts down)
// (@ghidraAddress 0x2fd050 = -300.0).
constexpr float kFadeDecayDivisor = -300.0f;
// The note-state-machine states the per-frame dispatcher switches on. State 6 (transitional) and
// any unlisted value do nothing; state 8 is the finished state the steps advance to.
constexpr int kNoteStateApproach = 1;
constexpr int kNoteStateExisting = 2;
constexpr int kNoteStateLongTouched = 3;
constexpr int kNoteStateShot = 4;
constexpr int kNoteStateSlideExisting = 5;
constexpr int kNoteStateFadeOut = 7;
constexpr int kNoteStateFinished = 8;
// The shot step's packed render draw flags: {bDrawFlag0 = 0, bDrawFlag1 = 1}.
constexpr unsigned short kShotDrawFlags = 0x100;
} // namespace

/** @ghidraAddress 0x136960 */
void NoteModel::AdvanceAlongWaypoint() {
    if (m_pCurrentWaypoint == nullptr) {
        return;
    }
    const float flPlayTime = PlayTimer::shared()->GetPlayTime();
    const float flFraction =
        (flPlayTime * kWaypointTimeScale + kWaypointTimeOffset) - m_pCurrentWaypoint->flStartTime;
    // position = startPos + endPos * fraction.
    S_VECTOR2 delta = m_pCurrentWaypoint->endPos;
    ScaleVector2(&delta, flFraction);
    AddVector2(&delta, &m_pCurrentWaypoint->startPos);
    m_pos = delta;
}

/** @ghidraAddress 0x1334dc */
void NoteModel::UpdateStepFadeOut() {
    const float flDelta = PlayTimer::shared()->GetFrameDelta();
    AdvancePosition();
    // The decay divisor is negative, so the timer counts down toward zero each frame.
    m_flFadeTimer += flDelta / kFadeDecayDivisor;
    if (m_flFadeTimer <= 0.0f) {
        m_flFadeTimer = 0.0f;
        m_nState = kNoteStateFinished;
        m_nSubState = 0;
    }
}

/** @ghidraAddress 0x132b20 */
void NoteModel::UpdateStepShot() {
    AdvancePosition();
    // Travel along the reversed, normalised velocity by the shot speed times its progress.
    S_VECTOR2 offset = m_velocity;
    ScaleVector2(&offset, -1.0f);
    NormalizeVector2(&offset);
    ScaleVector2(&offset, m_flShotSpeed * m_flShotProgress);
    AddVector2(&offset, &m_pos);
    m_flRenderX = offset.x;
    m_flRenderY = offset.y;
    // The two render draw flags, packed as {0, 1}.
    m_wDrawFlags = kShotDrawFlags;
    // Finish the note once it has flown below the play field's cull margin.
    const float flCullY = GameSystem::GetGameSystem()->GetSheetInsetHalfY() +
                          GameSystem::GetGameSystem()->GetSheetRadiusHalf();
    if (flCullY < offset.y) {
        m_nState = kNoteStateFinished;
        m_nSubState = 0;
    }
}

/** @ghidraAddress 0x131b64 */
void NoteModel::UpdateStep() {
    switch (m_nState) {
    case kNoteStateApproach:
        UpdateStepApproach();
        break;
    case kNoteStateExisting:
        UpdateStepExisted();
        break;
    case kNoteStateLongTouched:
        UpdateStepLongTouched();
        break;
    case kNoteStateShot:
        UpdateStepShot();
        break;
    case kNoteStateSlideExisting:
        UpdateStepSlideExisted();
        break;
    case kNoteStateFadeOut:
        UpdateStepFadeOut();
        break;
    default:
        break;
    }
}

namespace {
// The shot direction is clamped to this magnitude in each direction.
constexpr int kMaxShotDirection = 2;
// The spawn time is the play time converted to milliseconds, less a fixed lead-in.
constexpr float kShotSpawnTimeScale = 1000.0f;
constexpr float kShotSpawnTimeLeadIn = -1500.0f;
// The colour returned when no note is active at the queried index.
constexpr int kNoActiveNoteColor = 5;
// The active-note colours dispatched by CheckShot.
enum ShotColor {
    kShotColorPlayer = 0, // The player-controlled note.
    kShotColorCPU = 1,    // The CPU-controlled note.
    kShotColorGhost = 2,  // The ghost (replay) note.
    kShotColorInert = 3,  // A note that takes no shot action.
};
} // namespace

/** @ghidraAddress 0x1335ec */
void NoteModel::SetShotDirection(int nDirection) {
    const float flSpawnTime =
        PlayTimer::shared()->GetPlayTime() * kShotSpawnTimeScale + kShotSpawnTimeLeadIn;

    // Clamp the requested direction to [-kMaxShotDirection, kMaxShotDirection] and take its
    // magnitude for the waypoint count.
    int nClamped = nDirection;
    if (nClamped > kMaxShotDirection) {
        nClamped = kMaxShotDirection;
    }
    if (nClamped < -kMaxShotDirection) {
        nClamped = -kMaxShotDirection;
    }
    m_nDirectionSign = nClamped;
    m_nWaypointCount = nClamped < 0 ? -nClamped : nClamped;

    m_basePos = m_pos;
    m_flSpawnTime = flSpawnTime;
    SetRoute();

    // Propagate the spawn position, spawn time, and route along the note's linked chain.
    NoteEffectMgr *pManager = static_cast<NoteEffectMgr *>(m_pSheet);
    RbffNoteRecord *pRecord = m_pRecord;
    while (pRecord != nullptr && pRecord->GetChainLink().GetNext() != -1) {
        NoteModel *pLinked = pManager->FindNoteByIndex(pRecord->GetChainLink().GetNext());
        if (pLinked == nullptr) {
            break;
        }
        if (pLinked->GetState() != 0) {
            pLinked->m_basePos = m_pos;
            pLinked->m_flSpawnTime = flSpawnTime;
            pLinked->SetRoute();
        }
        pRecord = pLinked->m_pRecord;
    }
}

/** @ghidraAddress 0x1361b0 */
int NoteModel::GetActiveNoteColor() const {
    if (m_pRecord != nullptr && m_pRecord->GetStartTime() != -1) {
        NoteModel *pNote =
            static_cast<NoteEffectMgr *>(m_pSheet)->FindNoteByIndex(m_pRecord->GetStartTime());
        if (pNote != nullptr) {
            return pNote->GetRivalMode();
        }
    }
    return kNoActiveNoteColor;
}

/** @ghidraAddress 0x133774 */
void NoteModel::CheckShot() {
    if (!m_bShotActive) {
        return;
    }
    if (!m_bShotDecaying) {
        m_bShotActive = false;
        return;
    }
    // Decay the shot lifetime; once it runs out the note leaves its shot phase.
    if (m_flShotDecayTimer <= 0.0f) {
        m_bShotActive = false;
    } else {
        m_flShotDecayTimer -= PlayTimer::shared()->GetFrameDelta();
    }
    switch (GetActiveNoteColor()) {
    case kShotColorPlayer:
        CheckShotPlayer();
        return;
    case kShotColorCPU:
        CheckShotCPU();
        return;
    case kShotColorGhost:
        CheckShotGhost();
        return;
    case kShotColorInert:
        return;
    default:
        assert(0);
    }
}

namespace {
// The timing-window thresholds the note judge compares the signed time error against
// (@ghidraAddress 0x308b64..0x308b78). The just window is [b6c, b64_narrow); a hit inside the
// tighter [b74, b70) band grades early/late, otherwise far.
constexpr float kJudgeWindowJustHigh = 153.0f; // 0x308b64
constexpr float kJudgeWindowJustLow = -34.0f;  // 0x308b6c
constexpr float kJudgeWindowNearHigh = 102.0f; // 0x308b70
constexpr float kJudgeWindowNearLow = -102.0f; // 0x308b74
constexpr float kMissWindowLow = -153.0f;      // 0x308b78
// The narrow just-window high bound compared before the early/late/far split (0x308b68).
constexpr float kJudgeWindowJustHighNarrow = -83.33333587646484f;
// The note grades ResolveNoteHit records.
enum NoteGrade {
    kGradeJust = 0,      // A just (perfect) hit.
    kGradeEarlyLate = 1, // An early or late hit.
    kGradeFar = 2,       // A far (off) hit.
};
// The tap-only note kind that plays a sound and self-marks instead of resolving a hit.
constexpr int kNoteKindTapOnly = 3;
} // namespace

/** Computes the current play-field judge clock. */
float NoteModel::GetCurrentJudgeTime() const {
    return PlayTimer::shared()->GetPlayTime() * kWaypointTimeScale + kWaypointTimeOffset;
}

/** @ghidraAddress 0x133a48 */
void NoteModel::JudgeNoteTiming() {
    if (!m_bTouched) {
        return;
    }
    const float flError = GetHitTime() - GetCurrentJudgeTime();
    unsigned int nGrade;
    if (flError < kJudgeWindowJustHighNarrow && flError > kJudgeWindowJustLow) {
        nGrade = kGradeJust;
    } else {
        // Inside the narrow near band grades early/late, otherwise far.
        const bool bNear = flError > kJudgeWindowNearLow && flError < kJudgeWindowNearHigh;
        nGrade = bNear ? kGradeEarlyLate : kGradeFar;
    }
    ResolveNoteHit(nGrade);
}

/** @ghidraAddress 0x133b1c */
void NoteModel::CheckNoteMiss() {
    if (m_bMissProcessed) {
        return;
    }
    const float flNow = GetCurrentJudgeTime();
    const float flHitTime = GetHitTime();
    // The note has entered its miss window, is still before the late edge, and has reached its hit.
    if (flHitTime + kMissWindowLow < flNow && flNow < flHitTime + kJudgeWindowJustHigh &&
        flHitTime <= flNow) {
        if (m_nKind != kNoteKindTapOnly) {
            m_pos = S_VECTOR2{GetLaneX(), GetTargetLineY()};
            ResolveNoteHit(m_nKind);
            return;
        }
        PlayNoteTapSound();
        m_bMissProcessed = true;
    }
}

/** @ghidraAddress 0x133c8c */
void NoteModel::UpdateNoteAutoTap() {
    if (m_bMissProcessed) {
        return;
    }
    const float flNow = GetCurrentJudgeTime();
    const float flHitTime = GetHitTime();
    if (flHitTime + kMissWindowLow < flNow && flNow < flHitTime + kJudgeWindowJustHigh &&
        flHitTime <= flNow) {
        if (m_nKind != kNoteKindTapOnly) {
            m_pos = S_VECTOR2{GetLaneX(), GetTargetLineY()};
            ResolveNoteHit(m_nKind);
            return;
        }
        PlayNoteTapSound();
        m_bMissProcessed = true;
    }
}

/** @ghidraAddress 0x133578 */
void NoteModel::UpdateNotePathLinks() {
    if (m_pRecord == nullptr) {
        return;
    }
    NoteEffectMgr *pManager = static_cast<NoteEffectMgr *>(m_pSheet);
    const short *pPathPoints = m_pRecord->GetPathPoints();
    for (int nPoint = 0; nPoint < m_pRecord->GetPointCount(); ++nPoint) {
        if (pManager == nullptr) {
            continue;
        }
        // A path point maps to a chart note index (or the -1 sentinel when the array is absent).
        const int nLinkIndex = pPathPoints != nullptr ? pPathPoints[nPoint] : -1;
        pManager->ActivateNoteByIndex(nLinkIndex);
        m_bJustHit = false;
    }
}

/** @ghidraAddress 0x1336e4 */
void NoteModel::AdvancePosition() {
    const float flDelta = PlayTimer::shared()->GetFrameDelta();
    m_prevPos = m_pos;
    if (m_bWaypointActive) {
        AdvanceAlongWaypoint();
        return;
    }
    // position += velocity * frameDelta.
    S_VECTOR2 step = m_velocity;
    ScaleVector2(&step, flDelta);
    AddVector2(&step, &m_pos);
    m_pos = step;
}

/** @ghidraAddress 0x1352b8 */
float NoteModel::GetLaneX() const {
    int nKind;
    int nLane;
    if (m_pRecord != nullptr) {
        nKind = m_pRecord->GetHoldKind();
        nLane = m_pRecord->GetDisplayLane();
    } else {
        // A synthetic note (no record) derives its kind and lane from the own-side flag.
        nKind = m_bOwnSide ? 0 : kNoSideSentinel;
        nLane = m_bOwnSide ? -1 : kNoSideSentinel;
    }
    return GetNoteLaneFraction(nKind, nLane) * GameSystem::GetGameSystem()->GetSheetInsetHalfX();
}

/** @ghidraAddress 0x136afc */
void InitNoteLaneTable() {
    // The six across-field lane fractions are symmetric about the centre lane (which is zero).
    g_noteLaneTable.flLaneSpread = 288.0f;
    g_noteLaneTable.flWideLaneLeft = -0.888889f;
    g_noteLaneTable.flWideLaneRight = 0.888889f;
    g_noteLaneTable.flLaneFrac0 = -0.777778f;
    g_noteLaneTable.flLaneFrac1 = -0.518519f;
    g_noteLaneTable.flLaneFrac2 = -0.259259f;
    g_noteLaneTable.flLaneFrac4 = 0.259259f;
    g_noteLaneTable.flLaneFrac5 = -g_noteLaneTable.flLaneFrac1;
    g_noteLaneTable.flLaneFrac6 = -g_noteLaneTable.flLaneFrac0;
}

/** @ghidraAddress 0x136a38 */
float GetNoteLaneFraction(int nKind, int nLane) {
    // The alternate wide-lane kind places only its two wide lanes; every other lane is centred.
    if (nKind == kWideLaneKind) {
        if (nLane == kWideLaneLeft) {
            return 0.0f;
        }
        if (nLane == kWideLaneRight) {
            return g_noteLaneTable.flWideLaneRight;
        }
        return 0.0f;
    }

    // The ordinary kind maps each lane to its across-field fraction; the centre and any out-of-range
    // lane are zero.
    switch (nLane) {
    case 0:
        return g_noteLaneTable.flLaneFrac0;
    case 1:
        return g_noteLaneTable.flLaneFrac1;
    case 2:
        return g_noteLaneTable.flLaneFrac2;
    case 4:
        return g_noteLaneTable.flLaneFrac4;
    case 5:
        return g_noteLaneTable.flLaneFrac5;
    case 6:
        return g_noteLaneTable.flLaneFrac6;
    default:
        return 0.0f;
    }
}

/** @ghidraAddress 0x1372e4 */
void ProjectNoteHitPoint(S_VECTOR2 *pPointInOut) {
    // Build the screen pick ray (origin and direction) through the screen point.
    S_VECTOR3 rayOrigin;
    S_VECTOR3 rayDir;
    ComputeScreenPickRay(pPointInOut, &rayOrigin, &rayDir);

    // Intersect the ray with the downward reference plane: t = dot(ref, -origin) / dot(ref, dir).
    S_VECTOR3 downRef{0.0f, 0.0f, -1.0f};
    S_VECTOR3 negOrigin;
    SubtractVector3(&negOrigin, &rayOrigin);
    const float flNum = DotProductVector3(&downRef, &negOrigin);
    const float flDen = DotProductVector3(&downRef, &rayDir);

    // The intersection point is origin + dir * t; write its X and Y back.
    S_VECTOR3 hit = rayDir;
    ScaleVector3(flNum / flDen, &hit);
    AddVector3(&hit, &rayOrigin);
    pPointInOut->x = hit.x;
    pPointInOut->y = hit.y;
}

/** @ghidraAddress 0x1360a8 */
float NoteModel::GetVirtualBoundY(int nBand) {
    assert(nBand >= 0 && nBand < kBandCount);
    if (nBand == kCenterBand) {
        return 0.0f;
    }
    // Bands above the centre use the near-lane slope, bands below use its negative; the result is
    // twice the slope scaled by the band's multiplier (the binary sums s*m + s*m).
    const float flSlope =
        nBand < kCenterBand ? g_flPlayfieldNearLaneSlope : g_flPlayfieldNearLaneSlopeNeg;
    return (flSlope * kBandFractions[nBand]) + (flSlope * kBandFractions[nBand]);
}
