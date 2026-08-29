#include "full_combo_limelight_layer.h"

#include <cassert>

#include "../Share/bg_layer.h"
#import "AudioManager.h"
#include "curve.h"
#include "engineglobals.h"
#include "gamesystem.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#include "s_vector2.h"
#include "soundeffectmanager.h"
#include "sprite_uv_table.h"
#include "vectormath.h"

static FullComboLimelightLayer *g_pFullComboLimelightLayer = nullptr; // @ghidraAddress 0x3ddc40

// @ghidraAddress 0x2f7908
extern const SpriteUvEntry g_aTitlePartUvDefault[];

namespace {

constexpr float kLayoutWidth = 384.0f;
constexpr float kLayoutHeight = 1098.0f;

// @ghidraAddress 0x3ceaf0 and 0x3ceaa8
constexpr const char *kEffectTextureName = "00_texture/ti_parts_eff";
constexpr const char *kPartsTextureName = "00_texture/gm_parts2";

// @ghidraAddress 0x306260
constexpr unsigned int kSlotCapacities[] = {256, 32, 32};

// @ghidraAddress 0x30626c
constexpr int kSlotTextureField[] = {0, 1, 2};

constexpr int kAdditiveBlendSlot = 1;
constexpr int kAdditiveBlendMode = 1;

constexpr int kTexParamSlotHigh = 1;
constexpr int kTexParamSlotLow = 0;
constexpr int kTexParamEnabled = 1;

constexpr unsigned int kColorMax = 255;

constexpr int kSpriteTypeCount = 0x4a;

constexpr int kTitlePartBatch = 0;

struct LimelightSpriteDescriptor {
    int nBatch; // Also selects the atlas.
    float flAnchorX;
    float flAnchorY;
    float flSizeX; // In pixels.
    float flSizeY; // In pixels.
    int nUvFrameIndex;
};

// @ghidraAddress 0x307348
constexpr LimelightSpriteDescriptor kLimelightSpriteDescriptors[] = {
    {2, 19.0f, 32.0f, 38.0f, 64.0f, 0x33},   {2, 23.0f, 32.0f, 46.0f, 64.0f, 0x34},
    {2, 19.0f, 32.0f, 38.0f, 64.0f, 0x35},   {2, 19.0f, 32.0f, 38.0f, 64.0f, 0x36},
    {2, 31.0f, 32.0f, 62.0f, 64.0f, 0x37},   {2, 33.0f, 32.0f, 66.0f, 64.0f, 0x38},
    {2, 32.0f, 32.0f, 64.0f, 64.0f, 0x39},   {2, 22.0f, 32.0f, 44.0f, 64.0f, 0x3a},
    {2, 33.0f, 32.0f, 66.0f, 64.0f, 0x3b},   {2, 16.0f, 32.0f, 32.0f, 64.0f, 0x3c},
    {0, 23.0f, 22.0f, 46.0f, 44.0f, 0x7},    {0, 23.0f, 22.0f, 46.0f, 44.0f, 0x6},
    {0, 23.0f, 22.0f, 46.0f, 44.0f, 0x5},    {0, 23.0f, 22.0f, 46.0f, 44.0f, 0x4},
    {0, 27.0f, 27.0f, 54.0f, 54.0f, 0xa},    {0, 9.5f, 9.5f, 19.0f, 19.0f, 0xb},
    {0, 27.0f, 27.0f, 54.0f, 54.0f, 0x18},   {0, 9.5f, 9.5f, 16.0f, 16.0f, 0x19},
    {0, 27.0f, 27.0f, 54.0f, 54.0f, 0xa},    {0, 9.5f, 9.5f, 19.0f, 19.0f, 0xb},
    {0, 27.0f, 27.0f, 54.0f, 54.0f, 0x18},   {0, 9.5f, 9.5f, 16.0f, 16.0f, 0x19},
    {0, 27.0f, 27.0f, 54.0f, 54.0f, 0x18},   {0, 9.5f, 9.5f, 16.0f, 16.0f, 0x19},
    {0, 69.0f, 69.0f, 138.0f, 138.0f, 0x16}, {0, 55.5f, 55.5f, 110.0f, 110.0f, 0x17},
    {0, 69.0f, 69.0f, 138.0f, 138.0f, 0x16}, {0, 55.5f, 55.5f, 110.0f, 110.0f, 0x17},
    {0, 61.5f, 61.5f, 123.0f, 123.0f, 0x20}, {0, 69.0f, 69.0f, 138.0f, 138.0f, 0x1d},
    {0, 69.0f, 69.0f, 138.0f, 138.0f, 0x1c}, {0, 55.5f, 55.5f, 110.0f, 110.0f, 0x13},
    {0, 69.0f, 69.0f, 138.0f, 138.0f, 0x1c}, {0, 55.5f, 55.5f, 110.0f, 110.0f, 0x13},
    {0, 69.0f, 69.0f, 138.0f, 138.0f, 0x1c}, {0, 55.5f, 55.5f, 110.0f, 110.0f, 0x13},
    {0, 61.5f, 61.5f, 123.0f, 123.0f, 0x1e}, {0, 55.5f, 55.5f, 110.0f, 110.0f, 0x17},
    {0, 69.0f, 69.0f, 138.0f, 138.0f, 0x12}, {0, 55.5f, 55.5f, 110.0f, 110.0f, 0x13},
    {1, 32.0f, 106.0f, 64.0f, 106.0f, 0x3d}, {1, 32.0f, 106.0f, 64.0f, 106.0f, 0x3d},
    {0, 23.0f, 22.0f, 46.0f, 44.0f, 0x3},    {0, 23.0f, 22.0f, 46.0f, 44.0f, 0x2},
    {0, 23.0f, 22.0f, 46.0f, 44.0f, 0x1},    {0, 23.0f, 22.0f, 46.0f, 44.0f, 0x0},
    {0, 27.0f, 27.0f, 54.0f, 54.0f, 0xa},    {0, 9.5f, 9.5f, 19.0f, 19.0f, 0xb},
    {0, 27.0f, 27.0f, 54.0f, 54.0f, 0x8},    {0, 9.5f, 9.5f, 16.0f, 16.0f, 0x9},
    {0, 27.0f, 27.0f, 54.0f, 54.0f, 0xa},    {0, 9.5f, 9.5f, 19.0f, 19.0f, 0xb},
    {0, 27.0f, 27.0f, 54.0f, 54.0f, 0x8},    {0, 9.5f, 9.5f, 16.0f, 16.0f, 0x9},
    {0, 27.0f, 27.0f, 54.0f, 54.0f, 0x8},    {0, 9.5f, 9.5f, 16.0f, 16.0f, 0x9},
    {0, 69.0f, 69.0f, 138.0f, 138.0f, 0x16}, {0, 55.5f, 55.5f, 110.0f, 110.0f, 0x17},
    {0, 69.0f, 69.0f, 138.0f, 138.0f, 0x16}, {0, 55.5f, 55.5f, 110.0f, 110.0f, 0x17},
    {0, 61.5f, 61.5f, 123.0f, 123.0f, 0x20}, {0, 69.0f, 69.0f, 138.0f, 138.0f, 0x1d},
    {0, 69.0f, 69.0f, 138.0f, 138.0f, 0x1c}, {0, 55.5f, 55.5f, 110.0f, 110.0f, 0x13},
    {0, 69.0f, 69.0f, 138.0f, 138.0f, 0x1c}, {0, 55.5f, 55.5f, 110.0f, 110.0f, 0x13},
    {0, 69.0f, 69.0f, 138.0f, 138.0f, 0x1c}, {0, 55.5f, 55.5f, 110.0f, 110.0f, 0x13},
    {0, 61.5f, 61.5f, 123.0f, 123.0f, 0x1e}, {0, 55.5f, 55.5f, 110.0f, 110.0f, 0x17},
    {0, 69.0f, 69.0f, 138.0f, 138.0f, 0x12}, {0, 55.5f, 55.5f, 110.0f, 110.0f, 0x13},
    {1, 32.0f, 106.0f, 64.0f, 106.0f, 0x3e}, {1, 32.0f, 106.0f, 64.0f, 106.0f, 0x3e},
}; // @ghidraAddress 0x307348

} // namespace

/** @ghidraAddress 0x122870 */
FullComboLimelightLayer::FullComboLimelightLayer() {
    m_flWidth = kLayoutWidth;
    m_flHeight = kLayoutHeight;
}

/** @ghidraAddress 0x1228e4 */
FullComboLimelightLayer *FullComboLimelightLayer::shared() {
    if (g_pFullComboLimelightLayer == nullptr) {
        g_pFullComboLimelightLayer = new FullComboLimelightLayer();
    }
    return g_pFullComboLimelightLayer;
}

/** @ghidraAddress 0x122934 */
void FullComboLimelightLayer::LoadTexturesAndBatchesForLimelightLayer() {
    if (m_bBuilt) {
        return;
    }

    BgLayer *pBackgroundLayer = BgLayer::GetBackgroundLayer();
    ne::C_RENDER *pParent = pBackgroundLayer->GetBackgroundRenderObject();

    m_pEffectTexture = ne::C_TEXTURE::FindOrLoadCached(kEffectTextureName);
    m_pPartsTexture = ne::C_TEXTURE::FindOrLoadCached(kPartsTextureName);
    m_pPartsTexture2 = ne::C_TEXTURE::FindOrLoadCached(kPartsTextureName);

    ne::C_TEXTURE *const apTextureFields[] = {m_pEffectTexture, m_pPartsTexture, m_pPartsTexture2};

    for (int nSlot = 0; nSlot < kSpriteSlotCount; ++nSlot) {
        ne::C_SPRITE_INSTANCING_2D *pSprite = ne::CreateWorldSpriteBatch(kSlotCapacities[nSlot]);
        m_apSprites[nSlot] = pSprite;
        pParent->AttachChild(pSprite);
        pSprite->SetVisible(true);
        pSprite->SetRefCountedMember(apTextureFields[kSlotTextureField[nSlot]]);
        pSprite->SetSpriteCount(0);
        if (nSlot == kAdditiveBlendSlot) {
            pSprite->SetBlendMode(kAdditiveBlendMode);
        }
        pSprite->SetTexParam(kTexParamSlotHigh, kTexParamEnabled);
        pSprite->SetTexParam(kTexParamSlotLow, kTexParamEnabled);
    }

    m_bBuilt = true;
}

/** @ghidraAddress 0x122a44 */
void FullComboLimelightLayer::CreateFullComboLimelight(unsigned int nColor) {
    assert(static_cast<int>(nColor) >= 0 && nColor < kColorCount);
    EffectRecord &effect = m_aEffects[nColor];
    effect.m_bActive = true;
    effect.m_flTimer = 0.0f;
    effect.m_bVoiceFired = false;
}

/** @ghidraAddress 0x122abc */
void FullComboLimelightLayer::ClearEffectFlags() {
    for (EffectRecord &effect : m_aEffects) {
        effect.m_bActive = false;
    }
}

/** @ghidraAddress 0x122ad8 */
bool FullComboLimelightLayer::IsAnyEffectActive() const {
    for (const EffectRecord &effect : m_aEffects) {
        if (effect.m_bActive) {
            return true;
        }
    }
    return false;
}

/** @ghidraAddress 0x123658 */
void FullComboLimelightLayer::CreateSprite(int nType,
                                           const S_VECTOR2 *pPosition,
                                           int nAlpha,
                                           float flScaleX,
                                           float flScaleY,
                                           float flRotation) {
    assert(nType >= 0 && nType < kSpriteTypeCount);

    const LimelightSpriteDescriptor &descriptor = kLimelightSpriteDescriptors[nType];
    const int nBatch = descriptor.nBatch;

    // The write cursor is the layer's own per-batch count, not the instancer's.
    const int nIndex = m_aSpriteCounts[nBatch];
    if (nIndex >= static_cast<int>(kSlotCapacities[nBatch])) {
        return;
    }

    const SpriteUvEntry &uv = nBatch == kTitlePartBatch ?
                                  g_aTitlePartUvDefault[descriptor.nUvFrameIndex] :
                                  g_aSpriteUvTable[descriptor.nUvFrameIndex];

    ne::C_SPRITE_INSTANCING_2D *pBatch = m_apSprites[nBatch];
    pBatch->SetSpritePosition(nIndex, *pPosition);
    pBatch->SetSpriteAnchor(nIndex, S_VECTOR2{descriptor.flAnchorX, descriptor.flAnchorY});
    pBatch->SetSpriteSize(nIndex, S_VECTOR2{descriptor.flSizeX, descriptor.flSizeY});
    pBatch->SetSpriteUvOrigin(nIndex, S_VECTOR2{uv.flOriginU, uv.flOriginV});
    pBatch->SetSpriteUvSize(nIndex, S_VECTOR2{uv.flSizeU, uv.flSizeV});
    pBatch->SetSpriteScale(nIndex, flScaleX, flScaleY);
    pBatch->SetSpriteRotation(nIndex, flRotation);
    pBatch->SetSpriteColor(
        nIndex, kColorMax, kColorMax, kColorMax, static_cast<unsigned int>(nAlpha));

    m_aSpriteCounts[nBatch] = nIndex + 1;
}

namespace {

constexpr int kSideCount = 2;

constexpr float kEffectDuration = 2000.0f; // @ghidraAddress 0x2feff0
constexpr float kVoiceCueClock = 500.0f;   // @ghidraAddress 0x2feff4

constexpr float kLetterClockBias = -500.0f; // @ghidraAddress 0x2feff8

constexpr int kFullComboVoiceId = 9;

// (gameType | 2) == 2 admits exactly game types 0 and 2, the single-player modes.
constexpr int kSinglePlayerGameTypeMask = 2;

constexpr int kVersusGameType = 1;

constexpr float kMirrorRotation = 3.1415927f; // @ghidraAddress 0x2fe894

constexpr float kAlphaScale = 255.0f; // @ghidraAddress 0x2eed00

// @ghidraAddress 0x306278
constexpr float kSideRotation[kSideCount] = {3.1415927f, 0.0f};

// @ghidraAddress 0x305330, 0x305334, 0x305338, 0x306240, 0x306244, 0x305348, 0x30534c, 0x3053fc,
// 0x305358, 0x30535c, 0x3052a8, 0x305364, and 0x2f8550
constexpr float kColumnScreenX[] = {
    74.0f,
    194.0f,
    454.0f,
    414.0f,
    684.0f,
    564.0f,
    234.0f,
    524.0f,
    334.0f,
    134.0f,
    644.0f,
    424.0f,
    384.0f,
};

constexpr float kFlareScreenX = 384.0f;  // @ghidraAddress 0x2f8550
constexpr float kFlareScreenY = 1105.0f; // @ghidraAddress 0x2fefFC

constexpr int kColumnBurstCount = 26;
constexpr int kColumnEmberCount = 23;
constexpr int kLetterCount = 10;
constexpr int kColumnPairCount = 3;
constexpr int kFlareBackPairCount = 3;
constexpr int kFlareFrontAlphaPairCount = 2;
constexpr int kFlareFrontScalePairCount = 4;
constexpr int kLetterPairCount = 4;

constexpr int kColumnBurstKindBase[kSideCount] = {46, 14};
constexpr int kColumnEmberKindBase[kSideCount] = {42, 10};
constexpr int kFlareBackKind[kSideCount] = {72, 40};
constexpr int kFlareFrontKind[kSideCount] = {73, 41};

constexpr int kFlareBackAlpha = 0x7f;

constexpr int kBurstsPerColumn = 2;

constexpr int kEmberColumnIndex[kColumnEmberCount] = {
    0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 8, 9, 9, 10, 11, 11, 12, 12,
};

constexpr bool kEmberUsesFirstVariant[kColumnEmberCount] = {
    false, false, false, false, true, true, false, true, true, false, false, false,
    false, false, false, false, true, true, true,  true, true, true,  true,
};

constexpr int kEmberSecondVariantOffset = 2;

// @ghidraAddress 0x302510 (first eight), 0x306250 (last two)
constexpr S_VECTOR2 kLetterOffsets[kLetterCount] = {
    {-204.0f, 0.0f},
    {-166.0f, 0.0f},
    {-128.0f, 0.0f},
    {-95.0f, 0.0f},
    {-39.0f, 0.0f},
    {19.0f, 0.0f},
    {78.0f, 0.0f},
    {128.0f, 0.0f},
    {179.0f, 0.0f},
    {221.0f, 0.0f},
};

constexpr int kLetterRowInset = 232;

constexpr float kColumnBurstPosYPairs[][3 * 2] = {
    {333.33334f, 1024.0f, 500.0f, 1016.5f, 1000.0f, 994.0f},
    {333.33334f, 1024.0f, 500.0f, 1016.5f, 1000.0f, 994.0f},
    {333.33334f, 1054.0f, 500.0f, 1046.5f, 1000.0f, 1024.0f},
    {333.33334f, 1054.0f, 500.0f, 1046.5f, 1000.0f, 1024.0f},
    {166.66667f, 924.0f, 333.33334f, 916.5f, 833.3333f, 894.0f},
    {166.66667f, 924.0f, 333.33334f, 916.5f, 833.3333f, 894.0f},
    {316.66666f, 894.0f, 333.33334f, 894.0f, 1000.0f, 864.0f},
    {316.66666f, 894.0f, 333.33334f, 894.0f, 1000.0f, 864.0f},
    {316.66666f, 994.0f, 333.33334f, 994.0f, 1000.0f, 964.0f},
    {316.66666f, 994.0f, 333.33334f, 994.0f, 1000.0f, 964.0f},
    {166.66667f, 1050.0f, 333.33334f, 1025.0f, 833.3333f, 1010.0f},
    {166.66667f, 1050.0f, 333.33334f, 1025.0f, 833.3333f, 1010.0f},
    {0.0f, 1080.0f, 166.66667f, 1030.0f, 666.6667f, 1010.0f},
    {0.0f, 1080.0f, 166.66667f, 1030.0f, 666.6667f, 1010.0f},
    {0.0f, 1060.0f, 166.66667f, 1010.0f, 666.6667f, 990.0f},
    {0.0f, 1060.0f, 166.66667f, 1010.0f, 666.6667f, 990.0f},
    {0.0f, 990.0f, 166.66667f, 960.0f, 666.6667f, 940.0f},
    {0.0f, 990.0f, 166.66667f, 960.0f, 666.6667f, 940.0f},
    {333.33334f, 990.0f, 500.0f, 960.0f, 1000.0f, 930.0f},
    {333.33334f, 990.0f, 500.0f, 960.0f, 1000.0f, 930.0f},
    {250.0f, 990.0f, 416.66666f, 960.0f, 916.6667f, 930.0f},
    {250.0f, 990.0f, 416.66666f, 960.0f, 916.6667f, 930.0f},
    {83.333336f, 880.0f, 250.0f, 850.0f, 750.0f, 830.0f},
    {83.333336f, 880.0f, 250.0f, 850.0f, 750.0f, 830.0f},
    {166.66667f, 860.0f, 333.33334f, 810.0f, 833.3333f, 780.0f},
    {166.66667f, 860.0f, 333.33334f, 810.0f, 833.3333f, 780.0f},
};

constexpr float kColumnBurstAlphaPairs[][3 * 2] = {
    {483.33334f, 0.0f, 500.0f, 1.0f, 1000.0f, 0.0f},
    {466.66666f, 0.0f, 483.33334f, 1.0f, 650.0f, 0.0f},
    {483.33334f, 0.0f, 500.0f, 1.0f, 1000.0f, 0.0f},
    {466.66666f, 0.0f, 483.33334f, 1.0f, 650.0f, 0.0f},
    {316.66666f, 0.0f, 333.33334f, 1.0f, 833.3333f, 0.0f},
    {300.0f, 0.0f, 316.66666f, 1.0f, 483.33334f, 0.0f},
    {483.33334f, 0.0f, 500.0f, 1.0f, 1000.0f, 0.0f},
    {466.66666f, 0.0f, 483.33334f, 1.0f, 650.0f, 0.0f},
    {483.33334f, 0.0f, 500.0f, 1.0f, 1000.0f, 0.0f},
    {466.66666f, 0.0f, 483.33334f, 1.0f, 650.0f, 0.0f},
    {483.33334f, 0.0f, 500.0f, 1.0f, 1000.0f, 0.0f},
    {466.66666f, 0.0f, 483.33334f, 1.0f, 650.0f, 0.0f},
    {316.66666f, 0.0f, 333.33334f, 1.0f, 833.3333f, 0.0f},
    {466.66666f, 0.0f, 483.33334f, 1.0f, 650.0f, 0.0f},
    {150.0f, 0.0f, 166.66667f, 1.0f, 666.6667f, 0.0f},
    {133.33333f, 0.0f, 150.0f, 1.0f, 483.33334f, 0.0f},
    {150.0f, 0.0f, 166.66667f, 1.0f, 666.6667f, 0.0f},
    {133.33333f, 0.0f, 150.0f, 1.0f, 483.33334f, 0.0f},
    {150.0f, 0.0f, 166.66667f, 1.0f, 666.6667f, 0.0f},
    {133.33333f, 0.0f, 150.0f, 1.0f, 483.33334f, 0.0f},
    {150.0f, 0.0f, 166.66667f, 1.0f, 666.6667f, 0.0f},
    {133.33333f, 0.0f, 150.0f, 1.0f, 483.33334f, 0.0f},
    {150.0f, 0.0f, 166.66667f, 1.0f, 666.6667f, 0.0f},
    {133.33333f, 0.0f, 150.0f, 1.0f, 483.33334f, 0.0f},
    {150.0f, 0.0f, 166.66667f, 1.0f, 666.6667f, 0.0f},
    {133.33333f, 0.0f, 150.0f, 1.0f, 483.33334f, 0.0f},
};

constexpr float kColumnBurstScalePairs[][3 * 2] = {
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1016.6667f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1016.6667f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1016.6667f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1016.6667f, 0.5f},
    {166.66667f, 0.0f, 833.3333f, 0.5f, 850.0f, 0.5f},
    {166.66667f, 0.0f, 833.3333f, 0.5f, 850.0f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1016.6667f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1016.6667f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1016.6667f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1016.6667f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1016.6667f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1016.6667f, 0.5f},
    {166.66667f, 0.0f, 333.33334f, 0.6f, 833.3333f, 0.8f},
    {166.66667f, 0.0f, 333.33334f, 0.6f, 833.3333f, 0.8f},
    {0.0f, 0.0f, 166.66667f, 0.4f, 666.6667f, 0.7f},
    {0.0f, 0.0f, 166.66667f, 0.4f, 666.6667f, 0.7f},
    {0.0f, 0.0f, 166.66667f, 0.5f, 666.6667f, 1.0f},
    {0.0f, 0.0f, 166.66667f, 0.5f, 666.6667f, 1.0f},
    {0.0f, 0.0f, 166.66667f, 0.8f, 666.6667f, 1.0f},
    {0.0f, 0.0f, 166.66667f, 0.8f, 666.6667f, 1.0f},
    {0.0f, 0.0f, 166.66667f, 0.4f, 666.6667f, 1.0f},
    {0.0f, 0.0f, 166.66667f, 0.4f, 666.6667f, 1.0f},
    {0.0f, 0.0f, 166.66667f, 0.4f, 666.6667f, 1.0f},
    {0.0f, 0.0f, 166.66667f, 0.4f, 666.6667f, 1.0f},
    {0.0f, 0.0f, 166.66667f, 0.8f, 666.6667f, 1.0f},
    {0.0f, 0.0f, 166.66667f, 0.8f, 666.6667f, 1.0f},
};

constexpr float kColumnEmberPosYPairs[][3 * 2] = {
    {333.33334f, 1030.0f, 500.0f, 1022.5f, 1000.0f, 1000.0f},
    {333.33334f, 1030.0f, 500.0f, 1022.5f, 1000.0f, 1000.0f},
    {333.33334f, 1060.0f, 500.0f, 1052.5f, 1000.0f, 1030.0f},
    {333.33334f, 1060.0f, 500.0f, 1052.5f, 1000.0f, 1030.0f},
    {166.66667f, 930.0f, 333.33334f, 922.5f, 833.3333f, 900.0f},
    {166.66667f, 930.0f, 333.33334f, 922.5f, 833.3333f, 900.0f},
    {316.66666f, 900.0f, 333.33334f, 900.0f, 1000.0f, 870.0f},
    {316.66666f, 900.0f, 333.33334f, 900.0f, 1000.0f, 870.0f},
    {316.66666f, 1000.0f, 333.33334f, 1000.0f, 1000.0f, 970.0f},
    {316.66666f, 1000.0f, 333.33334f, 1000.0f, 1000.0f, 970.0f},
    {166.66667f, 1056.0f, 333.33334f, 1031.0f, 833.3333f, 1016.0f},
    {166.66667f, 1056.0f, 333.33334f, 1031.0f, 833.3333f, 1016.0f},
    {0.0f, 1086.0f, 166.66667f, 1036.0f, 666.6667f, 1016.0f},
    {0.0f, 1086.0f, 166.66667f, 1036.0f, 666.6667f, 1016.0f},
    {0.0f, 1066.0f, 166.66667f, 1016.0f, 666.6667f, 996.0f},
    {0.0f, 996.0f, 166.66667f, 966.0f, 666.6667f, 946.0f},
    {0.0f, 996.0f, 166.66667f, 966.0f, 666.6667f, 936.0f},
    {0.0f, 996.0f, 166.66667f, 966.0f, 666.6667f, 936.0f},
    {333.33334f, 996.0f, 500.0f, 966.0f, 1000.0f, 936.0f},
    {83.333336f, 886.0f, 250.0f, 856.0f, 750.0f, 836.0f},
    {83.333336f, 886.0f, 250.0f, 856.0f, 750.0f, 836.0f},
    {166.66667f, 866.0f, 333.33334f, 816.0f, 833.3333f, 786.0f},
    {166.66667f, 866.0f, 333.33334f, 816.0f, 833.3333f, 786.0f},
};

constexpr float kColumnEmberAlphaPairs[][3 * 2] = {
    {483.33334f, 0.0f, 500.0f, 1.0f, 1000.0f, 0.0f},
    {466.66666f, 0.0f, 483.33334f, 1.0f, 650.0f, 0.0f},
    {483.33334f, 0.0f, 500.0f, 1.0f, 1000.0f, 0.0f},
    {466.66666f, 0.0f, 483.33334f, 1.0f, 650.0f, 0.0f},
    {316.66666f, 0.0f, 333.33334f, 1.0f, 833.3333f, 0.0f},
    {300.0f, 0.0f, 316.66666f, 1.0f, 483.33334f, 0.0f},
    {483.33334f, 0.0f, 500.0f, 1.0f, 1000.0f, 0.0f},
    {466.66666f, 0.0f, 483.33334f, 1.0f, 650.0f, 0.0f},
    {483.33334f, 0.0f, 500.0f, 1.0f, 1000.0f, 0.0f},
    {466.66666f, 0.0f, 483.33334f, 1.0f, 650.0f, 0.0f},
    {316.66666f, 0.0f, 333.33334f, 1.0f, 833.3333f, 0.0f},
    {300.0f, 0.0f, 316.66666f, 1.0f, 650.0f, 0.0f},
    {150.0f, 0.0f, 166.66667f, 1.0f, 666.6667f, 0.0f},
    {133.33333f, 0.0f, 150.0f, 1.0f, 483.33334f, 0.0f},
    {150.0f, 0.0f, 166.66667f, 1.0f, 666.6667f, 0.0f},
    {150.0f, 0.0f, 166.66667f, 1.0f, 666.6667f, 0.0f},
    {483.33334f, 0.0f, 500.0f, 1.0f, 1000.0f, 0.0f},
    {466.66666f, 0.0f, 483.33334f, 1.0f, 650.0f, 0.0f},
    {400.0f, 0.0f, 416.66666f, 1.0f, 916.6667f, 0.0f},
    {233.33333f, 0.0f, 250.0f, 1.0f, 750.0f, 0.0f},
    {216.66667f, 0.0f, 233.33333f, 1.0f, 400.0f, 0.0f},
    {316.66666f, 0.0f, 333.33334f, 1.0f, 833.3333f, 0.0f},
    {300.0f, 0.0f, 316.66666f, 1.0f, 566.6667f, 0.0f},
};

constexpr float kColumnEmberScalePairs[][3 * 2] = {
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1016.6667f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1016.6667f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1016.6667f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1016.6667f, 0.5f},
    {166.66667f, 0.0f, 833.3333f, 0.5f, 850.0f, 0.5f},
    {166.66667f, 0.0f, 833.3333f, 0.5f, 850.0f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1016.6667f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1016.6667f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1016.6667f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1016.6667f, 0.5f},
    {166.66667f, 0.0f, 333.33334f, 0.6f, 833.3333f, 0.8f},
    {166.66667f, 0.0f, 333.33334f, 0.6f, 833.3333f, 0.8f},
    {0.0f, 0.0f, 166.66667f, 0.4f, 666.6667f, 0.7f},
    {0.0f, 0.0f, 166.66667f, 0.4f, 666.6667f, 0.7f},
    {0.0f, 0.0f, 166.66667f, 0.5f, 666.6667f, 1.0f},
    {0.0f, 0.0f, 166.66667f, 0.5f, 666.6667f, 1.0f},
    {333.33334f, 0.0f, 500.0f, 0.4f, 1000.0f, 0.5f},
    {333.33334f, 0.0f, 500.0f, 0.4f, 1000.0f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1016.6667f, 0.5f},
    {83.333336f, 0.0f, 250.0f, 0.8f, 750.0f, 1.0f},
    {83.333336f, 0.0f, 250.0f, 0.8f, 750.0f, 1.0f},
    {166.66667f, 0.0f, 333.33334f, 0.6f, 833.3333f, 1.0f},
    {166.66667f, 0.0f, 333.33334f, 0.6f, 833.3333f, 1.0f},
};

constexpr float kLetterScalePairs[][4 * 2] = {
    {166.66667f, 0.6f, 333.33334f, 1.1f, 383.33334f, 0.95f, 433.33334f, 1.0f},
    {200.0f, 0.6f, 366.66666f, 1.1f, 416.66666f, 0.95f, 466.66666f, 1.0f},
    {233.33333f, 0.6f, 400.0f, 1.1f, 450.0f, 0.95f, 500.0f, 1.0f},
    {266.66666f, 0.6f, 433.33334f, 1.1f, 483.33334f, 0.95f, 533.3333f, 1.0f},
    {300.0f, 0.6f, 466.66666f, 1.1f, 516.6667f, 0.95f, 566.6667f, 1.0f},
    {333.33334f, 0.6f, 500.0f, 1.1f, 550.0f, 0.95f, 600.0f, 1.0f},
    {366.66666f, 0.6f, 533.3333f, 1.1f, 583.3333f, 0.95f, 633.3333f, 1.0f},
    {400.0f, 0.6f, 566.6667f, 1.1f, 616.6667f, 0.95f, 666.6667f, 1.0f},
    {433.33334f, 0.6f, 600.0f, 1.1f, 650.0f, 0.95f, 700.0f, 1.0f},
    {466.66666f, 0.6f, 633.3333f, 1.1f, 683.3333f, 0.95f, 733.3333f, 1.0f},
};

constexpr float kLetterAlphaPairs[][4 * 2] = {
    {166.66667f, 0.0f, 300.0f, 1.0f, 1333.3334f, 1.0f, 1483.3334f, 0.0f},
    {200.0f, 0.0f, 333.33334f, 1.0f, 1333.3334f, 1.0f, 1483.3334f, 0.0f},
    {233.33333f, 0.0f, 366.66666f, 1.0f, 1333.3334f, 1.0f, 1483.3334f, 0.0f},
    {266.66666f, 0.0f, 400.0f, 1.0f, 1333.3334f, 1.0f, 1483.3334f, 0.0f},
    {266.66666f, 0.0f, 433.33334f, 1.0f, 1333.3334f, 1.0f, 1483.3334f, 0.0f},
    {300.0f, 0.0f, 466.66666f, 1.0f, 1333.3334f, 1.0f, 1483.3334f, 0.0f},
    {333.33334f, 0.0f, 500.0f, 1.0f, 1333.3334f, 1.0f, 1483.3334f, 0.0f},
    {366.66666f, 0.0f, 533.3333f, 1.0f, 1333.3334f, 1.0f, 1483.3334f, 0.0f},
    {400.0f, 0.0f, 566.6667f, 1.0f, 1333.3334f, 1.0f, 1483.3334f, 0.0f},
    {433.33334f, 0.0f, 600.0f, 1.0f, 1333.3334f, 1.0f, 1483.3334f, 0.0f},
};

constexpr float kFlareBackScaleXPairs[] = {0.0f, 5.0f, 133.33333f, 5.0f, 1250.0f, 0.0f};
constexpr float kFlareBackScaleYPairs[] = {0.0f, 0.0f, 133.33333f, 3.0f, 1250.0f, 7.0f};
constexpr float kFlareFrontAlphaPairs[] = {500.0f, 1.0f, 1250.0f, 0.0f};
constexpr float kFlareFrontScaleXPairs[] = {
    0.0f,
    15.0f,
    133.33333f,
    15.0f,
    500.0f,
    15.0f,
    1250.0f,
    12.0f,
};
constexpr float kFlareFrontScaleYPairs[] = {
    0.0f,
    0.0f,
    133.33333f,
    3.0f,
    500.0f,
    3.0f,
    1250.0f,
    0.0f,
};

inline int ScaleToAlpha(float flValue) {
    return static_cast<int>(flValue * kAlphaScale);
}

} // namespace

/** @ghidraAddress 0x122b08 */
void FullComboLimelightLayer::Update(float flDelta) {
    for (int &nCount : m_aSpriteCounts) {
        nCount = 0;
    }

    GameSystem *pGameSystem = GameSystem::GetGameSystem();

    for (int nSide = 0; nSide < kSideCount; ++nSide) {
        EffectRecord &effect = m_aEffects[nSide];
        if (!effect.m_bActive) {
            continue;
        }

        effect.m_flTimer += flDelta;
        const float flClock = effect.m_flTimer;
        if (flClock > kEffectDuration) {
            // The record retires here but still draws in full on the frame that retires it.
            effect.m_bActive = false;
        }

        // Unlike the Classic theme's layer, this one does not first check whether a voice is
        // already playing.
        if (!effect.m_bVoiceFired && flClock > kVoiceCueClock) {
            effect.m_bVoiceFired = true;
            const int nRivalSide = (pGameSystem->GetPlayColor() == 0) ? 1 : 0;
            const bool bSilent =
                nSide == nRivalSide && (pGameSystem->GetGameType() | kSinglePlayerGameTypeMask) ==
                                           kSinglePlayerGameTypeMask;
            if (!bSilent) {
                AudioManager *pAudio = AudioManager.sharedManager;
                [pAudio releaseVoice];
                SoundEffectManager::GetInstance()->LoadAndSetThemedVoice(kFullComboVoiceId);
            }
        }

        const int nPlayColor = pGameSystem->GetPlayColor();

        // The binary re-reads the game system on every iteration of this two-element loop.
        const float aRowSlope[kSideCount] = {g_flPlayfieldNearLaneSlope,
                                             g_flPlayfieldNearLaneSlopeNeg};
        float aRowBaseY[kSideCount] = {};
        for (int nRow = 0; nRow < kSideCount; ++nRow) {
            aRowBaseY[nRow] = aRowSlope[nRow] * GameSystem::GetGameSystem()->GetSheetInsetHalfY();
        }
        const int nGameType = GameSystem::GetGameSystem()->GetGameType();

        const bool bOwnSide = nPlayColor == nSide;
        const float flRowBaseY = aRowBaseY[bOwnSide ? 1 : 0];
        const float flColumnRotation = kSideRotation[bOwnSide ? 1 : 0];

        // @ghidraAddress 0x3ddc48 and 0x3ddcb8
        static float aBurstX[kColumnBurstCount];
        static bool bBurstXBuilt = false;
        if (!bBurstXBuilt) {
            for (int nBurst = 0; nBurst < kColumnBurstCount; ++nBurst) {
                aBurstX[nBurst] = kColumnScreenX[nBurst / kBurstsPerColumn] - m_flWidth;
            }
            bBurstXBuilt = true;
        }
        static float aEmberX[kColumnEmberCount];
        static bool bEmberXBuilt = false;
        if (!bEmberXBuilt) {
            for (int nEmber = 0; nEmber < kColumnEmberCount; ++nEmber) {
                aEmberX[nEmber] = kColumnScreenX[kEmberColumnIndex[nEmber]] - m_flWidth;
            }
            bEmberXBuilt = true;
        }

        for (int nBurst = 0; nBurst < kColumnBurstCount; ++nBurst) {
            const float flScreenY = CalculateCurveInterpolation(
                kColumnBurstPosYPairs[nBurst], kColumnPairCount, flClock);
            const float flAlpha = CalculateCurveInterpolation(
                kColumnBurstAlphaPairs[nBurst], kColumnPairCount, flClock);
            const float flScale = CalculateCurveInterpolation(
                kColumnBurstScalePairs[nBurst], kColumnPairCount, flClock);
            const float flOffsetY = flScreenY - m_flHeight;
            const S_VECTOR2 position{aBurstX[nBurst],
                                     flRowBaseY + (bOwnSide ? flOffsetY : -flOffsetY)};
            CreateSprite(kColumnBurstKindBase[nSide] + nBurst,
                         &position,
                         ScaleToAlpha(flAlpha),
                         flScale,
                         flScale,
                         flColumnRotation);
        }

        const int nEmberParity = static_cast<int>(flClock) & 1;
        for (int nEmber = 0; nEmber < kColumnEmberCount; ++nEmber) {
            const float flScreenY = CalculateCurveInterpolation(
                kColumnEmberPosYPairs[nEmber], kColumnPairCount, flClock);
            const float flAlpha = CalculateCurveInterpolation(
                kColumnEmberAlphaPairs[nEmber], kColumnPairCount, flClock);
            const float flScale = CalculateCurveInterpolation(
                kColumnEmberScalePairs[nEmber], kColumnPairCount, flClock);
            const float flOffsetY = flScreenY - m_flHeight;
            const S_VECTOR2 position{aEmberX[nEmber],
                                     flRowBaseY + (bOwnSide ? flOffsetY : -flOffsetY)};
            // Both terms are even, so the binary's bitwise or is an add.
            const int nVariant = kEmberUsesFirstVariant[nEmber] ? 0 : kEmberSecondVariantOffset;
            const int nKind = (kColumnEmberKindBase[nSide] + nVariant) | nEmberParity;
            CreateSprite(
                nKind, &position, ScaleToAlpha(flAlpha), flScale, flScale, flColumnRotation);
        }

        const float flFlareOffsetY = kFlareScreenY - m_flHeight;
        const S_VECTOR2 flarePosition{kFlareScreenX - m_flWidth,
                                      flRowBaseY + (bOwnSide ? flFlareOffsetY : -flFlareOffsetY)};
        const float flFlareBackScaleX =
            CalculateCurveInterpolation(kFlareBackScaleXPairs, kFlareBackPairCount, flClock);
        const float flFlareBackScaleY =
            CalculateCurveInterpolation(kFlareBackScaleYPairs, kFlareBackPairCount, flClock);
        CreateSprite(kFlareBackKind[nSide],
                     &flarePosition,
                     kFlareBackAlpha,
                     flFlareBackScaleX,
                     flFlareBackScaleY,
                     flColumnRotation);

        const float flFlareFrontAlpha =
            CalculateCurveInterpolation(kFlareFrontAlphaPairs, kFlareFrontAlphaPairCount, flClock);
        const float flFlareFrontScaleX =
            CalculateCurveInterpolation(kFlareFrontScaleXPairs, kFlareFrontScalePairCount, flClock);
        const float flFlareFrontScaleY =
            CalculateCurveInterpolation(kFlareFrontScaleYPairs, kFlareFrontScalePairCount, flClock);
        CreateSprite(kFlareFrontKind[nSide],
                     &flarePosition,
                     ScaleToAlpha(flFlareFrontAlpha),
                     flFlareFrontScaleX,
                     flFlareFrontScaleY,
                     flColumnRotation);

        // @ghidraAddress 0x3ddd78
        static S_VECTOR2 aLetterBase[kSideCount];
        static bool bLetterBaseBuilt = false;
        if (!bLetterBaseBuilt) {
            aLetterBase[0] =
                S_VECTOR2{0.0f,
                          static_cast<float>((g_nPlayfieldNearRowTop + kLetterRowInset) -
                                             g_nPlayfieldCentreSplit)};
            aLetterBase[1] =
                S_VECTOR2{0.0f,
                          static_cast<float>((g_nPlayfieldNearRowBottom - kLetterRowInset) -
                                             g_nPlayfieldCentreSplit)};
            bLetterBaseBuilt = true;
        }

        const float flLetterClock = flClock + kLetterClockBias;
        const bool bLetterMirrored = nGameType == kVersusGameType && !bOwnSide;
        const float flLetterRotation = bLetterMirrored ? kMirrorRotation : 0.0f;
        const S_VECTOR2 letterBase = aLetterBase[bOwnSide ? 1 : 0];

        for (int nLetter = 0; nLetter < kLetterCount; ++nLetter) {
            const float flScale = CalculateCurveInterpolation(
                kLetterScalePairs[nLetter], kLetterPairCount, flLetterClock);
            const float flAlpha = CalculateCurveInterpolation(
                kLetterAlphaPairs[nLetter], kLetterPairCount, flLetterClock);
            S_VECTOR2 position = letterBase;
            S_VECTOR2 offset = kLetterOffsets[nLetter];
            if (bLetterMirrored) {
                SubtractVector2(&position, &offset);
            } else {
                AddVector2(&position, &offset);
            }
            CreateSprite(
                nLetter, &position, ScaleToAlpha(flAlpha), flScale, flScale, flLetterRotation);
        }
    }

    for (int nSlot = 0; nSlot < kSpriteSlotCount; ++nSlot) {
        m_apSprites[nSlot]->SetSpriteCount(m_aSpriteCounts[nSlot]);
    }
}
