//
//  note_model.mm
//  REFLEC BEAT plus
//
//  A live play-field note (NoteModel). Reconstructed from Ghidra project rb458, program rb458.
//  @ghidraAddress values are relative to the program image base.
//

#include "note_model.h"

#include <cassert>
#include <cstdlib>

#include "Render/neRenderer.h"
#include "Render/s_vector3.h"
#include "Render/vectormath.h"
#include "deviceenvironment.h"
#include "engineglobals.h"
#include "gamesystem.h"
#include "note_effect_mgr.h"
#include "playtimer.h"
#include "rbffnoterecord.h"

// The near/far lane slopes, seeded by the play-field layout pass (ComputePlayfieldLayoutY) and read
// here and by the effect layers. Each is the ratio of a note row's offset to the field-centre row
// scale.
float g_flPlayfieldNearLaneSlope = {};    // @ghidraAddress 0x3ce95c
float g_flPlayfieldNearLaneSlopeNeg = {}; // @ghidraAddress 0x3ce960
float g_flPlayfieldFarLaneSlope = {};     // @ghidraAddress 0x3ce96c
float g_flPlayfieldFarLaneSlopeNeg = {};  // @ghidraAddress 0x3ce970

// The play-field gauge layout positions, seeded by the play-field layout pass and read by the gauge
// sprite emitter. The centre split is subtracted from the portrait gauge positions; the four base-Y
// values are the top and bottom band bases in the default and alternate gauge modes.
int g_nPlayfieldCentreSplit = {}; // @ghidraAddress 0x3ce934
int g_nGaugeAltTopBaseY = {};     // @ghidraAddress 0x3ce99c
int g_nGaugeAltBottomBaseY = {};  // @ghidraAddress 0x3ce9a0
int g_nGaugeTopBaseY = {};        // @ghidraAddress 0x3ce9a4
int g_nGaugeBottomBaseY = {};     // @ghidraAddress 0x3ce9a8

// The rest of the play-field vertical layout table (@ghidraAddress 0x3ce930..0x3ce998 and 0x3d0008),
// all derived from the field height by the play-field layout pass and read by the note, gauge, and
// background layers.
int g_nPlayfieldFieldHeight = {};          // @ghidraAddress 0x3ce930
int g_nPlayfieldHalfHeightY = {};          // @ghidraAddress 0x3ce938
int g_nPlayfieldFullHeightY = {};          // @ghidraAddress 0x3d0008
int g_nPlayfieldRow16 = {};                // @ghidraAddress 0x3ce93c
int g_nPlayfieldRow2c = {};                // @ghidraAddress 0x3ce940
int g_nPlayfieldRow36 = {};                // @ghidraAddress 0x3ce944
int g_nPlayfieldRow6c = {};                // @ghidraAddress 0x3ce948
float g_flPlayfieldRowScale = {};          // @ghidraAddress 0x3ce94c
int g_nPlayfieldNearRowTop = {};           // @ghidraAddress 0x3ce950
int g_nPlayfieldNearRowBottom = {};        // @ghidraAddress 0x3ce954
int g_nPlayfieldRow12e = {};               // @ghidraAddress 0x3ce958
int g_nPlayfieldFarRowTop = {};            // @ghidraAddress 0x3ce964
int g_nPlayfieldFarRowBottom = {};         // @ghidraAddress 0x3ce968
int g_nPlayfieldMidRowTop = {};            // @ghidraAddress 0x3ce974
int g_nPlayfieldMidRowBottom = {};         // @ghidraAddress 0x3ce978
float g_flPlayfieldMidLaneSlope = {};      // @ghidraAddress 0x3ce97c
float g_flPlayfieldMidLaneSlopeNeg = {};   // @ghidraAddress 0x3ce980
int g_nPlayfieldGaugeRowTop = {};          // @ghidraAddress 0x3ce984
int g_nPlayfieldGaugeRowBottom = {};       // @ghidraAddress 0x3ce988
float g_flPlayfieldExtraLaneSlope = {};    // @ghidraAddress 0x3ce98c
float g_flPlayfieldExtraLaneSlopeNeg = {}; // @ghidraAddress 0x3ce990
int g_nPlayfieldRowE4 = {};                // @ghidraAddress 0x3ce994
int g_nPlayfieldRow192 = {};               // @ghidraAddress 0x3ce998

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

// The number of sub-entries a play reset re-seeds (the active hold/slide segments).
constexpr int kResetSubEntryCount = 10;
// The colour-lock state a play reset restores (the none sentinel, leaving the note open).
constexpr int kColorLockReset = 5;

// The play-field layout pass scales its input by 1024 (a 10-bit scroll scale) and derives every row
// from the resulting field height.
constexpr float kPlayfieldHeightScale = 1024.0f;
constexpr int kPlayfieldHalfHeightOffset = 0x200; // half a 1024-unit field
constexpr int kPlayfieldFullHeightOffset = 0x400; // a full 1024-unit field
// The fixed pixel row offsets subtracted from the field height for the various note and HUD rows.
constexpr int kPlayfieldRowOffset16 = 0x16;
constexpr int kPlayfieldRowOffset2c = 0x2c;
constexpr int kPlayfieldRowOffset36 = 0x36;
constexpr int kPlayfieldRowOffset6c = 0x6c;
constexpr int kPlayfieldNearRowOffset = 0x97;
constexpr int kPlayfieldRowOffset12e = 0x12e;
constexpr int kPlayfieldFarRowOffset = 0x15e;
constexpr int kPlayfieldMidRowOffset = 0xfa;
constexpr int kPlayfieldGaugeRowOffset = 0x3e;
constexpr int kPlayfieldRowOffsetE4 = 0xe4;
constexpr int kPlayfieldRowOffset192 = 0x192;
constexpr int kPlayfieldGaugeAltBaseY = 0x120;
constexpr int kPlayfieldGaugeBaseY = 0x1ce;
// The fixed extra-lane slope numerator (a -62 offset). @ghidraAddress 0x2ef660
constexpr float kPlayfieldExtraLaneOffset = -62.0f;
} // namespace

/** @ghidraAddress 0x55488 */
void ComputePlayfieldLayoutY(float flScale) {
    // The field height is the base scale in 1024-unit scroll space; its half (rounded toward zero) is
    // the field centre.
    const int nHeight = static_cast<int>(flScale * kPlayfieldHeightScale);
    g_nPlayfieldFieldHeight = nHeight;
    const int nRounded = nHeight < 0 ? nHeight + 1 : nHeight;
    g_nPlayfieldCentreSplit = nRounded >> 1;

    // The half- and full-height rows and the near-HUD rows are fixed pixel offsets below the top.
    g_nPlayfieldHalfHeightY = nHeight - kPlayfieldHalfHeightOffset;
    g_nPlayfieldFullHeightY = nHeight - kPlayfieldFullHeightOffset;
    g_nPlayfieldRow16 = nHeight - kPlayfieldRowOffset16;
    g_nPlayfieldRow2c = nHeight - kPlayfieldRowOffset2c;
    g_nPlayfieldRow36 = nHeight - kPlayfieldRowOffset36;
    g_nPlayfieldRow6c = nHeight - kPlayfieldRowOffset6c;

    // The field-centre row scale is the slope denominator for every angled lane.
    g_flPlayfieldRowScale = static_cast<float>(g_nPlayfieldCentreSplit - kPlayfieldRowOffset36);

    // The near note row: its top constant, its bottom offset, and the derived near-lane slope.
    g_nPlayfieldNearRowTop = kPlayfieldNearRowOffset;
    g_nPlayfieldNearRowBottom = nHeight - kPlayfieldNearRowOffset;
    g_nPlayfieldRow12e = nHeight - kPlayfieldRowOffset12e;
    g_flPlayfieldNearLaneSlope =
        static_cast<float>(kPlayfieldNearRowOffset - g_nPlayfieldCentreSplit) /
        g_flPlayfieldRowScale;
    g_flPlayfieldNearLaneSlopeNeg = -g_flPlayfieldNearLaneSlope;

    // The far note row and its slope.
    g_nPlayfieldFarRowTop = kPlayfieldFarRowOffset;
    g_nPlayfieldFarRowBottom = nHeight - kPlayfieldFarRowOffset;
    g_flPlayfieldFarLaneSlope =
        static_cast<float>(kPlayfieldFarRowOffset - g_nPlayfieldCentreSplit) /
        g_flPlayfieldRowScale;
    g_flPlayfieldFarLaneSlopeNeg = -g_flPlayfieldFarLaneSlope;

    // The mid note row and its slope.
    g_nPlayfieldMidRowTop = kPlayfieldMidRowOffset;
    g_nPlayfieldMidRowBottom = nHeight - kPlayfieldMidRowOffset;
    g_flPlayfieldMidLaneSlope =
        static_cast<float>(kPlayfieldMidRowOffset - g_nPlayfieldCentreSplit) /
        g_flPlayfieldRowScale;
    g_flPlayfieldMidLaneSlopeNeg = -g_flPlayfieldMidLaneSlope;

    // The gauge row (centre split minus a fixed offset, mirrored to the bottom).
    g_nPlayfieldGaugeRowTop = g_nPlayfieldCentreSplit - kPlayfieldGaugeRowOffset;
    g_nPlayfieldGaugeRowBottom = nHeight - g_nPlayfieldGaugeRowTop;

    // The extra-lane slope from the fixed -62 numerator.
    g_flPlayfieldExtraLaneSlope = kPlayfieldExtraLaneOffset / g_flPlayfieldRowScale;
    g_flPlayfieldExtraLaneSlopeNeg = -g_flPlayfieldExtraLaneSlope;

    // The result rows and the two gauge base bands (alternate and default modes).
    g_nPlayfieldRowE4 = nHeight - kPlayfieldRowOffsetE4;
    g_nPlayfieldRow192 = nHeight - kPlayfieldRowOffset192;
    g_nGaugeAltTopBaseY = kPlayfieldGaugeAltBaseY;
    g_nGaugeAltBottomBaseY = nHeight - kPlayfieldGaugeAltBaseY;
    g_nGaugeTopBaseY = kPlayfieldGaugeBaseY;
    g_nGaugeBottomBaseY = nHeight - kPlayfieldGaugeBaseY;
}

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
    m_bIsPad = IsPad();
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

/** @ghidraAddress 0x131ae8 */
void NoteModel::ResetPlayState() {
    m_nState = 0;
    m_nSubState = 0;
    m_nActiveIndex = kSubEntryIndexNone;
    m_nJudgeGrade = kSubEntryKindNone;
    m_nActiveKind = kSubEntryKindNone;
    m_nActiveKind2 = kSubEntryKindNone;

    // Re-seed the active sub-entries to their empty defaults (clearing each record's coordinates).
    for (int i = 0; i < kResetSubEntryCount; ++i) {
        m_aSubEntries[i] = SubEntry{};
        m_aSubEntries[i].nKind = kSubEntryKindNone;
        m_aSubEntries[i].nIndex = kSubEntryIndexNone;
        m_aSubEntries[i].nSeedA = kSubEntrySeed;
        m_aSubEntries[i].nSeedD = kSubEntrySeed;
    }

    m_bPlayStateFlag510 = false;
    m_nColorLockState = kColorLockReset;
    m_bEmphasisFallback = false;
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
// The highest default tap-sound index, and the fixed sound a rival (CPU/ghost) note plays.
constexpr int kMaxDefaultSoundIndex = 2;
constexpr int kRivalTapSoundIndex = 3;
} // namespace

/** @ghidraAddress 0x133dfc */
void NoteModel::PlayNoteTapSound(int nSoundIndex, bool bUseAlt) {
    NoteEffectMgr *pManager = static_cast<NoteEffectMgr *>(m_pSheet);
    if (m_nRivalMode == 0) {
        assert(nSoundIndex <= kMaxDefaultSoundIndex);
    } else {
        // A CPU/ghost note stays silent when it is excluded from scoring, unless the game is in the
        // CPU full-combo mode; the alternate path checks the flag-40 exclusion instead.
        if (!GameSystem::GetGameSystem()->GetCpuFullCombo()) {
            if (bUseAlt) {
                if (pManager != nullptr && pManager->IsNoteFlag40Set(m_nNoteIndex)) {
                    return;
                }
            } else if (pManager != nullptr && pManager->IsNoteScoreExcluded(m_nNoteIndex)) {
                return;
            }
        }
        // A rival note always plays the fixed rival tap sound.
        nSoundIndex = kRivalTapSoundIndex;
    }
    if (pManager == nullptr) {
        return;
    }
    pManager->DispatchNoteJudgeEvent(IsOnPlaySide(), nSoundIndex);
}

/** Computes the current play-field judge clock. */
float NoteModel::GetCurrentJudgeTime() const {
    return PlayTimer::shared()->GetPlayTime() * kWaypointTimeScale + kWaypointTimeOffset;
}

namespace {
// The note states in which a note can accept a touch hit.
constexpr int kNoteStateTouchableExisting = 2;
constexpr int kNoteStateTouchableSlide = 5;
// The minimum signed distance below the target line at which an out-of-window note is still
// reachable by a touch (@ghidraAddress 0x308b7c).
constexpr float kTouchBelowLineThreshold = -64.0f;
} // namespace

/** @ghidraAddress 0x135ee8 */
bool NoteModel::CheckTouchHit(float flX, float flY, float *pOutDistanceSq) const {
    // Only a live player note in an existing or slide-existing state is touchable.
    if (m_nRivalMode != 0) {
        return false;
    }
    if (m_nState != kNoteStateTouchableSlide && m_nState != kNoteStateTouchableExisting) {
        return false;
    }

    const float flNow = GetCurrentJudgeTime();
    const float flHitTime = GetHitTime();
    const bool bInWindow =
        flHitTime + kMissWindowLow < flNow && flNow < flHitTime + kJudgeWindowJustHigh;

    // Out of the window, the note is still reachable only just below its target line.
    if (!bInWindow && m_pos.y - GetTargetLineY() < kTouchBelowLineThreshold) {
        return false;
    }

    // Compare the note's side-mirrored screen position against the touch point.
    const float flMirrorX = IsSideFlipped() ? 1.0f : -1.0f;
    const float flMirrorY = IsSideFlipped() ? -1.0f : 1.0f;
    const float flDx = m_pos.x * flMirrorX - flX;
    const float flDy = m_pos.y * flMirrorY - flY;
    const float flDistanceSq = flDx * flDx + flDy * flDy;
    if (GameSystem::GetGameSystem()->GetSheetDiameterSq() <= flDistanceSq) {
        return false;
    }
    *pOutDistanceSq = flDistanceSq;
    return true;
}

namespace {
// The per-combo emphasis probability, indexed by the combo count clamped to [0, 9]
// (@ghidraAddress 0x308c14).
constexpr float kEmphasisProbability[] = {
    0.02f, 0.02f, 0.02f, 0.02f, 0.05f, 0.1f, 0.1f, 0.6f, 0.6f, 0.7f};
constexpr int kEmphasisProbabilityMax = 9;
// Folds a rand() result into the unit interval (@ghidraAddress 0x3014d0 = 1 / RAND_MAX).
constexpr float kInverseRandMax = 1.0f / 2147483647.0f;
// The versus game type: game type zero or two are the two-side versus modes.
constexpr int kGameTypeVersusMask = 2;
// The side value a recordless note reports when its own-side flag is unset.
constexpr int kEmphasisNoSide = 3;
} // namespace

/** @ghidraAddress 0x136884 */
bool NoteModel::ShouldEmphasize() const {
    GameSystem *pGameSystem = GameSystem::GetGameSystem();

    // A per-combo random chance emphasises the note outright.
    const int nCombo = pGameSystem->GetComboCount();
    const int nProbabilityIndex =
        nCombo < 0 ? 0 : (nCombo > kEmphasisProbabilityMax ? kEmphasisProbabilityMax : nCombo);
    if (static_cast<float>(rand()) * kInverseRandMax < kEmphasisProbability[nProbabilityIndex]) {
        return true;
    }

    if ((pGameSystem->GetGameType() | kGameTypeVersusMask) == kGameTypeVersusMask) {
        // Versus mode: determine the note's side (from its record, or the own-side fallback).
        int nSide;
        if (m_pRecord == nullptr) {
            nSide = m_bOwnSide ? 0 : kEmphasisNoSide;
        } else {
            nSide = m_pRecord->GetSide();
        }
        // When the note's side differs from the local side (1 when the play colour is 0), emphasise
        // it on the CPU full combo, falling back to the per-note flag.
        if ((pGameSystem->GetPlayColor() == 0 ? 1 : 0) != nSide) {
            if (pGameSystem->GetCpuFullCombo()) {
                return true;
            }
            return m_bEmphasisFallback;
        }
    }
    // Non-versus (or the play-colour side): emphasise on the user's full combo.
    return pGameSystem->GetUserFullCombo();
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
        PlayNoteTapSound(0, false);
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
        PlayNoteTapSound(0, false);
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
