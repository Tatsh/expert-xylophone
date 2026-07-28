#include "colette_theme_layer.h"

#include "../Share/bg_layer.h"
#include "ScoreTracker.h"
#include "curve.h"
#include "engineglobals.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#include "s_vector2.h"
#include "sprite_uv_table.h"

// The process-wide Colette-theme layer, created lazily by shared().
static ColetteThemeLayer *g_pColetteThemeLayer = nullptr; // @ghidraAddress 0x3def58

namespace {

// The full-combo atlases the layer loads (@ghidraAddress 0x3ceaa8 and 0x3ceaf0). The first and last
// texture fields share the gm_parts2 atlas.
constexpr const char *kPartsTextureName = "00_texture/gm_parts2";
constexpr const char *kEffectTextureName = "00_texture/ti_parts_eff";

// The per-slot sprite-instancer capacities (@ghidraAddress 0x30e84c).
constexpr unsigned int kSlotCapacities[] = {1, 100, 100, 2};

// The per-slot texture-field selector (@ghidraAddress 0x30e85c): the index into the layer's three
// texture fields for each textured slot. Slot 0 binds no texture, so its entry is unused.
constexpr int kSlotTextureField[] = {-1, 0, 1, 2};

// The slot that receives additive blend mode, and that mode's identifier.
constexpr int kAdditiveBlendSlot = 3;
constexpr int kAdditiveBlendMode = 1;

// The layer's layout size the constructor seeds.
constexpr float kLayoutWidth = 384.0f;
constexpr float kLayoutHeight = 680.0f;

// The grade-display defaults: single-side, both best-rank flags four.
constexpr int kDefaultSideCount = 1;
constexpr int kGradeValueDefault = 4;

// The grade reveal-channel value that holds the display fully shown, the clock's off-screen start,
// and the two reveal-duration thresholds.
constexpr float kGradeChannelFull = 1.0f;
constexpr float kGradeClockStart = -500.0f;
constexpr float kGradeRevealDurationDual = 3000.0f;
constexpr float kGradeRevealDurationSingle = 5000.0f;

// The maximum value of an opaque colour channel.
constexpr unsigned int kColorMax = 255;

// One full-combo sprite-slot descriptor: the batch-kind selector, the sprite anchor and pixel size,
// and the shared UV atlas frame. The 24-byte stride matches the binary.
struct FcSpriteDescriptor {
    int nBatchKind;    // +0x00: the batch-kind selector (indexes the batch-index table).
    float flAnchorX;   // +0x04: the sprite's anchor X.
    float flAnchorY;   // +0x08: the sprite's anchor Y.
    float flSizeX;     // +0x0c: the sprite's pixel width.
    float flSizeY;     // +0x10: the sprite's pixel height.
    int nUvFrameIndex; // +0x14: the frame into the shared sprite UV atlas.
};

// The full-combo sprite-slot descriptor table, indexed by the sprite slot the caller passes.
// Read-only ROM data embedded in the binary. @ghidraAddress 0x30f494
constexpr FcSpriteDescriptor kFcSpriteDescriptors[] = {
    {4, 384.0f, 512.0f, 768.0f, 1024.0f, 0x0}, {0, 23.0f, 23.5f, 46.0f, 47.0f, 0x67},
    {0, 34.5f, 40.5f, 69.0f, 81.0f, 0x4c},     {0, 31.0f, 40.5f, 62.0f, 81.0f, 0x4d},
    {0, 33.0f, 40.5f, 66.0f, 81.0f, 0x4e},     {0, 39.0f, 40.5f, 78.0f, 81.0f, 0x4f},
    {0, 33.5f, 40.5f, 67.0f, 81.0f, 0x50},     {0, 25.5f, 40.5f, 51.0f, 81.0f, 0x51},
    {0, 32.0f, 37.5f, 64.0f, 75.0f, 0x52},     {0, 38.5f, 37.5f, 77.0f, 75.0f, 0x53},
    {0, 7.5f, 37.5f, 15.0f, 75.0f, 0x54},      {0, 31.0f, 37.5f, 62.0f, 75.0f, 0x55},
    {0, 32.5f, 37.5f, 65.0f, 75.0f, 0x56},     {0, 33.5f, 37.5f, 67.0f, 75.0f, 0x57},
    {0, 11.5f, 12.5f, 23.0f, 25.0f, 0x58},     {0, 11.5f, 12.5f, 23.0f, 25.0f, 0x58},
    {0, 11.5f, 12.5f, 23.0f, 25.0f, 0x58},     {0, 41.0f, 41.0f, 82.0f, 82.0f, 0x59},
    {2, 50.0f, 50.0f, 100.0f, 100.0f, 0x5b},   {2, 50.0f, 50.0f, 100.0f, 100.0f, 0x5c},
    {0, 53.0f, 53.0f, 106.0f, 106.0f, 0x5a},   {0, 38.0f, 38.0f, 76.0f, 76.0f, 0x68},
    {0, 38.0f, 38.0f, 76.0f, 76.0f, 0x68},     {0, 38.0f, 38.0f, 76.0f, 76.0f, 0x68},
};

// The batch-kind to sprite-instancer-index table: maps a descriptor's batch kind to the batch slot
// it draws into. @ghidraAddress 0x30f6d4
constexpr unsigned int kFcBatchIndex[] = {1, 2, 3, 4, 0};

// The sprite slot whose glyph draws black (the drop-shadow copy); every other slot draws white.
constexpr unsigned int kFcShadowSlot = 0;

// The "miss"/lower-rank full-combo burst: the six animated sprites and the sizes of their curves,
// the sprite-slot base they emit at, and the constants placing them.
constexpr int kMissSpriteCount = 6;
constexpr int kMissScaleCurvePairs = 0xe;
constexpr int kMissScaleCurveFloats = kMissScaleCurvePairs * 2;
constexpr int kMissRotCurvePairs = 2;
constexpr int kMissRotCurveFloats = kMissRotCurvePairs * 2;
constexpr int kBannerCurvePairs4 = 4;
constexpr int kBannerCurvePairs2 = 2;
constexpr unsigned int kMissSpriteSlotBase = 8; // the six sprites emit at slots 8..13.
constexpr unsigned int kMissBannerSlot = 1;     // the banner emits at slot 1.

// The single-player layout constants: the reference line the base Y sits below (@ghidraAddress
// 0x30e800), the second side's downward shift and the first side's Y reflection base (@ghidraAddress
// 0x301f78, 0x3052c0), the half-turn rotation for the mirrored side (@ghidraAddress 0x2fe894), and
// the unit-interval-to-alpha scale (@ghidraAddress 0x2eed00).
constexpr float kMissReferenceY = 663.0f;
constexpr float kMissSecondSideShiftY = 200.0f;
constexpr float kMissFirstSideReflectY = -200.0f;
constexpr float kMissMirrorRotation = 3.1415927f;
constexpr float kFcAlphaByteScale = 255.0f;

// The single-side display flag value (m_nSideCount == 1) that triggers the mirror/shift layout.
constexpr int kSingleSide = 1;
// The second player side, which shifts down rather than mirrors.
constexpr int kSecondSide = 1;

// The six sprites' fixed X columns (@ghidraAddress 0x3defa0, seeded once at first use). Their shared
// Y is the reference line less the layout height.
constexpr float kMissSpriteX[kMissSpriteCount] = {-177.0f, -106.0f, -38.0f, 40.0f, 118.0f, 185.0f};

// The rank-medal full-combo burst: the seven medal sprites, their curve sizes, the slot base they
// emit at, and the reveal-timer window they play within.
constexpr int kRankMedalCount = 7;
constexpr int kRankScaleCurvePairs = 9;
constexpr int kRankScaleCurveFloats = kRankScaleCurvePairs * 2;
constexpr int kRankAlphaCurvePairs = 3;
constexpr int kRankAlphaCurveFloats = kRankAlphaCurvePairs * 2;
constexpr int kRankRotCurvePairs = 2;
constexpr int kRankRotCurveFloats = kRankRotCurvePairs * 2;
constexpr int kRankOffsetCurvePairs = 3;
constexpr int kRankOffsetCurveFloats = kRankOffsetCurvePairs * 2;
constexpr unsigned int kRankSpriteSlotBase = 0x11; // the medals emit at slots 0x11..0x17.

// The reveal-timer window the rank medals animate within, and the offset applied to the timer
// (@ghidraAddress 0x305220 start, 0x30522c end, 0x305224 offset).
constexpr float kRankWindowStart = 3166.6667f;
constexpr float kRankWindowEnd = 4833.3335f;
constexpr float kRankTimerOffset = -3166.6667f;

// The second side's downward Y shift and the first side's Y reflection base for the mirror layout
// (@ghidraAddress 0x2ec6b0, 0x2fcfec), and the sound the medals play on first entry.
constexpr float kRankSecondSideShiftY = 100.0f;
constexpr float kRankFirstSideReflectY = -100.0f;
constexpr int kRankSoundEffect = 10;

// The half-turn the mirrored side adds to a medal's rotation, in double precision as the binary
// computes it (@ghidraAddress 0x2f85a0).
constexpr double kRankMirrorRotation = 3.141592653589793;

// One rank medal's fixed placement: its X column and its base Y (before the layout height is
// subtracted), from the load-once medal table (@ghidraAddress 0x3def60).
struct RankMedalPlacement {
    float flX;
    float flBaseY;
};
constexpr RankMedalPlacement kRankMedalPlacement[kRankMedalCount] = {
    {-177.0f, 653.0f},
    {-184.0f, 654.0f},
    {-184.0f, 654.0f},
    {-177.0f, 653.0f},
    {-142.0f, 660.0f},
    {-151.0f, 747.0f},
    {-210.0f, 662.0f},
};

// The two medal slots that draw only for one colour variant: slot 1 skips the base variant, slot 2
// skips the non-base variant.
constexpr int kRankMedalVariantSkip1 = 1;
constexpr int kRankMedalVariantSkip2 = 2;

// @ghidraAddress 0x30e924
constexpr float kRankScaleXCurve[kRankMedalCount][kRankScaleCurveFloats] = {
    {0f,
     0f,
     166.66667f,
     1.5f,
     250f,
     1f,
     500f,
     5f,
     500f,
     5f,
     500f,
     5f,
     500f,
     5f,
     500f,
     5f,
     500f,
     5f},
    {250f,
     0f,
     416.66666f,
     -1.5f,
     1250f,
     -2f,
     1250f,
     -2f,
     1250f,
     -2f,
     1250f,
     -2f,
     1250f,
     -2f,
     1250f,
     -2f,
     1250f,
     -2f},
    {250f,
     0f,
     416.66666f,
     -1.5f,
     1250f,
     -2f,
     1250f,
     -2f,
     1250f,
     -2f,
     1250f,
     -2f,
     1250f,
     -2f,
     1250f,
     -2f,
     1250f,
     -2f},
    {250f,
     0f,
     416.66666f,
     1.1f,
     500f,
     1f,
     583.3333f,
     1.05f,
     633.3333f,
     1f,
     683.3333f,
     1.02f,
     716.6667f,
     1f,
     750f,
     1.02f,
     783.3333f,
     1f},
    {250f,
     0f,
     916.6667f,
     0.5f,
     916.6667f,
     0.5f,
     916.6667f,
     0.5f,
     916.6667f,
     0.5f,
     916.6667f,
     0.5f,
     916.6667f,
     0.5f,
     916.6667f,
     0.5f,
     916.6667f,
     0.5f},
    {250f,
     0f,
     416.66666f,
     0.4f,
     916.6667f,
     0.7f,
     916.6667f,
     0.7f,
     916.6667f,
     0.7f,
     916.6667f,
     0.7f,
     916.6667f,
     0.7f,
     916.6667f,
     0.7f,
     916.6667f,
     0.7f},
    {250f,
     0f,
     416.66666f,
     0.8f,
     916.6667f,
     1f,
     916.6667f,
     1f,
     916.6667f,
     1f,
     916.6667f,
     1f,
     916.6667f,
     1f,
     916.6667f,
     1f,
     916.6667f,
     1f},
};

// @ghidraAddress 0x30eb1c
constexpr float kRankScaleYCurve[kRankMedalCount][kRankScaleCurveFloats] = {
    {0f,
     0f,
     166.66667f,
     1.5f,
     250f,
     1f,
     500f,
     1f,
     500f,
     1f,
     500f,
     1f,
     500f,
     1f,
     500f,
     1f,
     500f,
     1f},
    {250f,
     0f,
     416.66666f,
     -1.5f,
     1250f,
     -1.33f,
     1250f,
     -1.33f,
     1250f,
     -1.33f,
     1250f,
     -1.33f,
     1250f,
     -1.33f,
     1250f,
     -1.33f,
     1250f,
     -1.33f},
    {250f,
     0f,
     416.66666f,
     -1.5f,
     1250f,
     -1.33f,
     1250f,
     -1.33f,
     1250f,
     -1.33f,
     1250f,
     -1.33f,
     1250f,
     -1.33f,
     1250f,
     -1.33f,
     1250f,
     -1.33f},
    {250f,
     0f,
     416.66666f,
     1.1f,
     500f,
     1f,
     583.3333f,
     1.05f,
     633.3333f,
     1f,
     683.3333f,
     1.02f,
     716.6667f,
     1f,
     750f,
     1.02f,
     783.3333f,
     1f},
    {250f,
     0f,
     916.6667f,
     0.5f,
     916.6667f,
     0.5f,
     916.6667f,
     0.5f,
     916.6667f,
     0.5f,
     916.6667f,
     0.5f,
     916.6667f,
     0.5f,
     916.6667f,
     0.5f,
     916.6667f,
     0.5f},
    {250f,
     0f,
     416.66666f,
     0.4f,
     916.6667f,
     0.7f,
     916.6667f,
     0.7f,
     916.6667f,
     0.7f,
     916.6667f,
     0.7f,
     916.6667f,
     0.7f,
     916.6667f,
     0.7f,
     916.6667f,
     0.7f},
    {250f,
     0f,
     416.66666f,
     0.8f,
     916.6667f,
     1f,
     916.6667f,
     1f,
     916.6667f,
     1f,
     916.6667f,
     1f,
     916.6667f,
     1f,
     916.6667f,
     1f,
     916.6667f,
     1f},
};

// @ghidraAddress 0x30ed14
constexpr float kRankAlphaCurve[kRankMedalCount][kRankAlphaCurveFloats] = {
    {250f, 1f, 500f, 0f, 500f, 0f},
    {250f, 1f, 1250f, 0f, 1250f, 0f},
    {250f, 1f, 1250f, 0f, 1250f, 0f},
    {0f, 1f, 16.666666f, 1f, 16.666666f, 1f},
    {400f, 0f, 416.66666f, 1f, 916.6667f, 0f},
    {400f, 0f, 416.66666f, 1f, 916.6667f, 0f},
    {400f, 0f, 416.66666f, 1f, 916.6667f, 0f},
};

// @ghidraAddress 0x30edbc
constexpr float kRankRotCurve[kRankMedalCount][kRankRotCurveFloats] = {
    {0f, 0f, 16.666666f, 0f},
    {250f, 0f, 1250f, 0.7853982f},
    {250f, 0f, 1250f, 0.7853982f},
    {0f, 0f, 16.666666f, 0f},
    {0f, 0f, 16.666666f, 0f},
    {0f, 0f, 16.666666f, 0f},
    {0f, 0f, 16.666666f, 0f},
};

// @ghidraAddress 0x30e87c
constexpr float kRankOffsetYCurve[kRankMedalCount][kRankOffsetCurveFloats] = {
    {0f, 0f, 16.666666f, 0f, 16.666666f, 0f},
    {0f, 0f, 16.666666f, 0f, 16.666666f, 0f},
    {0f, 0f, 16.666666f, 0f, 16.666666f, 0f},
    {0f, 0f, 16.666666f, 0f, 16.666666f, 0f},
    {250f, 0f, 916.6667f, -30f, 916.6667f, -30f},
    {250f, 0f, 416.66666f, -50f, 916.6667f, -70f},
    {250f, 0f, 416.66666f, -30f, 916.6667f, -50f},
};

// The six per-sprite scale curves (14 {time, value} pairs each). @ghidraAddress 0x30ee2c
constexpr float kMissScaleCurve[kMissSpriteCount][kMissScaleCurveFloats] = {
    {350f,       0f,    516.6667f, 1.1f, 600f,       1f,    683.3333f,  1.05f, 733.3333f,  1f,
     783.3333f,  1.02f, 816.6667f, 1f,   850f,       1.02f, 883.3333f,  1f,    1066.6666f, 1f,
     1133.3334f, 1.02f, 1200f,     1f,   1266.6666f, 1.02f, 1316.6666f, 1f},
    {300f,       0f,    466.66666f, 1.1f, 550f,       1f,    633.3333f,  1.05f, 683.3333f,  1f,
     733.3333f,  1.02f, 766.6667f,  1f,   800f,       1.02f, 833.3333f,  1f,    1116.6666f, 1f,
     1183.3334f, 1.02f, 1250f,      1f,   1316.6666f, 1.02f, 1366.6666f, 1f},
    {250f,       0f,    416.66666f, 1.1f, 500f,       1f,    583.3333f,  1.05f, 633.3333f,  1f,
     683.3333f,  1.02f, 716.6667f,  1f,   750f,       1.02f, 783.3333f,  1f,    1166.6666f, 1f,
     1233.3334f, 1.02f, 1300f,      1f,   1366.6666f, 1.02f, 1416.6666f, 1f},
    {250f,       0f,    416.66666f, 1.1f, 500f,       1f,    583.3333f,  1.05f, 633.3333f,  1f,
     683.3333f,  1.02f, 716.6667f,  1f,   750f,       1.02f, 783.3333f,  1f,    1216.6666f, 1f,
     1283.3334f, 1.02f, 1350f,      1f,   1416.6666f, 1.02f, 1466.6666f, 1f},
    {300f,       0f,    466.66666f, 1.1f, 550f,       1f,    633.3333f,  1.05f, 683.3333f,  1f,
     733.3333f,  1.02f, 766.6667f,  1f,   800f,       1.02f, 833.3333f,  1f,    1266.6666f, 1f,
     1333.3334f, 1.02f, 1400f,      1f,   1466.6666f, 1.02f, 1516.6666f, 1f},
    {350f,       0f,    516.6667f, 1.1f, 600f,       1f,    683.3333f,  1.05f, 733.3333f,  1f,
     783.3333f,  1.02f, 816.6667f, 1f,   850f,       1.02f, 883.3333f,  1f,    1316.6666f, 1f,
     1383.3334f, 1.02f, 1450f,     1f,   1516.6666f, 1.02f, 1566.6666f, 1f},
};

// The six per-sprite rotation curves (2 {time, value} pairs each). @ghidraAddress 0x30f0cc
constexpr float kMissRotCurve[kMissSpriteCount][kMissRotCurveFloats] = {
    {2000f, 1f, 2333.3333f, 0f},
    {2000f, 1f, 2333.3333f, 0f},
    {2000f, 1f, 2333.3333f, 0f},
    {2000f, 1f, 2333.3333f, 0f},
    {2000f, 1f, 2333.3333f, 0f},
    {2000f, 1f, 2333.3333f, 0f},
};

// The banner sprite's scale-X, scale-Y, and alpha curves. @ghidraAddress 0x30f12c/0x30f14c/0x30f16c
constexpr float kBannerScaleXCurve[] = {0f, 0f, 166.66667f, 1.5f, 250f, 1f, 500f, 5f};
constexpr float kBannerScaleYCurve[] = {0f, 0f, 166.66667f, 1.5f, 250f, 1f, 500f, 1.5f};
constexpr float kBannerAlphaCurve[] = {250f, 1f, 500f, 0f};
} // namespace

/** @ghidraAddress 0x187484 */
ColetteThemeLayer::ColetteThemeLayer() {
    // The base constructor and the zero-initialised members clear the layer; the constructor then
    // seeds the layout size, the single-side default, and the two best-rank flag slots.
    m_flWidth = kLayoutWidth;
    m_flHeight = kLayoutHeight;
    m_nSideCount = kDefaultSideCount;
    for (int &nValue : m_aGradeValues) {
        nValue = kGradeValueDefault;
    }
}

/** @ghidraAddress 0x18751c */
ColetteThemeLayer *ColetteThemeLayer::shared() {
    if (g_pColetteThemeLayer == nullptr) {
        // The binary allocates the raw 0x98-byte object and runs the constructor, which chains the
        // base-layer constructor and seeds the layer's state.
        g_pColetteThemeLayer = new ColetteThemeLayer();
    }
    return g_pColetteThemeLayer;
}

/** @ghidraAddress 0x18756c */
void ColetteThemeLayer::CreateFcEffectSprites() {
    if (m_bBuilt) {
        return;
    }

    // The sprites hang beneath the shared background layer's render object rather than the global
    // scene root.
    BgLayer *pBackgroundLayer = BgLayer::GetBackgroundLayer();
    ne::C_RENDER *pParent = pBackgroundLayer->GetBackgroundRenderObject();

    m_pPartsTexture = ne::C_TEXTURE::FindOrLoadCached(kPartsTextureName);
    m_pEffectTexture = ne::C_TEXTURE::FindOrLoadCached(kEffectTextureName);
    m_pPartsTexture2 = ne::C_TEXTURE::FindOrLoadCached(kPartsTextureName);

    ne::C_TEXTURE *const apTextureFields[] = {m_pPartsTexture, m_pEffectTexture, m_pPartsTexture2};

    // Build one sprite instancer per slot, attach it under the background render object, and make it
    // visible. The first slot binds no texture; the rest bind their mapped atlas. Seed each slot's
    // sprite count and flag additive blend on the last slot.
    for (int nSlot = 0; nSlot < kSpriteSlotCount; ++nSlot) {
        ne::C_SPRITE_INSTANCING_2D *pSprite = ne::CreateWorldSpriteBatch(kSlotCapacities[nSlot]);
        pParent->AttachChild(pSprite);
        pSprite->SetVisible(true);
        if (nSlot != 0) {
            pSprite->SetRefCountedMember(apTextureFields[kSlotTextureField[nSlot]]);
        }
        pSprite->SetSpriteCount(m_aSpriteCounts[nSlot]);
        if (nSlot == kAdditiveBlendSlot) {
            pSprite->SetBlendMode(kAdditiveBlendMode);
        }
        m_apSprites[nSlot] = pSprite;
    }

    m_bBuilt = true;
}

/** @ghidraAddress 0x187690 */
void ColetteThemeLayer::ResetGradeDisplayState() {
    // Seed the reveal channel to hold a full value, park the clock off-screen, arm the display, and
    // load the per-side best-rank flags.
    m_gradeChannel.SetStart(kGradeChannelFull);
    m_gradeChannel.SetEnd(kGradeChannelFull);
    m_gradeChannel.SetDuration(0.0f);
    m_gradeChannel.SetElapsed(0.0f);
    m_gradeChannel.SetCurrent(kGradeChannelFull);
    m_flGradeRevealClock = kGradeClockStart;
    m_bGradeVisible = true;
    m_bGradeClockActive = true;
    m_bGradeArmed = true;
    LoadBestRankFlags();

    // The reveal runs longer for a single-side display or when the second side has no records.
    m_flGradeRevealDuration = kGradeRevealDurationDual;
    if (m_nSideCount == 1 || m_aGradeValues[1] == 0) {
        m_flGradeRevealDuration = kGradeRevealDurationSingle;
    }
}

/** @ghidraAddress 0x187710 */
void ColetteThemeLayer::LoadBestRankFlags() {
    for (int nSide = 0; nSide < kSideCount; ++nSide) {
        m_aGradeValues[nSide] =
            ScoreTracker::shared()->GetPlayRecordField10(static_cast<unsigned int>(nSide));
    }
}

/** @ghidraAddress 0x18774c */
void ColetteThemeLayer::StartFadeOut(float flDuration) {
    m_gradeChannel.SetStart(m_gradeChannel.GetCurrent());
    m_gradeChannel.SetEnd(0.0f);
    m_gradeChannel.SetDuration(flDuration);
    m_gradeChannel.SetElapsed(0.0f);
    if (flDuration <= 0.0f) {
        m_gradeChannel.SetCurrent(0.0f);
    }
}

/** @ghidraAddress 0x18795c */
void ColetteThemeLayer::AdvanceFadeInterp(float flDelta) {
    m_gradeChannel.Advance(flDelta);
}

/** @ghidraAddress 0x1879a4 */
void ColetteThemeLayer::EmitFcSprite(float flScaleX,
                                     float flScaleY,
                                     float flRotation,
                                     unsigned int nSpriteSlot,
                                     const S_VECTOR2 *pPosition,
                                     int nAlpha) {
    const FcSpriteDescriptor &descriptor = kFcSpriteDescriptors[nSpriteSlot];
    const unsigned int nBatch = kFcBatchIndex[descriptor.nBatchKind];

    ne::C_SPRITE_INSTANCING_2D *pBatch = m_apSprites[nBatch];
    const int nIndex = m_aSpriteCounts[nBatch];
    if (nIndex >= static_cast<int>(kSlotCapacities[nBatch])) {
        return;
    }

    const SpriteUvEntry &uv = g_aSpriteUvTable[descriptor.nUvFrameIndex];

    // The play-field half-height (rounded toward zero) offsets the quad's base Y.
    const int nHalfHeight =
        (g_nPlayfieldFullHeightY < 0 ? g_nPlayfieldFullHeightY + 1 : g_nPlayfieldFullHeightY) / 2;

    pBatch->SetSpritePositionXY(
        nIndex, pPosition->x, pPosition->y + static_cast<float>(nHalfHeight));
    pBatch->SetSpriteAnchor(nIndex, S_VECTOR2{descriptor.flAnchorX, descriptor.flAnchorY});
    pBatch->SetSpriteSize(nIndex, S_VECTOR2{descriptor.flSizeX, descriptor.flSizeY});
    pBatch->SetSpriteUvOrigin(nIndex, S_VECTOR2{uv.flOriginU, uv.flOriginV});
    pBatch->SetSpriteUvSize(nIndex, S_VECTOR2{uv.flSizeU, uv.flSizeV});
    pBatch->SetSpriteScale(nIndex, flScaleX, flScaleY);
    pBatch->SetSpriteRotation(nIndex, flRotation);

    // The drop-shadow slot draws black; every other slot draws white.
    const unsigned int nChannel = nSpriteSlot == kFcShadowSlot ? 0 : kColorMax;
    pBatch->SetSpriteColor(nIndex, nChannel, nChannel, nChannel, static_cast<unsigned int>(nAlpha));

    m_aSpriteCounts[nBatch] = nIndex + 1;
}

/** @ghidraAddress 0x187ea4 */
void ColetteThemeLayer::EmitFcMissSprites(int nSide) {
    const float flCurveScale = m_gradeChannel.GetCurrent();
    const float flBaseY = kMissReferenceY - m_flHeight;

    // The six curve-animated sprites, laid out along the fixed X columns at the shared base Y.
    for (int nSprite = 0; nSprite < kMissSpriteCount; ++nSprite) {
        const float flScale = CalculateCurveInterpolation(
            kMissScaleCurve[nSprite], kMissScaleCurvePairs, flCurveScale);
        const float flAlphaCurve =
            CalculateCurveInterpolation(kMissRotCurve[nSprite], kMissRotCurvePairs, flCurveScale);

        S_VECTOR2 position{kMissSpriteX[nSprite], flBaseY};
        float flRotation = 0.0f;
        if (m_nSideCount == kSingleSide) {
            if (nSide == kSecondSide) {
                position.y = flBaseY + kMissSecondSideShiftY;
            } else {
                // The first side is mirrored: its X is negated, its Y reflected, and it is turned a
                // half-turn.
                position.x = -kMissSpriteX[nSprite];
                position.y = kMissFirstSideReflectY - flBaseY;
                flRotation = kMissMirrorRotation;
            }
        }

        EmitFcSprite(flScale,
                     flScale,
                     flRotation,
                     kMissSpriteSlotBase + nSprite,
                     &position,
                     static_cast<int>(flAlphaCurve * flCurveScale * kFcAlphaByteScale));
    }

    // The banner sprite: its own scale-X, scale-Y, and alpha curves at the same base Y.
    const float flBannerScaleX =
        CalculateCurveInterpolation(kBannerScaleXCurve, kBannerCurvePairs4, flCurveScale);
    const float flBannerScaleY =
        CalculateCurveInterpolation(kBannerScaleYCurve, kBannerCurvePairs4, flCurveScale);
    const float flBannerAlpha =
        CalculateCurveInterpolation(kBannerAlphaCurve, kBannerCurvePairs2, flCurveScale);

    S_VECTOR2 bannerPos{0.0f, flBaseY};
    if (m_nSideCount == kSingleSide) {
        if (nSide == kSecondSide) {
            bannerPos.y = flBaseY + kMissSecondSideShiftY;
        } else {
            bannerPos.x = -0.0f;
            bannerPos.y = kMissFirstSideReflectY - flBaseY;
        }
    }
    EmitFcSprite(flBannerScaleX,
                 flBannerScaleY,
                 0.0f,
                 kMissBannerSlot,
                 &bannerPos,
                 static_cast<int>(flBannerAlpha * kFcAlphaByteScale));
}

/** @ghidraAddress 0x187b44 */
void ColetteThemeLayer::EmitFcRankSprites(int nSide, int nColorVariant) {
    // The medals only animate while the reveal clock is inside their window.
    const float flClock = m_flGradeRevealClock;
    if (flClock <= kRankWindowStart || flClock >= kRankWindowEnd) {
        return;
    }

    // On the first frame inside the window, play the medal reveal sound once.
    if (m_bGradeArmed) {
        SoundEffectManager::GetInstance()->PlayThemedSoundEffect(kRankSoundEffect);
        m_bGradeArmed = false;
    }

    const float flCurveScale = m_gradeChannel.GetCurrent();
    const float flQuery = flClock + kRankTimerOffset;

    for (int nMedal = 0; nMedal < kRankMedalCount; ++nMedal) {
        const float flScaleX =
            CalculateCurveInterpolation(kRankScaleXCurve[nMedal], kRankScaleCurvePairs, flQuery);
        const float flScaleY =
            CalculateCurveInterpolation(kRankScaleYCurve[nMedal], kRankScaleCurvePairs, flQuery);
        const float flAlpha =
            CalculateCurveInterpolation(kRankAlphaCurve[nMedal], kRankAlphaCurvePairs, flQuery);
        float flRotation =
            CalculateCurveInterpolation(kRankRotCurve[nMedal], kRankRotCurvePairs, flQuery);
        const float flOffsetY =
            CalculateCurveInterpolation(kRankOffsetYCurve[nMedal], kRankOffsetCurvePairs, flQuery);

        S_VECTOR2 position{kRankMedalPlacement[nMedal].flX,
                           (kRankMedalPlacement[nMedal].flBaseY - m_flHeight) + flOffsetY};
        if (nSide == kSecondSide) {
            position.y += kRankSecondSideShiftY;
        } else if (nSide == 0) {
            // The first side is mirrored: its X is negated, it is turned a half-turn, and its Y is
            // reflected.
            position.x = -position.x;
            flRotation = static_cast<float>(static_cast<double>(flRotation) + kRankMirrorRotation);
            position.y = kRankFirstSideReflectY - position.y;
        }

        // Two of the seven medals draw only for one colour variant; the rest always draw.
        bool bEmit = true;
        if (nMedal == kRankMedalVariantSkip1) {
            bEmit = nColorVariant != 0;
        } else if (nMedal == kRankMedalVariantSkip2) {
            bEmit = nColorVariant != 1;
        }
        if (bEmit) {
            EmitFcSprite(flScaleX,
                         flScaleY,
                         flRotation,
                         kRankSpriteSlotBase + nMedal,
                         &position,
                         static_cast<int>(flAlpha * flCurveScale * kFcAlphaByteScale));
        }
    }
}
