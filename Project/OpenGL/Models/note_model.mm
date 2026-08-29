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
#include "just_reflec_effect_layer.h"
#include "long_note_layer.h"
#include "note_born_layer.h"
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

float g_flPlayfieldNearLaneSlope = -0.7882096f;   // @ghidraAddress 0x3ce95c
float g_flPlayfieldNearLaneSlopeNeg = 0.7882096f; // @ghidraAddress 0x3ce960
float g_flPlayfieldFarLaneSlope = -0.35371178f;   // @ghidraAddress 0x3ce96c
float g_flPlayfieldFarLaneSlopeNeg = 0.35371178f; // @ghidraAddress 0x3ce970

int g_nPlayfieldCentreSplit = 512; // @ghidraAddress 0x3ce934
int g_nGaugeAltTopBaseY = 288;     // @ghidraAddress 0x3ce99c
int g_nGaugeAltBottomBaseY = 736;  // @ghidraAddress 0x3ce9a0
int g_nGaugeTopBaseY = 462;        // @ghidraAddress 0x3ce9a4
int g_nGaugeBottomBaseY = 562;     // @ghidraAddress 0x3ce9a8

int g_nPlayfieldFieldHeight = 1024;                 // @ghidraAddress 0x3ce930
int g_nPlayfieldHalfHeightY = 512;                  // @ghidraAddress 0x3ce938
int g_nPlayfieldFullHeightY = {};                   // @ghidraAddress 0x3d0008
int g_nPlayfieldRow16 = 1002;                       // @ghidraAddress 0x3ce93c
int g_nPlayfieldRow2c = 980;                        // @ghidraAddress 0x3ce940
int g_nPlayfieldRow36 = 970;                        // @ghidraAddress 0x3ce944
int g_nPlayfieldRow6c = 916;                        // @ghidraAddress 0x3ce948
float g_flPlayfieldRowScale = 458.0f;               // @ghidraAddress 0x3ce94c
int g_nPlayfieldNearRowTop = 151;                   // @ghidraAddress 0x3ce950
int g_nPlayfieldNearRowBottom = 873;                // @ghidraAddress 0x3ce954
int g_nPlayfieldRow12e = 722;                       // @ghidraAddress 0x3ce958
int g_nPlayfieldFarRowTop = 350;                    // @ghidraAddress 0x3ce964
int g_nPlayfieldFarRowBottom = 674;                 // @ghidraAddress 0x3ce968
int g_nPlayfieldMidRowTop = 250;                    // @ghidraAddress 0x3ce974
int g_nPlayfieldMidRowBottom = 774;                 // @ghidraAddress 0x3ce978
float g_flPlayfieldMidLaneSlope = -0.5720524f;      // @ghidraAddress 0x3ce97c
float g_flPlayfieldMidLaneSlopeNeg = 0.5720524f;    // @ghidraAddress 0x3ce980
int g_nPlayfieldGaugeRowTop = 450;                  // @ghidraAddress 0x3ce984
int g_nPlayfieldGaugeRowBottom = 574;               // @ghidraAddress 0x3ce988
float g_flPlayfieldExtraLaneSlope = -0.13537118f;   // @ghidraAddress 0x3ce98c
float g_flPlayfieldExtraLaneSlopeNeg = 0.13537118f; // @ghidraAddress 0x3ce990
int g_nPlayfieldRowE4 = 796;                        // @ghidraAddress 0x3ce994
int g_nPlayfieldRow192 = 622;                       // @ghidraAddress 0x3ce998

NoteLaneTable g_noteLaneTable = {}; // @ghidraAddress 0x3de000

namespace {

// @ghidraAddress 0x1360b8 (pool 0x2fd000, 0x2ec6b4, 0x2ee910, 0x308b80)
constexpr float kBandFractions[] = {0.38f, 0.30f, 0.20f, 0.10f, 0.0f, 0.10f, 0.20f, 0.30f, 0.38f};
constexpr int kBandCount = 9;
constexpr int kCenterBand = 4;

constexpr int kWideLaneKind = 1;
constexpr int kWideLaneLeft = 1;
constexpr int kWideLaneRight = 2;

} // namespace

namespace {
constexpr int kSubEntryKindNone = 5;
constexpr int kSubEntryIndexNone = -1;
constexpr int kSubEntrySeed = 5;

constexpr int kResetSubEntryCount = 10;
constexpr int kColorLockReset = 5;

constexpr float kPlayfieldHeightScale = 1024.0f;
constexpr int kPlayfieldHalfHeightOffset = 0x200;
constexpr int kPlayfieldFullHeightOffset = 0x400;
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
// @ghidraAddress 0x2ef660
constexpr float kPlayfieldExtraLaneOffset = -62.0f;
} // namespace

/** @ghidraAddress 0x55488 */
void ComputePlayfieldLayoutY(float flScale) {
    const int nHeight = static_cast<int>(flScale * kPlayfieldHeightScale);
    g_nPlayfieldFieldHeight = nHeight;
    const int nRounded = nHeight < 0 ? nHeight + 1 : nHeight;
    g_nPlayfieldCentreSplit = nRounded >> 1;

    g_nPlayfieldHalfHeightY = nHeight - kPlayfieldHalfHeightOffset;
    g_nPlayfieldFullHeightY = nHeight - kPlayfieldFullHeightOffset;
    g_nPlayfieldRow16 = nHeight - kPlayfieldRowOffset16;
    g_nPlayfieldRow2c = nHeight - kPlayfieldRowOffset2c;
    g_nPlayfieldRow36 = nHeight - kPlayfieldRowOffset36;
    g_nPlayfieldRow6c = nHeight - kPlayfieldRowOffset6c;

    g_flPlayfieldRowScale = static_cast<float>(g_nPlayfieldCentreSplit - kPlayfieldRowOffset36);

    g_nPlayfieldNearRowTop = kPlayfieldNearRowOffset;
    g_nPlayfieldNearRowBottom = nHeight - kPlayfieldNearRowOffset;
    g_nPlayfieldRow12e = nHeight - kPlayfieldRowOffset12e;
    g_flPlayfieldNearLaneSlope =
        static_cast<float>(kPlayfieldNearRowOffset - g_nPlayfieldCentreSplit) /
        g_flPlayfieldRowScale;
    g_flPlayfieldNearLaneSlopeNeg = -g_flPlayfieldNearLaneSlope;

    g_nPlayfieldFarRowTop = kPlayfieldFarRowOffset;
    g_nPlayfieldFarRowBottom = nHeight - kPlayfieldFarRowOffset;
    g_flPlayfieldFarLaneSlope =
        static_cast<float>(kPlayfieldFarRowOffset - g_nPlayfieldCentreSplit) /
        g_flPlayfieldRowScale;
    g_flPlayfieldFarLaneSlopeNeg = -g_flPlayfieldFarLaneSlope;

    g_nPlayfieldMidRowTop = kPlayfieldMidRowOffset;
    g_nPlayfieldMidRowBottom = nHeight - kPlayfieldMidRowOffset;
    g_flPlayfieldMidLaneSlope =
        static_cast<float>(kPlayfieldMidRowOffset - g_nPlayfieldCentreSplit) /
        g_flPlayfieldRowScale;
    g_flPlayfieldMidLaneSlopeNeg = -g_flPlayfieldMidLaneSlope;

    g_nPlayfieldGaugeRowTop = g_nPlayfieldCentreSplit - kPlayfieldGaugeRowOffset;
    g_nPlayfieldGaugeRowBottom = nHeight - g_nPlayfieldGaugeRowTop;

    g_flPlayfieldExtraLaneSlope = kPlayfieldExtraLaneOffset / g_flPlayfieldRowScale;
    g_flPlayfieldExtraLaneSlopeNeg = -g_flPlayfieldExtraLaneSlope;

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
        if (!m_bOwnSide) {
            return kNoSideSentinel;
        }
        nSide = 0;
    } else {
        nSide = m_pRecord->GetSide();
        // The binary compares unsigned, so a negative side takes this arm too.
        if (static_cast<unsigned int>(nSide) >= 2) {
            return m_bOwnSide ? 0 : kNoSideSentinel;
        }
    }
    return GameSystem::GetGameSystem()->GetPlayColor() != nSide;
}

/** @ghidraAddress 0x134924 */
int NoteModel::IsOnPlaySide() const {
    int nSide;
    if (m_pRecord == nullptr) {
        if (!m_bOwnSide) {
            return kNoSideSentinel;
        }
        nSide = 0;
    } else {
        nSide = m_pRecord->GetSide();
        // The binary compares unsigned, so a negative side takes this arm too.
        if (static_cast<unsigned int>(nSide) >= 2) {
            return m_bOwnSide ? 1 : kNoSideSentinel;
        }
    }
    return GameSystem::GetGameSystem()->GetPlayColor() == nSide;
}

// @ghidraAddress 0x2fcf80
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
    return m_bOwnSide ? 0 : kNoSideSentinel;
}

/** @ghidraAddress 0x1336c0 */
int NoteModel::GetType() const {
    if (m_pRecord != nullptr) {
        return m_pRecord->GetType();
    }
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
    static constexpr int kSlidePointJudgeMiss = 5;
    if (nIndex < m_pRecord->GetSlidePointCount()) {
        return m_aSubEntries[nIndex].nResolvedGrade;
    }
    return kSlidePointJudgeMiss;
}

/** @ghidraAddress 0x135310 */
float NoteModel::GetTargetLineY() const {
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
constexpr float kWaypointTimeScale = 1000.0f;   // @ghidraAddress 0x2f8540
constexpr float kWaypointTimeOffset = -1500.0f; // @ghidraAddress 0x308b60
constexpr float kFadeDecayDivisor = -300.0f;    // @ghidraAddress 0x2fd050
// State 6 (transitional) and any unlisted value do nothing.
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
    S_VECTOR2 delta = m_pCurrentWaypoint->endPos;
    ScaleVector2(&delta, flFraction);
    AddVector2(&delta, &m_pCurrentWaypoint->startPos);
    m_pos = delta;
}

namespace {

constexpr int kHoldKindHead = 1;
constexpr int kNoteTypeHold = 1;

constexpr float kEdgeHalfScale = 0.5f;

constexpr unsigned int kBoundsColorOwnSide = 3;
constexpr unsigned int kBoundsColorOtherSide = 0;

} // namespace

/** @ghidraAddress 0x133858 */
void NoteModel::HandleReflect(int nDirection) {
    const float flHalfWidth = GameSystem::GetGameSystem()->GetSheetPosX();
    const int nEdgePos = static_cast<int>(flHalfWidth * kEdgeHalfScale);
    const int nEdgeNeg = static_cast<int>(flHalfWidth * -kEdgeHalfScale);

    const int nForwardEdge = nDirection < 0 ? nEdgePos : nEdgeNeg;
    const int nFlippedEdge = nDirection < 0 ? nEdgeNeg : nEdgePos;
    const int nEdge = IsSideFlipped() == 0 ? nForwardEdge : nFlippedEdge;

    bool bBounced = false;
    if (m_nWaypointCount != m_nWaypointIndex) {
        ++m_nWaypointIndex;
        m_pCurrentWaypoint = &m_aWaypointBlock[m_nWaypointIndex];
        AdvanceAlongWaypoint();
        if (m_pCurrentWaypoint != nullptr) {
            m_velocity.x = m_pCurrentWaypoint->endPos.x;
            m_velocity.y = m_pCurrentWaypoint->endPos.y;
        }
    } else {
        const bool bHold = m_pRecord != nullptr && (m_pRecord->GetHoldKind() == kHoldKindHead ||
                                                    m_pRecord->GetType() == kNoteTypeHold);
        if (bHold) {
            m_bLongNoteActive = false;
            return;
        }
        m_pos.x = static_cast<float>(nDirection) + (static_cast<float>(nDirection) - m_pos.x);
        m_velocity.x = -m_velocity.x;
        bBounced = true;
    }

    const unsigned int nColor = m_pRecord != nullptr ?
                                    static_cast<unsigned int>(m_pRecord->GetSide()) :
                                    (m_bOwnSide ? kBoundsColorOtherSide : kBoundsColorOwnSide);
    const float flSideSign = IsSideFlipped() == 0 ? 1.0f : -1.0f;
    BoundsEffectLayer::shared()->CreateBoundsEffect(
        nColor, static_cast<float>(nEdge), m_pos.y * flSideSign);
    if (bBounced) {
        m_bLongNoteActive = false;
    }
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
    S_VECTOR2 offset = m_velocity;
    ScaleVector2(&offset, -1.0f);
    NormalizeVector2(&offset);
    ScaleVector2(&offset, m_flShotSpeed * m_flShotProgress);
    AddVector2(&offset, &m_pos);
    m_flRenderX = offset.x;
    m_flRenderY = offset.y;
    m_bRenderReflectPath = false;
    m_bRenderShotTail = true;
    const float flCullY = GameSystem::GetGameSystem()->GetSheetInsetHalfY() +
                          GameSystem::GetGameSystem()->GetSheetRadiusHalf();
    if (flCullY < offset.y) {
        m_nState = kNoteStateFinished;
        m_nSubState = 0;
    }
}

namespace {
constexpr float kApproachTimeScale = 1000.0f;  // @ghidraAddress 0x2f8540
constexpr float kApproachTimeBias = -1500.0f;  // @ghidraAddress 0x308b60
constexpr float kApproachSpeedDivisor = 60.0f; // @ghidraAddress 0x2f8578
constexpr int kNoteTypeSlideApproach = 3;
// @ghidraAddress 0x2eece8 slope, 0x2eea40 bias
constexpr double kAppearScaleSlope = 0.2;
constexpr double kAppearScaleBias = 0.8;
} // namespace

/** @ghidraAddress 0x131bc0 */
void NoteModel::UpdateStepApproach() {
    const float flNow = PlayTimer::shared()->GetPlayTime() * kApproachTimeScale + kApproachTimeBias;
    const float flHitTime = GetHitTime();
    if (flHitTime <= flNow) {
        UpdateNotePathLinks();
        m_nState = kNoteStateFinished;
        m_nSubState = 0;
        return;
    }

    const float flScrollSpeed = m_pRecord->IsScrollVisible() ? m_pRecord->GetScrollEndSpeed() :
                                                               m_pRecord->GetScrollStartSpeed();
    float flProgress =
        (flNow - m_flBornTime) * ((flScrollSpeed / kApproachSpeedDivisor) / kApproachTimeScale);
    if (flProgress < 0.0f) {
        flProgress = 0.0f;
    }

    if (flProgress < 1.0f) {
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

    m_flAppearScale = 1.0f;
    m_flFadeTimer = 1.0f;
    SetShotDirection(0);
    if (m_pRecord == nullptr || m_pRecord->GetType() != kNoteTypeSlideApproach) {
        m_nState = kNoteStateExisting;
        m_nSubState = 0;
        return;
    }

    m_nState = kNoteStateSlideExisting;
    m_nSubState = 0;
    const float flInsetHalfY = GameSystem::GetGameSystem()->GetSheetInsetHalfY();
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
constexpr float kHoldReleaseGrace = 153.0f; // @ghidraAddress 0x308b64
constexpr float kMissPenaltyScale = 3.0f;   // @ghidraAddress 0x40400000
constexpr int kMissScoreDelta = -3;
constexpr int kRivalModeGhost = 2;
constexpr int kRivalModeSpectate = 3;
constexpr int kScoreHoldKind = 1;
constexpr int kGradeMiss = 3;
constexpr float kShotTailMaxLength = 200.0f; // @ghidraAddress 0x301f78
// The row is the chart's density tier; the column is the timing grade.
// @ghidraAddress 0x308b84
constexpr int kGaugeGainGradeCount = 4;
constexpr float kGaugeGainByTier[][kGaugeGainGradeCount] = {
    {0.05f, 0.03f, 0.01f, 0.05f},
    {0.04f, 0.02f, 0.01f, 0.04f},
    {0.03f, 0.02f, 0.01f, 0.03f},
};
} // namespace

/** @ghidraAddress 0x131e3c */
void NoteModel::UpdateStepExisted() {
    const float flPlayTime = PlayTimer::shared()->GetPlayTime();

    AdvancePosition();
    CheckShot();
    GameSystem *pGameSystem = GameSystem::GetGameSystem();
    if (m_pos.x < -pGameSystem->GetSheetInsetHalfX()) {
        HandleReflect(static_cast<int>(-GameSystem::GetGameSystem()->GetSheetInsetHalfX()));
    }
    if (GameSystem::GetGameSystem()->GetSheetInsetHalfX() < m_pos.x) {
        HandleReflect(static_cast<int>(GameSystem::GetGameSystem()->GetSheetInsetHalfX()));
    }

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
        UpdateNotePathLinks();

        if (m_pRecord == nullptr) {
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
                const float flInsetHalfY = GameSystem::GetGameSystem()->GetSheetInsetHalfY();
                if (m_pos.y <= -flInsetHalfY) {
                    m_pos.y = -flInsetHalfY;
                } else if (flInsetHalfY <= m_pos.y) {
                    m_pos.y = flInsetHalfY;
                }
                m_nState = kNoteStateFinished;
                m_nSubState = 0;
            } else {
                m_nState = kNoteStateFadeOut;
                m_nSubState = 0;
            }
        } else {
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

    if (m_pRecord != nullptr && m_pRecord->GetType() == kNoteTypeHold) {
        if (m_nWaypointIndex == m_nWaypointCount) {
            S_VECTOR2 dirVec = m_velocity;
            ScaleVector2(&dirVec, -static_cast<float>(m_pRecord->GetTargetCopy()));
            const float flMaxLength = Vector2Length(&dirVec);
            NormalizeVector2(&dirVec);

            S_VECTOR2 deltaVec;
            if (m_nWaypointCount == 0) {
                deltaVec = m_basePos;
                SubtractVector2(&deltaVec, &m_pos);
            } else {
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

            S_VECTOR2 endPoint = dirVec;
            ScaleVector2(&endPoint, flLength);
            AddVector2(&endPoint, &m_pos);
            m_flRenderX = endPoint.x;
            m_flRenderY = endPoint.y;
        } else {
            m_flRenderX = m_pos.x;
            m_flRenderY = m_pos.y;
        }
    }
}

namespace {
constexpr float kSyntheticHoldLength = 1000.0f;    // @ghidraAddress 0x2f8540
constexpr float kReleaseWindowSlack = -83.333336f; // @ghidraAddress 0x308b68
} // namespace

/** @ghidraAddress 0x1324c4 */
void NoteModel::UpdateStepLongTouched() {
    const float flJudgeTime =
        PlayTimer::shared()->GetPlayTime() * kApproachTimeScale + kApproachTimeBias;

    const float flReleaseTime =
        m_pRecord != nullptr ? static_cast<float>(m_pRecord->GetTimeB() + m_pRecord->GetTimeA()) :
                               (m_bOwnSide ? m_flSpawnTime + kSyntheticHitLead : 0.0f);
    const float flHoldLength = m_pRecord != nullptr ?
                                   static_cast<float>(m_pRecord->GetTargetCopy()) :
                                   (m_bOwnSide ? kSyntheticHoldLength : 0.0f);

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

    bool bTouched;
    if (m_nRivalMode == 1 || m_nRivalMode == kRivalModeGhost) {
        bTouched = true;
    } else if (m_nRivalMode == kRivalModeSpectate) {
        return;
    } else {
        assert(m_nRivalMode == 0);
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

    const bool bResolved =
        bTouched || (flHoldLength + flReleaseTime + kReleaseWindowSlack < flJudgeTime);
    if (bResolved) {
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
    } else {
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
constexpr float kSlideJustHigh = 34.0f;  // @ghidraAddress 0x2fd00c
constexpr float kSlideJustLow = -34.0f;  // @ghidraAddress 0x308b6c
constexpr float kSlideNearHigh = 102.0f; // @ghidraAddress 0x308b70
constexpr float kSlideNearLow = -102.0f; // @ghidraAddress 0x308b74
constexpr float kSlideFarLow = -153.0f;  // @ghidraAddress 0x308b78
constexpr float kSlideFarHigh = 153.0f;  // @ghidraAddress 0x308b64
constexpr int kSlidePointUnresolved = 5;
constexpr int kSlideGradeMiss = 3;
constexpr int kSlideComboCutoff = 8;
} // namespace

/** @ghidraAddress 0x132be0 */
void NoteModel::UpdateStepSlideExisted() {
    const float flNow = PlayTimer::shared()->GetPlayTime() * kApproachTimeScale + kApproachTimeBias;
    const float flDelta = PlayTimer::shared()->GetFrameDelta();

    const int nPointCount = m_pRecord->GetSlidePointCount();
    // A per-call guard, not the persistent active index. @ghidraAddress 0x132c50
    int nActiveCandidate = -1;
    for (int nPoint = 0; nPoint < nPointCount; ++nPoint) {
        SubEntry &point = m_aSubEntries[nPoint];
        if (flNow > point.flTime2) {
            continue;
        }
        if (nActiveCandidate == -1 && point.flTime0 <= flNow && flNow < point.flTime2) {
            m_nActiveIndex = nPoint;
            nActiveCandidate = nPoint;
        }
        if (point.flTime0 <= flNow && flNow < point.flTime1) {
            S_VECTOR2 step{point.flSlopeX, 0.0f};
            ScaleVector2(&step, flDelta);
            S_VECTOR2 cur{point.flCurX, point.flCurY};
            AddVector2(&step, &cur);
            point.flCurX = step.x;
            point.flCurY = step.y;
        } else if (flNow >= point.flTime1 && flNow < point.flTime2) {
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

    const int nActive = m_nActiveIndex;
    const float flHitTime = GetHitTime();
    if (nActive == -1 || flNow <= flHitTime) {
        AdvancePosition();
    } else {
        m_prevPos = m_pos;
        const float flSegStart = nActive == 0 ? flHitTime : m_aSubEntries[nActive - 1].flTime2;
        SubEntry &active = m_aSubEntries[nActive];
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

    if (flHitTime < flNow) {
        m_pos.y = g_flPlayfieldNearLaneSlopeNeg * GameSystem::GetGameSystem()->GetSheetInsetHalfY();
    }

    bool bTouched = false;
    if (flNow > flHitTime + kReleaseWindowSlack) {
        switch (m_nRivalMode) {
        case 0:
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
            // A slide that never registered a point scores as a plain hit.
            const unsigned int nResolveGrade = m_aSubEntries[0].nIncomingGrade != 0 ? nGrade : 0;
            ResolveNoteHit(nResolveGrade);
            bScoredThisFrame = true;
            m_bScored = true;
        }
    }

    if (GetHitTime() <= flNow) {
        if (!bScoredThisFrame) {
            // The binary has no sign guard here: an index of -1 makes the write land on
            // m_nActiveIndex itself, promoting it from -1 to 0.
            // @ghidraAddress 0x13323c (the guarded arms are 0x1331fc and 0x133220)
            if (m_nActiveIndex >= 0) {
                ++m_aSubEntries[m_nActiveIndex].nMissCount;
            } else {
                ++m_nActiveIndex;
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
constexpr int kMaxShotDirection = 2;
constexpr float kShotSpawnTimeScale = 1000.0f;
constexpr float kShotSpawnTimeLeadIn = -1500.0f;
constexpr int kNoActiveNoteColor = 5;
enum ShotColor {
    kShotColorPlayer = 0,
    kShotColorCPU = 1,
    kShotColorGhost = 2,
    kShotColorInert = 3,
};
} // namespace

namespace {

constexpr int kRenderStateFirst = 1;
constexpr int kRenderStateCount = 7;

constexpr int kRenderTypeLongNote = 1;
constexpr int kRenderTypeSlideNote = 3;

constexpr int kRenderSideOwn = 0;
constexpr int kRenderSideNone = 3;

constexpr int kRenderGameTypeVersus = 1;
constexpr int kRenderRivalModeHiddenFirst = 1;
constexpr int kRenderRivalModeHiddenCount = 2;

constexpr int kRenderLinkEndCapMask = 2;
constexpr int kRenderTimingSelBound = 10;

constexpr int kRenderLongTrailState = 3;
constexpr int kRenderLongTrailGradeBound = 3;

constexpr float kRenderPlayClockScale = 1000.0f;   // @ghidraAddress 0x2f8540
constexpr float kRenderPlayClockOffset = -1500.0f; // @ghidraAddress 0x308b60

constexpr float kRenderChargeAngleOffset = 1.5707963267948966f; // @ghidraAddress 0x2fedd8 (pi/2)

constexpr int kRenderChainSkipStateUnset = 0;
constexpr int kRenderChainSkipStateRetired = 8;

constexpr float kRenderMirrorPositive = 1.0f;
constexpr float kRenderMirrorNegative = -1.0f;

} // namespace

// The binary re-tests the flip for every coordinate it mirrors, so these stay per-coordinate.
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
    // The null test is ours; the binary reads the link word without re-checking the record.
    if (m_pRecord == nullptr) {
        return false;
    }
    const unsigned int nTimingSel = static_cast<unsigned int>(m_pRecord->GetTimingSel());
    return (m_pRecord->GetLinkA() & kRenderLinkEndCapMask) == 0 &&
           nTimingSel < kRenderTimingSelBound;
}

/** @ghidraAddress 0x135388 */
void NoteModel::RenderNote() {
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

    if (m_bShotResolved) {
        const float flAngle =
            static_cast<float>(atan2(static_cast<double>(MirrorRenderY(m_velocity.y)),
                                     static_cast<double>(-MirrorRenderX(m_velocity.x)))) +
            kRenderChargeAngleOffset;
        JustReflecEffectLayer::shared()->Create(GetRenderSide(),
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
            // The bounds tests are ours; the binary indexes both without a lower bound.
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

    if (m_nState == kRenderLongTrailState &&
        static_cast<unsigned int>(m_nLongGrade) < kRenderLongTrailGradeBound) {
        NoteTrailLayer::shared()->Create(
            m_nLongGrade, MirrorRenderX(m_pos.x), MirrorRenderY(m_pos.y));
    }

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
    // The binary folds both states into a single `(state | 8) != 8` test.
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

// @ghidraAddress 0x308bb4, 0x308bd0, 0x308bec, 0x308c08
constexpr int kSingleBounceBandMap[] = {-2, -2, -1, 0, 1, 2, 2};
constexpr int kDoubleBounceBandMap[] = {0, 0, 1, 1, 1, 2, 2};
constexpr int kReflectBounceBandMap[] = {-2, -1, -1, 0, 1, 1, 2};
constexpr int kReflectLaneBandMap[] = {-2, 0, 2};

constexpr int kSingleBounceBaseBand = 3;
constexpr int kSingleBounceMinBand = 2;
constexpr int kSingleBounceMaxBand = 5;
constexpr int kReflectBounceBaseBand = 2;
constexpr int kReflectBounceMinBand = 1;
constexpr int kReflectBounceMaxBand = 4;
constexpr int kDoubleBounceMinBand = 0;
constexpr int kDoubleBounceMaxBand = 7;

constexpr int kDoubleBounceSecondStep = 5;
constexpr int kBounceMirrorSpan = 6;

constexpr int kBounceBandPlaySide = 6;
constexpr int kBounceBandOtherSide = 3;

constexpr int kRouteLaneOwnSide = 3;
constexpr int kRouteLaneNone = -1;

constexpr int kRouteKindPlain = 0;
constexpr int kRouteKindReflect = 1;
constexpr int kRouteKindNone = 3;

// A route with n bounces fills n + 2 nodes: the spawn point, one per bounce, and the target line.
constexpr int kRouteEndpointCount = 2;

constexpr int kRouteMaxSegmentCount = 3;

constexpr int kWaypointBlockSize = kWaypointBlockNodeCount * static_cast<int>(sizeof(WaypointNode));

int ClampBounceBand(int nBand, int nMin, int nMax) {
    if (nBand > nMax) {
        return nMax;
    }
    return nBand < nMin ? nMin : nBand;
}

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
    const int nBand = IsOnPlaySide() != 0 ? kBounceBandPlaySide : kBounceBandOtherSide;
    const int nLane = m_pRecord != nullptr ? m_pRecord->GetDisplayLane() :
                                             (m_bOwnSide ? kRouteLaneOwnSide : kRouteLaneNone);
    const GameSystem *pGameSystem = GameSystem::GetGameSystem();
    const float flInsetHalfX = pGameSystem->GetSheetInsetHalfX();
    const float flInsetHalfY = pGameSystem->GetSheetInsetHalfY();

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
            // The binary writes node 0 twice; the repeat is kept for fidelity.
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
    float flTotalLength = 0.0f;
    for (int i = 0; i <= m_nWaypointCount && i < kRouteMaxSegmentCount; ++i) {
        WaypointNode &node = m_aWaypointBlock[i];
        node.endPos = m_aWaypointBlock[i + 1].startPos;
        SubtractVector2(&node.endPos, &node.startPos);
        node.flLength = Vector2Length(&node.endPos);
        flTotalLength += node.flLength;
    }

    const float flHitTime = GetHitTime();
    if (m_nWaypointCount + kRouteEndpointCount > 0) {
        m_aWaypointBlock[0].flStartTime = m_flSpawnTime;
    }
    if (m_nWaypointCount >= 0) {
        const float flSpeed = flTotalLength / (flHitTime - m_flSpawnTime);
        for (int i = 0; i <= m_nWaypointCount && i < kRouteMaxSegmentCount; ++i) {
            WaypointNode &node = m_aWaypointBlock[i];
            ScaleVector2(&node.endPos, flSpeed / node.flLength);
            m_aWaypointBlock[i + 1].flStartTime = node.flStartTime + node.flLength / flSpeed;
        }
    }

    // The binary folds both bounds into one unsigned compare.
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
        // The chain-link block's chain id doubles as the head note's index.
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
constexpr int kShotColorOwnSide = 0;
constexpr int kShotColorNoPartner = 3;
constexpr int kAutoShotModeUser = 0;
constexpr int kAutoShotModeCpu = 1;
constexpr float kShotDirectionSplit = 0.5f;
constexpr float kInverseRandMax = 1.0f / 2147483647.0f; // @ghidraAddress 0x3014d0
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
        if (pGauge->GetAnotherValue(nColor) >= 1.0f) {
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

    if (m_bShotResolved) {
        SetShotDirection(PickShotBounceDirection());
    }
    m_bShotActive = false;
}

/** @ghidraAddress 0x13663c */
void NoteModel::CheckShotGhost() {
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

    if (m_bEmphasisFallback && !m_bShotResolved) {
        NoteEffectMgr::shared()->IncrementHitCount();
    }

    if (m_bShotResolved) {
        SetShotDirection(PickShotBounceDirection());
    }
    m_bShotActive = false;
}

int NoteModel::PickShotBounceDirection() const {
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
constexpr float kPlayerFlickThreshold = 20.0f;
} // namespace

/** @ghidraAddress 0x1361ec */
void NoteModel::CheckShotPlayer() {
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

        const float flSideX = m_pos.x * (IsSideFlipped() ? 1.0f : -1.0f);
        const float flDx = flSideX - pTouchPos->x;
        const float flSideY = m_pos.y * (IsSideFlipped() ? -1.0f : 1.0f);
        const float flDy = flSideY - pTouchPos->y;
        if (flDx * flDx + flDy * flDy >= flDiameterSq) {
            continue;
        }

        const float flDrag = static_cast<float>(pTouch->nCurrentX - pTouch->nBeginX);
        const float flSideDrag = IsSideFlipped() ? flDrag : -flDrag;
        if (flSideDrag <= kPlayerFlickThreshold && flSideDrag >= -kPlayerFlickThreshold) {
            continue;
        }

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

        m_bShotActive = false;
        if (!m_bShotResolved) {
            return;
        }

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
constexpr float kJudgeWindowJustHigh = 153.0f;      // @ghidraAddress 0x308b64
constexpr float kJudgeWindowJustLow = -34.0f;       // @ghidraAddress 0x308b6c
constexpr float kJudgeWindowNearHigh = 102.0f;      // @ghidraAddress 0x308b70
constexpr float kJudgeWindowNearLow = -102.0f;      // @ghidraAddress 0x308b74
constexpr float kMissWindowLow = -153.0f;           // @ghidraAddress 0x308b78
constexpr float kJudgeWindowJustHighNarrow = 34.0f; // @ghidraAddress 0x2fd00c
enum NoteGrade {
    kGradeJust = 0,
    kGradeEarlyLate = 1,
    kGradeFar = 2,
};
constexpr int kNoteKindTapOnly = 3;
constexpr int kMaxDefaultSoundIndex = 2;
constexpr int kRivalTapSoundIndex = 3;
} // namespace

/** @ghidraAddress 0x133dfc */
void NoteModel::PlayNoteTapSound(int nSoundIndex, bool bUseAlt) {
    NoteEffectMgr *pManager = m_pSheet;
    if (m_nRivalMode == 0) {
        assert(nSoundIndex <= kMaxDefaultSoundIndex);
    } else {
        if (!GameSystem::GetGameSystem()->GetCpuFullCombo()) {
            if (bUseAlt) {
                if (pManager != nullptr && pManager->IsNoteFlag40Set(m_nNoteIndex)) {
                    return;
                }
            } else if (pManager != nullptr && pManager->IsNoteScoreExcluded(m_nNoteIndex)) {
                return;
            }
        }
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
constexpr int kNoteStateTouchableExisting = 2;
constexpr int kNoteStateTouchableSlide = 5;
constexpr float kTouchBelowLineThreshold = -64.0f; // @ghidraAddress 0x308b7c
} // namespace

/** @ghidraAddress 0x135ee8 */
bool NoteModel::CheckTouchHit(float flX, float flY, float *pOutDistanceSq) const {
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

    if (!bInWindow && m_pos.y - GetTargetLineY() < kTouchBelowLineThreshold) {
        return false;
    }

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
// @ghidraAddress 0x308c14
constexpr float kEmphasisProbability[] = {
    0.02f, 0.02f, 0.02f, 0.02f, 0.05f, 0.1f, 0.1f, 0.6f, 0.6f, 0.7f};
constexpr int kEmphasisProbabilityMax = 9;
// Game types zero and two are the two-side versus modes.
constexpr int kGameTypeVersusMask = 2;
constexpr int kEmphasisNoSide = 3;
} // namespace

/** @ghidraAddress 0x136884 */
bool NoteModel::ShouldEmphasize() const {
    GameSystem *pGameSystem = GameSystem::GetGameSystem();

    const int nCombo = pGameSystem->GetComboCount();
    const int nProbabilityIndex =
        nCombo < 0 ? 0 : (nCombo > kEmphasisProbabilityMax ? kEmphasisProbabilityMax : nCombo);
    if (static_cast<float>(rand()) * kInverseRandMax < kEmphasisProbability[nProbabilityIndex]) {
        return true;
    }

    if ((pGameSystem->GetGameType() | kGameTypeVersusMask) == kGameTypeVersusMask) {
        int nSide;
        if (m_pRecord == nullptr) {
            nSide = m_bOwnSide ? 0 : kEmphasisNoSide;
        } else {
            nSide = m_pRecord->GetSide();
        }
        if ((pGameSystem->GetPlayColor() == 0 ? 1 : 0) != nSide) {
            if (pGameSystem->GetCpuFullCombo()) {
                return true;
            }
            return m_bEmphasisFallback;
        }
    }
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
        const int nLinkIndex = pPathPoints != nullptr ? pPathPoints[nPoint] : -1;
        pManager->ActivateNoteByIndex(nLinkIndex);
        m_bJustHit = false;
    }
}

namespace {

constexpr int kNoteTypeSlide = 3;

} // namespace

/** @ghidraAddress 0x133ec0 */
void NoteModel::ResolveNoteHit(unsigned int nGrade) {
    if (nGrade == 0) {
        m_bJustHit = true;
    }

    int nTapGrade = static_cast<int>(nGrade);

    if (m_pRecord != nullptr) {
        const int nType = m_pRecord->GetType();
        if (nType == kNoteTypeSlide) {
            m_nState = kNoteStateSlideExisting;
            m_nSubState = 0;
            m_nActiveKind = static_cast<int>(nGrade);
            nTapGrade = 0;
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

    m_bScored = true;
    m_nState = kNoteStateFinished;
    m_nSubState = 0;

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
        nKind = m_bOwnSide ? 0 : kNoSideSentinel;
        nLane = m_bOwnSide ? kNoSideSentinel : -1;
    }
    return GetNoteLaneFraction(nKind, nLane) * GameSystem::GetGameSystem()->GetSheetInsetHalfX();
}

// Reached through the __mod_init_func table (the pointer at 0x358cb8), not by name.
/** @ghidraAddress 0x136afc */
__attribute__((constructor)) void InitNoteLaneTable() {
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
    if (nKind == kWideLaneKind) {
        if (nLane == kWideLaneLeft) {
            return 0.0f;
        }
        if (nLane == kWideLaneRight) {
            return g_noteLaneTable.flWideLaneRight;
        }
        // The fall-through is the left wide lane, not the centre (0x136a98).
        return g_noteLaneTable.flWideLaneLeft;
    }

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
    S_VECTOR3 rayOrigin;
    S_VECTOR3 rayDir;
    ComputeScreenPickRay(pPointInOut, &rayOrigin, &rayDir);

    S_VECTOR3 downRef{0.0f, 0.0f, -1.0f};
    S_VECTOR3 negOrigin;
    SubtractVector3(&negOrigin, &rayOrigin);
    const float flNum = DotProductVector3(&downRef, &negOrigin);
    const float flDen = DotProductVector3(&downRef, &rayDir);

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
    // The binary sums s*m + s*m, so the result is twice the scaled slope.
    const float flSlope =
        nBand < kCenterBand ? g_flPlayfieldNearLaneSlope : g_flPlayfieldNearLaneSlopeNeg;
    return (flSlope * kBandFractions[nBand]) + (flSlope * kBandFractions[nBand]);
}

namespace {

// The slide path indexes this by a slide point's target, which runs to 9, so the trailing zero
// slots are reachable.
constexpr int kActivationLaneCount = 10;
constexpr int kActivationCenterLane = 3;

constexpr int kActivationFallbackLane = 2;

constexpr int kNoChosenTarget = -1;

constexpr int kNoteStateActivated = 2;
constexpr int kNoteStateSpawning = 1;
constexpr int kNoteStatePassed = 8;

constexpr float kInitialShotDecayTimer = 100.0f;
constexpr float kInitialShotSpeed = 0.0f;
constexpr float kInitialShotProgress = 1.0f;

constexpr int kLongGradeUnset = 5;

constexpr float kInitialAppearScale = 1.0f;
constexpr float kInitialFadeTimer = 1.0f;

constexpr float kMirrorScale = -1.0f;

constexpr int kSlideKindLevel = 0;
constexpr int kSlideKindRising = 1;
constexpr int kSlideKindFalling = 2;
constexpr int kSlideKindTerminal = 3;

constexpr int kActiveIndexNone = -1;

constexpr int kGameTypeVersus = 1;
constexpr int kGameTypeReplay = 2;

constexpr int kRivalModeOther = 1;
constexpr int kRivalModeOtherReplay = 2;

constexpr int kHoldKindHeld = 1;

// The binary writes the three trailing zeros only on the slide arm, the only arm that reads them.
inline void BuildActivationLaneFractions(float (&aFractions)[kActivationLaneCount]) {
    aFractions[0] = g_noteLaneTable.flLaneFrac0;
    aFractions[1] = g_noteLaneTable.flLaneFrac1;
    aFractions[2] = g_noteLaneTable.flLaneFrac2;
    aFractions[kActivationCenterLane] = 0.0f;
    aFractions[4] = g_noteLaneTable.flLaneFrac4;
    aFractions[5] = g_noteLaneTable.flLaneFrac5;
    aFractions[6] = g_noteLaneTable.flLaneFrac6;
    aFractions[7] = 0.0f;
    aFractions[8] = 0.0f;
    aFractions[9] = 0.0f;
}

} // namespace

/** @ghidraAddress 0x134128 */
void NoteModel::Init() {
    RbffNoteRecord *pRecord = m_pRecord;
    NoteModel *pMirrorSource = nullptr;
    bool bBasePosSet = false;

    if (pRecord != nullptr) {
        if (pRecord->GetStartTime() >= 0) {
            pMirrorSource = m_pSheet->FindNoteByIndex(pRecord->GetStartTime());
            pRecord = m_pRecord;
        }
        if (pRecord != nullptr) {
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
        S_VECTOR2 mirrored = pMirrorSource->m_pos;
        ScaleVector2(&mirrored, kMirrorScale);
        m_basePos = mirrored;
        bBasePosSet = true;
    }

    if (!bBasePosSet) {
        pRecord = m_pRecord;
        // The binary reads this without a null check; activation only runs for recorded notes.
        const bool bSlidePath = pRecord->GetChosenTarget() != kNoChosenTarget;

        float aLaneFractions[kActivationLaneCount];
        BuildActivationLaneFractions(aLaneFractions);

        const int nOwnLane = pRecord != nullptr ? pRecord->GetColor() : kActivationFallbackLane;
        m_basePos = S_VECTOR2{
            aLaneFractions[nOwnLane] * GameSystem::GetGameSystem()->GetSheetInsetHalfX(),
            g_flPlayfieldMidLaneSlope * GameSystem::GetGameSystem()->GetSheetInsetHalfY()};

        if (bSlidePath) {
            pRecord = m_pRecord;
            if (pRecord->GetSlidePointCount() > 0) {
                m_nActiveIndex = kActiveIndexNone;
                for (int nPoint = 0; nPoint < m_pRecord->GetSlidePointCount(); ++nPoint) {
                    SubEntry &entry = m_aSubEntries[nPoint];
                    const RbffSlideRecord &slide = m_pRecord->GetSlideRecord()[nPoint];
                    entry.nIndex = slide.nTimingSel;

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

                    const RbffSlideRecord &times = m_pRecord->GetSlideRecord()[nPoint];
                    const float flTime = static_cast<float>(times.nValueB + times.nValueA);
                    entry.flTime0 = flTime;
                    entry.flTime1 = flTime;
                    entry.flTime2 = flTime;

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

                    // Both slopes divide by a zero time span here; the approach step recomputes
                    // them once it has spread the times.
                    entry.flCurX = entry.flStartX;
                    entry.flCurY = entry.flStartY;
                    entry.flSlopeX =
                        (entry.flEndX - entry.flStartX) / (entry.flTime1 - entry.flTime0);
                    entry.flSlopeY =
                        (entry.flEndY - entry.flStartY) / (entry.flTime2 - entry.flTime1);
                }

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

    int nDirection = 0;
    if (pMirrorSource != nullptr && pMirrorSource->m_bScored) {
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
        m_nState = kNoteStateSpawning;
        m_nSubState = 0;
        m_flAppearScale = 0.0f;
        m_flFadeTimer = 0.0f;
        if (GameSystem::GetGameSystem()->GetRivalAlpha() != 0.0f ||
            GameSystem::GetGameSystem()->GetGameType() == kGameTypeVersus || IsOnPlaySide()) {
            NoteBornLayer *pBornLayer = NoteBornLayer::shared();
            const int nSide =
                m_pRecord != nullptr ? m_pRecord->GetSide() : (m_bOwnSide ? 0 : kNoSideSentinel);
            const float flX = m_pos.x * (IsSideFlipped() ? 1.0f : -1.0f);
            const float flY = m_pos.y * (IsSideFlipped() ? -1.0f : 1.0f);
            pBornLayer->Create(nSide, flX, flY);
        }
        m_flBornTime = m_flSpawnTime;
    }

    SetRoute();

    if (m_pRecord->GetSlidePointCount() > 0) {
        m_bLongNoteActive = false;
    }

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
