#import "engineruntime.h"

namespace {

// The achievement-rate thresholds for each clear rank, highest first. A rate at or above a threshold
// earns that rank; below the lowest earns rank zero.
constexpr float kClearRankThreshold5 = 0.95f; // @ghidraAddress 0x308d3c
constexpr float kClearRankThreshold4 = 0.90f; // @ghidraAddress 0x2ef17c
constexpr float kClearRankThreshold3 = 0.80f; // @ghidraAddress 0x2f856c
constexpr float kClearRankThreshold2 = 0.70f; // @ghidraAddress 0x2fd008
constexpr float kClearRankThreshold1 = 0.50f;

// The clear-rank values the thresholds map to.
constexpr int kClearRank5 = 5;
constexpr int kClearRank4 = 4;
constexpr int kClearRank3 = 3;
constexpr int kClearRank2 = 2;
constexpr int kClearRank1 = 1;
constexpr int kClearRank0 = 0;

} // namespace

/** @ghidraAddress 0x14992c */
int GetClearRank(float achievementRate) {
    if (achievementRate >= kClearRankThreshold5) {
        return kClearRank5;
    }
    if (achievementRate >= kClearRankThreshold4) {
        return kClearRank4;
    }
    if (achievementRate >= kClearRankThreshold3) {
        return kClearRank3;
    }
    if (achievementRate >= kClearRankThreshold2) {
        return kClearRank2;
    }
    return achievementRate >= kClearRankThreshold1 ? kClearRank1 : kClearRank0;
}
