#include "ScoreTracker.h"

#include "bg_layer.h"
#include "clear_gauge_layer.h"

// The process-wide score tracker, created lazily by GetScoreTracker.
static ScoreTracker *g_pScoreTracker = nullptr; // @ghidraAddress 0x3de4b0

// The gauge value at or below which the 2P side shows the low-gauge danger warning.
constexpr float kLowGaugeWarningThreshold = 0.7f; // @ghidraAddress 0x2fd008

// The second player's side index; only this side drives the background clear-effect overlay.
constexpr unsigned int kSecondPlayerSide = 1;

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
