#import "engineruntime.h"

#include <strings.h>

#import <QuartzCore/QuartzCore.h>

#include "customize_variant_tables.h"
#include "neTexture.h"
#include "ne_c_time.h"
#include "texture_cache_control.h"

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

// The texture-cache control singleton, lazily allocated by C_TEXTURE::EnsureCacheControl.
TextureCacheControl *g_pTextureCacheControl = nullptr; // @ghidraAddress 0x3cff20

/** @ghidraAddress 0x3198c */
void ne::C_TEXTURE::EnsureCacheControl(unsigned char nTag) {
    if (g_pTextureCacheControl != nullptr) {
        return;
    }
    g_pTextureCacheControl = new TextureCacheControl();
    g_pTextureCacheControl->nTag = nTag;
    g_pTextureCacheControl->pNext = nullptr;
    g_pTextureCacheControl->nValue = 0;
    g_pTextureCacheControl->pSpare = nullptr;
}

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

/** @ghidraAddress 0x54ee0 */
NSString *_Nullable BuildCustomizeAssetPathString(int assetType, int variantIndex) {
    // Each handled category formats a path with its variant token; the music item has no variant,
    // and every other category (6, 8, 9) returns nil.
    switch (assetType) {
    case kCustomizeKindBgm:
        return [NSString
            stringWithFormat:@"04_customize/cus_ibgm_%@", g_aCustomizeBgmVariants[variantIndex]];
    case kCustomizeKindShot:
        return [NSString
            stringWithFormat:@"04_customize/cus_ishot_%@", g_aCustomizeShotVariants[variantIndex]];
    case kCustomizeKindExplosion:
        return [NSString stringWithFormat:@"04_customize/cus_iexp_%@",
                                          g_aCustomizeExplosionVariants[variantIndex]];
    case kCustomizeKindFrame:
        return [NSString
            stringWithFormat:@"04_customize/cus_ifrm_%@", g_aCustomizeFrameVariants[variantIndex]];
    case kCustomizeKindBackground:
        return [NSString stringWithFormat:@"04_customize/cus_ibg_%@",
                                          g_aCustomizeBackgroundVariants[variantIndex]];
    case kCustomizeKindObject:
        return [NSString
            stringWithFormat:@"04_customize/cus_iobj_%@", g_aCustomizeObjectVariants[variantIndex]];
    case kCustomizeKindMusic:
        return [NSString stringWithFormat:@"04_customize/cus_imusic"];
    case kCustomizeKindThema:
        return [NSString
            stringWithFormat:@"04_customize/cus_ithm_%@", g_aCustomizeThemaVariants[variantIndex]];
    default:
        return nil;
    }
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
void C_TIME::Start() {
    m_flTime = CACurrentMediaTime();
}

/** @ghidraAddress 0x3671c */
float C_TIME::GetElapsedMillis() const {
    return static_cast<float>((CACurrentMediaTime() - m_flTime) * kMediaTimeMillisScale);
}

/** @ghidraAddress 0x12e900 */
void ZeroMemoryIfNonNull(void *pBuffer, size_t nSize) {
    if (pBuffer != nullptr) {
        bzero(pBuffer, nSize);
    }
}
