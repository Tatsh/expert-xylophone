//
//  note_model.mm
//  REFLEC BEAT plus
//
//  A live play-field note (NoteModel). Reconstructed from Ghidra project rb458, program rb458.
//  @ghidraAddress values are relative to the program image base.
//

#include "note_model.h"

#include <cassert>
#include <cmath>
#include <cstdlib>
#include <cstring>

#include "Render/neRenderer.h"
#include "Render/s_vector3.h"
#include "Render/vectormath.h"
#include "ScoreTracker.h"
#include "bounds_effect_layer.h"
#include "chain_connector_layer.h"
#include "damage_effect_layer.h"
#include "deviceenvironment.h"
#include "engineglobals.h"
#include "explosion_effect_layer.h"
#include "gamesystem.h"
#include "long_note_layer.h"
#include "note_born_layer.h"
#include "note_charge_layer.h"
#include "note_effect_mgr.h"
#include "note_glow_layer.h"
#include "note_layer.h"
#include "note_trail_layer.h"
#include "playtimer.h"
#include "rbffnoterecord.h"
#include "reflec_gauge_layer.h"
#include "slide_note_layer.h"
#include "slide_note_result_layer.h"
#include "touch_point.h"
#include "touchmanager.h"

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

// The rest of the play-field vertical layout table (@ghidraAddress 0x3ce930..0x3ce998 and
// 0x3d0008), all derived from the field height by the play-field layout pass and read by the note,
// gauge, and background layers.
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
// by GetNoteLaneFraction. It holds the six across-field lane fractions (symmetric about the
// centre), a lane spread span, and the two wide-lane fractions for the alternate lane kind. The
// leading span is unused padding preceding the seeded fields.
NoteLaneTable g_noteLaneTable = {}; // @ghidraAddress 0x3de000

namespace {

// The band fractions of the play-field edge, indexed by band, and the count of bands. Band 4 is the
// centre line and produces no offset; bands 0 through 3 sit above it and 5 through 8 below.
// The per-band multiplier applied to the near-lane slope, from the binary's band switch. Bands 2,
// 4, and 6 contribute nothing; the outer bands ramp 0.10, 0.30, 0.38 out from the centre.
constexpr float kBandFractions[] = {0.38f, 0.30f, 0.0f, 0.10f, 0.0f, 0.10f, 0.0f, 0.30f, 0.38f};
constexpr int kBandCount = 9;
constexpr int kCenterBand = 4;

// The alternate lane kind whose two wide lanes use the wide-lane fractions, and its two lane
// indices.
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
    // The field height is the base scale in 1024-unit scroll space; its half (rounded toward zero)
    // is the field centre.
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
NoteModel::NoteModel(NoteEffectMgr *pSheet) {
    m_pSheet = pSheet;
    m_nNoteIndex = -1;
    // Seed every hold/slide segment slot to its empty state; the other fields stay
    // zero-initialised.
    for (SubEntry &entry : m_aSubEntries) {
        entry.nKind = kSubEntryKindNone;
        entry.nIndex = kSubEntryIndexNone;
        entry.nResolvedGrade = kSubEntrySeed;
        entry.nIncomingGrade = kSubEntrySeed;
    }
    m_bIsPad = IsPad();
}

/** @ghidraAddress 0x131aa8 */
void NoteModel::SetNoteIndex(int nIndex) {
    m_nNoteIndex = nIndex;
    // Refresh the record pointer from the owning manager's currently-bound chart.
    if (m_pSheet != nullptr) {
        m_pRecord = m_pSheet->GetActiveNoteRecord(nIndex);
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
        m_aSubEntries[i].nResolvedGrade = kSubEntrySeed;
        m_aSubEntries[i].nIncomingGrade = kSubEntrySeed;
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

namespace {

// The note-record hold kinds a reflect skips (a hold's head or tail does not bounce).
constexpr int kHoldKindHead = 1;
constexpr int kNoteTypeHold = 1;

// The half-scale applied to the note-field width to get each edge extent.
constexpr float kEdgeHalfScale = 0.5f;

// The bounds-effect colours a record-less note uses: three when it is on its own side, zero when
// not.
constexpr unsigned int kBoundsColorOwnSide = 3;
constexpr unsigned int kBoundsColorOtherSide = 0;

} // namespace

/** @ghidraAddress 0x133858 */
void NoteModel::HandleReflect(int nDirection) {
    // The two field-edge extents are the note-field half-width, positive and negative.
    const float flHalfWidth = GameSystem::GetGameSystem()->GetSheetPosX();
    const int nEdgePos = static_cast<int>(flHalfWidth * kEdgeHalfScale);
    const int nEdgeNeg = static_cast<int>(flHalfWidth * -kEdgeHalfScale);

    // The reflect edge is picked by the travel direction, then swapped when the note is
    // side-flipped.
    const int nForwardEdge = nDirection < 0 ? nEdgePos : nEdgeNeg;
    const int nFlippedEdge = nDirection < 0 ? nEdgeNeg : nEdgePos;
    const int nEdge = IsSideFlipped() == 0 ? nForwardEdge : nFlippedEdge;

    if (m_nWaypointCount != m_nWaypointIndex) {
        // Advance to the next path waypoint and take its velocity.
        ++m_nWaypointIndex;
        m_pCurrentWaypoint = &m_aWaypointBlock[m_nWaypointIndex];
        AdvanceAlongWaypoint();
        if (m_pCurrentWaypoint != nullptr) {
            m_velocity.x = m_pCurrentWaypoint->endPos.x;
            m_velocity.y = m_pCurrentWaypoint->endPos.y;
        }
    } else {
        // No waypoints left: bounce off the edge unless the note is a hold's head or tail.
        const bool bHold = m_pRecord != nullptr && (m_pRecord->GetHoldKind() == kHoldKindHead ||
                                                    m_pRecord->GetType() == kNoteTypeHold);
        if (bHold) {
            m_bLongNoteActive = false;
            return;
        }
        // Mirror the note's X about the edge and reverse its X velocity.
        m_pos.x = static_cast<float>(nDirection) + (static_cast<float>(nDirection) - m_pos.x);
        m_velocity.x = -m_velocity.x;
    }

    // Spawn a bounds effect at the reflect edge, its Y taken from the note position mirrored by
    // side.
    const unsigned int nColor = m_pRecord != nullptr ?
                                    static_cast<unsigned int>(m_pRecord->GetSide()) :
                                    (m_bOwnSide ? kBoundsColorOwnSide : kBoundsColorOtherSide);
    const float flSideSign = IsSideFlipped() == 0 ? 1.0f : -1.0f;
    BoundsEffectLayer::shared()->CreateBoundsEffect(
        nColor, static_cast<float>(nEdge), m_pos.y * flSideSign);
    m_bLongNoteActive = false;
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
    // The shot tail is drawn; the reflect-path flag stays clear.
    m_bRenderReflectPath = false;
    m_bRenderShotTail = true;
    // Finish the note once it has flown below the play field's cull margin.
    const float flCullY = GameSystem::GetGameSystem()->GetSheetInsetHalfY() +
                          GameSystem::GetGameSystem()->GetSheetRadiusHalf();
    if (flCullY < offset.y) {
        m_nState = kNoteStateFinished;
        m_nSubState = 0;
    }
}

namespace {
// The approach step's appearance-progress and slide-path constants.
constexpr float kApproachTimeScale = 1000.0f;  // The play-clock to note-time scale (0x2f8540).
constexpr float kApproachTimeBias = -1500.0f;  // The play-clock lead-in bias (0x308b60).
constexpr float kApproachSpeedDivisor = 60.0f; // The scroll-speed-to-progress divisor (0x2f8578).
constexpr int kNoteTypeSlideApproach = 3;      // The record type that takes the slide path.
// The appearance-progress-to-scale easing (a double-precision ramp): scale = frac * 0.2 + 0.8
// (@ghidraAddress 0x2eece8 slope, 0x2eea40 bias).
constexpr double kAppearScaleSlope = 0.2;
constexpr double kAppearScaleBias = 0.8;
} // namespace

/** @ghidraAddress 0x131bc0 */
void NoteModel::UpdateStepApproach() {
    const float flNow = PlayTimer::shared()->GetPlayTime() * kApproachTimeScale + kApproachTimeBias;
    const float flHitTime = GetHitTime();
    if (flHitTime <= flNow) {
        // The note reached the field before appearing: link its path and finish it.
        UpdateNotePathLinks();
        m_nState = kNoteStateFinished;
        m_nSubState = 0;
        return;
    }

    // The appearance progress runs from the spawn epoch, scaled by the record's resolved scroll
    // speed (the end speed when the note is on-screen, else the start speed).
    const float flScrollSpeed = m_pRecord->IsScrollVisible() ? m_pRecord->GetScrollEndSpeed() :
                                                               m_pRecord->GetScrollStartSpeed();
    float flProgress =
        (flNow - m_flBornTime) * ((flScrollSpeed / kApproachSpeedDivisor) / kApproachTimeScale);
    if (flProgress < 0.0f) {
        flProgress = 0.0f;
    }

    if (flProgress < 1.0f) {
        // Still appearing: ease the scale from its fractional progress and store the raw fraction.
        const float flFraction = flProgress - static_cast<float>(static_cast<int>(flProgress));
        float flScale = static_cast<float>(static_cast<double>(flFraction) * kAppearScaleSlope +
                                           kAppearScaleBias);
        if (flScale < 0.0f || 1.0f < flScale) {
            flScale = 0.0f;
        }
        m_flAppearScale = flScale;
        m_flFadeTimer = (flFraction < 0.0f || 1.0f < flFraction) ? 0.0f : flFraction;
        return;
    }

    // Fully appeared: snap to full scale, clear the shot direction, and enter the next state.
    m_flAppearScale = 1.0f;
    m_flFadeTimer = 1.0f;
    SetShotDirection(0);
    if (m_pRecord == nullptr || m_pRecord->GetType() != kNoteTypeSlideApproach) {
        m_nState = kNoteStateExisting;
        m_nSubState = 0;
        return;
    }

    // A slide note enters the slide state and sets up each slide point's interpolation.
    m_nState = kNoteStateSlideExisting;
    m_nSubState = 0;
    const float flInsetHalfY = GameSystem::GetGameSystem()->GetSheetInsetHalfY();
    // The time offset that aligns every slide point's clock to the note-field crossing.
    const float flTimeOffset = (g_flPlayfieldNearLaneSlopeNeg * flInsetHalfY -
                                g_flPlayfieldExtraLaneSlopeNeg * flInsetHalfY) /
                               m_velocity.y;
    for (int nPoint = 0; nPoint < m_pRecord->GetSlidePointCount(); ++nPoint) {
        SubEntry &point = m_aSubEntries[nPoint];
        point.flTime1 = point.flTime2 - flTimeOffset;
        if (nPoint == 0) {
            point.flTime0 = flHitTime - flTimeOffset;
        } else {
            point.flTime0 = m_aSubEntries[nPoint - 1].flTime2 - flTimeOffset;
        }
        point.flSlopeX = (point.flEndX - point.flStartX) / (point.flTime1 - point.flTime0);
        point.flSlopeY = (point.flEndY - point.flStartY) / (point.flTime2 - point.flTime1);
    }
}

namespace {
// The existing step's constants.
// The grace a hold head is given past its release time before the note is finalised as a miss
// (@ghidraAddress 0x308b64 = 153).
constexpr float kHoldReleaseGrace = 153.0f;
// The miss penalty scale: a fractional shortfall times three (@ghidraAddress 0x40400000 = 3.0).
constexpr float kMissPenaltyScale = 3.0f;
// The player/CPU fixed miss penalty delta.
constexpr int kMissScoreDelta = -3;
// The rival mode of a ghost (replay) note.
constexpr int kRivalModeGhost = 2;
// The rival-play mode a scored note skips scoring for.
constexpr int kRivalModeSpectate = 3;
// The hold kind whose scored note counts as a hold-bonus hit in the score path.
constexpr int kScoreHoldKind = 1;
// The first non-scoring timing grade (a miss).
constexpr int kGradeMiss = 3;
// The maximum length of a missed hold note's render tail (@ghidraAddress 0x301f78 = 200).
constexpr float kShotTailMaxLength = 200.0f;
// The per-density-tier, per-grade reflec-gauge gain a scored note adds (@ghidraAddress 0x308b84).
// The row is the chart's density tier (0, 1, or 2); the column is the timing grade (0 through 3).
constexpr int kGaugeGainGradeCount = 4;
constexpr float kGaugeGainByTier[][kGaugeGainGradeCount] = {
    {0.05f, 0.03f, 0.01f, 0.05f},
    {0.04f, 0.02f, 0.01f, 0.04f},
    {0.03f, 0.02f, 0.01f, 0.03f},
};
} // namespace

/** @ghidraAddress 0x131e3c */
void NoteModel::UpdateStepExisted() {
    // The current play-field judge clock, read before the note advances.
    const float flPlayTime = PlayTimer::shared()->GetPlayTime();

    // Advance the note, resolve any pending shot, and reflect it off either play-field edge.
    AdvancePosition();
    CheckShot();
    GameSystem *pGameSystem = GameSystem::GetGameSystem();
    if (m_pos.x < -pGameSystem->GetSheetInsetHalfX()) {
        HandleReflect(static_cast<int>(-GameSystem::GetGameSystem()->GetSheetInsetHalfX()));
    }
    if (GameSystem::GetGameSystem()->GetSheetInsetHalfX() < m_pos.x) {
        HandleReflect(static_cast<int>(GameSystem::GetGameSystem()->GetSheetInsetHalfX()));
    }

    // While a hold head is still within its release grace (or the note is any non-hold note) and it
    // has not yet crossed the target line, run the per-mode judge and stop; otherwise it has passed
    // the field and is finalised below as a miss.
    const float flJudgeTime = flPlayTime * kApproachTimeScale + kApproachTimeBias;
    const bool bWithinRelease =
        m_pRecord == nullptr || m_pRecord->GetHoldKind() != kHoldKindHead ||
        flJudgeTime <=
            static_cast<float>(m_pRecord->GetTimeB() + m_pRecord->GetTimeA()) + kHoldReleaseGrace;
    if (bWithinRelease && m_pos.y < GameSystem::GetGameSystem()->GetSheetInsetHalfY()) {
        switch (m_nRivalMode) {
        case 0:
            JudgeNoteTiming();
            break;
        case 1:
            CheckNoteMiss();
            break;
        case kRivalModeGhost:
            UpdateNoteAutoTap();
            break;
        case kRivalModeSpectate:
            break;
        default:
            assert(0);
        }
    } else {
        // The miss path: the note reached or passed its target line without a hit (or a hold head
        // ran out its release grace). Link its path and resolve it as a miss.
        UpdateNotePathLinks();

        if (m_pRecord == nullptr) {
            // A record-less note snaps to the near lane target and finishes.
            const float flInsetHalfY = GameSystem::GetGameSystem()->GetSheetInsetHalfY();
            if (m_pos.y <= -flInsetHalfY) {
                m_pos.y = -flInsetHalfY;
            } else if (flInsetHalfY <= m_pos.y) {
                m_pos.y = flInsetHalfY;
            }
            m_nState = kNoteStateFinished;
            m_nSubState = 0;
        } else if (m_pRecord->GetType() != kNoteTypeHold) {
            if (m_pRecord->GetHoldKind() != kHoldKindHead) {
                // A normal note snaps to the near lane target and finishes.
                const float flInsetHalfY = GameSystem::GetGameSystem()->GetSheetInsetHalfY();
                if (m_pos.y <= -flInsetHalfY) {
                    m_pos.y = -flInsetHalfY;
                } else if (flInsetHalfY <= m_pos.y) {
                    m_pos.y = flInsetHalfY;
                }
                m_nState = kNoteStateFinished;
                m_nSubState = 0;
            } else {
                // A stray hold head fades out.
                m_nState = kNoteStateFadeOut;
                m_nSubState = 0;
            }
        } else {
            // A missed hold note enters the shot state and takes its per-mode miss penalty.
            m_nState = kNoteStateShot;
            m_nSubState = 0;
            if (m_nRivalMode != kRivalModeSpectate) {
                ScoreTracker *pTracker = ScoreTracker::shared();
                const int nSide = m_pRecord != nullptr ? m_pRecord->GetSide() :
                                                         (m_bOwnSide ? 0 : kBoundsColorOwnSide);
                const float flMirrorX = IsSideFlipped() ? 1.0f : -1.0f;
                const float flMirrorY = IsSideFlipped() ? -1.0f : 1.0f;
                const int nDelta = m_nRivalMode == kRivalModeGhost ?
                                       static_cast<int>((1.0f - m_flLongRate) * kMissPenaltyScale) :
                                       kMissScoreDelta;
                pTracker->AddScoreDelta(nSide,
                                        static_cast<int>(m_pos.x * flMirrorX),
                                        static_cast<int>(m_pos.y * flMirrorY),
                                        nDelta);
            }
        }

        // The common miss score: grade 3 (miss), plus its gauge penalty, unless spectating.
        if (m_nRivalMode != kRivalModeSpectate) {
            ScoreTracker *pTracker = ScoreTracker::shared();
            const int nSide = m_pRecord != nullptr ? m_pRecord->GetSide() :
                                                     (m_bOwnSide ? 0 : kBoundsColorOwnSide);
            const float flMirrorX = IsSideFlipped() ? 1.0f : -1.0f;
            const float flMirrorY = IsSideFlipped() ? -1.0f : 1.0f;
            const int nBonus =
                GameSystem::GetGameSystem()->GetFullJustReflec() ? 0 : (m_bShotResolved ? 1 : 0);
            const int nHoldKind = m_pRecord != nullptr ? m_pRecord->GetHoldKind() :
                                                         (m_bOwnSide ? 0 : kBoundsColorOwnSide);
            pTracker->AddScore(nSide,
                               static_cast<int>(m_pos.x * flMirrorX),
                               static_cast<int>(m_pos.y * flMirrorY),
                               kGradeMiss,
                               nBonus,
                               nHoldKind == kScoreHoldKind);
            m_nJudgeGrade = kGradeMiss;

            m_pSheet->HandleNoteScored(m_nNoteIndex, nSide);

            ReflecGaugeLayer *pGauge = ReflecGaugeLayer::shared();
            const int nGaugeSide = m_pRecord != nullptr ? m_pRecord->GetSide() :
                                                          (m_bOwnSide ? 0 : kBoundsColorOwnSide);
            const int nTier = m_pSheet->GetDensityTier();
            ReflecGaugeLayer::AddReflecGaugeValue(
                kGaugeGainByTier[nTier][kGradeMiss], pGauge, nGaugeSide);
        }

        // Spawn the miss glow, and a bounds-damage effect for every note but a hold.
        NoteGlowLayer *pGlow = NoteGlowLayer::shared();
        const int nGlowSide =
            m_pRecord != nullptr ? m_pRecord->GetSide() : (m_bOwnSide ? 0 : kBoundsColorOwnSide);
        pGlow->CreateEffect(static_cast<unsigned int>(nGlowSide));

        if (m_pRecord == nullptr ||
            (m_pRecord->GetType() != kNoteTypeHold && m_pRecord->GetHoldKind() != kHoldKindHead)) {
            DamageEffectLayer *pDamage = DamageEffectLayer::shared();
            const int nDamageSide = m_pRecord != nullptr ? m_pRecord->GetSide() :
                                                           (m_bOwnSide ? 0 : kBoundsColorOwnSide);
            const float flMirrorX = IsSideFlipped() ? 1.0f : -1.0f;
            const float flMirrorY = IsSideFlipped() ? -1.0f : 1.0f;
            pDamage->CreateBoundsDamage(nDamageSide, m_pos.x * flMirrorX, m_pos.y * flMirrorY);
        }
    }

    // A hold note (type 1) keeps its render endpoint tracking the held tail.
    if (m_pRecord != nullptr && m_pRecord->GetType() == kNoteTypeHold) {
        if (m_nWaypointIndex == m_nWaypointCount) {
            // The tail direction is the velocity scaled by the note's target-copy magnitude.
            S_VECTOR2 dirVec = m_velocity;
            ScaleVector2(&dirVec, -static_cast<float>(m_pRecord->GetTargetCopy()));
            const float flMaxLength = Vector2Length(&dirVec);
            NormalizeVector2(&dirVec);

            S_VECTOR2 deltaVec;
            if (m_nWaypointCount == 0) {
                // Straight to the spawn base.
                deltaVec = m_basePos;
                SubtractVector2(&deltaVec, &m_pos);
            } else {
                // To the reflect edge picked by the travel direction.
                const float flInsetHalfX = GameSystem::GetGameSystem()->GetSheetInsetHalfX();
                float flEdgeX;
                float flDistX;
                if (m_velocity.x <= 0.0f) {
                    flDistX = flInsetHalfX - m_pos.x;
                    flEdgeX = flInsetHalfX;
                } else {
                    flDistX = -flInsetHalfX - m_pos.x;
                    flEdgeX = -flInsetHalfX;
                }
                deltaVec.y = (dirVec.y * flDistX) / dirVec.x;
                deltaVec.x = flEdgeX - m_pos.x;
            }

            float flLength = Vector2Length(&deltaVec);
            if (flMaxLength <= flLength) {
                flLength = flMaxLength;
            }
            if (kShotTailMaxLength < flLength) {
                flLength = kShotTailMaxLength;
            }
            m_flShotSpeed = flLength;

            // The render endpoint is the tail direction scaled by the clamped length, from the
            // note.
            S_VECTOR2 endPoint = dirVec;
            ScaleVector2(&endPoint, flLength);
            AddVector2(&endPoint, &m_pos);
            m_flRenderX = endPoint.x;
            m_flRenderY = endPoint.y;
        } else {
            // Still travelling its waypoints: the render endpoint is the current position.
            m_flRenderX = m_pos.x;
            m_flRenderY = m_pos.y;
        }
    }
}

namespace {
// The synthetic-note hold length when it has no chart record (the achievement-rate hash scale,
// reused as a nominal hold duration) (@ghidraAddress 0x2f8540 = 1000).
constexpr float kSyntheticHoldLength = 1000.0f;
// The release-window slack: a held note is released once the judge clock is within this of the
// note's scheduled release (@ghidraAddress 0x308b68 = -83.333).
constexpr float kReleaseWindowSlack = -83.333336f;
} // namespace

/** @ghidraAddress 0x1324c4 */
void NoteModel::UpdateStepLongTouched() {
    const float flJudgeTime =
        PlayTimer::shared()->GetPlayTime() * kApproachTimeScale + kApproachTimeBias;

    // The note's scheduled release time and hold length (from the record, or the synthetic
    // fallback).
    const float flReleaseTime =
        m_pRecord != nullptr ? static_cast<float>(m_pRecord->GetTimeB() + m_pRecord->GetTimeA()) :
                               (m_bOwnSide ? m_flSpawnTime + kSyntheticHitLead : 0.0f);
    const float flHoldLength = m_pRecord != nullptr ?
                                   static_cast<float>(m_pRecord->GetTargetCopy()) :
                                   (m_bOwnSide ? kSyntheticHoldLength : 0.0f);

    // While the hold is still running, track its render endpoint along the reversed velocity by the
    // remaining fraction of the hold.
    const float flRemaining = (flHoldLength + flReleaseTime) - flJudgeTime;
    if (0.0f < flRemaining) {
        S_VECTOR2 dirVec = m_velocity;
        ScaleVector2(&dirVec, -1.0f);
        NormalizeVector2(&dirVec);
        const float flDenominator = m_pRecord != nullptr ?
                                        static_cast<float>(m_pRecord->GetTargetCopy()) :
                                        (m_bOwnSide ? kSyntheticHoldLength : 0.0f);
        float flProgress = flRemaining / flDenominator;
        if (1.0f < flProgress) {
            flProgress = 1.0f;
        }
        m_flShotProgress = flProgress;
        S_VECTOR2 offset = dirVec;
        ScaleVector2(&offset, m_flShotSpeed * flProgress);
        AddVector2(&offset, &m_pos);
        m_flRenderX = offset.x;
        m_flRenderY = offset.y;
        m_bRenderReflectPath = true;
    }

    // Determine whether the held note is still touched this frame.
    bool bTouched;
    if (m_nRivalMode == 1 || m_nRivalMode == kRivalModeGhost) {
        // A CPU or ghost note holds automatically.
        bTouched = true;
    } else if (m_nRivalMode == kRivalModeSpectate) {
        return;
    } else {
        assert(m_nRivalMode == 0);
        // A player note holds while any active touch stays within the sheet's release radius, or
        // unconditionally while the game is paused.
        if (GameSystem::GetGameSystem()->GetPaused()) {
            bTouched = true;
        } else {
            const float flRadius = GameSystem::GetGameSystem()->GetSheetRadius() * 2.0f;
            const float flRadiusSq = flRadius * flRadius;
            bTouched = false;
            TouchManager *pTouchManager = TouchManager::FetchSharedSingleton();
            NoteEffectMgr *pManager = m_pSheet;
            for (int i = 0; i < pTouchManager->GetActiveTouchCount(); ++i) {
                const S_VECTOR2 *pPoint =
                    pManager->GetOrCacheNotePosition(pTouchManager->GetActiveTouch(i)->nId);
                if (pPoint == nullptr) {
                    continue;
                }
                const float flMirrorX = IsSideFlipped() ? 1.0f : -1.0f;
                const float flMirrorY = IsSideFlipped() ? -1.0f : 1.0f;
                const float flDx = m_pos.x * flMirrorX - pPoint->x;
                const float flDy = m_pos.y * flMirrorY - pPoint->y;
                if (flDx * flDx + flDy * flDy < flRadiusSq) {
                    bTouched = true;
                    break;
                }
            }
        }
    }

    // The note resolves once it is no longer touched or the judge clock passes its release slack.
    const bool bResolved =
        bTouched || (flHoldLength + flReleaseTime + kReleaseWindowSlack < flJudgeTime);
    if (bResolved) {
        // The held note ran its full course: finish it as a hit at its stored grade.
        if (flHoldLength + flReleaseTime < flJudgeTime) {
            m_nState = kNoteStateFinished;
            m_nSubState = 0;
            UpdateNotePathLinks();

            ScoreTracker *pTracker = ScoreTracker::shared();
            const int nSide = GetSide();
            const float flMirrorX = IsSideFlipped() ? 1.0f : -1.0f;
            const float flMirrorY = IsSideFlipped() ? -1.0f : 1.0f;
            const int nHoldKind = m_pRecord != nullptr ? m_pRecord->GetHoldKind() :
                                                         (m_bOwnSide ? 0 : kBoundsColorOwnSide);
            pTracker->AddScore(nSide,
                               static_cast<int>(m_pos.x * flMirrorX),
                               static_cast<int>(m_pos.y * flMirrorY),
                               m_nLongGrade,
                               0,
                               nHoldKind == kScoreHoldKind);
            m_nJudgeGrade = m_nLongGrade;

            ExplosionEffectLayer::shared()->CreateExplosionEffect(static_cast<unsigned int>(nSide),
                                                                  m_nLongGrade,
                                                                  m_pos.x * flMirrorX,
                                                                  m_pos.y * flMirrorY);

            ReflecGaugeLayer *pGauge = ReflecGaugeLayer::shared();
            const int nTier = m_pSheet->GetDensityTier();
            ReflecGaugeLayer::AddReflecGaugeValue(
                kGaugeGainByTier[nTier][m_nLongGrade], pGauge, nSide);

            m_pSheet->HandleNoteScored(m_nNoteIndex, nSide);
            PlayNoteTapSound(m_nLongGrade, true);
        }
        // Otherwise the note is still within its release grace: hold it another frame.
    } else {
        // The note was released early: enter the shot state, take the shortfall penalty, and score
        // it as a miss.
        m_nState = kNoteStateShot;
        m_nSubState = 0;
        UpdateNotePathLinks();

        ScoreTracker *pTracker = ScoreTracker::shared();
        const int nSide = GetSide();
        const float flMirrorX = IsSideFlipped() ? 1.0f : -1.0f;
        const float flMirrorY = IsSideFlipped() ? -1.0f : 1.0f;
        pTracker->AddScoreDelta(nSide,
                                static_cast<int>(m_pos.x * flMirrorX),
                                static_cast<int>(m_pos.y * flMirrorY),
                                static_cast<int>((1.0f - m_flShotProgress) * kMissPenaltyScale));

        const int nBonus =
            GameSystem::GetGameSystem()->GetFullJustReflec() ? 0 : (m_bShotResolved ? 1 : 0);
        const int nHoldKind = m_pRecord != nullptr ? m_pRecord->GetHoldKind() :
                                                     (m_bOwnSide ? 0 : kBoundsColorOwnSide);
        pTracker->AddScore(nSide,
                           static_cast<int>(m_pos.x * flMirrorX),
                           static_cast<int>(m_pos.y * flMirrorY),
                           kGradeMiss,
                           nBonus,
                           nHoldKind == kScoreHoldKind);
        m_nJudgeGrade = kGradeMiss;
        m_pSheet->HandleNoteScored(m_nNoteIndex, nSide);
    }
}

namespace {
// The slide step's judge-timing windows around the point's release time: the note's hit time minus
// the current judge clock gives the signed error, which is graded against nested magnitude bands
// (just, near, far). The just-high bound reuses the narrow collection-start constant.
constexpr float kSlideJustHigh = 34.0f;  // 0x2fd00c (shared with g_flCollectionStartYNarrow)
constexpr float kSlideJustLow = -34.0f;  // 0x308b6c
constexpr float kSlideNearHigh = 102.0f; // 0x308b70
constexpr float kSlideNearLow = -102.0f; // 0x308b74
constexpr float kSlideFarLow = -153.0f;  // 0x308b78
constexpr float kSlideFarHigh = 153.0f;  // 0x308b64
// The unresolved slide-point sentinel, the far/miss grade, and the combo cutoff above which an
// unresolved point misses.
constexpr int kSlidePointUnresolved = 5;
constexpr int kSlideGradeMiss = 3;
constexpr int kSlideComboCutoff = 8;
} // namespace

/** @ghidraAddress 0x132be0 */
void NoteModel::UpdateStepSlideExisted() {
    const float flNow = PlayTimer::shared()->GetPlayTime() * kApproachTimeScale + kApproachTimeBias;
    const float flDelta = PlayTimer::shared()->GetFrameDelta();

    // Advance each slide point that has not yet passed its end time: pick the active point (the
    // first whose window contains the clock) and interpolate its live position along its X then Y
    // span.
    const int nPointCount = m_pRecord->GetSlidePointCount();
    for (int nPoint = 0; nPoint < nPointCount; ++nPoint) {
        SubEntry &point = m_aSubEntries[nPoint];
        if (flNow > point.flTime2) {
            continue;
        }
        if (m_nActiveIndex == -1 && point.flTime0 <= flNow && flNow < point.flTime2) {
            m_nActiveIndex = nPoint;
        }
        if (point.flTime0 <= flNow && flNow < point.flTime1) {
            // First span: slide the live X toward the end by the X slope; the Y is unchanged.
            S_VECTOR2 step{point.flSlopeX, 0.0f};
            ScaleVector2(&step, flDelta);
            S_VECTOR2 cur{point.flCurX, point.flCurY};
            AddVector2(&step, &cur);
            point.flCurX = step.x;
            point.flCurY = step.y;
        } else if (flNow >= point.flTime1 && flNow < point.flTime2) {
            // Second span: slide the live Y by the Y slope, clamped to the end Y, snapping X to
            // end.
            S_VECTOR2 step{0.0f, point.flSlopeY};
            ScaleVector2(&step, flDelta);
            S_VECTOR2 cur{point.flCurX, point.flCurY};
            AddVector2(&step, &cur);
            if (point.flEndY < point.flCurY) {
                step.y = point.flEndY;
            }
            point.flCurX = point.flEndX;
            point.flCurY = step.y;
        }
    }

    // Move the note: before its hit time it just advances; otherwise it follows the active point's
    // segment along X, its per-frame direction stored in the first sub-entry's kind slot.
    const int nActive = m_nActiveIndex;
    const float flHitTime = GetHitTime();
    if (nActive == -1 || flNow <= flHitTime) {
        AdvancePosition();
    } else {
        m_prevPos = m_pos;
        // The segment's start time: the note's hit time for the first point, else the previous
        // point's second time.
        const float flSegStart = nActive == 0 ? flHitTime : m_aSubEntries[nActive - 1].flTime2;
        SubEntry &active = m_aSubEntries[nActive];
        // The segment's X velocity is its X span over its time span; the note tracks it toward the
        // segment's end X, snapping the Y to the segment's end Y. Its per-frame travel direction
        // (still, right, or left) is recorded in the second active-kind slot.
        S_VECTOR2 move{(active.flEndX - active.flStartX) / (active.flTime2 - flSegStart), 0.0f};
        m_velocity.x = move.x;
        m_velocity.y = 0.0f;
        if (move.x == 0.0f) {
            m_nActiveKind2 = 0;
            move.y = active.flEndY;
            move.x = active.flEndX;
        } else if (move.x >= 0.0f) {
            m_nActiveKind2 = 1;
            ScaleVector2(&move, flDelta);
            AddVector2(&move, &m_pos);
            if (active.flEndX < m_pos.x) {
                move.x = active.flEndX;
            }
        } else {
            m_nActiveKind2 = 2;
            ScaleVector2(&move, flDelta);
            AddVector2(&move, &m_pos);
            if (m_pos.x < active.flEndX) {
                move.x = active.flEndX;
            }
        }
        m_pos.x = move.x;
        m_pos.y = move.y;
    }

    // Once past the hit time, pin the note to its near-lane target line.
    if (flHitTime < flNow) {
        m_pos.y = g_flPlayfieldNearLaneSlopeNeg * GameSystem::GetGameSystem()->GetSheetInsetHalfY();
    }

    // Decide whether the note is touched this frame (only once the clock is within the release
    // slack of the hit time).
    bool bTouched = false;
    if (flNow > flHitTime + kReleaseWindowSlack) {
        switch (m_nRivalMode) {
        case 0:
            // The auto-assist flag counts the slide as touched outright; otherwise the note is hit
            // only when a live touch falls within twice the sheet radius of its mirrored position.
            if (GameSystem::GetGameSystem()->GetPaused()) {
                bTouched = true;
            } else {
                const float flRadius = GameSystem::GetGameSystem()->GetSheetRadius() * 2.0f;
                const float flRadiusSq = flRadius * flRadius;
                TouchManager *pTouchManager = TouchManager::FetchSharedSingleton();
                NoteEffectMgr *pManager = m_pSheet;
                for (int i = 0; i < pTouchManager->GetActiveTouchCount(); ++i) {
                    const S_VECTOR2 *pPoint =
                        pManager->GetOrCacheNotePosition(pTouchManager->GetActiveTouch(i)->nId);
                    if (pPoint == nullptr) {
                        continue;
                    }
                    const float flMirrorX = IsSideFlipped() ? 1.0f : -1.0f;
                    const float flMirrorY = IsSideFlipped() ? -1.0f : 1.0f;
                    const float flDx = m_pos.x * flMirrorX - pPoint->x;
                    const float flDy = m_pos.y * flMirrorY - pPoint->y;
                    if (flDx * flDx + flDy * flDy < flRadiusSq) {
                        bTouched = true;
                        break;
                    }
                }
            }
            break;
        case 1:
        case kRivalModeGhost:
            // A CPU or ghost note counts as touched once the clock reaches its hit time.
            if (flNow > flHitTime) {
                bTouched = true;
                m_bTouched = true;
            }
            break;
        case kRivalModeSpectate:
            return;
        default:
            assert(0);
        }
    }
    m_bPlayStateFlag510 = bTouched;

    // Score the whole slide the first time it is registered as touched: grade the release timing
    // against the nested just/near/far magnitude bands and resolve the note.
    bool bScoredThisFrame = m_bScored;
    if (!m_bScored && bTouched) {
        if (!m_bTouched) {
            bScoredThisFrame = false;
        } else {
            const float flError = GetHitTime() - GetCurrentJudgeTime();
            unsigned int nGrade = 0;
            if (flError >= kSlideJustHigh || flError <= kSlideJustLow) {
                if (flError >= kSlideNearHigh || flError <= kSlideNearLow) {
                    nGrade = (flError > kSlideFarLow && flError < kSlideFarHigh) ? 2 : 3;
                } else {
                    nGrade = 1;
                }
            }
            // The first slide point's incoming grade gates whether the timing grade counts (a slide
            // that never registered a point scores as a plain hit).
            const unsigned int nResolveGrade = m_aSubEntries[0].nIncomingGrade != 0 ? nGrade : 0;
            ResolveNoteHit(nResolveGrade);
            bScoredThisFrame = true;
            m_bScored = true;
        }
    }

    // Tally the frame's outcome onto the active point once past the hit time: an unscored frame (or
    // a scored frame that was not touched this frame) bumps the point's miss/combo tally, while a
    // scored-and-touched frame bumps its hit tally (the resolve loop reads a zero hit tally as a
    // miss).
    if (GetHitTime() <= flNow) {
        if (!bScoredThisFrame) {
            if (m_nActiveIndex >= 0) {
                ++m_aSubEntries[m_nActiveIndex].nMissCount;
            }
        } else {
            if (!m_bPlayStateFlag510 && m_nActiveIndex >= 0) {
                ++m_aSubEntries[m_nActiveIndex].nMissCount;
            }
            if (m_bPlayStateFlag510 && m_nActiveIndex >= 0) {
                ++m_aSubEntries[m_nActiveIndex].nSlidePointJudge;
            }
        }
    }

    // Resolve each passed, still-unresolved slide point: pick its grade, fire its burst and tap
    // sound (unless it grades far), and add its score and gauge gain.
    for (int nPoint = 0; nPoint < m_pRecord->GetSlidePointCount(); ++nPoint) {
        SubEntry &point = m_aSubEntries[nPoint];
        if (!(point.flTime2 < flNow && point.nResolvedGrade == kSlidePointUnresolved)) {
            continue;
        }

        if (point.nIncomingGrade == kSlidePointUnresolved) {
            if (point.nSlidePointJudge == 0 || point.nMissCount > kSlideComboCutoff) {
                point.nResolvedGrade = kSlideGradeMiss;
            } else {
                point.nResolvedGrade = 0;
                ExplosionEffectLayer::shared()->CreateExplosionEffect(
                    static_cast<unsigned int>(GetSide()),
                    point.nResolvedGrade,
                    m_pos.x * (IsSideFlipped() ? 1.0f : -1.0f),
                    m_pos.y * (IsSideFlipped() ? -1.0f : 1.0f));
                PlayNoteTapSound(0, true);
            }
        } else {
            point.nResolvedGrade = point.nIncomingGrade;
            if (point.nResolvedGrade != kSlideGradeMiss) {
                ExplosionEffectLayer::shared()->CreateExplosionEffect(
                    static_cast<unsigned int>(GetSide()),
                    point.nResolvedGrade,
                    m_pos.x * (IsSideFlipped() ? 1.0f : -1.0f),
                    m_pos.y * (IsSideFlipped() ? -1.0f : 1.0f));
                PlayNoteTapSound(0, true);
            }
        }

        ScoreTracker *pTracker = ScoreTracker::shared();
        const int nSide = GetSide();
        const float flMirrorX = IsSideFlipped() ? 1.0f : -1.0f;
        const float flMirrorY = IsSideFlipped() ? -1.0f : 1.0f;
        const int nHoldKind = m_pRecord != nullptr ? m_pRecord->GetHoldKind() :
                                                     (m_bOwnSide ? 0 : kBoundsColorOwnSide);
        pTracker->AddScore(nSide,
                           static_cast<int>(m_pos.x * flMirrorX),
                           static_cast<int>(m_pos.y * flMirrorY),
                           point.nResolvedGrade,
                           0,
                           nHoldKind == kScoreHoldKind);

        ReflecGaugeLayer *pGauge = ReflecGaugeLayer::shared();
        const int nTier = m_pSheet->GetDensityTier();
        ReflecGaugeLayer::AddReflecGaugeValue(
            kGaugeGainByTier[nTier][point.nResolvedGrade], pGauge, nSide);
    }

    // Finish the note once the last slide point's second-time boundary has passed.
    const int nLast = m_pRecord->GetSlidePointCount() - 1;
    if (m_aSubEntries[nLast].flTime2 < flNow) {
        m_nState = kNoteStateFinished;
        m_nSubState = 0;
        m_pSheet->HandleNoteScored(m_nNoteIndex, GetSide());
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

namespace {

// The note states that draw: the render pass skips any state outside [1, 7].
constexpr int kRenderStateFirst = 1;
constexpr int kRenderStateCount = 7;

// The note type the render pass gives its own body layer: the long note and the slide note. Every
// other type, and a note with no chart record at all, takes the plain note body.
constexpr int kRenderTypeLongNote = 1;
constexpr int kRenderTypeSlideNote = 3;

// The side a note with no chart record reports: its own side draws as colour 0, the other side
// takes the no-side sentinel.
constexpr int kRenderSideOwn = 0;
constexpr int kRenderSideNone = 3;

// The game type whose rival side is always drawn, and the rival modes that hide a slide segment on
// the other play side.
constexpr int kRenderGameTypeVersus = 1;
constexpr int kRenderRivalModeHiddenFirst = 1;
constexpr int kRenderRivalModeHiddenCount = 2;

// The note's end-cap flag: the link's second bit must be clear and the timing selector under its
// bound.
constexpr int kRenderLinkEndCapMask = 2;
constexpr int kRenderTimingSelBound = 10;

// The long-note state that draws a trail, and the grade bound above which no trail is drawn.
constexpr int kRenderLongTrailState = 3;
constexpr int kRenderLongTrailGradeBound = 3;

// The play clock the slide-point windows are tested against: the play time scaled into chart units,
// then biased.
constexpr float kRenderPlayClockScale = 1000.0f;   // @ghidraAddress 0x2f8540
constexpr float kRenderPlayClockOffset = -1500.0f; // @ghidraAddress 0x308b60

// The quarter turn the shot angle is rotated by before it reaches the charge layer.
constexpr float kRenderChargeAngleOffset = 1.5707963267948966f; // @ghidraAddress 0x2fedd8 (pi/2)

// The partner states that draw no chain connector: the unset state and the retired state. The
// binary folds both into `(state | 8) != 8`.
constexpr int kRenderChainSkipStateUnset = 0;
constexpr int kRenderChainSkipStateRetired = 8;

// The play side mirrors every position and direction the render pass emits.
constexpr float kRenderMirrorPositive = 1.0f;
constexpr float kRenderMirrorNegative = -1.0f;

} // namespace

// The side flip negates X on the near side and Y on the flipped one. The binary re-tests the flip
// for every single coordinate it mirrors, so these stay per-coordinate calls.
float NoteModel::MirrorRenderX(float flX) const {
    return flX * (IsSideFlipped() != 0 ? kRenderMirrorPositive : kRenderMirrorNegative);
}

float NoteModel::MirrorRenderY(float flY) const {
    return flY * (IsSideFlipped() != 0 ? kRenderMirrorNegative : kRenderMirrorPositive);
}

int NoteModel::GetRenderSide() const {
    if (m_pRecord != nullptr) {
        return m_pRecord->GetSide();
    }
    return m_bOwnSide ? kRenderSideOwn : kRenderSideNone;
}

bool NoteModel::HasRenderEndCap() const {
    // The binary reads the link word without re-checking the record, so a note with no record
    // dereferences null here. The null test is ours; the shipped code has none.
    if (m_pRecord == nullptr) {
        return false;
    }
    const unsigned int nTimingSel = static_cast<unsigned int>(m_pRecord->GetTimingSel());
    return (m_pRecord->GetLinkA() & kRenderLinkEndCapMask) == 0 &&
           nTimingSel < kRenderTimingSelBound;
}

/** @ghidraAddress 0x135388 */
void NoteModel::RenderNote() {
    // A note on the other play side is drawn only when the rival side is visible at all, or the
    // game type always shows it.
    if (GameSystem::GetGameSystem()->GetRivalAlpha() == 0.0f &&
        GameSystem::GetGameSystem()->GetGameType() != kRenderGameTypeVersus &&
        IsOnPlaySide() == 0) {
        return;
    }
    if (static_cast<unsigned int>(m_nState - kRenderStateFirst) >= kRenderStateCount) {
        return;
    }

    const int nType = m_pRecord != nullptr ? m_pRecord->GetType() : 0;
    if (m_pRecord != nullptr && nType == kRenderTypeSlideNote) {
        RenderSlideNote();
    } else if (m_pRecord != nullptr && nType == kRenderTypeLongNote && m_pos.x == m_flRenderX &&
               m_pos.y == m_flRenderY) {
        RenderLongNote(true);
    } else if (m_pRecord != nullptr && nType == kRenderTypeLongNote) {
        RenderLongNote(false);
    } else {
        RenderPlainNote();
    }

    RenderChainConnector();

    // A resolved shot leaves its charge on the field, angled along the note's travel direction.
    if (m_bShotResolved) {
        const float flAngle =
            static_cast<float>(atan2(static_cast<double>(MirrorRenderY(m_velocity.y)),
                                     static_cast<double>(-MirrorRenderX(m_velocity.x)))) +
            kRenderChargeAngleOffset;
        NoteChargeLayer::shared()->Create(GetRenderSide(),
                                          MirrorRenderX(m_pos.x),
                                          MirrorRenderY(m_pos.y),
                                          flAngle,
                                          m_flFadeTimer);
    }
}

/** @ghidraAddress 0x135388 */
void NoteModel::RenderPlainNote() {
    NoteLayer *const pLayer = NoteLayer::shared();
    const int nSide = GetRenderSide();
    const int nHoldKind = m_pRecord != nullptr ? m_pRecord->GetHoldKind() :
                                                 (m_bOwnSide ? kRenderSideOwn : kRenderSideNone);
    const bool bEndCap = HasRenderEndCap();
    const int nHasPoints = m_pRecord != nullptr && m_pRecord->GetPointCount() > 0 ? 1 : 0;
    const int nSpawnTrail = m_pRecord != nullptr ? static_cast<int>(m_pRecord->GetFlags() & 1) : 0;

    pLayer->Create(nSide,
                   nHoldKind,
                   bEndCap ? 1 : 0,
                   nHasPoints,
                   nSpawnTrail,
                   MirrorRenderX(m_pos.x),
                   MirrorRenderY(m_pos.y),
                   MirrorRenderX(m_velocity.x),
                   MirrorRenderY(m_velocity.y),
                   m_flAppearScale,
                   m_flFadeTimer);
}

/** @ghidraAddress 0x135388 */
void NoteModel::RenderSlideNote() {
    const bool bResultReady = m_bPlayStateFlag510 && m_bScored;

    SlideNoteLayer::shared()->Create(GetRenderSide(),
                                     m_bScored,
                                     m_nActiveKind2,
                                     MirrorRenderX(m_pos.x),
                                     MirrorRenderY(m_pos.y),
                                     MirrorRenderX(m_pos.x),
                                     MirrorRenderY(m_pos.y),
                                     m_flFadeTimer,
                                     bResultReady,
                                     m_bRenderShotTail,
                                     0,
                                     0);
    if (bResultReady) {
        SlideNoteResultLayer::shared()->Create(
            0, S_VECTOR2{MirrorRenderX(m_pos.x), MirrorRenderY(m_pos.y)});
    }

    // Each slide point whose window contains the play clock draws a segment from the previous
    // point's live position (or from the note itself, for the first and the active point) to its
    // own.
    const float flPlayClock =
        PlayTimer::shared()->GetPlayTime() * kRenderPlayClockScale + kRenderPlayClockOffset;
    for (int i = 0; i < m_pRecord->GetSlidePointCount(); ++i) {
        const SubEntry &point = m_aSubEntries[i];
        if (point.flTime0 > flPlayClock || flPlayClock > point.flTime2) {
            continue;
        }
        if (static_cast<unsigned int>(m_nRivalMode - kRenderRivalModeHiddenFirst) <
                kRenderRivalModeHiddenCount &&
            IsOnPlaySide() == 0) {
            continue;
        }

        float flStartX = 0.0f;
        float flStartY = 0.0f;
        int nKind = kRenderSideNone;
        unsigned char nTailFlag = 0;
        if (!point.bLastPoint) {
            if (i == 0 || i == m_nActiveIndex) {
                flStartX = m_pos.x;
                flStartY = m_pos.y;
            } else {
                flStartX = m_aSubEntries[i - 1].flCurX;
                flStartY = m_aSubEntries[i - 1].flCurY;
            }
            nKind = point.nKind;
        } else {
            // The final point starts at the preceding point until the path's own end time passes,
            // and at the note itself after it. The binary indexes both the end time and the
            // preceding point without a lower bound, so a one-point path reads off the front of the
            // sub-entry table; the bounds tests are ours.
            const int nPathEndIndex = m_pRecord->GetSlidePointCount() - 2;
            const float flPathEndTime =
                nPathEndIndex >= 0 ? m_aSubEntries[nPathEndIndex].flTime2 : flPlayClock;
            if (flPlayClock <= flPathEndTime && i > 0) {
                flStartX = m_aSubEntries[i - 1].flCurX;
                flStartY = m_aSubEntries[i - 1].flCurY;
            } else {
                flStartX = m_pos.x;
                flStartY = m_pos.y;
            }
            nTailFlag = 1;
        }

        SlideNoteLayer::shared()->Create(GetRenderSide(),
                                         m_bScored ? 1 : 0,
                                         nKind,
                                         MirrorRenderX(flStartX),
                                         MirrorRenderY(flStartY),
                                         MirrorRenderX(point.flCurX),
                                         MirrorRenderY(point.flCurY),
                                         m_flFadeTimer,
                                         m_bPlayStateFlag510 && m_bScored,
                                         m_bRenderShotTail,
                                         nTailFlag,
                                         nTailFlag);
    }
}

/** @ghidraAddress 0x135388 */
void NoteModel::RenderLongNote(bool bAtRenderPoint) {
    LongNoteLayer *const pLayer = LongNoteLayer::shared();
    const int nSide = GetRenderSide();
    const int nHoldKind = m_pRecord != nullptr ? m_pRecord->GetHoldKind() :
                                                 (m_bOwnSide ? kRenderSideOwn : kRenderSideNone);
    const bool bEndCap = HasRenderEndCap();

    // The body runs from the note to its render endpoint. While the note still sits on that
    // endpoint the segment is angled along the travel direction; once it has left, it is drawn
    // flat.
    float flRotation = 0.0f;
    unsigned char nRotated = 0;
    if (bAtRenderPoint) {
        flRotation = static_cast<float>(atan2(static_cast<double>(-MirrorRenderY(m_velocity.y)),
                                              static_cast<double>(MirrorRenderX(m_velocity.x)))) +
                     kRenderChargeAngleOffset;
        nRotated = 1;
    }

    pLayer->Create(nSide,
                   nHoldKind == 1,
                   bEndCap,
                   MirrorRenderX(m_pos.x),
                   MirrorRenderY(m_pos.y),
                   MirrorRenderX(m_flRenderX),
                   MirrorRenderY(m_flRenderY),
                   m_bRenderReflectPath,
                   m_bRenderShotTail,
                   m_flFadeTimer,
                   nRotated,
                   flRotation);

    // A held note that has been graded leaves its trail behind.
    if (m_nState == kRenderLongTrailState &&
        static_cast<unsigned int>(m_nLongGrade) < kRenderLongTrailGradeBound) {
        NoteTrailLayer::shared()->Create(
            m_nLongGrade, MirrorRenderX(m_pos.x), MirrorRenderY(m_pos.y));
    }

    // A long note whose record asks for one also spawns a head particle, until the shot tail takes
    // over the note's rendering.
    if (m_pRecord != nullptr && (m_pRecord->GetFlags() & 1) != 0 && !m_bRenderShotTail) {
        NoteLayer::shared()->SpawnParticle(MirrorRenderX(m_pos.x),
                                           MirrorRenderY(m_pos.y),
                                           m_flAppearScale,
                                           m_flFadeTimer,
                                           GetRenderSide());
    }
}

/** @ghidraAddress 0x135388 */
void NoteModel::RenderChainConnector() {
    if (m_pRecord == nullptr || m_pRecord->GetChainLink().IsHead()) {
        return;
    }
    NoteModel *const pPartner = m_pSheet->FindNoteByIndex(m_pRecord->GetChainLink().GetChainId());
    if (pPartner == nullptr) {
        return;
    }
    // The connector is skipped while the partner is unset or already retired; the binary folds both
    // states into a single `(state | 8) != 8` test.
    if (pPartner->m_nState == kRenderChainSkipStateUnset ||
        pPartner->m_nState == kRenderChainSkipStateRetired) {
        return;
    }
    ChainConnectorLayer::shared()->Create(GetRenderSide(),
                                          MirrorRenderX(m_pos.x),
                                          MirrorRenderY(m_pos.y),
                                          pPartner->MirrorRenderX(pPartner->m_pos.x),
                                          pPartner->MirrorRenderY(pPartner->m_pos.y));
}

namespace {

// The bounce-band lookup tables. Each maps a bounce position in [0, 6] onto the play-field band its
// bounce point takes; the reflect route's lane table is instead indexed by the record's display
// lane. @ghidraAddress 0x308bb4, 0x308bd0, 0x308bec, 0x308c08
constexpr int kSingleBounceBandMap[] = {-2, -2, -1, 0, 1, 2, 2};
constexpr int kDoubleBounceBandMap[] = {0, 0, 1, 1, 1, 2, 2};
constexpr int kReflectBounceBandMap[] = {-2, -1, -1, 0, 1, 1, 2};
constexpr int kReflectLaneBandMap[] = {-2, 0, 2};

// The band each route kind measures its bounce from, and the range it clamps the result into before
// asking for that band's Y bound.
constexpr int kSingleBounceBaseBand = 3;
constexpr int kSingleBounceMinBand = 2;
constexpr int kSingleBounceMaxBand = 5;
constexpr int kReflectBounceBaseBand = 2;
constexpr int kReflectBounceMinBand = 1;
constexpr int kReflectBounceMaxBand = 4;
constexpr int kDoubleBounceMinBand = 0;
constexpr int kDoubleBounceMaxBand = 7;

// The double bounce's second point sits a fixed step past the first, and a forward shot mirrors a
// lane or band through the middle of the seven bounce positions.
constexpr int kDoubleBounceSecondStep = 5;
constexpr int kBounceMirrorSpan = 6;

// The bounce band a note takes on its own play side, and on the other one.
constexpr int kBounceBandPlaySide = 6;
constexpr int kBounceBandOtherSide = 3;

// The display lane a note with no chart record falls back to, and the marker the other side takes.
constexpr int kRouteLaneOwnSide = 3;
constexpr int kRouteLaneNone = -1;

// The two route kinds SetRoute lays out. A synthetic note on the other play side has no route kind
// and takes the third value, which the binary asserts on.
constexpr int kRouteKindPlain = 0;
constexpr int kRouteKindReflect = 1;
constexpr int kRouteKindNone = 3;

// A route with n bounces fills n + 2 nodes: the spawn point, one per bounce, and the target line.
constexpr int kRouteEndpointCount = 2;

// The route never builds a segment past the third node.
constexpr int kRouteMaxSegmentCount = 3;

// The size of the whole waypoint block, cleared in one span.
constexpr int kWaypointBlockSize = kWaypointBlockNodeCount * static_cast<int>(sizeof(WaypointNode));

int ClampBounceBand(int nBand, int nMin, int nMax) {
    if (nBand > nMax) {
        return nMax;
    }
    return nBand < nMin ? nMin : nBand;
}

// The route writes a node's start coordinate only when that node is within the live part of the
// block. Every guarded write in the route passes takes this shape.
void SetNodeStartX(WaypointNode *pBlock, int nIndex, int nLiveCount, float flX) {
    if (nIndex < nLiveCount) {
        pBlock[nIndex].startPos.x = flX;
    }
}

void SetNodeStartY(WaypointNode *pBlock, int nIndex, int nLiveCount, float flY) {
    if (nIndex < nLiveCount) {
        pBlock[nIndex].startPos.y = flY;
    }
}

} // namespace

/** @ghidraAddress 0x13498c */
void NoteModel::BuildRouteWaypoints(int nRouteKind) {
    const int nLiveCount = m_nWaypointCount + kRouteEndpointCount;
    // The bounce bands are keyed off the play side, and the lane off the chart record; a synthetic
    // note falls back to its own-side lane. The binary re-derives both inline at every use.
    const int nBand = IsOnPlaySide() != 0 ? kBounceBandPlaySide : kBounceBandOtherSide;
    const int nLane = m_pRecord != nullptr ? m_pRecord->GetDisplayLane() :
                                             (m_bOwnSide ? kRouteLaneOwnSide : kRouteLaneNone);
    const GameSystem *pGameSystem = GameSystem::GetGameSystem();
    const float flInsetHalfX = pGameSystem->GetSheetInsetHalfX();
    const float flInsetHalfY = pGameSystem->GetSheetInsetHalfY();

    // The Y pass. A reflect note bounces once off a band derived from its lane; a plain note
    // bounces once or twice depending on the magnitude of its shot direction.
    if (nRouteKind == kRouteKindReflect) {
        assert(m_nDirectionSign >= -1 && m_nDirectionSign <= 1);
        if (m_nDirectionSign != 0) {
            const int nRawBand = m_nDirectionSign < 0 ?
                                     (kReflectLaneBandMap[nLane] + kReflectBounceBaseBand) -
                                         kReflectBounceBandMap[nBand] :
                                     (kReflectBounceBaseBand - kReflectLaneBandMap[nLane]) +
                                         kReflectBounceBandMap[nBand];
            const int nBounceBand =
                ClampBounceBand(nRawBand, kReflectBounceMinBand, kReflectBounceMaxBand);
            SetNodeStartY(m_aWaypointBlock, 0, nLiveCount, m_basePos.y);
            SetNodeStartY(
                m_aWaypointBlock, 1, nLiveCount, GetVirtualBoundY(nBounceBand) * flInsetHalfY);
            SetNodeStartY(m_aWaypointBlock, 2, nLiveCount, GetTargetLineY());
        } else {
            SetNodeStartY(m_aWaypointBlock, 0, nLiveCount, m_basePos.y);
            SetNodeStartY(m_aWaypointBlock, 1, nLiveCount, GetTargetLineY());
        }
    } else {
        assert(nRouteKind == kRouteKindPlain);
        switch (m_nDirectionSign) {
        case 0:
            SetNodeStartY(m_aWaypointBlock, 0, nLiveCount, m_basePos.y);
            SetNodeStartY(m_aWaypointBlock, 1, nLiveCount, GetTargetLineY());
            break;
        case -1:
        case 1: {
            const int nRawBand = m_nDirectionSign < 0 ?
                                     (kSingleBounceBaseBand - kSingleBounceBandMap[nLane]) +
                                         kSingleBounceBandMap[nBand] :
                                     (kSingleBounceBandMap[nLane] + kSingleBounceBaseBand) -
                                         kSingleBounceBandMap[nBand];
            const int nBounceBand =
                ClampBounceBand(nRawBand, kSingleBounceMinBand, kSingleBounceMaxBand);
            // The binary seeds all three nodes with the base Y, writes node 0 a second time, then
            // overwrites nodes 1 and 2. The repeat is kept for fidelity.
            for (int i = 0; i < kRouteMaxSegmentCount; ++i) {
                SetNodeStartY(m_aWaypointBlock, i, nLiveCount, m_basePos.y);
            }
            SetNodeStartY(m_aWaypointBlock, 0, nLiveCount, m_basePos.y);
            SetNodeStartY(
                m_aWaypointBlock, 1, nLiveCount, GetVirtualBoundY(nBounceBand) * flInsetHalfY);
            SetNodeStartY(m_aWaypointBlock, 2, nLiveCount, GetTargetLineY());
            break;
        }
        case -2:
        case 2: {
            // A double bounce takes one band from the play side and one from the lane; a forward
            // shot mirrors both through the middle bounce position.
            int anRawBands[2];
            if (m_nDirectionSign < 0) {
                anRawBands[0] = kDoubleBounceBandMap[nBand];
                anRawBands[1] = kDoubleBounceBandMap[nLane] + kDoubleBounceSecondStep;
            } else {
                anRawBands[0] = kDoubleBounceBandMap[kBounceMirrorSpan - nBand];
                anRawBands[1] =
                    kDoubleBounceBandMap[kBounceMirrorSpan - nLane] + kDoubleBounceSecondStep;
            }
            for (int i = 0; i < 2; ++i) {
                const int nBounceBand =
                    ClampBounceBand(anRawBands[i], kDoubleBounceMinBand, kDoubleBounceMaxBand);
                SetNodeStartY(m_aWaypointBlock,
                              i + 1,
                              nLiveCount,
                              GetVirtualBoundY(nBounceBand) * flInsetHalfY);
            }
            SetNodeStartY(m_aWaypointBlock, 0, nLiveCount, m_basePos.y);
            SetNodeStartY(m_aWaypointBlock, 3, nLiveCount, GetTargetLineY());
            break;
        }
        default:
            assert(false);
            break;
        }
    }

    // The X pass. Every route starts at the base position and ends on its lane; each bounce in
    // between is thrown at an alternating field edge.
    assert(nRouteKind != kRouteKindReflect || (m_nDirectionSign >= -1 && m_nDirectionSign <= 1));
    SetNodeStartX(m_aWaypointBlock, 0, nLiveCount, m_basePos.x);
    switch (m_nDirectionSign) {
    case 0:
        SetNodeStartX(m_aWaypointBlock, 1, nLiveCount, GetLaneX());
        break;
    case 1:
        SetNodeStartX(m_aWaypointBlock, 1, nLiveCount, flInsetHalfX);
        SetNodeStartX(m_aWaypointBlock, 2, nLiveCount, GetLaneX());
        break;
    case -1:
        SetNodeStartX(m_aWaypointBlock, 1, nLiveCount, -flInsetHalfX);
        SetNodeStartX(m_aWaypointBlock, 2, nLiveCount, GetLaneX());
        break;
    case 2:
        SetNodeStartX(m_aWaypointBlock, 1, nLiveCount, flInsetHalfX);
        SetNodeStartX(m_aWaypointBlock, 2, nLiveCount, -flInsetHalfX);
        SetNodeStartX(m_aWaypointBlock, 3, nLiveCount, GetLaneX());
        break;
    case -2:
        SetNodeStartX(m_aWaypointBlock, 1, nLiveCount, -flInsetHalfX);
        SetNodeStartX(m_aWaypointBlock, 2, nLiveCount, flInsetHalfX);
        SetNodeStartX(m_aWaypointBlock, 3, nLiveCount, GetLaneX());
        break;
    default:
        assert(false);
        break;
    }
}

/** @ghidraAddress 0x13498c */
void NoteModel::FinishRoute() {
    // Each node's end position becomes the offset to the next node, and its length that offset's
    // magnitude.
    float flTotalLength = 0.0f;
    for (int i = 0; i <= m_nWaypointCount && i < kRouteMaxSegmentCount; ++i) {
        WaypointNode &node = m_aWaypointBlock[i];
        node.endPos = m_aWaypointBlock[i + 1].startPos;
        SubtractVector2(&node.endPos, &node.startPos);
        node.flLength = Vector2Length(&node.endPos);
        flTotalLength += node.flLength;
    }

    // The path is walked at one speed from the spawn time to the hit time, so each segment's share
    // of the total length is its share of that span.
    const float flHitTime = GetHitTime();
    if (m_nWaypointCount + kRouteEndpointCount > 0) {
        m_aWaypointBlock[0].flStartTime = m_flSpawnTime;
    }
    if (m_nWaypointCount >= 0) {
        const float flSpeed = flTotalLength / (flHitTime - m_flSpawnTime);
        for (int i = 0; i <= m_nWaypointCount && i < kRouteMaxSegmentCount; ++i) {
            WaypointNode &node = m_aWaypointBlock[i];
            // Scaling the segment delta by speed over length turns it into the segment's velocity.
            ScaleVector2(&node.endPos, flSpeed / node.flLength);
            m_aWaypointBlock[i + 1].flStartTime = node.flStartTime + node.flLength / flSpeed;
        }
    }

    // The node past the last bounce starts at the hit time. The binary folds both bounds into one
    // unsigned compare, and recomputes the hit time here rather than reusing the value above.
    const int nFinalNode = m_nWaypointCount + 1;
    if (nFinalNode >= 0 && nFinalNode < kWaypointBlockNodeCount) {
        m_aWaypointBlock[nFinalNode].flStartTime = flHitTime;
    }

    if (m_pCurrentWaypoint != nullptr) {
        m_velocity = m_pCurrentWaypoint->endPos;
    }
}

/** @ghidraAddress 0x13498c */
void NoteModel::SetRoute() {
    memset(m_aWaypointBlock, 0, kWaypointBlockSize);

    if (m_pRecord != nullptr && !m_pRecord->GetChainLink().IsHead()) {
        // A note partway along a chain copies its head note's route outright rather than deriving
        // its own; the chain-link block's chain id doubles as the head note's index.
        NoteModel *const pHead = m_pSheet->FindNoteByIndex(m_pRecord->GetChainLink().GetChainId());
        if (pHead != nullptr) {
            m_nDirectionSign = pHead->m_nDirectionSign;
            m_nWaypointCount = pHead->m_nWaypointCount;
            const int nHeadLiveCount = pHead->m_nWaypointCount + kRouteEndpointCount;
            for (int i = 0; i < m_nWaypointCount + kRouteEndpointCount; ++i) {
                if (i < kWaypointBlockNodeCount && i < nHeadLiveCount) {
                    m_aWaypointBlock[i].startPos = pHead->m_aWaypointBlock[i].startPos;
                }
            }
        }
    } else {
        // A head note takes its record's hold kind; a synthetic note routes as a plain note on its
        // own side, and has no route at all on the other one.
        const int nRouteKind = m_pRecord != nullptr ?
                                   m_pRecord->GetHoldKind() :
                                   (m_bOwnSide ? kRouteKindPlain : kRouteKindNone);
        BuildRouteWaypoints(nRouteKind);
    }

    FinishRoute();
}

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
    NoteEffectMgr *pManager = m_pSheet;
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
        NoteModel *pNote = m_pSheet->FindNoteByIndex(m_pRecord->GetStartTime());
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
// The gauge/effect colour a record-less note reports: its own side when set, otherwise the
// no-partner sentinel.
constexpr int kShotColorOwnSide = 0;
constexpr int kShotColorNoPartner = 3;
// The CPU shot's per-note auto-play modes: user-driven full combo, CPU-driven full combo.
constexpr int kAutoShotModeUser = 0;
constexpr int kAutoShotModeCpu = 1;
// The random threshold that splits a bounce into its two directions, and the display lanes.
constexpr float kShotDirectionSplit = 0.5f;
// Folds a rand() result into the unit interval (@ghidraAddress 0x3014d0 = 1 / RAND_MAX).
constexpr float kInverseRandMax = 1.0f / 2147483647.0f;
constexpr int kDisplayLaneCentre = 0;
constexpr int kDisplayLaneLeft = 1;
constexpr int kDisplayLaneRight = 2;
} // namespace

/** @ghidraAddress 0x136480 */
void NoteModel::CheckShotCPU() {
    if (m_bShotDecaying) {
        ReflecGaugeLayer *pGauge = ReflecGaugeLayer::shared();
        const int nColor = m_pRecord != nullptr ?
                               m_pRecord->GetSide() :
                               (m_bOwnSide ? kShotColorOwnSide : kShotColorNoPartner);
        // Only a filled opposing gauge lets the CPU note score.
        if (pGauge->GetAnotherValue(nColor) >= 1.0f) {
            // Score the note when it is emphasised, or when its side's full-combo run is still
            // live.
            bool bScore = ShouldEmphasize();
            if (!bScore) {
                if (m_nAutoShotMode == kAutoShotModeUser &&
                    GameSystem::GetGameSystem()->GetUserFullCombo()) {
                    bScore = true;
                } else {
                    bScore = m_nAutoShotMode == kAutoShotModeCpu &&
                             GameSystem::GetGameSystem()->GetCpuFullCombo();
                }
            }
            if (bScore) {
                const int nSubColor = m_pRecord != nullptr ?
                                          m_pRecord->GetSide() :
                                          (m_bOwnSide ? kShotColorOwnSide : kShotColorNoPartner);
                ReflecGaugeLayer::SubReflecGaugeValue(1.0f, pGauge, nSubColor);
                m_bShotResolved = true;
                ScoreTracker *pTracker = ScoreTracker::shared();
                pTracker->AddLaneJudgeResult(
                    IsOnPlaySide(),
                    static_cast<unsigned int>(GameSystem::GetGameSystem()->GetFullJustReflec()));
            }
        }
    }

    // Once resolved, choose the bounce direction.
    if (m_bShotResolved) {
        SetShotDirection(PickShotBounceDirection());
    }
    m_bShotActive = false;
}

/** @ghidraAddress 0x13663c */
void NoteModel::CheckShotGhost() {
    // Subtracts one from the opposing gauge, marks the shot resolved, and records the lane judge
    // result — the score-and-record block the binary inlines at each ghost scoring site.
    const auto scoreShot = [&](ReflecGaugeLayer *pGauge) {
        const int nColor = m_pRecord != nullptr ?
                               m_pRecord->GetSide() :
                               (m_bOwnSide ? kShotColorOwnSide : kShotColorNoPartner);
        ReflecGaugeLayer::SubReflecGaugeValue(1.0f, pGauge, nColor);
        m_bShotResolved = true;
        ScoreTracker::shared()->AddLaneJudgeResult(
            IsOnPlaySide(),
            static_cast<unsigned int>(GameSystem::GetGameSystem()->GetFullJustReflec()));
    };

    if (m_bShotDecaying) {
        ReflecGaugeLayer *pGauge = ReflecGaugeLayer::shared();
        const int nColor = m_pRecord != nullptr ?
                               m_pRecord->GetSide() :
                               (m_bOwnSide ? kShotColorOwnSide : kShotColorNoPartner);
        if (pGauge->GetAnotherValue(nColor) >= 1.0f) {
            // A ghost/replay note scores directly; a non-ghost note scores by emphasis or its
            // side's live full-combo run, and otherwise consumes a queued hit from the manager.
            bool bScoreDirect = m_bEmphasisFallback;
            if (!bScoreDirect) {
                if (m_nAutoShotMode == kAutoShotModeUser &&
                    GameSystem::GetGameSystem()->GetUserFullCombo()) {
                    bScoreDirect = true;
                } else {
                    bScoreDirect = m_nAutoShotMode == kAutoShotModeCpu &&
                                   GameSystem::GetGameSystem()->GetCpuFullCombo();
                }
            }
            if (bScoreDirect) {
                scoreShot(pGauge);
            } else if (NoteEffectMgr::shared()->GetHitCount() > 0) {
                scoreShot(pGauge);
                NoteEffectMgr::shared()->DecrementHitCount();
            }
        }
    }

    // A ghost note that did not score feeds a hit back into the manager's queue.
    if (m_bEmphasisFallback && !m_bShotResolved) {
        NoteEffectMgr::shared()->IncrementHitCount();
    }

    if (m_bShotResolved) {
        SetShotDirection(PickShotBounceDirection());
    }
    m_bShotActive = false;
}

int NoteModel::PickShotBounceDirection() const {
    // A hold note follows its display lane; any other note flips a coin between the two outer
    // directions.
    if (m_pRecord != nullptr && m_pRecord->GetHoldKind() == kHoldKindHead) {
        const int nLane = m_pRecord->GetDisplayLane();
        if (nLane == kDisplayLaneCentre) {
            return -1;
        }
        if (nLane == kDisplayLaneLeft) {
            return static_cast<float>(rand()) * kInverseRandMax >= kShotDirectionSplit ? 1 : -1;
        }
        assert(nLane == kDisplayLaneRight);
        return 1;
    }
    return static_cast<float>(rand()) * kInverseRandMax >= kShotDirectionSplit ? 2 : -2;
}

namespace {
// The minimum horizontal touch drag, in pixels, that a player flick must exceed to shoot a note.
constexpr float kPlayerFlickThreshold = 20.0f;
} // namespace

/** @ghidraAddress 0x1361ec */
void NoteModel::CheckShotPlayer() {
    // The player cannot shoot while paused or once the shot lifetime has run out.
    if (GameSystem::GetGameSystem()->GetPaused() || m_flShotDecayTimer <= 0.0f) {
        return;
    }

    TouchManager *pTouchManager = TouchManager::FetchSharedSingleton();
    const float flDiameterSq = GameSystem::GetGameSystem()->GetSheetDiameterSq();
    NoteEffectMgr *pManager = m_pSheet;
    const int nActive = pTouchManager->GetActiveTouchCount();
    for (int i = 0; i < nActive; ++i) {
        TouchPoint *pTouch = pTouchManager->GetActiveTouch(i);
        const S_VECTOR2 *pTouchPos = pManager->GetOrCacheNotePosition(pTouch->nId);
        if (pTouchPos == nullptr) {
            continue;
        }

        // The touch must fall within the note's catch radius (mirrored to the note's side).
        const float flSideX = m_pos.x * (IsSideFlipped() ? 1.0f : -1.0f);
        const float flDx = flSideX - pTouchPos->x;
        const float flSideY = m_pos.y * (IsSideFlipped() ? -1.0f : 1.0f);
        const float flDy = flSideY - pTouchPos->y;
        if (flDx * flDx + flDy * flDy >= flDiameterSq) {
            continue;
        }

        // The flick's horizontal drag (mirrored to the note's side) must exceed the threshold.
        const float flDrag = static_cast<float>(pTouch->nCurrentX - pTouch->nBeginX);
        const float flSideDrag = IsSideFlipped() ? flDrag : -flDrag;
        if (flSideDrag <= kPlayerFlickThreshold && flSideDrag >= -kPlayerFlickThreshold) {
            continue;
        }

        // Score the note when its opposing gauge is filled, then shoot it in the flick's direction.
        if (m_bShotDecaying) {
            ReflecGaugeLayer *pGauge = ReflecGaugeLayer::shared();
            const int nColor = m_pRecord != nullptr ?
                                   m_pRecord->GetSide() :
                                   (m_bOwnSide ? kShotColorOwnSide : kShotColorNoPartner);
            if (pGauge->GetAnotherValue(nColor) >= 1.0f) {
                ReflecGaugeLayer::SubReflecGaugeValue(1.0f, pGauge, nColor);
                m_bShotResolved = true;
                ScoreTracker::shared()->AddLaneJudgeResult(
                    IsOnPlaySide(),
                    static_cast<unsigned int>(GameSystem::GetGameSystem()->GetFullJustReflec()));
            }
        }

        // Whether or not the note scored, this frame's shot check is done: leave the shot phase.
        m_bShotActive = false;
        if (!m_bShotResolved) {
            return;
        }

        // A hold note follows its display lane (its ambiguous lane picking the flick side); any
        // other note shoots in the flick's horizontal direction.
        int nDirection;
        if (m_pRecord != nullptr && m_pRecord->GetHoldKind() == kHoldKindHead) {
            const int nLane = m_pRecord->GetDisplayLane();
            if (nLane == kDisplayLaneCentre) {
                nDirection = -1;
            } else if (nLane == kDisplayLaneLeft) {
                nDirection = flSideDrag >= 0.0f ? 1 : -1;
            } else {
                assert(nLane == kDisplayLaneRight);
                nDirection = 1;
            }
        } else {
            nDirection = flSideDrag >= 0.0f ? 2 : -2;
        }
        SetShotDirection(nDirection);
        return;
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
constexpr float kJudgeWindowJustHighNarrow = -83.333336f;
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
    NoteEffectMgr *pManager = m_pSheet;
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
    NoteEffectMgr *pManager = m_pSheet;
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

namespace {

// The note-record types that take the held/slide resolution paths (every other type is a normal
// tap note). The rival-mode, hold-kind, grade, and gauge-gain constants shared with the step
// handlers are defined earlier in this file.
constexpr int kNoteTypeSlide = 3;

} // namespace

/** @ghidraAddress 0x133ec0 */
void NoteModel::ResolveNoteHit(unsigned int nGrade) {
    if (nGrade == 0) {
        m_bJustHit = true;
    }

    // The tap sound's grade: a slide note plays it as grade 0, every other path uses the real
    // grade.
    int nTapGrade = static_cast<int>(nGrade);

    // The slide and long-note types take their own resolution paths.
    if (m_pRecord != nullptr) {
        const int nType = m_pRecord->GetType();
        if (nType == kNoteTypeSlide) {
            m_nState = kNoteStateSlideExisting;
            m_nSubState = 0;
            m_nActiveKind = static_cast<int>(nGrade);
            nTapGrade = 0;
            // A non-scoring slide grade (a miss or worse) stops here without even the tap sound.
            if (static_cast<int>(nGrade) >= kGradeMiss) {
                return;
            }
            PlayNoteTapSound(nTapGrade, false);
            return;
        }
        if (nType == kNoteTypeHold) {
            m_nLongGrade = static_cast<int>(nGrade);
            m_nState = kNoteStateLongTouched;
            m_nSubState = 0;
            m_bLongNoteActive = false;
            PlayNoteTapSound(nTapGrade, false);
            return;
        }
    }

    // A normal tap note: mark it scored and finished, then spawn the hit burst.
    m_bScored = true;
    m_nState = kNoteStateFinished;
    m_nSubState = 0;

    // The note's side (from the record, or its own-side flag when it has none) and its screen
    // position, mirrored when the note is side-flipped.
    const int nSide =
        m_pRecord != nullptr ? m_pRecord->GetSide() : (m_bOwnSide ? 0 : kBoundsColorOwnSide);
    const float flMirrorX = IsSideFlipped() ? 1.0f : -1.0f;
    const float flMirrorY = IsSideFlipped() ? -1.0f : 1.0f;
    ExplosionEffectLayer::shared()->CreateExplosionEffect(static_cast<unsigned int>(nSide),
                                                          static_cast<int>(nGrade),
                                                          m_pos.x * flMirrorX,
                                                          m_pos.y * flMirrorY);

    if (m_nRivalMode != kRivalModeSpectate) {
        ScoreTracker *pTracker = ScoreTracker::shared();
        const int nScoreSide =
            m_pRecord != nullptr ? m_pRecord->GetSide() : (m_bOwnSide ? 0 : kBoundsColorOwnSide);
        const int nHoldKind = m_pRecord != nullptr ? m_pRecord->GetHoldKind() :
                                                     (m_bOwnSide ? 0 : kBoundsColorOwnSide);
        pTracker->AddScore(nScoreSide,
                           static_cast<int>(m_pos.x * flMirrorX),
                           static_cast<int>(m_pos.y * flMirrorY),
                           static_cast<int>(nGrade),
                           0,
                           nHoldKind == kScoreHoldKind);
        m_nJudgeGrade = static_cast<int>(nGrade);

        // Add the reflec-gauge gain for this grade at the chart's density tier.
        ReflecGaugeLayer *pGauge = ReflecGaugeLayer::shared();
        const int nGaugeSide =
            m_pRecord != nullptr ? m_pRecord->GetSide() : (m_bOwnSide ? 0 : kBoundsColorOwnSide);
        const int nTier = m_pSheet->GetDensityTier();
        ReflecGaugeLayer::AddReflecGaugeValue(kGaugeGainByTier[nTier][nGrade], pGauge, nGaugeSide);
    }

    UpdateNotePathLinks();
    if (m_pSheet != nullptr) {
        const int nScoredSide =
            m_pRecord != nullptr ? m_pRecord->GetSide() : (m_bOwnSide ? 0 : kBoundsColorOwnSide);
        m_pSheet->HandleNoteScored(m_nNoteIndex, nScoredSide);
    }

    PlayNoteTapSound(nTapGrade, false);
}

/** @ghidraAddress 0x1336e4 */
void NoteModel::AdvancePosition() {
    const float flDelta = PlayTimer::shared()->GetFrameDelta();
    m_prevPos = m_pos;
    if (m_bLongNoteActive) {
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

    // The ordinary kind maps each lane to its across-field fraction; the centre and any
    // out-of-range lane are zero.
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

namespace {

// The five-entry lane-fraction lookup the activation pass builds on the stack: the three left lane
// fractions, the zero centre lane, and the first right lane fraction. It is an inlined
// GetNoteLaneFraction over the ordinary lane kind.
constexpr int kActivationLaneCount = 5;
constexpr int kActivationCenterLane = 3;

// The lane the activation pass falls back to when the note has no chart record.
constexpr int kActivationFallbackLane = 2;

// The chosen-target value marking a note that takes the plain lane placement rather than a slide
// path.
constexpr int kNoChosenTarget = -1;

// The note-state seeds: the activated state, and the pre-spawn state a freshly born note enters.
constexpr int kNoteStateActivated = 2;
constexpr int kNoteStateSpawning = 1;
// The state a note that is already past its hit time snaps straight to.
constexpr int kNoteStatePassed = 8;

// The shot phase's seeded lifetime, speed, and progress.
constexpr float kInitialShotDecayTimer = 100.0f;
constexpr float kInitialShotSpeed = 0.0f;
constexpr float kInitialShotProgress = 1.0f;

// The long-note grade sentinel meaning "not yet judged".
constexpr int kLongGradeUnset = 5;

// The appearance scale and fade a note is seeded fully shown at.
constexpr float kInitialAppearScale = 1.0f;
constexpr float kInitialFadeTimer = 1.0f;

// The mirrored-source position is negated to place the note on the opposite side.
constexpr float kMirrorScale = -1.0f;

// The slide segment kinds a point takes from its successor's lane: level, rising, falling, and the
// terminating kind the final point takes.
constexpr int kSlideKindLevel = 0;
constexpr int kSlideKindRising = 1;
constexpr int kSlideKindFalling = 2;
constexpr int kSlideKindTerminal = 3;

// The active-segment index sentinel meaning "none".
constexpr int kActiveIndexNone = -1;

// The game types whose rival side is drawn: the versus type, and the replay type.
constexpr int kGameTypeVersus = 1;
constexpr int kGameTypeReplay = 2;

// The rival modes a note takes when it belongs to the other side, by game type.
constexpr int kRivalModeOther = 1;
constexpr int kRivalModeOtherReplay = 2;

// The hold-note kind that leaves an activated note's shot direction undirected.
constexpr int kHoldKindHeld = 1;

// Builds the activation pass's five-entry lane-fraction lookup.
inline void BuildActivationLaneFractions(float (&aFractions)[kActivationLaneCount]) {
    aFractions[0] = g_noteLaneTable.flLaneFrac0;
    aFractions[1] = g_noteLaneTable.flLaneFrac1;
    aFractions[2] = g_noteLaneTable.flLaneFrac2;
    aFractions[kActivationCenterLane] = 0.0f;
    aFractions[4] = g_noteLaneTable.flLaneFrac4;
}

} // namespace

/** @ghidraAddress 0x134128 */
void NoteModel::Init() {
    RbffNoteRecord *pRecord = m_pRecord;
    NoteModel *pMirrorSource = nullptr;
    bool bBasePosSet = false;

    // The base position comes from one of three sources, in order: a chain-mate's base position, a
    // mirrored partner's live position, or the note's own lane placement.
    if (pRecord != nullptr) {
        if (pRecord->GetStartTime() >= 0) {
            pMirrorSource = m_pSheet->FindNoteByIndex(pRecord->GetStartTime());
            pRecord = m_pRecord;
        }
        if (pRecord != nullptr) {
            // A note that is not its chain's head inherits the head's base position.
            const short nChainId = pRecord->GetChainLink().GetChainId();
            if (nChainId >= 0) {
                NoteModel *pChainNote = m_pSheet->FindNoteByIndex(nChainId);
                if (pChainNote != nullptr) {
                    m_basePos = pChainNote->m_basePos;
                    bBasePosSet = true;
                }
            }
        }
    }

    if (!bBasePosSet && pMirrorSource != nullptr) {
        // A mirrored note takes its partner's live position, negated through the field centre.
        S_VECTOR2 mirrored = pMirrorSource->m_pos;
        ScaleVector2(&mirrored, kMirrorScale);
        m_basePos = mirrored;
        bBasePosSet = true;
    }

    if (!bBasePosSet) {
        pRecord = m_pRecord;
        // The binary reads the chosen target through the record without a null check, so a note
        // with no record faults here; activation only ever runs for recorded notes, so it does not
        // fire in practice.
        const bool bSlidePath = pRecord->GetChosenTarget() != kNoChosenTarget;

        float aLaneFractions[kActivationLaneCount];
        BuildActivationLaneFractions(aLaneFractions);

        // The note sits on its own lane, at the mid-lane row.
        const int nOwnLane = pRecord != nullptr ? pRecord->GetColor() : kActivationFallbackLane;
        m_basePos = S_VECTOR2{
            aLaneFractions[nOwnLane] * GameSystem::GetGameSystem()->GetSheetInsetHalfX(),
            g_flPlayfieldMidLaneSlope * GameSystem::GetGameSystem()->GetSheetInsetHalfY()};

        // A note with a chosen target also lays out a slide path: one sub-entry per slide point,
        // each running from the previous point's end to its own lane.
        if (bSlidePath) {
            pRecord = m_pRecord;
            if (pRecord->GetSlidePointCount() > 0) {
                m_nActiveIndex = kActiveIndexNone;
                for (int nPoint = 0; nPoint < m_pRecord->GetSlidePointCount(); ++nPoint) {
                    SubEntry &entry = m_aSubEntries[nPoint];
                    const RbffSlideRecord &slide = m_pRecord->GetSlideRecord()[nPoint];
                    entry.nIndex = slide.nTimingSel;

                    // The segment kind follows the step to the next point's lane; the last point
                    // terminates the path.
                    if (nPoint == m_pRecord->GetSlidePointCount() - 1) {
                        entry.bLastPoint = true;
                        entry.nKind = kSlideKindTerminal;
                    } else {
                        const int nNextLane = m_pRecord->GetSlideRecord()[nPoint + 1].nTimingSel;
                        if (entry.nIndex == nNextLane) {
                            entry.nKind = kSlideKindLevel;
                        } else if (entry.nIndex < nNextLane) {
                            entry.nKind = kSlideKindRising;
                        } else {
                            entry.nKind = kSlideKindFalling;
                        }
                    }

                    // All three interpolation times start equal; the approach step spreads them out
                    // once the note's scroll speed is known.
                    const RbffSlideRecord &times = m_pRecord->GetSlideRecord()[nPoint];
                    const float flTime = static_cast<float>(times.nValueB + times.nValueA);
                    entry.flTime0 = flTime;
                    entry.flTime1 = flTime;
                    entry.flTime2 = flTime;

                    // The first point starts on the note's own lane; every later point starts where
                    // its predecessor ends, so the path is continuous.
                    if (nPoint == 0) {
                        entry.flStartX = aLaneFractions[nOwnLane] *
                                         GameSystem::GetGameSystem()->GetSheetInsetHalfX();
                    } else {
                        entry.flStartX = m_aSubEntries[nPoint - 1].flEndX;
                    }
                    entry.flStartY = g_flPlayfieldExtraLaneSlopeNeg *
                                     GameSystem::GetGameSystem()->GetSheetInsetHalfY();
                    entry.flEndX = aLaneFractions[entry.nIndex] *
                                   GameSystem::GetGameSystem()->GetSheetInsetHalfX();
                    entry.flEndY = g_flPlayfieldNearLaneSlopeNeg *
                                   GameSystem::GetGameSystem()->GetSheetInsetHalfY();

                    // The live position starts at the segment's start. Both slopes divide by a zero
                    // time span here (the three times are still equal); the approach step
                    // recomputes them once it has spread the times.
                    entry.flCurX = entry.flStartX;
                    entry.flCurY = entry.flStartY;
                    entry.flSlopeX =
                        (entry.flEndX - entry.flStartX) / (entry.flTime1 - entry.flTime0);
                    entry.flSlopeY =
                        (entry.flEndY - entry.flStartY) / (entry.flTime2 - entry.flTime1);
                }

                // The path's leading segment kind follows the step from the note's own lane to the
                // first slide point.
                const int nFirstLane = m_aSubEntries[0].nIndex;
                if (nOwnLane == nFirstLane) {
                    m_nActiveKind2 = kSlideKindLevel;
                } else if (nOwnLane < nFirstLane) {
                    m_nActiveKind2 = kSlideKindRising;
                } else {
                    m_nActiveKind2 = kSlideKindFalling;
                }
            }
        }
    }

    // Seed the note's live play state from the base position.
    m_pos = m_basePos;
    m_prevPos = m_basePos;
    m_velocity = S_VECTOR2{0.0f, 0.0f};
    m_nState = kNoteStateActivated;
    m_nSubState = 0;
    m_flShotDecayTimer = kInitialShotDecayTimer;
    m_flShotSpeed = kInitialShotSpeed;
    m_flShotProgress = kInitialShotProgress;
    m_flRenderX = m_basePos.x;
    m_flRenderY = m_basePos.y;
    m_nLongGrade = kLongGradeUnset;
    m_flSpawnTime = GetCurrentJudgeTime();

    // A mirrored note that has already been scored takes its partner's shot direction; every other
    // note starts undirected.
    int nDirection = 0;
    if (pMirrorSource != nullptr && pMirrorSource->m_bScored) {
        // A held note keeps the undirected default; every other note maps its colour index to a
        // direction, and a note with no record takes the zero index (and so the leftward
        // direction).
        bool bDirected = true;
        int nColorIndex = 0;
        if (m_pRecord != nullptr) {
            if (m_pRecord->GetHoldKind() == kHoldKindHeld) {
                bDirected = false;
            } else {
                nColorIndex = m_pRecord->GetColorIndex();
            }
        }
        if (bDirected) {
            nDirection = nColorIndex == 0 ? -1 : (nColorIndex == 1 ? 1 : 0);
        }
    }
    m_nDirectionSign = nDirection;
    m_nWaypointCount = nDirection < 0 ? -nDirection : nDirection;
    m_nWaypointIndex = 0;
    m_pCurrentWaypoint = &m_aWaypointBlock[0];

    // The rival mode records whether this note belongs to the other play side, and how the current
    // game type draws it.
    GameSystem *pGameSystem = GameSystem::GetGameSystem();
    int nRivalMode = 0;
    bool bOtherSide = false;
    if (pGameSystem->GetGameType() != kGameTypeVersus) {
        const int nSide =
            m_pRecord != nullptr ? m_pRecord->GetSide() : (m_bOwnSide ? 0 : kNoSideSentinel);
        bOtherSide = pGameSystem->GetPlayColor() != nSide;
        if (bOtherSide) {
            nRivalMode = pGameSystem->GetGameType() == kGameTypeReplay ? kRivalModeOtherReplay :
                                                                         kRivalModeOther;
        } else {
            nRivalMode = pGameSystem->GetUserFullCombo();
        }
    }
    // Only a note on the other side keeps its auto-shot mode; every other note has it cleared.
    if (!bOtherSide) {
        m_nAutoShotMode = 0;
    }
    m_nRivalMode = nRivalMode;

    memset(m_aWaypointBlock, 0, kWaypointBlockSize);
    m_flBornTime = 0.0f;
    m_flAppearScale = kInitialAppearScale;
    m_flFadeTimer = kInitialFadeTimer;
    m_bPlayStateFlag510 = false;
    m_bScored = false;
    m_bJustHit = false;
    m_bShotDecaying = false;
    if (pMirrorSource == nullptr) {
        m_bShotResolved = false;
        m_bShotActive = false;
    } else {
        // A mirrored note inherits its partner's scored and just-hit flags: both set marks the shot
        // as already decaying, and the scored flag alone drives the shot phase.
        if (pMirrorSource->m_bScored && pMirrorSource->m_bJustHit) {
            m_bShotDecaying = true;
        }
        m_bShotResolved = false;
        m_bShotActive = pMirrorSource->m_bScored;
    }
    m_bRenderReflectPath = false;
    m_bRenderShotTail = false;
    m_bMissProcessed = false;
    m_bLongNoteActive = true;
    m_bTouched = false;

    if (pMirrorSource == nullptr) {
        // A note with no mirrored partner spawns fresh: it enters the pre-spawn state hidden, and
        // emits its spawn burst when its side is drawn.
        m_nState = kNoteStateSpawning;
        m_nSubState = 0;
        m_flAppearScale = 0.0f;
        m_flFadeTimer = 0.0f;
        if (GameSystem::GetGameSystem()->GetRivalAlpha() != 0.0f ||
            GameSystem::GetGameSystem()->GetGameType() == kGameTypeVersus || IsOnPlaySide()) {
            NoteBornLayer *pBornLayer = NoteBornLayer::shared();
            const int nSide =
                m_pRecord != nullptr ? m_pRecord->GetSide() : (m_bOwnSide ? 0 : kNoSideSentinel);
            // A flipped side mirrors the burst through both axes.
            const float flX = m_pos.x * (IsSideFlipped() ? 1.0f : -1.0f);
            const float flY = m_pos.y * (IsSideFlipped() ? -1.0f : 1.0f);
            pBornLayer->Create(nSide, flX, flY);
        }
        m_flBornTime = m_flSpawnTime;
    }

    SetRoute();

    // A slide note drives its own path rather than the long-note hold.
    if (m_pRecord->GetSlidePointCount() > 0) {
        m_bLongNoteActive = false;
    }

    // A note whose hit time has already passed skips straight to the passed state, snapped onto the
    // target line.
    const float flHitTime = m_pRecord != nullptr ?
                                static_cast<float>(m_pRecord->GetTimeB() + m_pRecord->GetTimeA()) :
                                (m_bOwnSide ? m_flSpawnTime + kSyntheticHitLead : 0.0f);
    if (flHitTime < m_flSpawnTime) {
        m_pos = S_VECTOR2{GetLaneX(), GetTargetLineY()};
        UpdateNotePathLinks();
        m_nState = kNoteStatePassed;
        m_nSubState = 0;
    }
}
