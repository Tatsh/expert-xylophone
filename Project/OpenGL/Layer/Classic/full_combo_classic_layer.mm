#include "full_combo_classic_layer.h"

#include <cassert>

#include "../Share/bg_layer.h"
#import "AudioManager.h"
#include "curve.h"
#include "engineglobals.h"
#include "full_combo_classic_sprite_table.h"
#include "gamesystem.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#include "s_vector2.h"
#include "soundeffectmanager.h"
#include "sprite_uv_table.h"
#include "vectormath.h"

static FullComboClassicLayer *g_pFullComboClassicLayer = nullptr; // @ghidraAddress 0x3dd078

extern const SpriteUvEntry g_aSpriteUvTable[]; // @ghidraAddress 0x2efcc8

// @ghidraAddress 0x302bf8
const ClassicFullComboSpriteType g_aClassicFullComboSpriteTypes[kClassicFullComboSpriteTypeCount] =
    {
        {15.0f, 24.0f, 30.0f, 48.0f, 13},
        {19.0f, 24.0f, 38.0f, 48.0f, 14},
        {15.0f, 24.0f, 30.0f, 48.0f, 15},
        {27.0f, 24.0f, 54.0f, 48.0f, 16},
        {29.0f, 24.0f, 58.0f, 48.0f, 17},
        {28.0f, 24.0f, 56.0f, 48.0f, 18},
        {18.0f, 24.0f, 36.0f, 48.0f, 19},
        {4.0f, 24.0f, 8.0f, 48.0f, 20},
        {234.0f, 39.0f, 468.0f, 78.0f, 21},
        {62.0f, 200.0f, 124.0f, 200.0f, 22},
        {62.0f, 200.0f, 124.0f, 200.0f, 23},
        {22.0f, 22.0f, 44.0f, 44.0f, 24},
        {22.0f, 22.0f, 44.0f, 44.0f, 25},
        {32.0f, 106.0f, 64.0f, 106.0f, 26},
        {32.0f, 106.0f, 64.0f, 106.0f, 27},
        {14.0f, 14.0f, 28.0f, 28.0f, 12},
};

namespace {

// @ghidraAddress 0x3ceaa8
constexpr const char *kTextureName = "00_texture/gm_parts2";

constexpr unsigned int kSlotCapacity = 0x40;

constexpr int kAdditiveBlendMode = 1;

constexpr int kTexParamSlotHigh = 1;
constexpr int kTexParamSlotLow = 0;
constexpr int kTexParamEnabled = 1;

} // namespace

/** @ghidraAddress 0x10f280 */
FullComboClassicLayer::FullComboClassicLayer() = default;

/** @ghidraAddress 0x10f2dc */
FullComboClassicLayer *FullComboClassicLayer::shared() {
    if (g_pFullComboClassicLayer == nullptr) {
        g_pFullComboClassicLayer = new FullComboClassicLayer();
    }
    return g_pFullComboClassicLayer;
}

/** @ghidraAddress 0x10f32c */
void FullComboClassicLayer::InitializeBackgroundSprites() {
    if (m_bBuilt) {
        return;
    }

    BgLayer *pBackgroundLayer = BgLayer::GetBackgroundLayer();
    ne::C_RENDER *pParent = pBackgroundLayer->GetBackgroundRenderObject();

    m_pTexture = ne::C_TEXTURE::FindOrLoadCached(kTextureName);

    for (int nSlot = 0; nSlot < kSpriteSlotCount; ++nSlot) {
        ne::C_SPRITE_INSTANCING_2D *pSprite = ne::CreateWorldSpriteBatch(kSlotCapacity);
        m_apSprites[nSlot] = pSprite;
        pParent->AttachChild(pSprite);
        pSprite->SetVisible(true);
        pSprite->SetRefCountedMember(m_pTexture);
        pSprite->SetSpriteCount(0);
        pSprite->SetBlendMode(kAdditiveBlendMode);
        pSprite->SetTexParam(kTexParamSlotHigh, kTexParamEnabled);
        pSprite->SetTexParam(kTexParamSlotLow, kTexParamEnabled);
    }

    m_bBuilt = true;
}

/** @ghidraAddress 0x10f3f4 */
void FullComboClassicLayer::CreateFullComboClassic(unsigned int nColor) {
    assert(static_cast<int>(nColor) >= 0 && nColor < kColorCount);
    EffectRecord &effect = m_aEffects[nColor];
    effect.m_bActive = true;
    effect.m_flTimer = 0.0f;
    effect.m_bVoiceFired = false;
}

/** @ghidraAddress 0x10fe88 */
void FullComboClassicLayer::CreateSprite(int nObjType,
                                         int nType,
                                         const S_VECTOR2 *pPosition,
                                         unsigned int nAlpha,
                                         float flScaleX,
                                         float flScaleY,
                                         float flRotation) {
    assert(nObjType >= 0);
    assert(nObjType < kClassicFullComboObjectTypeCount);
    assert(nType >= 0);
    assert(nType < kClassicFullComboSpriteTypeCount);

    const int nIndex = m_aSpriteCounts[nObjType];
    if (nIndex >= static_cast<int>(kSlotCapacity)) {
        return;
    }

    const ClassicFullComboSpriteType &spriteType = g_aClassicFullComboSpriteTypes[nType];
    const SpriteUvEntry &uv = g_aSpriteUvTable[spriteType.nUvIndex];
    ne::C_SPRITE_INSTANCING_2D *pBatch = m_apSprites[nObjType];

    pBatch->SetSpritePosition(nIndex, *pPosition);
    pBatch->SetSpriteAnchor(nIndex, S_VECTOR2{spriteType.flAnchorX, spriteType.flAnchorY});
    pBatch->SetSpriteSize(nIndex, S_VECTOR2{spriteType.flSizeW, spriteType.flSizeH});
    pBatch->SetSpriteUvOrigin(nIndex, S_VECTOR2{uv.flOriginU, uv.flOriginV});
    pBatch->SetSpriteUvSize(nIndex, S_VECTOR2{uv.flSizeU, uv.flSizeV});
    pBatch->SetSpriteScale(nIndex, flScaleX, flScaleY);
    pBatch->SetSpriteRotation(nIndex, flRotation);
    pBatch->SetSpriteColor(nIndex, 0xff, 0xff, 0xff, nAlpha);

    ++m_aSpriteCounts[nObjType];
}

/** @ghidraAddress 0x10f46c */
void FullComboClassicLayer::ClearEffectFlags() {
    for (EffectRecord &effect : m_aEffects) {
        effect.m_bActive = false;
    }
}

/** @ghidraAddress 0x10f488 */
bool FullComboClassicLayer::IsAnyEffectActive() const {
    for (const EffectRecord &effect : m_aEffects) {
        if (effect.m_bActive) {
            return true;
        }
    }
    return false;
}

namespace {

constexpr int kSideCount = 2;

constexpr float kEffectDuration = 2000.0f; // @ghidraAddress 0x2feff0
constexpr float kVoiceCueClock = 500.0f;   // @ghidraAddress 0x2feff4

constexpr float kCentreClockBias = -500.0f; // @ghidraAddress 0x2feff8

constexpr int kFullComboVoiceId = 9;

// The binary's (gameType | 2) == 2 test admits game types 0 and 2, the single-player modes.
constexpr int kSinglePlayerGameTypeMask = 2;

constexpr int kVersusGameType = 1;

constexpr float kMirrorRotation = 3.1415927f;           // @ghidraAddress 0x2fe894
constexpr double kOrbSpinPerSecond = 3.141592653589793; // @ghidraAddress 0x2f85a0
constexpr double kSparkleSweep = -1.5707963267948966;   // @ghidraAddress 0x3025b0

constexpr float kFrameRate = 60.0f;               // @ghidraAddress 0x2f8578
constexpr float kMillisecondsPerSecond = 1000.0f; // @ghidraAddress 0x2f8540

constexpr float kAlphaScale = 255.0f; // @ghidraAddress 0x2eed00
constexpr float kUnitScale = 1.0f;
constexpr unsigned int kOpaqueAlpha = 255;

constexpr int kBaseBatch = 0;
constexpr int kLetterBatch = 1;
constexpr int kGlowBatch = 2;

constexpr int kBeamKindBase = 9;
constexpr int kSparkKindBase = 11;
constexpr int kFlareKindBase = 13;
constexpr int kBannerKind = 8;
constexpr int kSparkleKind = 15;

constexpr int kBeamCount = 6;
constexpr int kFlareCount = 2;
constexpr int kSparkCount = 10;
constexpr int kLetterCount = 10;
constexpr int kSparkleCount = 10;

constexpr float kSparkFrameLimit = 45.0f; // @ghidraAddress 0x302488
constexpr float kSparkBlinkPeriod = 5.0f;
constexpr float kSparkBlinkOnFrames = 3.0f;
constexpr float kSparkRampMidpoint = 15.0f;
constexpr float kSparkRampFallSpan = -30.0f;

constexpr float kSparkleFrameLimit = 30.0f;
constexpr float kSparkleRampMidpoint = 10.0f;
constexpr float kSparkleRampFallSpan = -20.0f;

constexpr int kBannerRowInset = 232;

constexpr S_VECTOR2 kBannerOffset{-1.0f, 0.0f};

// @ghidraAddress 0x302490
constexpr S_VECTOR2 kBeamOffsets[kBeamCount] = {
    {214.0f, 0.0f},
    {0.0f, 0.0f},
    {-214.0f, 0.0f},
    {214.0f, 0.0f},
    {0.0f, 0.0f},
    {-214.0f, 0.0f},
};

// The binary zeroes this array and still runs it through the vector combine.
constexpr S_VECTOR2 kFlareOffsets[kFlareCount] = {};

// @ghidraAddress 0x3024c0
constexpr S_VECTOR2 kSparkOffsets[kSparkCount] = {
    {250.0f, -143.0f},
    {153.0f, -143.0f},
    {130.0f, -93.0f},
    {70.0f, -173.0f},
    {-250.0f, -143.0f},
    {-150.0f, -143.0f},
    {-80.0f, -143.0f},
    {-30.0f, -143.0f},
    {-100.0f, -143.0f},
    {0.0f, -143.0f},
};

// @ghidraAddress 0x302510
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
    {214.0f, 0.0f},
};

// @ghidraAddress 0x302560
constexpr S_VECTOR2 kSparkleOffsets[kSparkleCount] = {
    {-223.0f, -29.0f},
    {-177.0f, 0.0f},
    {-104.0f, -23.0f},
    {-38.0f, 17.0f},
    {19.0f, -23.0f},
    {51.0f, 22.0f},
    {99.0f, -23.0f},
    {143.0f, 3.0f},
    {205.0f, -1.0f},
    {229.0f, -34.0f},
};

// The ten entries spell FULLCOMBO!, which is why kinds 2 and 4 each appear twice.
// @ghidraAddress 0x302ba8
constexpr int kLetterKinds[kLetterCount] = {0, 1, 2, 2, 3, 4, 5, 6, 4, 7};

// @ghidraAddress 0x3027f0
constexpr float kSparkStartClocks[kSparkCount] = {
    450.0f,
    250.0f,
    400.0f,
    333.33334f,
    500.0f,
    400.0f,
    333.33334f,
    400.0f,
    250.0f,
    250.0f,
};

// @ghidraAddress 0x302bd0
constexpr float kSparkleStartClocks[kSparkleCount] = {
    133.33333f,
    216.66667f,
    300.0f,
    383.33334f,
    466.66666f,
    500.0f,
    566.6667f,
    600.0f,
    633.3333f,
    666.6667f,
};

constexpr int kBeamScaleXPairCount = 2;
constexpr int kBeamScaleYPairCount = 4;
constexpr int kBeamAlphaPairCount = 3;
constexpr int kSparkRisePairCount = 2;
constexpr int kBannerAlphaPairCount = 4;
constexpr int kLetterScaleYPairCount = 2;
constexpr int kLetterFillAlphaPairCount = 4;
constexpr int kLetterGlowAlphaPairCount = 3;

// @ghidraAddress 0x3025b8
constexpr float kBeamScaleXPairs[kBeamCount][kBeamScaleXPairCount * 2] = {
    {0.0f, 2.0f, 1250.0f, 2.0f},
    {0.0f, 1.465f, 1250.0f, 1.465f},
    {0.0f, 2.0f, 1250.0f, 2.0f},
    {0.0f, 2.0f, 1250.0f, 2.0f},
    {0.0f, 1.465f, 1250.0f, 1.465f},
    {0.0f, 2.0f, 1250.0f, 2.0f},
};

// @ghidraAddress 0x302618
constexpr float kBeamScaleYPairs[kBeamCount][kBeamScaleYPairCount * 2] = {
    {0.0f, 0.0f, 133.33333f, 3.0f, 500.0f, 3.0f, 1250.0f, 0.0f},
    {0.0f, 0.0f, 133.33333f, 3.0f, 500.0f, 3.0f, 1250.0f, 0.0f},
    {0.0f, 0.0f, 133.33333f, 3.0f, 500.0f, 3.0f, 1250.0f, 0.0f},
    {0.0f, 0.0f, 133.33333f, 4.0f, 500.0f, 4.0f, 1250.0f, 2.0f},
    {0.0f, 0.0f, 133.33333f, 4.0f, 500.0f, 4.0f, 1250.0f, 2.0f},
    {0.0f, 0.0f, 133.33333f, 4.0f, 500.0f, 4.0f, 1250.0f, 2.0f},
};

// @ghidraAddress 0x3026d8
constexpr float kBeamAlphaPairs[kBeamCount][kBeamAlphaPairCount * 2] = {
    {0.0f, 0.0f, 133.33333f, 1.0f, 500.0f, 0.0f},
    {0.0f, 0.0f, 133.33333f, 1.0f, 500.0f, 0.0f},
    {0.0f, 0.0f, 133.33333f, 1.0f, 500.0f, 0.0f},
    {0.0f, 0.5f, 500.0f, 0.5f, 1250.0f, 0.0f},
    {0.0f, 0.5f, 500.0f, 0.5f, 1250.0f, 0.0f},
    {0.0f, 0.5f, 500.0f, 0.5f, 1250.0f, 0.0f},
};

// @ghidraAddress 0x302768 through 0x3027e8
constexpr float kFlareScaleXNearPairs[] = {0.0f, 2.7f, 133.33333f, 2.7f, 1250.0f, 0.0f};
constexpr float kFlareScaleXFarPairs[] = {0.0f, 12.0f, 1250.0f, 12.0f};
constexpr float kFlareScaleYNearPairs[] = {0.0f, 0.0f, 133.33333f, 3.0f, 1250.0f, 7.0f};
constexpr float kFlareScaleYFarPairs[] = {
    0.0f, 0.0f, 133.33333f, 2.0f, 500.0f, 2.0f, 1250.0f, 0.0f};
constexpr float kFlareAlphaNearPairs[] = {0.0f, 0.5f, 1250.0f, 0.5f};
constexpr float kFlareAlphaFarPairs[] = {0.0f, 1.0f, 500.0f, 1.0f, 1250.0f, 0.0f};

// The curve starts at the spark's own start clock, so it is sampled with the raw clock.
// @ghidraAddress 0x302818
constexpr float kSparkRisePairs[kSparkCount][kSparkRisePairCount * 2] = {
    {450.0f, 0.0f, 1200.0f, -100.0f},
    {250.0f, 0.0f, 1000.0f, -110.0f},
    {400.0f, 0.0f, 1150.0f, -170.0f},
    {333.33334f, 0.0f, 1083.3334f, -170.0f},
    {500.0f, 0.0f, 1250.0f, -100.0f},
    {400.0f, 0.0f, 1150.0f, -110.0f},
    {333.33334f, 0.0f, 1083.3334f, -170.0f},
    {400.0f, 0.0f, 1150.0f, -170.0f},
    {250.0f, 0.0f, 1000.0f, -230.0f},
    {250.0f, 0.0f, 1000.0f, -430.0f},
};

// @ghidraAddress 0x3028b8
constexpr float kBannerAlphaPairs[kBannerAlphaPairCount * 2] = {
    0.0f,
    0.0f,
    383.33334f,
    0.8f,
    1316.6666f,
    0.8f,
    1483.3334f,
    0.0f,
};

// @ghidraAddress 0x3028d8
constexpr float kLetterScaleYPairs[kLetterCount][kLetterScaleYPairCount * 2] = {
    {0.0f, 0.0f, 100.0f, 1.0f},
    {33.333332f, 0.0f, 133.33333f, 1.0f},
    {66.666664f, 0.0f, 166.66667f, 1.0f},
    {100.0f, 0.0f, 200.0f, 1.0f},
    {133.33333f, 0.0f, 233.33333f, 1.0f},
    {166.66667f, 0.0f, 266.66666f, 1.0f},
    {200.0f, 0.0f, 300.0f, 1.0f},
    {233.33333f, 0.0f, 333.33334f, 1.0f},
    {266.66666f, 0.0f, 366.66666f, 1.0f},
    {300.0f, 0.0f, 400.0f, 1.0f},
};

// @ghidraAddress 0x302978
constexpr float kLetterFillAlphaPairs[kLetterCount][kLetterFillAlphaPairCount * 2] = {
    {-16.666666f, 0.0f, 0.0f, 1.0f, 1316.6666f, 1.0f, 1483.3334f, 0.0f},
    {16.666666f, 0.0f, 33.333332f, 1.0f, 1316.6666f, 1.0f, 1483.3334f, 0.0f},
    {50.0f, 0.0f, 66.666664f, 1.0f, 1316.6666f, 1.0f, 1483.3334f, 0.0f},
    {83.333336f, 0.0f, 100.0f, 1.0f, 1316.6666f, 1.0f, 1483.3334f, 0.0f},
    {116.666664f, 0.0f, 133.33333f, 1.0f, 1316.6666f, 1.0f, 1483.3334f, 0.0f},
    {150.0f, 0.0f, 166.66667f, 1.0f, 1316.6666f, 1.0f, 1483.3334f, 0.0f},
    {183.33333f, 0.0f, 200.0f, 1.0f, 1316.6666f, 1.0f, 1483.3334f, 0.0f},
    {216.66667f, 0.0f, 233.33333f, 1.0f, 1316.6666f, 1.0f, 1483.3334f, 0.0f},
    {250.0f, 0.0f, 266.66666f, 1.0f, 1316.6666f, 1.0f, 1483.3334f, 0.0f},
    {283.33334f, 0.0f, 300.0f, 1.0f, 1316.6666f, 1.0f, 1483.3334f, 0.0f},
};

// @ghidraAddress 0x302ab8
constexpr float kLetterGlowAlphaPairs[kLetterCount][kLetterGlowAlphaPairCount * 2] = {
    {116.666664f, 0.0f, 133.33333f, 0.8f, 350.0f, 0.0f},
    {166.66667f, 0.0f, 183.33333f, 0.8f, 400.0f, 0.0f},
    {216.66667f, 0.0f, 233.33333f, 0.8f, 450.0f, 0.0f},
    {266.66666f, 0.0f, 283.33334f, 0.8f, 500.0f, 0.0f},
    {316.66666f, 0.0f, 333.33334f, 0.8f, 550.0f, 0.0f},
    {366.66666f, 0.0f, 383.33334f, 0.8f, 600.0f, 0.0f},
    {416.66666f, 0.0f, 433.33334f, 0.8f, 650.0f, 0.0f},
    {466.66666f, 0.0f, 483.33334f, 0.8f, 700.0f, 0.0f},
    {516.6667f, 0.0f, 533.3333f, 0.8f, 750.0f, 0.0f},
    {566.6667f, 0.0f, 583.3333f, 0.8f, 800.0f, 0.0f},
};

// @ghidraAddress 0x35ce10, 0x35ce30, 0x35ce50, 0x35ce70, 0x35cf10, 0x35cf20, 0x35cfc0, and
// 0x35d060.
const FloatCurve g_aFlareScaleXCurves[kFlareCount] = {
    {3, kFlareScaleXNearPairs},
    {2, kFlareScaleXFarPairs},
};
const FloatCurve g_aFlareScaleYCurves[kFlareCount] = {
    {3, kFlareScaleYNearPairs},
    {4, kFlareScaleYFarPairs},
};
const FloatCurve g_aFlareAlphaCurves[kFlareCount] = {
    {2, kFlareAlphaNearPairs},
    {3, kFlareAlphaFarPairs},
};
const FloatCurve g_aSparkRiseCurves[kSparkCount] = {
    {kSparkRisePairCount, kSparkRisePairs[0]},
    {kSparkRisePairCount, kSparkRisePairs[1]},
    {kSparkRisePairCount, kSparkRisePairs[2]},
    {kSparkRisePairCount, kSparkRisePairs[3]},
    {kSparkRisePairCount, kSparkRisePairs[4]},
    {kSparkRisePairCount, kSparkRisePairs[5]},
    {kSparkRisePairCount, kSparkRisePairs[6]},
    {kSparkRisePairCount, kSparkRisePairs[7]},
    {kSparkRisePairCount, kSparkRisePairs[8]},
    {kSparkRisePairCount, kSparkRisePairs[9]},
};
const FloatCurve g_aBannerAlphaCurve = {kBannerAlphaPairCount, kBannerAlphaPairs};
const FloatCurve g_aLetterScaleYCurves[kLetterCount] = {
    {kLetterScaleYPairCount, kLetterScaleYPairs[0]},
    {kLetterScaleYPairCount, kLetterScaleYPairs[1]},
    {kLetterScaleYPairCount, kLetterScaleYPairs[2]},
    {kLetterScaleYPairCount, kLetterScaleYPairs[3]},
    {kLetterScaleYPairCount, kLetterScaleYPairs[4]},
    {kLetterScaleYPairCount, kLetterScaleYPairs[5]},
    {kLetterScaleYPairCount, kLetterScaleYPairs[6]},
    {kLetterScaleYPairCount, kLetterScaleYPairs[7]},
    {kLetterScaleYPairCount, kLetterScaleYPairs[8]},
    {kLetterScaleYPairCount, kLetterScaleYPairs[9]},
};
const FloatCurve g_aLetterFillAlphaCurves[kLetterCount] = {
    {kLetterFillAlphaPairCount, kLetterFillAlphaPairs[0]},
    {kLetterFillAlphaPairCount, kLetterFillAlphaPairs[1]},
    {kLetterFillAlphaPairCount, kLetterFillAlphaPairs[2]},
    {kLetterFillAlphaPairCount, kLetterFillAlphaPairs[3]},
    {kLetterFillAlphaPairCount, kLetterFillAlphaPairs[4]},
    {kLetterFillAlphaPairCount, kLetterFillAlphaPairs[5]},
    {kLetterFillAlphaPairCount, kLetterFillAlphaPairs[6]},
    {kLetterFillAlphaPairCount, kLetterFillAlphaPairs[7]},
    {kLetterFillAlphaPairCount, kLetterFillAlphaPairs[8]},
    {kLetterFillAlphaPairCount, kLetterFillAlphaPairs[9]},
};
const FloatCurve g_aLetterGlowAlphaCurves[kLetterCount] = {
    {kLetterGlowAlphaPairCount, kLetterGlowAlphaPairs[0]},
    {kLetterGlowAlphaPairCount, kLetterGlowAlphaPairs[1]},
    {kLetterGlowAlphaPairCount, kLetterGlowAlphaPairs[2]},
    {kLetterGlowAlphaPairCount, kLetterGlowAlphaPairs[3]},
    {kLetterGlowAlphaPairCount, kLetterGlowAlphaPairs[4]},
    {kLetterGlowAlphaPairCount, kLetterGlowAlphaPairs[5]},
    {kLetterGlowAlphaPairCount, kLetterGlowAlphaPairs[6]},
    {kLetterGlowAlphaPairCount, kLetterGlowAlphaPairs[7]},
    {kLetterGlowAlphaPairCount, kLetterGlowAlphaPairs[8]},
    {kLetterGlowAlphaPairCount, kLetterGlowAlphaPairs[9]},
};

inline float ClockToFrames(float flClock) {
    return flClock * kFrameRate / kMillisecondsPerSecond;
}

inline unsigned int ScaleToAlpha(float flValue) {
    return static_cast<unsigned int>(static_cast<int>(flValue * kAlphaScale));
}

// The comparison order leaves a NaN at zero, as the binary's does.
inline float RampAndClamp(float flFrames, float flMidpoint, float flFallSpan) {
    const float flValue = (flFrames >= flMidpoint) ? ((flFrames - flMidpoint) / flFallSpan + 1.0f) :
                                                     (flFrames / flMidpoint);
    if (flValue > 1.0f) {
        return 1.0f;
    }
    if (flValue >= 0.0f) {
        return flValue;
    }
    return 0.0f;
}

inline S_VECTOR2 CombineOffset(const S_VECTOR2 &base, const S_VECTOR2 &offset, bool bMirrored) {
    S_VECTOR2 position = base;
    S_VECTOR2 delta = offset;
    if (bMirrored) {
        SubtractVector2(&position, &delta);
    } else {
        AddVector2(&position, &delta);
    }
    return position;
}

} // namespace

/** @ghidraAddress 0x10f4b8 */
void FullComboClassicLayer::Update(float flDelta) {
    for (int &nCount : m_aSpriteCounts) {
        nCount = 0;
    }

    GameSystem *pGameSystem = GameSystem::GetGameSystem();

    // The binary re-reads the game system on every iteration of this two-element loop.
    const float aRowSlope[kSideCount] = {g_flPlayfieldNearLaneSlope, g_flPlayfieldNearLaneSlopeNeg};
    float aRowBaseY[kSideCount] = {};
    for (int nRow = 0; nRow < kSideCount; ++nRow) {
        aRowBaseY[nRow] = aRowSlope[nRow] * GameSystem::GetGameSystem()->GetSheetInsetHalfY();
    }

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

        if (!effect.m_bVoiceFired && flClock > kVoiceCueClock) {
            effect.m_bVoiceFired = true;
            const int nRivalSide = (pGameSystem->GetPlayColor() == 0) ? 1 : 0;
            const bool bSilent =
                nSide == nRivalSide && (pGameSystem->GetGameType() | kSinglePlayerGameTypeMask) ==
                                           kSinglePlayerGameTypeMask;
            if (!bSilent) {
                AudioManager *pAudio = AudioManager.sharedManager;
                if (![pAudio isPlayingVoice]) {
                    [pAudio releaseVoice];
                    SoundEffectManager::GetInstance()->LoadAndSetThemedVoice(kFullComboVoiceId);
                }
            }
        }

        const bool bOwnSide = pGameSystem->GetPlayColor() == nSide;
        const S_VECTOR2 rowBase{0.0f, aRowBaseY[bOwnSide ? 1 : 0]};
        const float flRowRotation = bOwnSide ? 0.0f : kMirrorRotation;

        for (int nBeam = 0; nBeam < kBeamCount; ++nBeam) {
            const float flScaleX =
                CalculateCurveInterpolation(kBeamScaleXPairs[nBeam], kBeamScaleXPairCount, flClock);
            const float flScaleY =
                CalculateCurveInterpolation(kBeamScaleYPairs[nBeam], kBeamScaleYPairCount, flClock);
            const float flAlpha =
                CalculateCurveInterpolation(kBeamAlphaPairs[nBeam], kBeamAlphaPairCount, flClock);
            S_VECTOR2 position = CombineOffset(rowBase, kBeamOffsets[nBeam], !bOwnSide);
            CreateSprite(kBaseBatch,
                         kBeamKindBase + nSide,
                         &position,
                         ScaleToAlpha(flAlpha),
                         flScaleX,
                         flScaleY,
                         flRowRotation);
        }

        for (int nFlare = 0; nFlare < kFlareCount; ++nFlare) {
            const float flScaleX = CalculateCurveValue(&g_aFlareScaleXCurves[nFlare], flClock);
            const float flScaleY = CalculateCurveValue(&g_aFlareScaleYCurves[nFlare], flClock);
            const float flAlpha = CalculateCurveValue(&g_aFlareAlphaCurves[nFlare], flClock);
            S_VECTOR2 position = CombineOffset(rowBase, kFlareOffsets[nFlare], !bOwnSide);
            CreateSprite(kBaseBatch,
                         kFlareKindBase + nSide,
                         &position,
                         ScaleToAlpha(flAlpha),
                         flScaleX,
                         flScaleY,
                         flRowRotation);
        }

        for (int nSpark = 0; nSpark < kSparkCount; ++nSpark) {
            const float flElapsed = flClock - kSparkStartClocks[nSpark];
            const float flFrames = ClockToFrames(flElapsed);
            if (flFrames < 0.0f || flFrames >= kSparkFrameLimit) {
                continue;
            }

            const float flPhase =
                flFrames - static_cast<float>(static_cast<int>(flFrames / kSparkBlinkPeriod)) *
                               kSparkBlinkPeriod;
            const float flAlpha =
                (flPhase >= kSparkBlinkOnFrames) ?
                    0.0f :
                    RampAndClamp(flFrames, kSparkRampMidpoint, kSparkRampFallSpan);

            const float flRise = CalculateCurveValue(&g_aSparkRiseCurves[nSpark], flClock);
            S_VECTOR2 position = CombineOffset(rowBase, kSparkOffsets[nSpark], !bOwnSide);
            position.y = bOwnSide ? (flRise + position.y) : (position.y - flRise);
            const float flRotation = static_cast<float>(
                static_cast<double>(flRowRotation) +
                static_cast<double>(flElapsed / kMillisecondsPerSecond) * kOrbSpinPerSecond);
            CreateSprite(kBaseBatch,
                         kSparkKindBase + nSide,
                         &position,
                         ScaleToAlpha(flAlpha),
                         kUnitScale,
                         kUnitScale,
                         flRotation);
        }

        const S_VECTOR2 aBannerBase[kSideCount] = {
            {0.0f,
             static_cast<float>((g_nPlayfieldNearRowTop + kBannerRowInset) -
                                g_nPlayfieldCentreSplit)},
            {0.0f,
             static_cast<float>((g_nPlayfieldNearRowBottom - kBannerRowInset) -
                                g_nPlayfieldCentreSplit)},
        };
        const float flCentreClock = flClock + kCentreClockBias;
        const bool bCentreMirrored =
            GameSystem::GetGameSystem()->GetGameType() == kVersusGameType && !bOwnSide;
        const float flCentreRotation = bCentreMirrored ? kMirrorRotation : 0.0f;
        const S_VECTOR2 centreBase = aBannerBase[bOwnSide ? 1 : 0];

        const float flBannerAlpha = CalculateCurveValue(&g_aBannerAlphaCurve, flCentreClock);
        S_VECTOR2 bannerPosition = CombineOffset(centreBase, kBannerOffset, bCentreMirrored);
        CreateSprite(kBaseBatch,
                     kBannerKind,
                     &bannerPosition,
                     ScaleToAlpha(flBannerAlpha),
                     kUnitScale,
                     kUnitScale,
                     flCentreRotation);

        for (int nLetter = 0; nLetter < kLetterCount; ++nLetter) {
            const float flScaleY =
                CalculateCurveValue(&g_aLetterScaleYCurves[nLetter], flCentreClock);
            const float flFillAlpha =
                CalculateCurveValue(&g_aLetterFillAlphaCurves[nLetter], flCentreClock);
            S_VECTOR2 position =
                CombineOffset(centreBase, kLetterOffsets[nLetter], bCentreMirrored);
            const int nKind = kLetterKinds[nLetter];
            CreateSprite(kLetterBatch,
                         nKind,
                         &position,
                         ScaleToAlpha(flFillAlpha),
                         kUnitScale,
                         flScaleY,
                         flCentreRotation);
            const float flGlowAlpha =
                CalculateCurveValue(&g_aLetterGlowAlphaCurves[nLetter], flCentreClock);
            CreateSprite(kGlowBatch,
                         nKind,
                         &position,
                         ScaleToAlpha(flGlowAlpha),
                         kUnitScale,
                         kUnitScale,
                         flCentreRotation);
        }

        for (int nSparkle = 0; nSparkle < kSparkleCount; ++nSparkle) {
            const float flFrames = ClockToFrames(flCentreClock - kSparkleStartClocks[nSparkle]);
            const float flScale =
                RampAndClamp(flFrames, kSparkleRampMidpoint, kSparkleRampFallSpan);
            const bool bVisible = flFrames >= 0.0f && flFrames <= kSparkleFrameLimit;
            const float flRotation = static_cast<float>(
                static_cast<double>(flCentreRotation) +
                static_cast<double>(flFrames / kSparkleFrameLimit) * kSparkleSweep);
            S_VECTOR2 position =
                CombineOffset(centreBase, kSparkleOffsets[nSparkle], bCentreMirrored);
            // Out of its window the sparkle is still appended, just fully transparent.
            CreateSprite(kGlowBatch,
                         kSparkleKind,
                         &position,
                         bVisible ? kOpaqueAlpha : 0,
                         flScale,
                         flScale,
                         flRotation);
        }
    }

    for (int nSlot = 0; nSlot < kSpriteSlotCount; ++nSlot) {
        m_apSprites[nSlot]->SetSpriteCount(m_aSpriteCounts[nSlot]);
    }
}
