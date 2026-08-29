#include "ScoreTracker.h"

#include <cassert>

#include "bg_layer.h"
#include "clear_gauge_layer.h"
#include "engineglobals.h"
#include "gamesystem.h"
#include "judge_effect_layer.h"
#include "note_result_layer.h"

static ScoreTracker *g_pScoreTracker = nullptr; // @ghidraAddress 0x3de4b0

constexpr float kLowGaugeWarningThreshold = 0.7f; // @ghidraAddress 0x2fd008

constexpr unsigned int kSecondPlayerSide = 1;

namespace {

constexpr int kJudgeBonus0 = 0x32;
constexpr int kJudgeBonus2 = 0x19;
constexpr int kJudgeBonus3 = 10;

// @ghidraAddress 0x2eedcc
constexpr float kBonusScoreAnimDuration = 300.0f;

enum ScoreCell {
    kCellScore = 0,
    kCellCombo = 1,
    kCellMaxCombo = 2,
    kCellJust = 3,
    kCellGreat = 4,
    kCellGood = 5,
    kCellMiss = 6,
};

enum JudgeType {
    kJudgeJust = 0,
    kJudgeGreat = 1,
    kJudgeGood = 2,
    kJudgeMiss = 3,
    kJudgeTypeCount = 4,
};

constexpr int kScoreDeltaJust = 3;
constexpr int kScoreDeltaGreat = 2;
constexpr int kScoreDeltaGood = 1;
constexpr int kScoreDeltaMiss = -3;
constexpr int kScoreDeltaMissBonus = -13;

constexpr int kRateWeightJust = 3;
constexpr int kRateWeightGreat = 2;
constexpr int kRateDenominatorScale = 3;

constexpr float kGradeThreshold5 = 0.95f; // @ghidraAddress 0x308d3c
constexpr float kGradeThreshold4 = 0.90f; // @ghidraAddress 0x2ef17c
constexpr float kGradeThreshold3 = 0.80f; // @ghidraAddress 0x2f856c
constexpr float kGradeThreshold2 = 0.70f; // @ghidraAddress 0x2fd008
constexpr float kGradeThreshold1 = 0.50f;
constexpr int kGradeTier5 = 5;
constexpr int kGradeTier4 = 4;
constexpr int kGradeTier3 = 3;
constexpr int kGradeTier2 = 2;
constexpr int kGradeTier1 = 1;
constexpr int kGradeTier0 = 0;

constexpr int kCellHitCount = 7;
constexpr int kLaneJudgeScore = 10;
constexpr unsigned int kNoSideLaneSlot = 3;

enum LeadingSide {
    kLeadingSideFirst = 0,
    kLeadingSideSecond = 1,
    kLeadingSideTie = 2,
};

constexpr float kBandNearFactor = -0.25f;
constexpr float kBandFarFactor = 0.25f;

constexpr int kBandSideMatchOffset = 6;
constexpr int kBandModeOffset = 3;

} // namespace

/** @ghidraAddress 0x14983c */
void ScoreTracker::ComputeLaneClearRateAndGrade() {
    const int nFirstSideLead = m_aRecords[0].nCells[kCellScore];
    const int nSecondSideLead = m_aRecords[1].nCells[kCellScore];
    if (nSecondSideLead < nFirstSideLead) {
        m_aRecords[0].nField10 = kLeadingSideFirst;
        m_aRecords[1].nField10 = kLeadingSideSecond;
    } else if (nFirstSideLead < nSecondSideLead) {
        m_aRecords[0].nField10 = kLeadingSideSecond;
        m_aRecords[1].nField10 = kLeadingSideFirst;
    } else {
        m_aRecords[0].nField10 = kLeadingSideTie;
        m_aRecords[1].nField10 = kLeadingSideTie;
    }

    for (int nSide = 0; nSide < kSideCount; ++nSide) {
        PlayRecord &record = m_aRecords[nSide];
        const int nNumerator = record.nCells[kCellJust] * kRateWeightJust +
                               record.nCells[kCellGreat] * kRateWeightGreat +
                               record.nCells[kCellGood];
        const float flClearRate = static_cast<float>(nNumerator) /
                                  static_cast<float>(m_nTotalNotes * kRateDenominatorScale);
        record.flRate = flClearRate;

        int nGrade = kGradeTier0;
        if (flClearRate >= kGradeThreshold5) {
            nGrade = kGradeTier5;
        } else if (flClearRate >= kGradeThreshold4) {
            nGrade = kGradeTier4;
        } else if (flClearRate >= kGradeThreshold3) {
            nGrade = kGradeTier3;
        } else if (flClearRate >= kGradeThreshold2) {
            nGrade = kGradeTier2;
        } else if (flClearRate >= kGradeThreshold1) {
            nGrade = kGradeTier1;
        }
        record.nRank = nGrade;
    }
}

/** @ghidraAddress 0x149268 */
void ScoreTracker::ResetLaneGaugeState() {
    for (unsigned int nSide = 0; nSide < kSideCount; ++nSide) {
        PlayRecord &record = m_aRecords[nSide];
        // The binary clears only the judgement counters, leaving the rate, rank, and last field.
        for (int &nCell : record.nCells) {
            nCell = 0;
        }
        PlayerFieldLayer::shared()->SetScoreDigitTarget(nSide, record.nCells[0], 0.0f);
        ApplyLaneGaugeValueAndBackground(0.0f, nSide);
    }
}

/** @ghidraAddress 0x149324 */
void ScoreTracker::ApplyLaneGaugeValueAndBackground(float flValue, unsigned int uSide) {
    m_aRecords[uSide].flRate = flValue;
    ClearGaugeLayer::shared()->SetValue(flValue, uSide);
    if (uSide == kSecondPlayerSide) {
        BgLayer::GetBackgroundLayer()->SetClearEffectActive(kLowGaugeWarningThreshold <= flValue);
    }
}

/** @ghidraAddress 0x1492cc */
ScoreTracker *ScoreTracker::shared() {
    if (g_pScoreTracker == nullptr) {
        // Value-initialisation zeroes the object, so the binary's field clear is redundant.
        g_pScoreTracker = new ScoreTracker();
        g_pScoreTracker->ResetLaneGaugeState();
    }
    return g_pScoreTracker;
}

/** @ghidraAddress 0x1493b0 */
void ScoreTracker::AddScore(
    int nPlayer, int nPosX, int nPosY, int nJudge, int nBonusFlag, int nMode) {
    (void)nPosY; // The screen y is passed through but unused by the score path.
    const bool bSideMatch = GameSystem::GetGameSystem()->GetPlayColor() == nPlayer;

    const float flPosX = static_cast<float>(nPosX);
    const float flSheetPosX = GameSystem::GetGameSystem()->GetSheetPosX();
    const int nGroup = (bSideMatch ? kBandSideMatchOffset : 0) + (nMode != 0 ? kBandModeOffset : 0);
    int nBand;
    if (flPosX < flSheetPosX * kBandNearFactor) {
        nBand = nGroup;
    } else {
        nBand = flPosX > flSheetPosX * kBandFarFactor ? nGroup + 2 : nGroup + 1;
    }

    int nDelta;
    int nCounterCell;
    switch (nJudge) {
    case kJudgeJust:
        nDelta = kScoreDeltaJust;
        nCounterCell = kCellJust;
        break;
    case kJudgeGreat:
        nDelta = kScoreDeltaGreat;
        nCounterCell = kCellGreat;
        break;
    case kJudgeGood:
        nDelta = kScoreDeltaGood;
        nCounterCell = kCellGood;
        break;
    case kJudgeMiss:
        nDelta = nBonusFlag != 0 ? kScoreDeltaMissBonus : kScoreDeltaMiss;
        nCounterCell = kCellMiss;
        break;
    default:
        assert(0 && "AddScore: judge out of range");
        return;
    }

    PlayRecord &record = m_aRecords[bSideMatch ? 1 : 0];
    int nScore = record.nCells[kCellScore] + nDelta;
    if (nScore < 0) {
        nScore = 0;
    }
    record.nCells[kCellScore] = nScore;
    ++record.nCells[nCounterCell];

    const int nCombo = nJudge != kJudgeMiss ? record.nCells[kCellCombo] + 1 : 0;
    record.nCells[kCellCombo] = nCombo;
    if (record.nCells[kCellMaxCombo] < nCombo) {
        record.nCells[kCellMaxCombo] = nCombo;
    }

    const float flRateNumerator =
        static_cast<float>(record.nCells[kCellJust] * kRateWeightJust +
                           record.nCells[kCellGreat] * kRateWeightGreat + record.nCells[kCellGood]);
    const float flRate =
        flRateNumerator / static_cast<float>(m_nTotalNotes * kRateDenominatorScale);
    ApplyLaneGaugeValueAndBackground(flRate, bSideMatch ? 1 : 0);

    NoteResultLayer::shared()->Create(static_cast<unsigned int>(nBand), nJudge, nCombo);
    PlayerFieldLayer::shared()->SetScoreDigitTarget(bSideMatch ? 1 : 0, nScore, 0.0f);
}

/** @ghidraAddress 0x149610 */
void ScoreTracker::AddScoreDelta(int nPlayer, int nPosX, int nPosY, int nDelta) {
    (void)nPosX; // The hit-position arguments mirror AddScore but are unused here.
    (void)nPosY;
    const unsigned int nSide = GameSystem::GetGameSystem()->GetPlayColor() == nPlayer ? 1 : 0;
    int nScore = m_aRecords[nSide].nCells[kCellScore] + nDelta;
    if (nScore < 0) {
        nScore = 0;
    }
    m_aRecords[nSide].nCells[kCellScore] = nScore;
    PlayerFieldLayer::shared()->SetScoreDigitTarget(nSide, nScore, 0.0f);
}

/** @ghidraAddress 0x149678 */
void ScoreTracker::AddLaneJudgeResult(int nPlayerSide, unsigned int nJudgeFlags) {
    // The no-side slot reads one record past the two named sides, reproduced faithfully.
    unsigned int nSlot;
    if (nPlayerSide == 0) {
        nSlot = 1;
    } else if (nPlayerSide == 1) {
        nSlot = 0;
    } else {
        nSlot = kNoSideLaneSlot;
    }

    PlayRecord &record = m_aRecords[nSlot];
    if ((nJudgeFlags & 1) != 0) {
        ++record.nCells[kCellHitCount];
        return;
    }

    record.nCells[kCellScore] += kLaneJudgeScore;
    ++record.nCells[kCellHitCount];
    PlayerFieldLayer::shared()->SetScoreDigitTarget(
        nSlot, record.nCells[kCellScore], kBonusScoreAnimDuration);
    JudgeEffectLayer::shared()->TriggerJudgeEffect(nSlot, kLaneJudgeScore, 1);
}

/** @ghidraAddress 0x149710 */
void ScoreTracker::SetJudgeScore0(unsigned int nSide) {
    int &nScore = m_aRecords[nSide].nCells[0];
    nScore += kJudgeBonus0;
    PlayerFieldLayer::shared()->SetScoreDigitTarget(nSide, nScore, kBonusScoreAnimDuration);
    JudgeEffectLayer::shared()->TriggerJudgeEffect(nSide, kJudgeBonus0, 0);
}

/** @ghidraAddress 0x14976c */
void ScoreTracker::SetJudgeScore2(unsigned int nSide) {
    int &nScore = m_aRecords[nSide].nCells[0];
    nScore += kJudgeBonus2;
    PlayerFieldLayer::shared()->SetScoreDigitTarget(nSide, nScore, kBonusScoreAnimDuration);
    JudgeEffectLayer::shared()->TriggerJudgeEffect(nSide, kJudgeBonus2, 2);
}

/** @ghidraAddress 0x1497c8 */
void ScoreTracker::SetJudgeScore3(unsigned int nSide) {
    int &nScore = m_aRecords[nSide].nCells[0];
    nScore += kJudgeBonus3;
    PlayerFieldLayer::shared()->SetScoreDigitTarget(nSide, nScore, kBonusScoreAnimDuration);
    JudgeEffectLayer::shared()->TriggerJudgeEffect(nSide, kJudgeBonus3, 3);
}

/** @ghidraAddress 0x1499d8 */
bool ScoreTracker::IsSideAllNotesJudged(unsigned int nSide) const {
    const PlayRecord &record = m_aRecords[nSide];
    const int nJudged =
        record.nCells[kCellJust] + record.nCells[kCellGreat] + record.nCells[kCellGood];
    return nJudged == m_nTotalNotes;
}
