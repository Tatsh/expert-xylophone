#include "full_combo_classic_layer.h"

#include <cassert>

#include "../Share/bg_layer.h"
#include "../Share/sprite_uv_table.h"
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
#include "vectormath.h"

// The process-wide Classic full-combo layer, created lazily by shared().
static FullComboClassicLayer *g_pFullComboClassicLayer = nullptr; // @ghidraAddress 0x3dd078

// The shared sprite-UV atlas the descriptor entries index by uvIndex.
extern const SpriteUvEntry g_aSpriteUvTable[]; // @ghidraAddress 0x2efcc8

// The Classic full-combo sprite-type descriptor table (declared in
// full_combo_classic_sprite_table.h): read-only ROM data transcribed from the binary at 0x302bf8.
const ClassicFullComboSpriteType g_aClassicFullComboSpriteTypes[kClassicFullComboSpriteTypeCount] =
    {
        // {anchorX, anchorY, sizeW, sizeH, uvIndex}
        {15.0f, 24.0f, 30.0f, 48.0f, 13},    // 0
        {19.0f, 24.0f, 38.0f, 48.0f, 14},    // 1
        {15.0f, 24.0f, 30.0f, 48.0f, 15},    // 2
        {27.0f, 24.0f, 54.0f, 48.0f, 16},    // 3
        {29.0f, 24.0f, 58.0f, 48.0f, 17},    // 4
        {28.0f, 24.0f, 56.0f, 48.0f, 18},    // 5
        {18.0f, 24.0f, 36.0f, 48.0f, 19},    // 6
        {4.0f, 24.0f, 8.0f, 48.0f, 20},      // 7
        {234.0f, 39.0f, 468.0f, 78.0f, 21},  // 8
        {62.0f, 200.0f, 124.0f, 200.0f, 22}, // 9
        {62.0f, 200.0f, 124.0f, 200.0f, 23}, // 10
        {22.0f, 22.0f, 44.0f, 44.0f, 24},    // 11
        {22.0f, 22.0f, 44.0f, 44.0f, 25},    // 12
        {32.0f, 106.0f, 64.0f, 106.0f, 26},  // 13
        {32.0f, 106.0f, 64.0f, 106.0f, 27},  // 14
        {14.0f, 14.0f, 28.0f, 28.0f, 12},    // 15
};

namespace {

// The atlas the full-combo sprites draw from (@ghidraAddress 0x3ceaa8).
constexpr const char *kTextureName = "00_texture/gm_parts2";

// The sprite capacity each of the layer's instancers is built with.
constexpr unsigned int kSlotCapacity = 0x40;

// The additive blend-mode identifier the sprites use.
constexpr int kAdditiveBlendMode = 1;

// The two texture-environment parameter slots the builder seeds (to 1 each), and that value.
constexpr int kTexParamSlotHigh = 1;
constexpr int kTexParamSlotLow = 0;
constexpr int kTexParamEnabled = 1;

} // namespace

/** @ghidraAddress 0x10f280 */
FullComboClassicLayer::FullComboClassicLayer() = default;

/** @ghidraAddress 0x10f2dc */
FullComboClassicLayer *FullComboClassicLayer::shared() {
    if (g_pFullComboClassicLayer == nullptr) {
        // The binary allocates the raw 0x50-byte object and runs the constructor, which chains the
        // base-layer constructor and zero-clears the layer's state.
        g_pFullComboClassicLayer = new FullComboClassicLayer();
    }
    return g_pFullComboClassicLayer;
}

/** @ghidraAddress 0x10f32c */
void FullComboClassicLayer::InitializeBackgroundSprites() {
    if (m_bBuilt) {
        return;
    }

    // The sprites hang beneath the shared background layer's render object rather than the global
    // scene root.
    BgLayer *pBackgroundLayer = BgLayer::GetBackgroundLayer();
    ne::C_RENDER *pParent = pBackgroundLayer->GetBackgroundRenderObject();

    m_pTexture = ne::C_TEXTURE::FindOrLoadCached(kTextureName);

    // Build one sprite instancer per slot, attach it under the background render object, make it
    // visible, bind the atlas, clear its sprite count, put it in additive blend, and enable its two
    // texture-environment parameters.
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

    // Skip the sprite when the object type's batch is already full.
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

// The number of play sides the effect can run on, one per player colour.
constexpr int kSideCount = 2;

// The animation clock past which an effect record retires (@ghidraAddress 0x2feff0), and the clock
// at which it fires its themed voice cue exactly once (@ghidraAddress 0x2feff4).
constexpr float kEffectDuration = 2000.0f;
constexpr float kVoiceCueClock = 500.0f;

// The bias the four centre-anchored groups sample their curves at (@ghidraAddress 0x2feff8): they
// run half a second behind the lane groups.
constexpr float kCentreClockBias = -500.0f;

// The themed voice cue the effect announces itself with.
constexpr int kFullComboVoiceId = 9;

// The game types that leave the rival's side silent. The binary's bitwise test,
// (gameType | 2) == 2, admits exactly game types 0 and 2 — the single-player modes, which have no
// rival to announce a full combo to.
constexpr int kSinglePlayerGameTypeMask = 2;

// The game type whose centre-anchored sprites mirror onto the other side.
constexpr int kVersusGameType = 1;

// The half-turn rotation a mirrored side's sprites take, in radians (@ghidraAddress 0x2fe894). The
// orbiting sparks spin a further half turn per second about it, at double precision
// (@ghidraAddress 0x2f85a0), and the trailing sparkles sweep a quarter turn backwards over their
// life (@ghidraAddress 0x3025b0).
constexpr float kMirrorRotation = 3.1415927f;
constexpr double kOrbSpinPerSecond = 3.141592653589793;
constexpr double kSparkleSweep = -1.5707963267948966;

// The clock-to-frame conversion both timed groups gate on: a millisecond clock scaled by the frame
// rate (@ghidraAddress 0x2f8578) over a second (@ghidraAddress 0x2f8540).
constexpr float kFrameRate = 60.0f;
constexpr float kMillisecondsPerSecond = 1000.0f;

// The unit-interval-to-byte alpha scale (@ghidraAddress 0x2eed00), the scale the untimed groups draw
// at, and the fully opaque alpha the sparkles take while they are in range.
constexpr float kAlphaScale = 255.0f;
constexpr float kUnitScale = 1.0f;
constexpr unsigned int kOpaqueAlpha = 255;

// The three batches the effect emits into: the lane beams, flares, sparks, and centre banner; the
// letter fills; and the letter glow pass together with the trailing sparkles.
constexpr int kBaseBatch = 0;
constexpr int kLetterBatch = 1;
constexpr int kGlowBatch = 2;

// The sprite kinds each group draws. The beams, flares, and sparks come in a per-side pair, so the
// side index is added to the base kind; the banner and sparkle kinds are shared.
constexpr int kBeamKindBase = 9;
constexpr int kSparkKindBase = 11;
constexpr int kFlareKindBase = 13;
constexpr int kBannerKind = 8;
constexpr int kSparkleKind = 15;

// The sprite count of each group.
constexpr int kBeamCount = 6;
constexpr int kFlareCount = 2;
constexpr int kSparkCount = 10;
constexpr int kLetterCount = 10;
constexpr int kSparkleCount = 10;

// The spark group's frame window (@ghidraAddress 0x302488), within which it blinks on for the first
// three frames of every five, and the rise-then-fall ramp its alpha follows.
constexpr float kSparkFrameLimit = 45.0f;
constexpr float kSparkBlinkPeriod = 5.0f;
constexpr float kSparkBlinkOnFrames = 3.0f;
constexpr float kSparkRampMidpoint = 15.0f;
constexpr float kSparkRampFallSpan = -30.0f;

// The sparkle group's frame window and the ramp its scale follows.
constexpr float kSparkleFrameLimit = 30.0f;
constexpr float kSparkleRampMidpoint = 10.0f;
constexpr float kSparkleRampFallSpan = -20.0f;

// How far the centre banner is inset from each near lane row.
constexpr int kBannerRowInset = 232;

// The banner's own offset from that row, a single pixel to the left.
constexpr S_VECTOR2 kBannerOffset{-1.0f, 0.0f};

// The six beam layers' offsets from the side's lane row (@ghidraAddress 0x302490).
constexpr S_VECTOR2 kBeamOffsets[kBeamCount] = {
    {214.0f, 0.0f},
    {0.0f, 0.0f},
    {-214.0f, 0.0f},
    {214.0f, 0.0f},
    {0.0f, 0.0f},
    {-214.0f, 0.0f},
};

// The two column flares carry no offset of their own: the binary zeroes this local array and still
// runs it through the vector combine.
constexpr S_VECTOR2 kFlareOffsets[kFlareCount] = {};

// The ten orbiting sparks' offsets from the side's lane row (@ghidraAddress 0x3024c0).
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

// The ten letters' offsets from the centre banner (@ghidraAddress 0x302510).
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

// The ten trailing sparkles' offsets from the centre banner (@ghidraAddress 0x302560).
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

// The letter kinds, indexing the sprite-type table (@ghidraAddress 0x302ba8). Read against that
// table's glyph widths the ten entries spell FULLCOMBO!, which is why kinds 2 and 4 each appear
// twice.
constexpr int kLetterKinds[kLetterCount] = {0, 1, 2, 2, 3, 4, 5, 6, 4, 7};

// Each spark's start clock, in milliseconds (@ghidraAddress 0x3027f0).
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

// Each sparkle's start clock, in milliseconds (@ghidraAddress 0x302bd0).
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

// The keyframe-pair count of each of the curves below.
constexpr int kBeamScaleXPairCount = 2;
constexpr int kBeamScaleYPairCount = 4;
constexpr int kBeamAlphaPairCount = 3;
constexpr int kSparkRisePairCount = 2;
constexpr int kBannerAlphaPairCount = 4;
constexpr int kLetterScaleYPairCount = 2;
constexpr int kLetterFillAlphaPairCount = 4;
constexpr int kLetterGlowAlphaPairCount = 3;

// The six beam layers' horizontal scale over the effect clock (@ghidraAddress 0x3025b8).
constexpr float kBeamScaleXPairs[kBeamCount][kBeamScaleXPairCount * 2] = {
    {0.0f, 2.0f, 1250.0f, 2.0f},
    {0.0f, 1.465f, 1250.0f, 1.465f},
    {0.0f, 2.0f, 1250.0f, 2.0f},
    {0.0f, 2.0f, 1250.0f, 2.0f},
    {0.0f, 1.465f, 1250.0f, 1.465f},
    {0.0f, 2.0f, 1250.0f, 2.0f},
};

// The six beam layers' vertical scale over the effect clock (@ghidraAddress 0x302618). The trailing
// three layers grow taller and never fully collapse.
constexpr float kBeamScaleYPairs[kBeamCount][kBeamScaleYPairCount * 2] = {
    {0.0f, 0.0f, 133.33333f, 3.0f, 500.0f, 3.0f, 1250.0f, 0.0f},
    {0.0f, 0.0f, 133.33333f, 3.0f, 500.0f, 3.0f, 1250.0f, 0.0f},
    {0.0f, 0.0f, 133.33333f, 3.0f, 500.0f, 3.0f, 1250.0f, 0.0f},
    {0.0f, 0.0f, 133.33333f, 4.0f, 500.0f, 4.0f, 1250.0f, 2.0f},
    {0.0f, 0.0f, 133.33333f, 4.0f, 500.0f, 4.0f, 1250.0f, 2.0f},
    {0.0f, 0.0f, 133.33333f, 4.0f, 500.0f, 4.0f, 1250.0f, 2.0f},
};

// The six beam layers' alpha over the effect clock (@ghidraAddress 0x3026d8). The trailing three
// layers hold a constant half alpha instead of flashing.
constexpr float kBeamAlphaPairs[kBeamCount][kBeamAlphaPairCount * 2] = {
    {0.0f, 0.0f, 133.33333f, 1.0f, 500.0f, 0.0f},
    {0.0f, 0.0f, 133.33333f, 1.0f, 500.0f, 0.0f},
    {0.0f, 0.0f, 133.33333f, 1.0f, 500.0f, 0.0f},
    {0.0f, 0.5f, 500.0f, 0.5f, 1250.0f, 0.0f},
    {0.0f, 0.5f, 500.0f, 0.5f, 1250.0f, 0.0f},
    {0.0f, 0.5f, 500.0f, 0.5f, 1250.0f, 0.0f},
};

// The two column flares' curves. Unlike every other group these two entries do not share a keyframe
// count, so each pair block stands alone (@ghidraAddress 0x302768 through 0x3027e8).
constexpr float kFlareScaleXNearPairs[] = {0.0f, 2.7f, 133.33333f, 2.7f, 1250.0f, 0.0f};
constexpr float kFlareScaleXFarPairs[] = {0.0f, 12.0f, 1250.0f, 12.0f};
constexpr float kFlareScaleYNearPairs[] = {0.0f, 0.0f, 133.33333f, 3.0f, 1250.0f, 7.0f};
constexpr float kFlareScaleYFarPairs[] = {
    0.0f, 0.0f, 133.33333f, 2.0f, 500.0f, 2.0f, 1250.0f, 0.0f};
constexpr float kFlareAlphaNearPairs[] = {0.0f, 0.5f, 1250.0f, 0.5f};
constexpr float kFlareAlphaFarPairs[] = {0.0f, 1.0f, 500.0f, 1.0f, 1250.0f, 0.0f};

// Each spark's vertical rise over the effect clock (@ghidraAddress 0x302818). The curve starts at
// the spark's own start clock, so it is sampled with the raw clock rather than the elapsed time.
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

// The centre banner's alpha over the centre clock (@ghidraAddress 0x3028b8).
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

// Each letter's vertical scale over the centre clock (@ghidraAddress 0x3028d8): a staggered
// third-of-a-frame drop-in, one letter after another.
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

// Each letter's fill alpha over the centre clock (@ghidraAddress 0x302978): the same stagger, held
// until the whole word fades out together.
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

// Each letter's glow alpha over the centre clock (@ghidraAddress 0x302ab8): a single bloom that
// fires as the letter lands and decays well before the fill does.
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

// The curve arrays the groups above sample, each pairing a keyframe count with one of the pair
// blocks. @ghidraAddress 0x35ce10, 0x35ce30, 0x35ce50, 0x35ce70, 0x35cf10, 0x35cf20, 0x35cfc0, and
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

// Converts a millisecond clock into the frame count the two timed groups gate on.
inline float ClockToFrames(float flClock) {
    return flClock * kFrameRate / kMillisecondsPerSecond;
}

// The truncation the binary applies before handing a curve value to CreateSprite: the scaled value
// is rounded towards zero as a signed integer, then widened.
inline unsigned int ScaleToAlpha(float flValue) {
    return static_cast<unsigned int>(static_cast<int>(flValue * kAlphaScale));
}

// The rise-then-fall ramp the spark and sparkle groups share: it climbs to one over @p flMidpoint
// frames, then falls away over @p flFallSpan (a negative span), and clamps into the unit interval.
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

// Combines a group's offset into its base position, mirroring it through the anchor when the side is
// drawn flipped.
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

    // Each lane row sits on the near lane's slope, scaled by the sheet's half inset. The binary
    // re-reads the game system on every iteration of this two-element loop.
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

        // Announce the full combo once, half a second in. The rival's side stays silent in the
        // single-player modes, where there is no rival to announce it to.
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

        // The lane-anchored groups mirror on whichever side is not the local player's.
        const bool bOwnSide = pGameSystem->GetPlayColor() == nSide;
        const S_VECTOR2 rowBase{0.0f, aRowBaseY[bOwnSide ? 1 : 0]};
        const float flRowRotation = bOwnSide ? 0.0f : kMirrorRotation;

        // The six stacked beam layers rising off the lane row.
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

        // The two column flares, drawn on the lane row itself.
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

        // The orbiting sparks: each waits for its own start clock, then rises along its curve while
        // spinning a half turn per second, blinking on for three frames in every five.
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

        // The centre banner spans both near lane rows, inset from each and shifted by the field's
        // centre split. Everything anchored on it runs half a second behind the lane groups, and
        // mirrors only in the versus game type.
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

        // The FULLCOMBO! letters, each dropping in on its own stagger and taking a second, brighter
        // bloom pass in the glow batch.
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

        // The trailing sparkle sweep: each pops in on its own stagger, swells then shrinks, and
        // turns a quarter of the way backwards across its thirty-frame life.
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
