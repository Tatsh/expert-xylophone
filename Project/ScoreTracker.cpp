#include "ScoreTracker.h"

#include <cassert>

#include "bg_layer.h"
#include "clear_gauge_layer.h"
#include "engineglobals.h"
#include "gamesystem.h"
#include "judge_effect_layer.h"
#include "note_result_layer.h"

// The process-wide score tracker, created lazily by GetScoreTracker.
static ScoreTracker *g_pScoreTracker = nullptr; // @ghidraAddress 0x3de4b0

// The gauge value at or below which the 2P side shows the low-gauge danger warning.
constexpr float kLowGaugeWarningThreshold = 0.7f; // @ghidraAddress 0x2fd008

// The second player's side index; only this side drives the background clear-effect overlay.
constexpr unsigned int kSecondPlayerSide = 1;

namespace {

// The score bonuses awarded per judgement grade by the SetJudgeScore* helpers.
constexpr int kJudgeBonus0 = 0x32;
constexpr int kJudgeBonus2 = 0x19;
constexpr int kJudgeBonus3 = 10;

// The duration the score digits roll up to a new bonus score over. This reads the shared 300.0
// float literal the binary pools across many timing sites (@ghidraAddress 0x2eedcc).
constexpr float kBonusScoreAnimDuration = 300.0f;

// The play-record cell indices AddScore addresses by name.
enum ScoreCell {
    kCellScore = 0,    // The running score.
    kCellCombo = 1,    // The current combo.
    kCellMaxCombo = 2, // The maximum combo reached.
    kCellJust = 3,     // The just-judgement counter.
    kCellGreat = 4,    // The great-judgement counter.
    kCellGood = 5,     // The good-judgement counter.
    kCellMiss = 6,     // The miss-judgement counter.
};

// The judgement types AddScore classifies.
enum JudgeType {
    kJudgeJust = 0,
    kJudgeGreat = 1,
    kJudgeGood = 2,
    kJudgeMiss = 3,
    kJudgeTypeCount = 4,
};

// The score deltas applied per judgement (a miss deepens to -13 when the bonus flag is set).
constexpr int kScoreDeltaJust = 3;
constexpr int kScoreDeltaGreat = 2;
constexpr int kScoreDeltaGood = 1;
constexpr int kScoreDeltaMiss = -3;
constexpr int kScoreDeltaMissBonus = -13;

// The clear-rate numerator weights: just counts triple, great double, good single.
constexpr int kRateWeightJust = 3;
constexpr int kRateWeightGreat = 2;
constexpr int kRateDenominatorScale = 3;

// The achievement-rate thresholds for each grade tier, highest first (the same tiers GetClearRank
// uses); a rate at or above a threshold earns that tier, and below the lowest earns tier zero.
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

// The record cell holding a lane's judged-note (hit) count.
constexpr int kCellHitCount = 7;
// The fixed score a shot-note lane judgement adds.
constexpr int kLaneJudgeScore = 10;
// The lane slot a note with no play side maps to (past the two named sides; the binary reads the
// scratch record there faithfully).
constexpr unsigned int kNoSideLaneSlot = 3;

// The leading-side indicator stored in each record's trailing field.
enum LeadingSide {
    kLeadingSideFirst = 0,  // The first side leads.
    kLeadingSideSecond = 1, // The second side leads.
    kLeadingSideTie = 2,    // The two sides are tied.
};

// The result-quad band selection thresholds against the sheet's near-plane half-width.
constexpr float kBandNearFactor = -0.25f;
constexpr float kBandFarFactor = 0.25f;

// The result-quad band base offsets: a matching-side hit shifts up by six, a non-default mode by
// three, and the near/mid/far screen thirds pick the low/high pair within a band.
constexpr int kBandSideMatchOffset = 6;
constexpr int kBandModeOffset = 3;

} // namespace

/** @ghidraAddress 0x14983c */
void ScoreTracker::ComputeLaneClearRateAndGrade() {
    // Pick the leading side from the two sides' first counters, recording it in each side's trailing
    // field.
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

    // Compute each side's clear rate and grade tier.
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
    // Zero each side's play record, then repaint that side's score digits and lane gauge from the
    // now-zeroed value.
    for (unsigned int nSide = 0; nSide < kSideCount; ++nSide) {
        PlayRecord &record = m_aRecords[nSide];
        // The binary clears only the judgement counters, leaving the rate, rank, and trailing field.
        for (int &nCell : record.nCells) {
            nCell = 0;
        }
        SetScoreDigitTarget(0.0f, PlayerFieldLayer::shared(), nSide, record.nCells[0]);
        ApplyLaneGaugeValueAndBackground(0.0f, nSide);
    }
}

/** @ghidraAddress 0x149324 */
void ScoreTracker::ApplyLaneGaugeValueAndBackground(float flValue, unsigned int uSide) {
    // Store the value into this side's play-record rate slot, then push it to the clear-gauge bar.
    m_aRecords[uSide].flRate = flValue;
    ClearGaugeLayer::shared()->SetValue(flValue, uSide);
    // Only the 2P side drives the background clear-effect overlay.
    if (uSide == kSecondPlayerSide) {
        BgLayer::GetBackgroundLayer()->SetClearEffectActive(kLowGaugeWarningThreshold <= flValue);
    }
}

/** @ghidraAddress 0x18b7cc */
void ScoreTracker::SetScoreDigitTarget(float flDuration,
                                       PlayerFieldLayer *pLayer,
                                       unsigned int uSide,
                                       int nValue) {
    ScoreDigitField &field = pLayer->GetScoreDigitField(uSide);
    field.nTarget = nValue;
    field.flFrom = field.flCurrent;
    field.flTo = static_cast<float>(nValue);
    field.flElapsed = 0.0f;
    field.flDuration = flDuration;
}

/** @ghidraAddress 0x1492cc */
ScoreTracker *ScoreTracker::shared() {
    if (g_pScoreTracker == nullptr) {
        // The binary allocates the raw object, clears the leading field, then resets the per-side
        // records; value-initialisation zeroes the whole object, so only the record reset remains.
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

    // Choose the result-quad band from the hit's screen x against the sheet's quarter-width, shifted
    // by the play mode and whether the note is on the current play side.
    const float flPosX = static_cast<float>(nPosX);
    const float flSheetPosX = GameSystem::GetGameSystem()->GetSheetPosX();
    const int nGroup = (bSideMatch ? kBandSideMatchOffset : 0) + (nMode != 0 ? kBandModeOffset : 0);
    int nBand;
    if (flPosX < flSheetPosX * kBandNearFactor) {
        nBand = nGroup;
    } else {
        nBand = flPosX > flSheetPosX * kBandFarFactor ? nGroup + 2 : nGroup + 1;
    }

    // Map the judgement to its score delta and the counter cell it bumps.
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
    // Apply the score delta, clamped at zero, and bump the judgement counter.
    int nScore = record.nCells[kCellScore] + nDelta;
    if (nScore < 0) {
        nScore = 0;
    }
    record.nCells[kCellScore] = nScore;
    ++record.nCells[nCounterCell];

    // Advance the combo (a miss breaks it) and track the maximum.
    const int nCombo = nJudge != kJudgeMiss ? record.nCells[kCellCombo] + 1 : 0;
    record.nCells[kCellCombo] = nCombo;
    if (record.nCells[kCellMaxCombo] < nCombo) {
        record.nCells[kCellMaxCombo] = nCombo;
    }

    // Recompute the clear rate: (just*3 + great*2 + good) / (totalNotes*3).
    const float flRateNumerator =
        static_cast<float>(record.nCells[kCellJust] * kRateWeightJust +
                           record.nCells[kCellGreat] * kRateWeightGreat + record.nCells[kCellGood]);
    const float flRate =
        flRateNumerator / static_cast<float>(m_nTotalNotes * kRateDenominatorScale);
    ApplyLaneGaugeValueAndBackground(flRate, bSideMatch ? 1 : 0);

    // Fire the result-quad and score-digit effects.
    NoteResultLayer::shared()->Create(static_cast<unsigned int>(nBand), nJudge, nCombo);
    SetScoreDigitTarget(0.0f, PlayerFieldLayer::shared(), bSideMatch ? 1 : 0, nScore);
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
    SetScoreDigitTarget(0.0f, PlayerFieldLayer::shared(), nSide, nScore);
}

/** @ghidraAddress 0x149678 */
void ScoreTracker::AddLaneJudgeResult(int nPlayerSide, unsigned int nJudgeFlags) {
    // Map the player side to a lane slot: side 0 -> 1, side 1 -> 0, anything else -> the 3 (no-side)
    // slot. The no-side slot reads one record past the two named sides, reproduced faithfully.
    unsigned int nSlot;
    if (nPlayerSide == 0) {
        nSlot = 1;
    } else if (nPlayerSide == 1) {
        nSlot = 0;
    } else {
        nSlot = kNoSideLaneSlot;
    }

    PlayRecord &record = m_aRecords[nSlot];
    // The no-score path (a bit-0 flag) only advances the lane's hit counter.
    if ((nJudgeFlags & 1) != 0) {
        ++record.nCells[kCellHitCount];
        return;
    }

    // Otherwise add the fixed lane score, bump the hit counter, repaint the digits, and fire the
    // judge effect.
    record.nCells[kCellScore] += kLaneJudgeScore;
    ++record.nCells[kCellHitCount];
    SetScoreDigitTarget(
        kBonusScoreAnimDuration, PlayerFieldLayer::shared(), nSlot, record.nCells[kCellScore]);
    JudgeEffectLayer::shared()->TriggerJudgeEffect(nSlot, kLaneJudgeScore, 1);
}

/** @ghidraAddress 0x149710 */
void ScoreTracker::SetJudgeScore0(unsigned int nSide) {
    int &nScore = m_aRecords[nSide].nCells[0];
    nScore += kJudgeBonus0;
    SetScoreDigitTarget(kBonusScoreAnimDuration, PlayerFieldLayer::shared(), nSide, nScore);
    JudgeEffectLayer::shared()->TriggerJudgeEffect(nSide, kJudgeBonus0, 0);
}

/** @ghidraAddress 0x14976c */
void ScoreTracker::SetJudgeScore2(unsigned int nSide) {
    int &nScore = m_aRecords[nSide].nCells[0];
    nScore += kJudgeBonus2;
    SetScoreDigitTarget(kBonusScoreAnimDuration, PlayerFieldLayer::shared(), nSide, nScore);
    JudgeEffectLayer::shared()->TriggerJudgeEffect(nSide, kJudgeBonus2, 2);
}

/** @ghidraAddress 0x1497c8 */
void ScoreTracker::SetJudgeScore3(unsigned int nSide) {
    int &nScore = m_aRecords[nSide].nCells[0];
    nScore += kJudgeBonus3;
    SetScoreDigitTarget(kBonusScoreAnimDuration, PlayerFieldLayer::shared(), nSide, nScore);
    JudgeEffectLayer::shared()->TriggerJudgeEffect(nSide, kJudgeBonus3, 3);
}

/** @ghidraAddress 0x1499d8 */
bool ScoreTracker::IsSideAllNotesJudged(unsigned int nSide) const {
    const PlayRecord &record = m_aRecords[nSide];
    const int nJudged =
        record.nCells[kCellGreat] + record.nCells[kCellGood] + record.nCells[kCellMiss];
    return nJudged == m_nTotalNotes;
}
