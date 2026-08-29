#include "full_combo_colette_layer.h"

#include <cassert>

#include "../Share/bg_layer.h"
#import "AudioManager.h"
#include "curve.h"
#include "engineglobals.h"
#include "full_combo_colette_sprite_table.h"
#include "gamesystem.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#include "s_vector2.h"
#include "soundeffectmanager.h"
#include "sprite_uv_table.h"
#include "vectormath.h"

static FullComboColetteLayer *g_pFullComboColetteLayer = nullptr; // @ghidraAddress 0x3dc668

extern const SpriteUvEntry g_aSpriteUvTable[]; // @ghidraAddress 0x2efcc8

// @ghidraAddress 0x3005f0
const ColetteFullComboSpriteType g_aColetteFullComboSpriteTypes[kColetteFullComboSpriteTypeCount] =
    {
        {2, 23.0f, 23.5f, 46.0f, 47.0f, 63},    // 0
        {2, 19.5f, 23.0f, 39.0f, 46.0f, 93},    // 1
        {2, 19.0f, 23.0f, 38.0f, 46.0f, 94},    // 2
        {2, 18.5f, 23.0f, 37.0f, 46.0f, 95},    // 3
        {2, 18.5f, 23.0f, 37.0f, 46.0f, 96},    // 4
        {2, 21.0f, 23.0f, 42.0f, 46.0f, 97},    // 5
        {2, 21.0f, 23.0f, 42.0f, 46.0f, 98},    // 6
        {2, 22.5f, 23.0f, 45.0f, 46.0f, 99},    // 7
        {2, 20.0f, 23.0f, 40.0f, 46.0f, 100},   // 8
        {2, 21.0f, 23.0f, 42.0f, 46.0f, 101},   // 9
        {2, 7.0f, 23.0f, 14.0f, 46.0f, 102},    // 10
        {1, 32.0f, 106.0f, 64.0f, 106.0f, 106}, // 11
        {1, 32.0f, 106.0f, 64.0f, 106.0f, 106}, // 12
        {1, 32.0f, 106.0f, 64.0f, 106.0f, 107}, // 13
        {1, 32.0f, 106.0f, 64.0f, 106.0f, 107}, // 14
        {1, 50.0f, 50.0f, 100.0f, 100.0f, 92},  // 15
        {1, 50.0f, 50.0f, 100.0f, 100.0f, 92},  // 16
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 104},   // 17
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 104},   // 18
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 104},   // 19
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 104},   // 20
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 104},   // 21
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 104},   // 22
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 104},   // 23
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 104},   // 24
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 104},   // 25
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 26
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 27
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 28
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 29
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 30
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 31
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 32
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 33
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 34
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 35
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 36
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 37
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 38
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 39
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 40
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 41
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 42
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 43
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 44
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 45
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 46
        {1, 20.0f, 20.0f, 40.0f, 40.0f, 109},   // 47
        {1, 20.0f, 20.0f, 40.0f, 40.0f, 109},   // 48
        {1, 20.0f, 20.0f, 40.0f, 40.0f, 109},   // 49
        {1, 20.0f, 20.0f, 40.0f, 40.0f, 109},   // 50
        {1, 20.0f, 20.0f, 40.0f, 40.0f, 109},   // 51
        {1, 20.0f, 20.0f, 40.0f, 40.0f, 109},   // 52
        {1, 20.0f, 20.0f, 40.0f, 40.0f, 109},   // 53
        {1, 20.0f, 20.0f, 40.0f, 40.0f, 109},   // 54
        {1, 23.0f, 22.0f, 46.0f, 44.0f, 110},   // 55
        {1, 23.0f, 22.0f, 46.0f, 44.0f, 110},   // 56
        {1, 23.0f, 22.0f, 46.0f, 44.0f, 110},   // 57
        {1, 23.0f, 22.0f, 46.0f, 44.0f, 110},   // 58
        {1, 50.0f, 50.0f, 100.0f, 100.0f, 91},  // 59
        {1, 50.0f, 50.0f, 100.0f, 100.0f, 91},  // 60
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 104},   // 61
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 104},   // 62
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 104},   // 63
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 104},   // 64
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 104},   // 65
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 104},   // 66
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 104},   // 67
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 104},   // 68
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 104},   // 69
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 70
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 71
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 72
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 73
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 74
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 75
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 76
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 77
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 78
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 79
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 80
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 81
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 82
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 83
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 84
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 85
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 86
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 87
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 88
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 89
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 90
        {1, 20.0f, 20.0f, 40.0f, 40.0f, 108},   // 91
        {1, 20.0f, 20.0f, 40.0f, 40.0f, 108},   // 92
        {1, 20.0f, 20.0f, 40.0f, 40.0f, 108},   // 93
        {1, 20.0f, 20.0f, 40.0f, 40.0f, 108},   // 94
        {1, 20.0f, 20.0f, 40.0f, 40.0f, 108},   // 95
        {1, 20.0f, 20.0f, 40.0f, 40.0f, 108},   // 96
        {1, 20.0f, 20.0f, 40.0f, 40.0f, 108},   // 97
        {1, 20.0f, 20.0f, 40.0f, 40.0f, 108},   // 98
        {1, 23.0f, 22.0f, 46.0f, 44.0f, 110},   // 99
        {1, 23.0f, 22.0f, 46.0f, 44.0f, 110},   // 100
        {1, 23.0f, 22.0f, 46.0f, 44.0f, 110},   // 101
        {1, 23.0f, 22.0f, 46.0f, 44.0f, 110},   // 102
};

namespace {

constexpr float kLayoutWidth = 384.0f;
constexpr float kLayoutHeight = 1098.0f;

// @ghidraAddress 0x3ceaa8
constexpr const char *kTextureName = "00_texture/gm_parts2";

// @ghidraAddress 0x2ff050
constexpr unsigned int kSlotCapacities[] = {32, 256, 32};

// @ghidraAddress 0x2ff05c
constexpr int kSlotTextureField[] = {0, 1, 2};

constexpr int kAdditiveBlendSlot = 1;
constexpr int kAdditiveBlendMode = 1;

constexpr int kTexParamSlotHigh = 1;
constexpr int kTexParamSlotLow = 0;
constexpr int kTexParamEnabled = 1;

} // namespace

/** @ghidraAddress 0x9b118 */
FullComboColetteLayer::FullComboColetteLayer() {
    m_flWidth = kLayoutWidth;
    m_flHeight = kLayoutHeight;
}

/** @ghidraAddress 0x9b18c */
FullComboColetteLayer *FullComboColetteLayer::shared() {
    if (g_pFullComboColetteLayer == nullptr) {
        g_pFullComboColetteLayer = new FullComboColetteLayer();
    }
    return g_pFullComboColetteLayer;
}

/** @ghidraAddress 0x9b1dc */
void FullComboColetteLayer::InitializeBackgroundSpriteLayers() {
    if (m_bBuilt) {
        return;
    }

    BgLayer *pBackgroundLayer = BgLayer::GetBackgroundLayer();
    ne::C_RENDER *pParent = pBackgroundLayer->GetBackgroundRenderObject();

    m_pTexture0 = ne::C_TEXTURE::FindOrLoadCached(kTextureName);
    m_pTexture1 = ne::C_TEXTURE::FindOrLoadCached(kTextureName);
    m_pTexture2 = ne::C_TEXTURE::FindOrLoadCached(kTextureName);

    ne::C_TEXTURE *const apTextureFields[] = {m_pTexture0, m_pTexture1, m_pTexture2};

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

/** @ghidraAddress 0x9b2e4 */
void FullComboColetteLayer::CreateFullComboColette(unsigned int nColor) {
    assert(static_cast<int>(nColor) >= 0 && nColor < kColorCount);
    EffectRecord &effect = m_aEffects[nColor];
    effect.m_bActive = true;
    effect.m_flTimer = 0.0f;
    effect.m_bVoiceFired = false;
}

/** @ghidraAddress 0x9c264 */
void FullComboColetteLayer::CreateSprite(int nType,
                                         const S_VECTOR2 *pPosition,
                                         unsigned int nAlpha,
                                         float flScaleX,
                                         float flScaleY,
                                         float flRotation) {
    assert(nType >= 0);
    assert(nType < kColetteFullComboSpriteTypeCount);

    const ColetteFullComboSpriteType &spriteType = g_aColetteFullComboSpriteTypes[nType];
    const unsigned int nGroup = spriteType.nGroup;

    const int nIndex = m_aSpriteCounts[nGroup];
    if (nIndex >= static_cast<int>(kSlotCapacities[nGroup])) {
        return;
    }

    const SpriteUvEntry &uv = g_aSpriteUvTable[spriteType.nUvIndex];
    ne::C_SPRITE_INSTANCING_2D *pBatch = m_apSprites[nGroup];

    pBatch->SetSpritePosition(nIndex, *pPosition);
    pBatch->SetSpriteAnchor(nIndex, S_VECTOR2{spriteType.flAnchorX, spriteType.flAnchorY});
    pBatch->SetSpriteSize(nIndex, S_VECTOR2{spriteType.flSizeW, spriteType.flSizeH});
    pBatch->SetSpriteUvOrigin(nIndex, S_VECTOR2{uv.flOriginU, uv.flOriginV});
    pBatch->SetSpriteUvSize(nIndex, S_VECTOR2{uv.flSizeU, uv.flSizeV});
    pBatch->SetSpriteScale(nIndex, flScaleX, flScaleY);
    pBatch->SetSpriteRotation(nIndex, flRotation);
    pBatch->SetSpriteColor(nIndex, 0xff, 0xff, 0xff, nAlpha);

    ++m_aSpriteCounts[nGroup];
}

/** @ghidraAddress 0x9b35c */
void FullComboColetteLayer::ClearEffectFlags() {
    for (EffectRecord &effect : m_aEffects) {
        effect.m_bActive = false;
    }
}

/** @ghidraAddress 0x9b378 */
bool FullComboColetteLayer::IsAnyEffectActive() const {
    for (const EffectRecord &effect : m_aEffects) {
        if (effect.m_bActive) {
            return true;
        }
    }
    return false;
}

// @ghidraAddress 0x3dc660
static int g_nColetteFullComboFrameCount = 0;

namespace {

constexpr int kSideCount = 2;

// At a millisecond clock every real frame clears this, so the counter is a frame tally.
// @ghidraAddress 0x2ee878
constexpr double kFrameCountThreshold = 0.001;

// @ghidraAddress 0x2feff0
// @ghidraAddress 0x2feff4
// @ghidraAddress 0x2f8540
constexpr float kEffectDuration = 2000.0f;
constexpr float kVoiceCueClockMin = 500.0f;
constexpr float kVoiceCueClockMax = 1000.0f;

// @ghidraAddress 0x2feff8
constexpr float kLetterClockBias = -500.0f;

constexpr int kFullComboVoiceId = 9;

// The binary's (gameType | 2) == 2 test admits game types 0 and 2, the single-player modes.
constexpr int kSinglePlayerGameTypeMask = 2;

constexpr int kVersusGameType = 1;

// @ghidraAddress 0x2fe894
// @ghidraAddress 0x2f85a0
constexpr float kMirrorRotation = 3.1415927f;
constexpr double kMirrorRotationExact = 3.141592653589793;

// @ghidraAddress 0x2eed00
constexpr float kAlphaScale = 255.0f;

// @ghidraAddress 0x2ff068
constexpr float kSideRotation[kSideCount] = {3.1415927f, 0.0f};

// @ghidraAddress 0x2f8550
// @ghidraAddress 0x2fefFC
constexpr float kFlareScreenX = 384.0f;
constexpr float kFlareScreenY = 1105.0f;

constexpr int kLetterRowInset = 232;

constexpr int kFanACount = 2;
constexpr int kFanBCount = 9;
constexpr int kFanCCount = 21;
constexpr int kFanDCount = 12;
constexpr int kLetterCount = 10;
constexpr int kThreePointCurve = 3;
constexpr int kTwoPointCurve = 2;
constexpr int kFourPointCurve = 4;

constexpr int kFanAKindBase[kSideCount] = {0x3b, 0xf};
constexpr int kFanBKindBase[kSideCount] = {0x3d, 0x11};
constexpr int kFanDKindBase[kSideCount] = {0x5b, 0x2f};
constexpr int kFlareBackKind[kSideCount] = {0xd, 0xb};
constexpr int kFlareFrontKind[kSideCount] = {0xe, 0xc};

constexpr unsigned int kFlareBackAlpha = 0x7f;

// The letter loop counts from -10 up to 0, so its kinds run 1 through 10 rather than 0 through 9.
constexpr int kBannerKind = 0;
constexpr int kLetterKindBias = 0xb;

constexpr int kFanDStrobePeriod = 6;
constexpr int kFanDStrobeOnFrames = 3;

struct MoteLayout {
    float flScreenX;
    int nRowInset;
};

constexpr MoteLayout kFanALayout[kFanACount] = {{12.0f, 60}, {0.0f, 120}};

// Entries 4 and 5 reuse the earlier 30-inset row rather than their neighbours' 60, as the binary
// does.
constexpr MoteLayout kFanBLayout[kFanBCount] = {
    {-234.0f, 30},
    {-234.0f, 30},
    {-134.0f, 20},
    {-134.0f, 20},
    {-114.0f, 30},
    {-114.0f, 30},
    {216.0f, 60},
    {216.0f, 60},
    {-369.0f, 120},
};

constexpr MoteLayout kFanCLayout[kFanCCount] = {
    {30.0f, 90},   {30.0f, 90},    {10.0f, 100},   {10.0f, 100}, {216.0f, 50},  {216.0f, 50},
    {146.0f, 30},  {146.0f, 30},   {126.0f, 40},   {126.0f, 40}, {-34.0f, 60},  {-34.0f, 60},
    {-294.0f, 30}, {-294.0f, 30},  {266.0f, 30},   {266.0f, 30}, {-192.0f, 60}, {-192.0f, 60},
    {10.0f, 100},  {-384.0f, 120}, {-384.0f, 120},
};

constexpr MoteLayout kFanDLayout[kFanDCount] = {
    {-310.0f, 90},
    {-190.0f, 100},
    {70.0f, 50},
    {30.0f, 30},
    {300.0f, 40},
    {180.0f, 60},
    {-150.0f, 30},
    {-50.0f, 60},
    {-250.0f, 100},
    {260.0f, 120},
    {40.0f, 120},
    {0.0f, 120},
};

// @ghidraAddress 0x2ff000
// @ghidraAddress 0x3dc670
constexpr S_VECTOR2 kLetterOffsets[kLetterCount] = {
    {-203.0f, -10.0f},
    {-160.0f, -10.0f},
    {-119.0f, -10.0f},
    {-77.0f, -10.0f},
    {-14.0f, -10.0f},
    {30.0f, -10.0f},
    {77.0f, -10.0f},
    {124.0f, -10.0f},
    {168.0f, -10.0f},
    {198.0f, -10.0f},
};

// @ghidraAddress 0x2ff070
constexpr float kFanAScaleXPairs[][3 * 2] = {
    {0.0f, 0.0f, 166.66667f, -1.05f, 1000.0f, -1.4f},
    {0.0f, 0.0f, 166.66667f, 1.75f, 1000.0f, 3.15f},
};

// @ghidraAddress 0x2ff0a0
constexpr float kFanAScaleYPairs[][3 * 2] = {
    {0.0f, 0.0f, 166.66667f, -1.05f, 1000.0f, -0.931f},
    {0.0f, 0.0f, 166.66667f, 1.75f, 1000.0f, 2.1f},
};

// @ghidraAddress 0x2ff0d0
constexpr float kFanAAlphaPairs[][2 * 2] = {
    {0.0f, 1.0f, 1000.0f, 0.0f},
    {0.0f, 1.0f, 1000.0f, 0.0f},
};

// @ghidraAddress 0x2ff0f0
constexpr float kFanARotationPairs[][2 * 2] = {
    {0.0f, 0.0f, 1000.0f, 0.7853982f},
    {0.0f, 0.0f, 1000.0f, 0.7853982f},
};

// @ghidraAddress 0x2ff110
constexpr float kFanAOffsetXPairs[][2 * 2] = {
    {0.0f, 0.0f, 1000.0f, -70.0f},
    {0.0f, 0.0f, 1000.0f, 30.0f},
};

// @ghidraAddress 0x2ff130
constexpr float kFanAOffsetYPairs[][2 * 2] = {
    {0.0f, 0.0f, 1000.0f, -60.0f},
    {0.0f, 0.0f, 1000.0f, -40.0f},
};

// @ghidraAddress 0x2ff150
constexpr float kFanBScaleXPairs[][3 * 2] = {
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1000.0f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1000.0f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1000.0f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1000.0f, 0.5f},
    {0.0f, 0.0f, 166.66667f, 0.4f, 666.6667f, 0.7f},
    {0.0f, 0.0f, 166.66667f, 0.4f, 666.6667f, 0.7f},
    {250.0f, 0.0f, 416.66666f, 0.4f, 916.6667f, 0.5f},
    {250.0f, 0.0f, 416.66666f, 0.4f, 916.6667f, 0.5f},
    {83.333336f, 0.0f, 250.0f, 0.8f, 750.0f, 1.0f},
};

// @ghidraAddress 0x2ff228
constexpr float kFanBScaleYPairs[][3 * 2] = {
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1000.0f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1000.0f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1000.0f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1000.0f, 0.5f},
    {0.0f, 0.0f, 166.66667f, 0.4f, 666.6667f, 0.7f},
    {0.0f, 0.0f, 166.66667f, 0.4f, 666.6667f, 0.7f},
    {250.0f, 0.0f, 416.66666f, 0.4f, 916.6667f, 0.5f},
    {250.0f, 0.0f, 416.66666f, 0.4f, 916.6667f, 0.5f},
    {83.333336f, 0.0f, 250.0f, 0.8f, 750.0f, 1.0f},
};

// @ghidraAddress 0x2ff300
constexpr float kFanBAlphaPairs[][3 * 2] = {
    {483.33334f, 0.0f, 500.0f, 1.0f, 1000.0f, 0.0f},
    {483.33334f, 1.0f, 650.0f, 0.0f, 1000.0f, 0.0f},
    {483.33334f, 0.0f, 500.0f, 1.0f, 1000.0f, 0.0f},
    {483.33334f, 1.0f, 650.0f, 0.0f, 1000.0f, 0.0f},
    {150.0f, 0.0f, 166.66667f, 1.0f, 666.6667f, 0.0f},
    {150.0f, 1.0f, 483.33334f, 0.0f, 1000.0f, 0.0f},
    {400.0f, 0.0f, 416.66666f, 1.0f, 916.6667f, 0.0f},
    {400.0f, 1.0f, 566.6667f, 0.0f, 1000.0f, 0.0f},
    {233.33333f, 0.0f, 250.0f, 1.0f, 750.0f, 0.0f},
};

// @ghidraAddress 0x2ff3d8
constexpr float kFanBOffsetYPairs[][3 * 2] = {
    {333.33334f, 0.0f, 500.0f, -7.5f, 1000.0f, -30.0f},
    {333.33334f, 0.0f, 500.0f, -7.5f, 1000.0f, -30.0f},
    {333.33334f, 0.0f, 500.0f, -7.5f, 1000.0f, -30.0f},
    {333.33334f, 0.0f, 500.0f, -7.5f, 1000.0f, -30.0f},
    {0.0f, 0.0f, 166.66667f, -20.0f, 666.6667f, -40.0f},
    {0.0f, 0.0f, 166.66667f, -20.0f, 666.6667f, -40.0f},
    {250.0f, 0.0f, 416.66666f, -30.0f, 916.6667f, -60.0f},
    {250.0f, 0.0f, 416.66666f, -30.0f, 916.6667f, -60.0f},
    {250.0f, 0.0f, 416.66666f, -30.0f, 916.6667f, -60.0f},
};

// @ghidraAddress 0x2ff4b0
constexpr float kFanCScaleXPairs[][3 * 2] = {
    {166.66667f, 0.0f, 833.3333f, 0.5f, 1000.0f, 0.5f},
    {166.66667f, 0.0f, 833.3333f, 0.5f, 1000.0f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1000.0f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1000.0f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1000.0f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1000.0f, 0.5f},
    {166.66667f, 0.0f, 333.33334f, 0.6f, 833.3333f, 0.8f},
    {166.66667f, 0.0f, 333.33334f, 0.6f, 833.3333f, 0.8f},
    {0.0f, 0.0f, 166.66667f, 0.4f, 666.6667f, 1.0f},
    {0.0f, 0.0f, 166.66667f, 0.4f, 666.6667f, 1.0f},
    {0.0f, 0.0f, 166.66667f, 0.8f, 666.6667f, 1.0f},
    {0.0f, 0.0f, 166.66667f, 0.8f, 666.6667f, 1.0f},
    {366.66666f, 0.0f, 533.3333f, 0.3f, 1033.3334f, 0.4f},
    {366.66666f, 0.0f, 533.3333f, 0.3f, 1033.3334f, 0.4f},
    {283.33334f, 0.0f, 450.0f, 0.3f, 950.0f, 0.4f},
    {283.33334f, 0.0f, 450.0f, 0.3f, 950.0f, 0.4f},
    {333.33334f, 0.0f, 500.0f, 0.4f, 1000.0f, 0.5f},
    {333.33334f, 0.0f, 500.0f, 0.4f, 1000.0f, 0.5f},
    {83.333336f, 0.0f, 250.0f, 0.8f, 750.0f, 1.0f},
    {166.66667f, 0.0f, 333.33334f, 0.6f, 833.3333f, 1.0f},
    {166.66667f, 0.0f, 333.33334f, 0.6f, 833.3333f, 1.0f},
};

// @ghidraAddress 0x2ff6a8
constexpr float kFanCScaleYPairs[][3 * 2] = {
    {166.66667f, 0.0f, 833.3333f, 0.5f, 833.3333f, 0.5f},
    {166.66667f, 0.0f, 833.3333f, 0.5f, 833.3333f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1000.0f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1000.0f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1000.0f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1000.0f, 0.5f},
    {166.66667f, 0.0f, 333.33334f, 0.6f, 833.3333f, 0.8f},
    {166.66667f, 0.0f, 333.33334f, 0.6f, 833.3333f, 0.8f},
    {0.0f, 0.0f, 166.66667f, 0.4f, 666.6667f, 1.0f},
    {0.0f, 0.0f, 166.66667f, 0.4f, 666.6667f, 1.0f},
    {0.0f, 0.0f, 166.66667f, 0.8f, 666.6667f, 1.0f},
    {0.0f, 0.0f, 166.66667f, 0.8f, 666.6667f, 1.0f},
    {366.66666f, 0.0f, 533.3333f, 0.3f, 1033.3334f, 0.4f},
    {366.66666f, 0.0f, 533.3333f, 0.3f, 1033.3334f, 0.4f},
    {283.33334f, 0.0f, 450.0f, 0.3f, 950.0f, 0.4f},
    {283.33334f, 0.0f, 450.0f, 0.3f, 950.0f, 0.4f},
    {333.33334f, 0.0f, 500.0f, 0.4f, 1000.0f, 0.5f},
    {333.33334f, 0.0f, 500.0f, 0.4f, 1000.0f, 0.5f},
    {83.333336f, 0.0f, 250.0f, 0.8f, 750.0f, 1.0f},
    {166.66667f, 0.0f, 333.33334f, 0.6f, 833.3333f, 1.0f},
    {166.66667f, 0.0f, 333.33334f, 0.6f, 833.3333f, 1.0f},
};

// @ghidraAddress 0x2ff8a0
constexpr float kFanCAlphaPairs[][3 * 2] = {
    {316.66666f, 0.0f, 333.33334f, 1.0f, 833.3333f, 0.0f},
    {316.66666f, 1.0f, 483.33334f, 0.0f, 483.33334f, 0.0f},
    {483.33334f, 0.0f, 500.0f, 1.0f, 1000.0f, 0.0f},
    {483.33334f, 1.0f, 650.0f, 0.0f, 650.0f, 0.0f},
    {483.33334f, 0.0f, 500.0f, 1.0f, 1000.0f, 0.0f},
    {483.33334f, 1.0f, 650.0f, 0.0f, 650.0f, 0.0f},
    {316.66666f, 0.0f, 333.33334f, 1.0f, 833.3333f, 0.0f},
    {316.66666f, 1.0f, 650.0f, 0.0f, 650.0f, 0.0f},
    {150.0f, 0.0f, 166.66667f, 1.0f, 666.6667f, 0.0f},
    {150.0f, 1.0f, 483.33334f, 0.0f, 483.33334f, 0.0f},
    {150.0f, 0.0f, 166.66667f, 1.0f, 666.6667f, 0.0f},
    {150.0f, 1.0f, 483.33334f, 0.0f, 483.33334f, 0.0f},
    {516.6667f, 0.0f, 533.3333f, 1.0f, 1033.3334f, 0.0f},
    {516.6667f, 1.0f, 683.3333f, 0.0f, 683.3333f, 0.0f},
    {433.33334f, 0.0f, 450.0f, 1.0f, 950.0f, 0.0f},
    {433.33334f, 1.0f, 600.0f, 0.0f, 600.0f, 0.0f},
    {483.33334f, 0.0f, 500.0f, 1.0f, 1000.0f, 0.0f},
    {483.33334f, 1.0f, 650.0f, 0.0f, 650.0f, 0.0f},
    {233.33333f, 1.0f, 400.0f, 0.0f, 400.0f, 0.0f},
    {316.66666f, 0.0f, 333.33334f, 1.0f, 833.3333f, 0.0f},
    {316.66666f, 1.0f, 566.6667f, 0.0f, 566.6667f, 0.0f},
};

// @ghidraAddress 0x2ffa98
constexpr float kFanCOffsetYPairs[][3 * 2] = {
    {166.66667f, 0.0f, 333.33334f, -7.5f, 833.3333f, -30.0f},
    {166.66667f, 0.0f, 333.33334f, -7.5f, 833.3333f, -30.0f},
    {333.33334f, 0.0f, 1000.0f, -30.0f, 1000.0f, -30.0f},
    {333.33334f, 0.0f, 1000.0f, -30.0f, 1000.0f, -30.0f},
    {333.33334f, 0.0f, 1000.0f, -30.0f, 1000.0f, -30.0f},
    {333.33334f, 0.0f, 1000.0f, -30.0f, 1000.0f, -30.0f},
    {166.66667f, 0.0f, 333.33334f, -25.0f, 833.3333f, -40.0f},
    {166.66667f, 0.0f, 333.33334f, -25.0f, 833.3333f, -40.0f},
    {0.0f, 0.0f, 166.66667f, -20.0f, 666.6667f, -40.0f},
    {0.0f, 0.0f, 166.66667f, -20.0f, 666.6667f, -40.0f},
    {0.0f, 0.0f, 166.66667f, 0.0f, 666.6667f, -20.0f},
    {0.0f, 0.0f, 166.66667f, 0.0f, 666.6667f, -20.0f},
    {366.66666f, 0.0f, 533.3333f, -30.0f, 1033.3334f, -60.0f},
    {366.66666f, 0.0f, 533.3333f, -30.0f, 1033.3334f, -60.0f},
    {283.33334f, 0.0f, 450.0f, -30.0f, 950.0f, -60.0f},
    {283.33334f, 0.0f, 450.0f, -30.0f, 950.0f, -60.0f},
    {333.33334f, 0.0f, 500.0f, -30.0f, 1000.0f, -60.0f},
    {333.33334f, 0.0f, 500.0f, -30.0f, 1000.0f, -60.0f},
    {83.333336f, 0.0f, 250.0f, 0.0f, 750.0f, -20.0f},
    {166.66667f, 0.0f, 333.33334f, -50.0f, 833.3333f, -80.0f},
    {166.66667f, 0.0f, 333.33334f, -50.0f, 833.3333f, -80.0f},
};

// @ghidraAddress 0x2ffc90
constexpr float kFanDScaleXPairs[][3 * 2] = {
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1000.0f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1000.0f, 0.5f},
    {166.66667f, 0.0f, 833.3333f, 0.5f, 1000.0f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1000.0f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1000.0f, 0.5f},
    {166.66667f, 0.0f, 333.33334f, 0.6f, 833.3333f, 0.8f},
    {0.0f, 0.0f, 166.66667f, 0.4f, 666.6667f, 0.7f},
    {0.0f, 0.0f, 166.66667f, 0.4f, 666.6667f, 1.0f},
    {333.33334f, 0.0f, 500.0f, 0.4f, 1000.0f, 0.5f},
    {250.0f, 0.0f, 416.66666f, 0.4f, 916.6667f, 0.5f},
    {83.333336f, 0.0f, 250.0f, 0.8f, 750.0f, 1.0f},
    {166.66667f, 0.0f, 333.33334f, 0.6f, 833.3333f, 1.0f},
};

// @ghidraAddress 0x2ffdb0
constexpr float kFanDScaleYPairs[][3 * 2] = {
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1000.0f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1000.0f, 0.5f},
    {166.66667f, 0.0f, 833.3333f, 0.5f, 1000.0f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1000.0f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1000.0f, 0.5f},
    {166.66667f, 0.0f, 333.33334f, 0.6f, 833.3333f, 0.8f},
    {0.0f, 0.0f, 166.66667f, 0.4f, 666.6667f, 0.7f},
    {0.0f, 0.0f, 166.66667f, 0.4f, 666.6667f, 1.0f},
    {333.33334f, 0.0f, 500.0f, 0.4f, 1000.0f, 0.5f},
    {250.0f, 0.0f, 416.66666f, 0.4f, 916.6667f, 0.5f},
    {83.333336f, 0.0f, 250.0f, 0.8f, 750.0f, 1.0f},
    {166.66667f, 0.0f, 333.33334f, 0.6f, 833.3333f, 1.0f},
};

// @ghidraAddress 0x2ffed0
constexpr float kFanDAlphaPairs[][3 * 2] = {
    {483.33334f, 0.0f, 500.0f, 1.0f, 1000.0f, 0.0f},
    {483.33334f, 0.0f, 500.0f, 1.0f, 1000.0f, 0.0f},
    {316.66666f, 0.0f, 333.33334f, 1.0f, 833.3333f, 0.0f},
    {483.33334f, 0.0f, 500.0f, 1.0f, 1000.0f, 0.0f},
    {483.33334f, 0.0f, 500.0f, 1.0f, 1000.0f, 0.0f},
    {316.66666f, 0.0f, 333.33334f, 1.0f, 833.3333f, 0.0f},
    {150.0f, 0.0f, 166.66667f, 1.0f, 666.6667f, 0.0f},
    {150.0f, 0.0f, 166.66667f, 1.0f, 666.6667f, 0.0f},
    {483.33334f, 0.0f, 500.0f, 1.0f, 1000.0f, 0.0f},
    {400.0f, 0.0f, 416.66666f, 1.0f, 916.6667f, 0.0f},
    {233.33333f, 0.0f, 250.0f, 1.0f, 750.0f, 0.0f},
    {316.66666f, 0.0f, 333.33334f, 1.0f, 833.3333f, 0.0f},
};

// @ghidraAddress 0x2ffff0
constexpr float kFanDOffsetYPairs[][3 * 2] = {
    {333.33334f, 0.0f, 500.0f, -7.5f, 1000.0f, -30.0f},
    {333.33334f, 0.0f, 500.0f, -7.5f, 1000.0f, -30.0f},
    {166.66667f, 0.0f, 333.33334f, -7.5f, 833.3333f, -30.0f},
    {333.33334f, 0.0f, 1000.0f, -30.0f, 1000.0f, -30.0f},
    {333.33334f, 0.0f, 1000.0f, -30.0f, 1000.0f, -30.0f},
    {166.66667f, 0.0f, 333.33334f, -25.0f, 833.3333f, -50.0f},
    {0.0f, 0.0f, 166.66667f, -50.0f, 666.6667f, -70.0f},
    {0.0f, 0.0f, 166.66667f, -50.0f, 666.6667f, -70.0f},
    {333.33334f, 0.0f, 500.0f, -30.0f, 1000.0f, -60.0f},
    {250.0f, 0.0f, 416.66666f, -30.0f, 916.6667f, -60.0f},
    {83.333336f, 0.0f, 250.0f, -30.0f, 750.0f, -50.0f},
    {166.66667f, 0.0f, 333.33334f, -50.0f, 833.3333f, -80.0f},
};

// @ghidraAddress 0x300110
constexpr float kFlareBackScaleXPairs[] = {0.0f, 5.0f, 133.33333f, 5.0f, 1250.0f, 0.0f};

// @ghidraAddress 0x300128
constexpr float kFlareBackScaleYPairs[] = {0.0f, 0.0f, 133.33333f, 3.0f, 1250.0f, 7.0f};

// @ghidraAddress 0x300140
constexpr float kFlareFrontAlphaPairs[] = {500.0f, 1.0f, 1250.0f, 0.0f};

// @ghidraAddress 0x300150
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

// @ghidraAddress 0x300170
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

// @ghidraAddress 0x300190
constexpr float kLetterScalePairs[][4 * 2] = {
    {450.0f, 0.0f, 616.6667f, 1.1f, 700.0f, 1.0f, 783.3333f, 1.05f},
    {400.0f, 0.0f, 566.6667f, 1.1f, 650.0f, 1.0f, 733.3333f, 1.05f},
    {350.0f, 0.0f, 516.6667f, 1.1f, 600.0f, 1.0f, 683.3333f, 1.05f},
    {300.0f, 0.0f, 466.66666f, 1.1f, 550.0f, 1.0f, 633.3333f, 1.05f},
    {250.0f, 0.0f, 416.66666f, 1.1f, 500.0f, 1.0f, 583.3333f, 1.05f},
    {250.0f, 0.0f, 416.66666f, 1.1f, 500.0f, 1.0f, 583.3333f, 1.05f},
    {300.0f, 0.0f, 466.66666f, 1.1f, 550.0f, 1.0f, 633.3333f, 1.05f},
    {350.0f, 0.0f, 516.6667f, 1.1f, 600.0f, 1.0f, 683.3333f, 1.05f},
    {400.0f, 0.0f, 566.6667f, 1.1f, 650.0f, 1.0f, 733.3333f, 1.05f},
    {450.0f, 0.0f, 616.6667f, 1.1f, 700.0f, 1.0f, 783.3333f, 1.05f},
};

// @ghidraAddress 0x300460
constexpr float kLetterAlphaPairs[][4 * 2] = {
    {450.0f, 0.0f, 700.0f, 1.0f, 1333.3334f, 1.0f, 1483.3334f, 0.0f},
    {400.0f, 0.0f, 650.0f, 1.0f, 1333.3334f, 1.0f, 1483.3334f, 0.0f},
    {350.0f, 0.0f, 600.0f, 1.0f, 1333.3334f, 1.0f, 1483.3334f, 0.0f},
    {300.0f, 0.0f, 550.0f, 1.0f, 1333.3334f, 1.0f, 1483.3334f, 0.0f},
    {250.0f, 0.0f, 500.0f, 1.0f, 1333.3334f, 1.0f, 1483.3334f, 0.0f},
    {250.0f, 0.0f, 500.0f, 1.0f, 1333.3334f, 1.0f, 1483.3334f, 0.0f},
    {300.0f, 0.0f, 550.0f, 1.0f, 1333.3334f, 1.0f, 1483.3334f, 0.0f},
    {350.0f, 0.0f, 600.0f, 1.0f, 1333.3334f, 1.0f, 1483.3334f, 0.0f},
    {400.0f, 0.0f, 650.0f, 1.0f, 1333.3334f, 1.0f, 1483.3334f, 0.0f},
    {450.0f, 0.0f, 700.0f, 1.0f, 1333.3334f, 1.0f, 1483.3334f, 0.0f},
};

// @ghidraAddress 0x3005a0
constexpr float kBannerScaleXPairs[] = {0.0f, 0.0f, 166.66667f, 1.5f, 250.0f, 1.0f, 500.0f, 5.0f};

// @ghidraAddress 0x3005c0
constexpr float kBannerScaleYPairs[] = {0.0f, 0.0f, 166.66667f, 1.5f, 250.0f, 1.0f, 500.0f, 1.5f};

// @ghidraAddress 0x3005e0
constexpr float kBannerAlphaPairs[] = {250.0f, 1.0f, 500.0f, 0.0f};

inline unsigned int ScaleToAlpha(float flValue) {
    return static_cast<unsigned int>(static_cast<int>(flValue * kAlphaScale));
}

inline float MoteRowY(int nRowInset) {
    return static_cast<float>((g_nPlayfieldNearRowBottom - nRowInset) - g_nPlayfieldCentreSplit);
}

} // namespace

/** @ghidraAddress 0x9b3a8 */
void FullComboColetteLayer::Update(float flDelta) {
    m_aSpriteCounts[0] = 0;
    m_aSpriteCounts[1] = 0;
    m_aSpriteCounts[2] = 0;

    if (!IsAnyEffectActive()) {
        for (int nSlot = 0; nSlot < kSpriteSlotCount; ++nSlot) {
            m_apSprites[nSlot]->SetSpriteCount(0);
        }
        return;
    }

    if (static_cast<double>(flDelta) > kFrameCountThreshold) {
        ++g_nColetteFullComboFrameCount;
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

        if (!effect.m_bVoiceFired && flClock > kVoiceCueClockMin && flClock < kVoiceCueClockMax) {
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

        for (int nMote = 0; nMote < kFanACount; ++nMote) {
            const float flScaleX =
                CalculateCurveInterpolation(kFanAScaleXPairs[nMote], kThreePointCurve, flClock);
            const float flScaleY =
                CalculateCurveInterpolation(kFanAScaleYPairs[nMote], kThreePointCurve, flClock);
            const float flAlpha =
                CalculateCurveInterpolation(kFanAAlphaPairs[nMote], kTwoPointCurve, flClock);
            float flRotation =
                CalculateCurveInterpolation(kFanARotationPairs[nMote], kTwoPointCurve, flClock);
            const float flOffsetX =
                CalculateCurveInterpolation(kFanAOffsetXPairs[nMote], kTwoPointCurve, flClock);
            const float flOffsetY =
                CalculateCurveInterpolation(kFanAOffsetYPairs[nMote], kTwoPointCurve, flClock);

            const float flBaseX = kFanALayout[nMote].flScreenX;
            const float flBaseY = MoteRowY(kFanALayout[nMote].nRowInset);
            S_VECTOR2 position{flBaseX + flOffsetX, flBaseY + flOffsetY};
            if (!bOwnSide) {
                flRotation =
                    static_cast<float>(static_cast<double>(flRotation) + kMirrorRotationExact);
                position = S_VECTOR2{-flBaseX - flOffsetX, -flBaseY - flOffsetY};
            }
            CreateSprite(kFanAKindBase[nSide] + nMote,
                         &position,
                         ScaleToAlpha(flAlpha),
                         flScaleX,
                         flScaleY,
                         flRotation);
        }

        const auto EmitMoteFan = [&](float flCurveClock,
                                     const MoteLayout *pLayout,
                                     int nCount,
                                     int nKindBase,
                                     const float (*pScaleX)[kThreePointCurve * 2],
                                     const float (*pScaleY)[kThreePointCurve * 2],
                                     const float (*pAlpha)[kThreePointCurve * 2],
                                     const float (*pOffsetY)[kThreePointCurve * 2]) {
            for (int nMote = 0; nMote < nCount; ++nMote) {
                const float flScaleX =
                    CalculateCurveInterpolation(pScaleX[nMote], kThreePointCurve, flCurveClock);
                const float flScaleY =
                    CalculateCurveInterpolation(pScaleY[nMote], kThreePointCurve, flCurveClock);
                const float flAlpha =
                    CalculateCurveInterpolation(pAlpha[nMote], kThreePointCurve, flCurveClock);
                const float flOffsetY =
                    CalculateCurveInterpolation(pOffsetY[nMote], kThreePointCurve, flCurveClock);

                const float flBaseX = pLayout[nMote].flScreenX;
                const float flBaseY = MoteRowY(pLayout[nMote].nRowInset);
                const S_VECTOR2 position = bOwnSide ? S_VECTOR2{flBaseX, flBaseY + flOffsetY} :
                                                      S_VECTOR2{-flBaseX, -flBaseY - flOffsetY};
                const float flRotation = bOwnSide ? 0.0f : kMirrorRotation;
                CreateSprite(nKindBase + nMote,
                             &position,
                             ScaleToAlpha(flAlpha),
                             flScaleX,
                             flScaleY,
                             flRotation);
            }
        };

        // The second fan alone runs on the letters' half-second-delayed clock.
        EmitMoteFan(flClock + kLetterClockBias,
                    kFanBLayout,
                    kFanBCount,
                    kFanBKindBase[nSide],
                    kFanBScaleXPairs,
                    kFanBScaleYPairs,
                    kFanBAlphaPairs,
                    kFanBOffsetYPairs);

        // The third fan reuses the first fan's kind base, as the binary does.
        EmitMoteFan(flClock,
                    kFanCLayout,
                    kFanCCount,
                    kFanAKindBase[nSide],
                    kFanCScaleXPairs,
                    kFanCScaleYPairs,
                    kFanCAlphaPairs,
                    kFanCOffsetYPairs);

        if (g_nColetteFullComboFrameCount % kFanDStrobePeriod < kFanDStrobeOnFrames) {
            EmitMoteFan(flClock,
                        kFanDLayout,
                        kFanDCount,
                        kFanDKindBase[nSide],
                        kFanDScaleXPairs,
                        kFanDScaleYPairs,
                        kFanDAlphaPairs,
                        kFanDOffsetYPairs);
        }

        const float flFlareOffsetY = kFlareScreenY - m_flHeight;
        const float flFlareX = kFlareScreenX - m_flWidth;
        const float flFlareRotation = kSideRotation[bOwnSide ? 1 : 0];

        const float flBackScaleX =
            CalculateCurveInterpolation(kFlareBackScaleXPairs, kThreePointCurve, flClock);
        const float flBackScaleY =
            CalculateCurveInterpolation(kFlareBackScaleYPairs, kThreePointCurve, flClock);
        // Only the back flare mirrors its X, as the binary has it; both land on zero anyway.
        S_VECTOR2 backPosition{bOwnSide ? flFlareX : -flFlareX,
                               flRowBaseY + (bOwnSide ? flFlareOffsetY : -flFlareOffsetY)};
        CreateSprite(kFlareBackKind[nSide],
                     &backPosition,
                     kFlareBackAlpha,
                     flBackScaleX,
                     flBackScaleY,
                     flFlareRotation);

        const float flFrontAlpha =
            CalculateCurveInterpolation(kFlareFrontAlphaPairs, kTwoPointCurve, flClock);
        const float flFrontScaleX =
            CalculateCurveInterpolation(kFlareFrontScaleXPairs, kFourPointCurve, flClock);
        const float flFrontScaleY =
            CalculateCurveInterpolation(kFlareFrontScaleYPairs, kFourPointCurve, flClock);
        S_VECTOR2 frontPosition{flFlareX,
                                flRowBaseY + (bOwnSide ? flFlareOffsetY : -flFlareOffsetY)};
        CreateSprite(kFlareFrontKind[nSide],
                     &frontPosition,
                     ScaleToAlpha(flFrontAlpha),
                     flFrontScaleX,
                     flFrontScaleY,
                     flFlareRotation);

        const S_VECTOR2 aCentreBase[kSideCount] = {
            {0.0f,
             static_cast<float>((g_nPlayfieldNearRowTop + kLetterRowInset) -
                                g_nPlayfieldCentreSplit)},
            {0.0f,
             static_cast<float>((g_nPlayfieldNearRowBottom - kLetterRowInset) -
                                g_nPlayfieldCentreSplit)},
        };
        const float flLetterClock = flClock + kLetterClockBias;
        const bool bLetterMirrored = nGameType == kVersusGameType && !bOwnSide;
        const float flLetterRotation = bLetterMirrored ? kMirrorRotation : 0.0f;
        const S_VECTOR2 centreBase = aCentreBase[bOwnSide ? 1 : 0];

        for (int nLetter = 0; nLetter < kLetterCount; ++nLetter) {
            const float flScale = CalculateCurveInterpolation(
                kLetterScalePairs[nLetter], kFourPointCurve, flLetterClock);
            const float flAlpha = CalculateCurveInterpolation(
                kLetterAlphaPairs[nLetter], kFourPointCurve, flLetterClock);
            S_VECTOR2 position = centreBase;
            S_VECTOR2 offset = kLetterOffsets[nLetter];
            if (bLetterMirrored) {
                SubtractVector2(&position, &offset);
            } else {
                AddVector2(&position, &offset);
            }
            CreateSprite((nLetter - kLetterCount) + kLetterKindBias,
                         &position,
                         ScaleToAlpha(flAlpha),
                         flScale,
                         flScale,
                         flLetterRotation);
        }

        // The binary still runs the banner's zero offset through the vector helpers.
        const float flBannerScaleX =
            CalculateCurveInterpolation(kBannerScaleXPairs, kFourPointCurve, flLetterClock);
        const float flBannerScaleY =
            CalculateCurveInterpolation(kBannerScaleYPairs, kFourPointCurve, flLetterClock);
        const float flBannerAlpha =
            CalculateCurveInterpolation(kBannerAlphaPairs, kTwoPointCurve, flLetterClock);
        S_VECTOR2 bannerPosition = centreBase;
        S_VECTOR2 bannerOffset{};
        if (bLetterMirrored) {
            SubtractVector2(&bannerPosition, &bannerOffset);
        } else {
            AddVector2(&bannerPosition, &bannerOffset);
        }
        CreateSprite(kBannerKind,
                     &bannerPosition,
                     ScaleToAlpha(flBannerAlpha),
                     flBannerScaleX,
                     flBannerScaleY,
                     flLetterRotation);
    }

    for (int nSlot = 0; nSlot < kSpriteSlotCount; ++nSlot) {
        m_apSprites[nSlot]->SetSpriteCount(m_aSpriteCounts[nSlot]);
    }
}
