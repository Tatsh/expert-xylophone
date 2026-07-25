#import "engineruntime.h"

#import <QuartzCore/QuartzCore.h>

namespace {

// The media-timer scale: elapsed seconds are reported in milliseconds. @ghidraAddress 0x2eeea0
constexpr double kMediaTimeMillisScale = 1000.0;

// The achievement-rate thresholds for each clear rank, highest first. A rate at or above a threshold
// earns that rank; below the lowest earns rank zero.
constexpr float kClearRankThreshold5 = 0.95f; // @ghidraAddress 0x308d3c
constexpr float kClearRankThreshold4 = 0.90f; // @ghidraAddress 0x2ef17c
constexpr float kClearRankThreshold3 = 0.80f; // @ghidraAddress 0x2f856c
constexpr float kClearRankThreshold2 = 0.70f; // @ghidraAddress 0x2fd008
constexpr float kClearRankThreshold1 = 0.50f;

// The customize-asset categories BuildCustomizeAssetPathString and GetCustomizeFrameImagePath key
// off. The gaps (6, 8, 9) have no asset path.
enum {
    kCustomizeKindBgm = 0,
    kCustomizeKindShot = 1,
    kCustomizeKindExplosion = 2,
    kCustomizeKindFrame = 3,
    kCustomizeKindBackground = 4,
    kCustomizeKindObject = 5,
    kCustomizeKindMusic = 7,
    kCustomizeKindThema = 10,
};

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

/** @ghidraAddress 0x550dc */
NSString *_Nullable GetCustomizeFrameImagePath(int kind) {
    // Only the music item (kind 7) has a frame overlay; every other customize element returns nil.
    if (kind == kCustomizeKindMusic) {
        return [NSString stringWithFormat:@"04_customize/cus_imusic_frm"];
    }
    return nil;
}

/** @ghidraAddress 0x366f8 */
void StartMediaTimer(double *pStartTime) {
    *pStartTime = CACurrentMediaTime();
}

/** @ghidraAddress 0x3671c */
float GetElapsedMediaTime(double *pStartTime) {
    return static_cast<float>((CACurrentMediaTime() - *pStartTime) * kMediaTimeMillisScale);
}
