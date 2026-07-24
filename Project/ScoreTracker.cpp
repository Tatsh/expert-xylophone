#include "ScoreTracker.h"

// The process-wide score tracker, created lazily by GetScoreTracker.
static ScoreTracker *g_pScoreTracker = nullptr; // @ghidraAddress 0x3de4b0

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
        PlayFieldLayerBase *pLayer = GetPlayerFieldLayer();
        SetScoreDigitTarget(0.0f, pLayer, nSide, record.nCells[0]);
        ApplyLaneGaugeValueAndBackground(0.0f, this, nSide);
    }
}

/** @ghidraAddress 0x1492cc */
ScoreTracker *GetScoreTracker() {
    if (g_pScoreTracker == nullptr) {
        // The binary allocates the raw object, clears the leading field, then resets the per-side
        // records; value-initialisation zeroes the whole object, so only the record reset remains.
        g_pScoreTracker = new ScoreTracker();
        g_pScoreTracker->ResetLaneGaugeState();
    }
    return g_pScoreTracker;
}
