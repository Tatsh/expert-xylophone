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

// The result-quad band selection thresholds against the sheet's near-plane half-width.
constexpr float kBandNearFactor = -0.25f;
constexpr float kBandFarFactor = 0.25f;

// The result-quad band base offsets: a matching-side hit shifts up by six, a non-default mode by
// three, and the near/mid/far screen thirds pick the low/high pair within a band.
constexpr int kBandSideMatchOffset = 6;
constexpr int kBandModeOffset = 3;

} // namespace

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

/** @ghidraAddress 0x149710 */
void ScoreTracker::SetJudgeScore0(unsigned int nSide) {
    int &nScore = m_aRecords[nSide].nCells[0];
    nScore += kJudgeBonus0;
    SetScoreDigitTarget(g_flMascotBaseYOffsetPad, PlayerFieldLayer::shared(), nSide, nScore);
    JudgeEffectLayer::shared()->TriggerJudgeEffect(nSide, kJudgeBonus0, 0);
}

/** @ghidraAddress 0x14976c */
void ScoreTracker::SetJudgeScore2(unsigned int nSide) {
    int &nScore = m_aRecords[nSide].nCells[0];
    nScore += kJudgeBonus2;
    SetScoreDigitTarget(g_flMascotBaseYOffsetPad, PlayerFieldLayer::shared(), nSide, nScore);
    JudgeEffectLayer::shared()->TriggerJudgeEffect(nSide, kJudgeBonus2, 2);
}

/** @ghidraAddress 0x1497c8 */
void ScoreTracker::SetJudgeScore3(unsigned int nSide) {
    int &nScore = m_aRecords[nSide].nCells[0];
    nScore += kJudgeBonus3;
    SetScoreDigitTarget(g_flMascotBaseYOffsetPad, PlayerFieldLayer::shared(), nSide, nScore);
    JudgeEffectLayer::shared()->TriggerJudgeEffect(nSide, kJudgeBonus3, 3);
}
