#include "ScoreTracker.h"

// The process-wide score tracker, created lazily by GetScoreTracker.
static ScoreTracker *g_pScoreTracker = nullptr; // @ghidraAddress 0x3de4b0

/** @ghidraAddress 0x1492cc */
ScoreTracker *GetScoreTracker() {
    if (g_pScoreTracker == nullptr) {
        // The binary allocates the raw object, clears the leading field, then resets the per-side
        // records; value-initialisation zeroes the whole object, so only the record reset remains.
        g_pScoreTracker = new ScoreTracker();
        ResetLaneGaugeState(g_pScoreTracker);
    }
    return g_pScoreTracker;
}
