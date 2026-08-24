#include "limelight_effect_layer.h"

#include "bg_layer.h"
#include "curve.h"
#include "gamesystem.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#include "s_vector2.h"
#include "sprite_uv_table.h"

// The title-part UV atlas (a distinct atlas from the shared sprite UV table); the higher effect
// glyph kinds (12 and up) take their UV from it.
extern const SpriteUvEntry g_aTitlePartUvDefault[]; // @ghidraAddress 0x2f7908

// The process-wide Limelight effect layer, created lazily by shared().
static LimelightEffectLayer *g_pLimelightEffectLayer = nullptr; // @ghidraAddress 0x3dd300

namespace {

// The background-effect atlases the layer loads (@ghidraAddress 0x3ceaa8 and 0x3ceaf0).
constexpr const char *kBackgroundTextureName = "00_texture/gm_parts2";
constexpr const char *kEffectTextureName = "00_texture/ti_parts_eff";

// The per-slot sprite-instancer capacities (@ghidraAddress 0x304210).
constexpr unsigned int kSlotCapacities[] = {12, 28};

// The per-slot texture-field selector (@ghidraAddress 0x304218): 0 binds the background atlas, 1
// binds the effect atlas.
constexpr int kSlotTextureField[] = {0, 1};

// The per-slot additive-blend flag (@ghidraAddress 0x304220): a non-zero entry puts the slot into
// additive blend mode.
constexpr bool kSlotAdditiveBlend[] = {false, false};

// The additive blend-mode identifier the flagged slots use.
constexpr int kAdditiveBlendMode = 1;

// One record of the effect sprite-layout table: the target sprite group, the fixed anchor and quad
// size, and the atlas-frame index for an effect glyph kind.
struct EffectSpriteLayout {
    int nGroup = {};      // +0x00: the sprite group, used directly as the instancer slot.
    float flAnchorX = {}; // +0x04: the anchor's X offset.
    float flAnchorY = {}; // +0x08: the anchor's Y offset.
    float flSizeX = {};   // +0x0c: the quad's width.
    float flSizeY = {};   // +0x10: the quad's height.
    int nAtlasFrame = {}; // +0x14: the atlas-frame index into the UV table.
};

// The per-kind effect sprite layout (@ghidraAddress 0x304d64): kinds 0..11 are the base glyphs
// (group 0), kinds 12..39 the curve-animated glyphs (group 1).
constexpr EffectSpriteLayout kEffectSpriteLayout[] = {
    {0, 30.0f, 28.0f, 60.0f, 56.0f, 28},   {0, 23.0f, 28.0f, 46.0f, 56.0f, 29},
    {0, 20.0f, 28.0f, 40.0f, 56.0f, 30},   {0, 20.0f, 28.0f, 50.0f, 56.0f, 31},
    {0, 33.0f, 28.0f, 66.0f, 56.0f, 32},   {0, 23.0f, 28.0f, 46.0f, 56.0f, 33},
    {0, 23.0f, 28.0f, 46.0f, 56.0f, 29},   {0, 20.0f, 28.0f, 40.0f, 56.0f, 30},
    {0, 30.0f, 28.0f, 60.0f, 56.0f, 28},   {0, 27.0f, 28.0f, 54.0f, 56.0f, 34},
    {0, 26.0f, 28.0f, 52.0f, 56.0f, 35},   {0, 22.0f, 28.0f, 44.0f, 56.0f, 36},
    {1, 69.0f, 69.0f, 138.0f, 138.0f, 20}, {1, 55.5f, 55.5f, 110.0f, 110.0f, 21},
    {1, 27.0f, 27.0f, 54.0f, 54.0f, 24},   {1, 9.5f, 9.5f, 16.0f, 16.0f, 25},
    {1, 27.0f, 27.0f, 54.0f, 54.0f, 8},    {1, 9.5f, 9.5f, 19.0f, 19.0f, 9},
    {1, 69.0f, 69.0f, 138.0f, 138.0f, 22}, {1, 55.5f, 55.5f, 110.0f, 110.0f, 23},
    {1, 9.5f, 9.5f, 16.0f, 16.0f, 25},     {1, 27.0f, 27.0f, 54.0f, 54.0f, 24},
    {1, 69.0f, 69.0f, 138.0f, 138.0f, 20}, {1, 55.5f, 55.5f, 110.0f, 110.0f, 21},
    {1, 69.0f, 69.0f, 138.0f, 138.0f, 18}, {1, 55.5f, 55.5f, 110.0f, 110.0f, 19},
    {1, 27.0f, 27.0f, 54.0f, 54.0f, 8},    {1, 9.5f, 9.5f, 19.0f, 19.0f, 9},
    {1, 27.0f, 27.0f, 54.0f, 54.0f, 8},    {1, 9.5f, 9.5f, 19.0f, 19.0f, 9},
    {1, 69.0f, 69.0f, 138.0f, 138.0f, 22}, {1, 55.5f, 55.5f, 110.0f, 110.0f, 23},
    {1, 69.0f, 69.0f, 138.0f, 138.0f, 22}, {1, 55.5f, 55.5f, 110.0f, 110.0f, 23},
    {1, 69.0f, 69.0f, 138.0f, 138.0f, 18}, {1, 55.5f, 55.5f, 110.0f, 110.0f, 19},
    {1, 70.0f, 70.0f, 140.0f, 140.0f, 14}, {1, 70.0f, 70.0f, 140.0f, 140.0f, 15},
    {1, 69.0f, 69.0f, 138.0f, 138.0f, 20}, {1, 55.5f, 55.5f, 110.0f, 110.0f, 21},
};

// The highest effect glyph kind whose UV comes from the shared atlas table rather than the
// title-part table (@c kind @c > @c 11 selects the title-part atlas).
constexpr unsigned int kMaxSharedAtlasKind = 11;

// The layout offsets the phone and iPad use to place a glyph relative to the cached viewport size
// (@ghidraAddress 0x2f8568 = -384 half-width bias, 0x301f94 = -680 height bias). The phone halves
// the biased position and adds half the cached viewport; the iPad keeps full size and only shifts
// vertically.
constexpr float kPhoneHalfWidthBias = -384.0f;
constexpr float kHeightBias = -680.0f;
constexpr float kViewportHalfScale = 0.5f;

// The opaque white channel value each effect glyph is tinted with.
constexpr unsigned int kChannelWhite = 0xff;

// The number of curve-animated effect glyphs, the first grade sprite kind they occupy (kinds
// 12..39, the group-1 glyphs), and the curve knot counts.
constexpr int kCurveGlyphCount = 28;
constexpr int kCurveGlyphFirstKind = 12;
constexpr int kCurveXKnots = 2;
constexpr int kCurveYKnots = 2;
constexpr int kCurveAlphaKnots = 3;
constexpr int kCurveScaleKnots = 2;

// The vertical offset added to each curve-animated glyph's sampled Y (@ghidraAddress 0x3041a8), and
// the byte alpha scale (@ghidraAddress 0x2eed00).
constexpr float kCurveGlyphOffsetY = 580.0f;
constexpr float kAlphaByteScale = 255.0f;

// Each curve-animated glyph's horizontal-position curve ({time, x} knots at @ghidraAddress
// 0x304584): the glyph sweeps in from the right.
constexpr float kCurveGlyphXCurve[kCurveGlyphCount][kCurveXKnots * 2] = {
    {400.0f, 684.0f, 900.0f, 694.0f},
    {400.0f, 684.0f, 900.0f, 694.0f},
    {366.66666f, 668.0f, 866.66669f, 678.0f},
    {366.66666f, 668.0f, 866.66669f, 678.0f},
    {333.33334f, 604.0f, 833.33331f, 614.0f},
    {333.33334f, 604.0f, 833.33331f, 614.0f},
    {300.0f, 541.0f, 800.0f, 551.0f},
    {300.0f, 541.0f, 800.0f, 551.0f},
    {266.66666f, 498.0f, 766.66669f, 508.0f},
    {266.66666f, 498.0f, 766.66669f, 508.0f},
    {233.33333f, 481.0f, 733.33331f, 491.0f},
    {233.33333f, 481.0f, 733.33331f, 491.0f},
    {200.0f, 434.0f, 700.0f, 444.0f},
    {200.0f, 434.0f, 700.0f, 444.0f},
    {166.66667f, 382.0f, 666.66669f, 392.0f},
    {166.66667f, 382.0f, 666.66669f, 392.0f},
    {133.33333f, 339.0f, 633.33331f, 349.0f},
    {133.33333f, 339.0f, 633.33331f, 349.0f},
    {100.0f, 326.0f, 600.0f, 336.0f},
    {100.0f, 326.0f, 600.0f, 336.0f},
    {66.66666f, 279.0f, 566.66669f, 289.0f},
    {66.66666f, 279.0f, 566.66669f, 289.0f},
    {66.66666f, 179.0f, 566.66669f, 189.0f},
    {66.66666f, 179.0f, 566.66669f, 189.0f},
    {33.33333f, 242.0f, 533.33331f, 252.0f},
    {33.33333f, 242.0f, 533.33331f, 252.0f},
    {0.0f, 95.0f, 500.0f, 105.0f},
    {0.0f, 95.0f, 500.0f, 105.0f},
};

// Each curve-animated glyph's vertical-position curve ({time, y} knots at @ghidraAddress 0x304744).
constexpr float kCurveGlyphYCurve[kCurveGlyphCount][kCurveYKnots * 2] = {
    {400.0f, 96.0f, 900.0f, 91.0f},
    {400.0f, 96.0f, 900.0f, 91.0f},
    {366.66666f, 90.0f, 866.66669f, 85.0f},
    {366.66666f, 90.0f, 866.66669f, 85.0f},
    {333.33334f, 106.0f, 833.33331f, 96.0f},
    {333.33334f, 106.0f, 833.33331f, 101.0f},
    {300.0f, 104.0f, 800.0f, 94.0f},
    {300.0f, 104.0f, 800.0f, 99.0f},
    {266.66666f, 102.0f, 766.66669f, 92.0f},
    {266.66666f, 102.0f, 766.66669f, 97.0f},
    {233.33333f, 93.0f, 733.33331f, 88.0f},
    {233.33333f, 93.0f, 733.33331f, 88.0f},
    {200.0f, 97.0f, 700.0f, 92.0f},
    {200.0f, 97.0f, 700.0f, 92.0f},
    {166.66667f, 115.0f, 666.66669f, 110.0f},
    {166.66667f, 115.0f, 666.66669f, 110.0f},
    {133.33333f, 98.0f, 633.33331f, 93.0f},
    {133.33333f, 98.0f, 633.33331f, 93.0f},
    {100.0f, 108.0f, 600.0f, 103.0f},
    {100.0f, 108.0f, 600.0f, 108.0f},
    {66.66666f, 93.0f, 566.66669f, 88.0f},
    {66.66666f, 93.0f, 566.66669f, 88.0f},
    {66.66666f, 98.0f, 566.66669f, 93.0f},
    {66.66666f, 98.0f, 566.66669f, 93.0f},
    {33.33333f, 96.0f, 533.33331f, 91.0f},
    {33.33333f, 96.0f, 533.33331f, 91.0f},
    {0.0f, 96.0f, 500.0f, 91.0f},
    {0.0f, 96.0f, 500.0f, 91.0f},
};

// Each curve-animated glyph's alpha curve ({time, alpha} knots at @ghidraAddress 0x304904): a quick
// fade in and a long fade out, staggered per glyph.
constexpr float kCurveGlyphAlphaCurve[kCurveGlyphCount][kCurveAlphaKnots * 2] = {
    {633.33331f, 0.0f, 650.0f, 1.0f, 900.0f, 0.0f},
    {400.0f, 0.0f, 633.33331f, 1.0f, 650.0f, 0.0f},
    {600.0f, 0.0f, 616.66669f, 1.0f, 866.66669f, 0.0f},
    {366.66666f, 0.0f, 600.0f, 1.0f, 616.66669f, 0.0f},
    {566.66669f, 0.0f, 583.33331f, 1.0f, 833.33331f, 0.0f},
    {333.33334f, 0.0f, 566.66669f, 1.0f, 583.33331f, 0.0f},
    {533.33331f, 0.0f, 550.0f, 1.0f, 800.0f, 0.0f},
    {300.0f, 0.0f, 533.33331f, 1.0f, 550.0f, 0.0f},
    {500.0f, 0.0f, 516.66669f, 1.0f, 766.66669f, 0.0f},
    {266.66666f, 0.0f, 500.0f, 1.0f, 516.66669f, 0.0f},
    {466.66666f, 0.0f, 483.33334f, 1.0f, 733.33331f, 0.0f},
    {233.33333f, 0.0f, 466.66666f, 1.0f, 483.33334f, 0.0f},
    {433.33334f, 0.0f, 450.0f, 1.0f, 700.0f, 0.0f},
    {200.0f, 0.0f, 433.33334f, 1.0f, 450.0f, 0.0f},
    {400.0f, 0.0f, 416.66666f, 1.0f, 666.66669f, 0.0f},
    {166.66667f, 0.0f, 400.0f, 1.0f, 416.66666f, 0.0f},
    {366.66666f, 0.0f, 383.33334f, 1.0f, 466.66666f, 0.0f},
    {133.33333f, 0.0f, 366.66666f, 1.0f, 383.33334f, 0.0f},
    {333.33334f, 0.0f, 350.0f, 1.0f, 433.33334f, 0.0f},
    {100.0f, 0.0f, 333.33334f, 1.0f, 350.0f, 0.0f},
    {300.0f, 0.0f, 316.66666f, 1.0f, 400.0f, 0.0f},
    {66.66666f, 0.0f, 300.0f, 1.0f, 316.66666f, 0.0f},
    {300.0f, 0.0f, 316.66666f, 1.0f, 566.66669f, 0.0f},
    {66.66666f, 0.0f, 300.0f, 1.0f, 316.66666f, 0.0f},
    {266.66666f, 0.0f, 283.33334f, 1.0f, 533.33331f, 0.0f},
    {33.33333f, 0.0f, 266.66666f, 1.0f, 283.33334f, 0.0f},
    {233.33333f, 0.0f, 250.0f, 1.0f, 500.0f, 0.0f},
    {0.0f, 0.0f, 233.33333f, 1.0f, 250.0f, 0.0f},
};

// Each curve-animated glyph's scale curve ({time, scale} knots at @ghidraAddress 0x304ba4).
constexpr float kCurveGlyphScaleCurve[kCurveGlyphCount][kCurveScaleKnots * 2] = {
    {400.0f, 0.0f, 900.0f, 0.5f},
    {400.0f, 0.0f, 900.0f, 0.5f},
    {366.66666f, 0.0f, 866.66669f, 0.45f},
    {366.66666f, 0.0f, 866.66669f, 0.45f},
    {333.33334f, 0.0f, 833.33331f, 0.45f},
    {333.33334f, 0.0f, 833.33331f, 0.45f},
    {300.0f, 0.0f, 800.0f, 0.6f},
    {300.0f, 0.0f, 800.0f, 0.6f},
    {266.66666f, 0.0f, 766.66669f, 0.65f},
    {266.66666f, 0.0f, 766.66669f, 0.65f},
    {233.33333f, 0.0f, 733.33331f, 0.45f},
    {233.33333f, 0.0f, 733.33331f, 0.45f},
    {200.0f, 0.0f, 700.0f, 0.45f},
    {200.0f, 0.0f, 700.0f, 0.45f},
    {166.66667f, 0.0f, 666.66669f, 0.45f},
    {166.66667f, 0.0f, 666.66669f, 0.45f},
    {133.33333f, 0.0f, 633.33331f, 0.55f},
    {133.33333f, 0.0f, 633.33331f, 0.55f},
    {100.0f, 0.0f, 600.0f, 0.45f},
    {100.0f, 0.0f, 600.0f, 0.45f},
    {66.66666f, 0.0f, 566.66669f, 0.55f},
    {66.66666f, 0.0f, 566.66669f, 0.55f},
    {66.66666f, 0.0f, 566.66669f, 0.45f},
    {66.66666f, 0.0f, 566.66669f, 0.45f},
    {33.33333f, 0.0f, 533.33331f, 0.65f},
    {33.33333f, 0.0f, 533.33331f, 0.65f},
    {0.0f, 0.0f, 500.0f, 0.5f},
    {0.0f, 0.0f, 500.0f, 0.5f},
};

// The number of base glyphs in the effect strip (grade sprite kinds 0..11) and their curve knot
// counts.
constexpr int kBaseGlyphCount = 12;
constexpr int kBaseYKnots = 5;
constexpr int kBaseAlphaKnots = 4;

// The effect clock's end threshold, the curve-phase start threshold, and the offset added to the
// clock for the curve-animated pass (@ghidraAddress 0x2feff0, 0x3041a0, 0x3041a4).
constexpr float kEffectEndThreshold = 2000.0f;
constexpr float kCurvePhaseStart = 116.66666f;
constexpr float kCurvePhaseClockOffset = -116.66666f;

// The base glyph's alpha on an iPad (full) and on the phone (half); the scale takes the same value.
constexpr float kBaseGlyphPadAlpha = 1.0f;
constexpr float kBaseGlyphPhoneAlpha = 0.5f;

// Each base glyph's fixed horizontal position (@ghidraAddress 0x3041b0): a constant base subtracted
// from the layout origin (all share one vertical position, 653).
constexpr float kBaseGlyphAbsoluteX[kBaseGlyphCount] = {
    123.0f, 172.0f, 211.0f, 269.0f, 320.0f, 373.0f, 437.0f, 476.0f, 521.0f, 574.0f, 616.0f, 660.0f};

// Each base glyph's per-frame vertical-position curve ({time, y} knots at @ghidraAddress 0x3043a4).
constexpr float kBaseGlyphYCurve[kBaseGlyphCount][kBaseYKnots * 2] = {
    {0.0f, 593.0f, 183.33333f, 663.0f, 350.0f, 623.0f, 500.0f, 668.0f, 616.66669f, 653.0f},
    {16.66667f, 593.0f, 200.0f, 663.0f, 383.33334f, 623.0f, 516.66669f, 668.0f, 633.33331f, 653.0f},
    {33.33333f, 593.0f, 216.66667f, 663.0f, 383.33334f, 623.0f, 533.33331f, 668.0f, 650.0f, 653.0f},
    {50.0f, 593.0f, 233.33333f, 663.0f, 400.0f, 623.0f, 550.0f, 668.0f, 666.66669f, 653.0f},
    {66.66666f, 593.0f, 250.0f, 663.0f, 416.66666f, 623.0f, 566.66669f, 668.0f, 683.33331f, 653.0f},
    {83.33334f, 593.0f, 266.66666f, 663.0f, 433.33334f, 623.0f, 583.33331f, 668.0f, 700.0f, 653.0f},
    {100.0f, 593.0f, 283.33334f, 663.0f, 450.0f, 623.0f, 600.0f, 668.0f, 716.66669f, 653.0f},
    {116.66666f,
     593.0f,
     300.0f,
     663.0f,
     466.66666f,
     623.0f,
     616.66669f,
     668.0f,
     733.33331f,
     653.0f},
    {133.33333f,
     593.0f,
     316.66666f,
     663.0f,
     483.33334f,
     623.0f,
     633.33331f,
     668.0f,
     750.0f,
     653.0f},
    {150.0f, 593.0f, 333.33334f, 663.0f, 500.0f, 623.0f, 650.0f, 668.0f, 766.66669f, 653.0f},
    {166.66667f,
     593.0f,
     350.0f,
     663.0f,
     516.66669f,
     623.0f,
     666.66669f,
     668.0f,
     783.33331f,
     653.0f},
    {183.33333f,
     593.0f,
     366.66666f,
     663.0f,
     533.33331f,
     623.0f,
     683.33331f,
     668.0f,
     800.0f,
     653.0f},
};

// Each base glyph's per-frame alpha curve ({time, alpha} knots at @ghidraAddress 0x304224): a fade
// in, a long hold, and a fade out, staggered per glyph.
constexpr float kBaseGlyphAlphaCurve[kBaseGlyphCount][kBaseAlphaKnots * 2] = {
    {0.0f, 0.0f, 166.66667f, 1.0f, 1416.66663f, 1.0f, 1583.33337f, 0.0f},
    {16.66667f, 0.0f, 183.33333f, 1.0f, 1416.66663f, 1.0f, 1583.33337f, 0.0f},
    {33.33333f, 0.0f, 200.0f, 1.0f, 1416.66663f, 1.0f, 1583.33337f, 0.0f},
    {50.0f, 0.0f, 216.66667f, 1.0f, 1416.66663f, 1.0f, 1583.33337f, 0.0f},
    {66.66666f, 0.0f, 233.33333f, 1.0f, 1416.66663f, 1.0f, 1583.33337f, 0.0f},
    {83.33334f, 0.0f, 250.0f, 1.0f, 1416.66663f, 1.0f, 1583.33337f, 0.0f},
    {100.0f, 0.0f, 266.66666f, 1.0f, 1416.66663f, 1.0f, 1583.33337f, 0.0f},
    {116.66666f, 0.0f, 283.33334f, 1.0f, 1416.66663f, 1.0f, 1583.33337f, 0.0f},
    {133.33333f, 0.0f, 300.0f, 1.0f, 1416.66663f, 1.0f, 1583.33337f, 0.0f},
    {150.0f, 0.0f, 316.66666f, 1.0f, 1416.66663f, 1.0f, 1583.33337f, 0.0f},
    {166.66667f, 0.0f, 333.33334f, 1.0f, 1416.66663f, 1.0f, 1583.33337f, 0.0f},
    {183.33333f, 0.0f, 350.0f, 1.0f, 1416.66663f, 1.0f, 1583.33337f, 0.0f},
};

} // namespace

/** @ghidraAddress 0x11ff84 */
LimelightEffectLayer::LimelightEffectLayer() = default;

/** @ghidraAddress 0x11ffcc */
LimelightEffectLayer *LimelightEffectLayer::shared() {
    if (g_pLimelightEffectLayer == nullptr) {
        // The binary allocates the raw 0x48-byte object and runs the constructor, which chains the
        // base-layer constructor and zero-clears the layer's state.
        g_pLimelightEffectLayer = new LimelightEffectLayer();
    }
    return g_pLimelightEffectLayer;
}

/** @ghidraAddress 0x12001c */
void LimelightEffectLayer::InitializeBackgroundSprites() {
    if (m_bSpritesBuilt) {
        return;
    }

    // The sprites hang beneath the shared background layer's render object rather than the global
    // scene root.
    BgLayer *pBackgroundLayer = BgLayer::GetBackgroundLayer();
    ne::C_RENDER *pParent = pBackgroundLayer->GetBackgroundRenderObject();

    m_pBackgroundTexture = ne::C_TEXTURE::FindOrLoadCached(kBackgroundTextureName);
    m_pEffectTexture = ne::C_TEXTURE::FindOrLoadCached(kEffectTextureName);

    ne::C_TEXTURE *const apTextureFields[] = {m_pBackgroundTexture, m_pEffectTexture};

    // Build one sprite instancer per slot, attach it under the background render object, make it
    // visible, bind its atlas, seed its sprite count, and flag additive blend where requested.
    for (int nSlot = 0; nSlot < kSpriteSlotCount; ++nSlot) {
        ne::C_SPRITE_INSTANCING_2D *pSprite = ne::CreateSpriteInstancer(kSlotCapacities[nSlot]);
        pParent->AttachChild(pSprite);
        pSprite->SetVisible(true);
        pSprite->SetRefCountedMember(apTextureFields[kSlotTextureField[nSlot]]);
        pSprite->SetSpriteCount(m_aSpriteCounts[nSlot]);
        if (kSlotAdditiveBlend[nSlot]) {
            pSprite->SetBlendMode(kAdditiveBlendMode);
        }
        m_apSprites[nSlot] = pSprite;
    }

    m_bSpritesBuilt = true;
}

/** @ghidraAddress 0x120118 */
void LimelightEffectLayer::SetActiveAndResetCounter() {
    m_bActive = true;
    m_flClock = 0.0f;
}

/** @ghidraAddress 0x120128 */
void LimelightEffectLayer::SetInactive(float flDuration) {
    (void)flDuration; // The binary takes a duration in s0 and never reads it.
    m_bActive = false;
}

/** @ghidraAddress 0x120130 */
void LimelightEffectLayer::UpdateEffect(float flDeltaTime) {
    GameSystem *pGameSystem = GameSystem::GetGameSystem();
    m_flCachedViewportWidth = pGameSystem->GetViewportWidth();
    m_flCachedViewportHeight = pGameSystem->GetViewportHeight();

    // Clear both instancers' live counts for the frame.
    for (int nSlot = 0; nSlot < kSpriteSlotCount; ++nSlot) {
        m_apSprites[nSlot]->SetSpriteCount(0);
    }

    if (!m_bActive) {
        return;
    }

    // Advance the clock, deactivating once it passes the end threshold.
    m_flClock += flDeltaTime;
    if (m_flClock >= kEffectEndThreshold) {
        m_bActive = false;
        return;
    }

    // The base glyphs draw at full alpha and scale on an iPad, half on the phone.
    const float flBaseAlphaScale = IsPad() ? kBaseGlyphPadAlpha : kBaseGlyphPhoneAlpha;

    // Once the clock passes the curve-phase start, emit the curve-animated glyphs.
    if (m_flClock >= kCurvePhaseStart) {
        EmitCurveAnimatedSprites(m_flClock + kCurvePhaseClockOffset);
    }

    // Emit the twelve base glyphs: each takes a fixed horizontal base and a curve-animated vertical
    // position, faded by its own alpha curve scaled by the device alpha.
    for (int nGlyph = 0; nGlyph < kBaseGlyphCount; ++nGlyph) {
        const float flPosY =
            CalculateCurveInterpolation(kBaseGlyphYCurve[nGlyph], kBaseYKnots, m_flClock);
        const float flAlpha =
            CalculateCurveInterpolation(kBaseGlyphAlphaCurve[nGlyph], kBaseAlphaKnots, m_flClock);

        S_VECTOR2 position{kBaseGlyphAbsoluteX[nGlyph], flPosY};
        const unsigned int nAlpha =
            static_cast<unsigned int>(static_cast<int>(flAlpha * kAlphaByteScale));
        EmitSpriteSlot(static_cast<unsigned int>(nGlyph),
                       &position,
                       nAlpha,
                       flBaseAlphaScale,
                       flBaseAlphaScale);
    }
}

/** @ghidraAddress 0x120328 */
void LimelightEffectLayer::EmitCurveAnimatedSprites(float flClock) {
    for (int nGlyph = 0; nGlyph < kCurveGlyphCount; ++nGlyph) {
        // Each glyph samples four independent curves at the same clock: its horizontal and vertical
        // positions, its alpha, and its scale.
        const float flPosX =
            CalculateCurveInterpolation(kCurveGlyphXCurve[nGlyph], kCurveXKnots, flClock);
        const float flPosY =
            CalculateCurveInterpolation(kCurveGlyphYCurve[nGlyph], kCurveYKnots, flClock);
        const float flAlpha =
            CalculateCurveInterpolation(kCurveGlyphAlphaCurve[nGlyph], kCurveAlphaKnots, flClock);
        const float flScale =
            CalculateCurveInterpolation(kCurveGlyphScaleCurve[nGlyph], kCurveScaleKnots, flClock);

        S_VECTOR2 position{flPosX, flPosY + kCurveGlyphOffsetY};
        const unsigned int nAlpha =
            static_cast<unsigned int>(static_cast<int>(flAlpha * kAlphaByteScale));
        EmitSpriteSlot(static_cast<unsigned int>(kCurveGlyphFirstKind + nGlyph),
                       &position,
                       nAlpha,
                       flScale,
                       flScale);
    }
}

/** @ghidraAddress 0x120434 */
void LimelightEffectLayer::EmitSpriteSlot(unsigned int nSpriteKind,
                                          S_VECTOR2 *pPosition,
                                          unsigned int nAlpha,
                                          float flScaleX,
                                          float flScaleY) {
    const EffectSpriteLayout &layout = kEffectSpriteLayout[nSpriteKind];
    // The higher kinds index the title-part atlas; the lower kinds index the shared atlas.
    const SpriteUvEntry &uv = nSpriteKind > kMaxSharedAtlasKind ?
                                  g_aTitlePartUvDefault[layout.nAtlasFrame] :
                                  g_aSpriteUvTable[layout.nAtlasFrame];

    ne::C_SPRITE_INSTANCING_2D *pBatch = m_apSprites[layout.nGroup];
    const int nIndex = pBatch->GetSpriteCount();
    // Drop the sprite when the target batch is full.
    if (nIndex >= static_cast<int>(pBatch->GetCapacity())) {
        return;
    }

    // The iPad keeps the base position and only shifts it vertically by the cached viewport height;
    // the phone halves the horizontally-biased position and re-centres it on the cached viewport.
    if (IsPad()) {
        pPosition->y = pPosition->y + kHeightBias + m_flCachedViewportHeight * kViewportHalfScale;
    } else {
        pPosition->x = (pPosition->x + kPhoneHalfWidthBias) * kViewportHalfScale +
                       m_flCachedViewportWidth * kViewportHalfScale;
        pPosition->y = (pPosition->y + kHeightBias) * kViewportHalfScale +
                       m_flCachedViewportHeight * kViewportHalfScale;
    }

    pBatch->SetSpritePosition(nIndex, *pPosition);
    pBatch->SetSpriteAnchor(nIndex, S_VECTOR2{layout.flAnchorX, layout.flAnchorY});
    pBatch->SetSpriteSize(nIndex, S_VECTOR2{layout.flSizeX, layout.flSizeY});
    pBatch->SetSpriteUvOrigin(nIndex, S_VECTOR2{uv.flOriginU, uv.flOriginV});
    pBatch->SetSpriteUvSize(nIndex, S_VECTOR2{uv.flSizeU, uv.flSizeV});
    pBatch->SetSpriteScale(nIndex, flScaleX, flScaleY);
    pBatch->SetSpriteColor(nIndex, kChannelWhite, kChannelWhite, kChannelWhite, nAlpha);
    pBatch->SetSpriteCount(nIndex + 1);
}
