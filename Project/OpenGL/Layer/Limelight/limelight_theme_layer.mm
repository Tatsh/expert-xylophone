#include "limelight_theme_layer.h"

#include "../Share/bg_layer.h"
#include "ScoreTracker.h"
#include "curve.h"
#include "engineglobals.h"
#include "gamesystem.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#include "s_vector2.h"
#include "soundeffectmanager.h"
#include "sprite_uv_table.h"

extern const SpriteUvEntry g_aTitlePartUvDefault[]; // @ghidraAddress 0x2f7908

static LimelightThemeLayer *g_pLimelightThemeLayer = nullptr; // @ghidraAddress 0x3dd380

namespace {

// @ghidraAddress 0x3ceaa8, 0x3ceaf0, 0x3ceb00
constexpr const char *kPartsTextureName = "00_texture/gm_parts2";
constexpr const char *kEffectTextureName = "00_texture/ti_parts_eff";
constexpr const char *kWinTextureName = "00_texture/gm_win";

// @ghidraAddress 0x305404
constexpr unsigned int kSlotCapacities[] = {1, 100, 100, 2};

// Slot 0 binds no texture, so its -1 entry is unused.
// @ghidraAddress 0x305414
constexpr int kSlotTextureField[] = {-1, 0, 1, 2};

constexpr int kAdditiveBlendSlot = 3;
constexpr int kAdditiveBlendMode = 1;

constexpr float kLayoutWidth = 384.0f;
constexpr float kLayoutHeight = 680.0f;

constexpr int kDefaultSideCount = 1;
constexpr int kGradeValueDefault = 4;

constexpr float kGradeChannelFull = 1.0f;

constexpr float kGradeClockStart = -500.0f;

constexpr float kGradeRevealDurationDual = 3000.0f;
constexpr float kGradeRevealDurationSingle = 5000.0f;

constexpr unsigned int kGradeBaseSlot = 0;
constexpr unsigned int kGradeBaseKind = 0;
// @ghidraAddress 0x305424
constexpr float kGradeRevealCurve[] = {-500.0f, 0.0f, -333.33334f, 0.75f};
constexpr int kGradeRevealCurvePairs = 2;
// @ghidraAddress 0x2eed00
constexpr float kAlphaByteScale = 255.0f;

constexpr int kMinRankGlyphs = 2;

struct GradeSpriteLayout {
    int nGroup = {};
    float flAnchorX = {};
    float flAnchorY = {};
    float flSizeX = {};
    float flSizeY = {};
    int nAtlasFrame = {};
};

// @ghidraAddress 0x305d64
constexpr GradeSpriteLayout kGradeSpriteLayout[] = {
    {4, 384.0f, 512.0f, 768.0f, 1024.0f, 0}, {0, 52.0f, 53.0f, 104.0f, 106.0f, 37},
    {0, 30.0f, 53.0f, 60.0f, 106.0f, 38},    {0, 31.0f, 53.0f, 62.0f, 106.0f, 39},
    {0, 51.0f, 53.0f, 102.0f, 106.0f, 40},   {0, 37.0f, 53.0f, 74.0f, 106.0f, 41},
    {0, 10.0f, 53.0f, 20.0f, 106.0f, 42},    {0, 10.0f, 53.0f, 20.0f, 106.0f, 43},
    {0, 29.0f, 53.0f, 58.0f, 106.0f, 44},    {0, 51.0f, 53.0f, 102.0f, 106.0f, 45},
    {0, 10.0f, 53.0f, 20.0f, 106.0f, 46},    {0, 30.0f, 53.0f, 60.0f, 106.0f, 47},
    {0, 31.0f, 53.0f, 62.0f, 106.0f, 48},    {0, 45.0f, 53.0f, 90.0f, 106.0f, 49},
    {0, 33.0f, 53.0f, 66.0f, 106.0f, 50},    {1, 27.0f, 27.0f, 54.0f, 54.0f, 10},
    {1, 9.5f, 9.5f, 19.0f, 19.0f, 11},       {1, 27.0f, 27.0f, 54.0f, 54.0f, 8},
    {1, 9.5f, 9.5f, 19.0f, 19.0f, 9},        {1, 27.0f, 27.0f, 54.0f, 54.0f, 10},
    {1, 9.5f, 9.5f, 19.0f, 19.0f, 11},       {1, 27.0f, 27.0f, 54.0f, 54.0f, 8},
    {1, 9.5f, 9.5f, 19.0f, 19.0f, 9},        {1, 27.0f, 27.0f, 54.0f, 54.0f, 8},
    {1, 9.5f, 9.5f, 19.0f, 19.0f, 9},        {1, 27.0f, 27.0f, 54.0f, 54.0f, 24},
    {1, 9.5f, 9.5f, 16.0f, 16.0f, 25},       {1, 69.0f, 69.0f, 138.0f, 138.0f, 22},
    {1, 55.5f, 55.5f, 110.0f, 110.0f, 23},   {1, 69.0f, 69.0f, 138.0f, 138.0f, 22},
    {1, 55.5f, 55.5f, 110.0f, 110.0f, 23},   {1, 69.0f, 69.0f, 138.0f, 138.0f, 18},
    {1, 55.5f, 55.5f, 110.0f, 110.0f, 19},   {1, 69.0f, 69.0f, 138.0f, 138.0f, 18},
    {1, 55.5f, 55.5f, 110.0f, 110.0f, 19},   {1, 61.5f, 61.5f, 123.0f, 123.0f, 32},
    {1, 55.5f, 55.5f, 110.0f, 110.0f, 33},   {1, 61.5f, 61.5f, 123.0f, 123.0f, 32},
    {1, 55.5f, 55.5f, 110.0f, 110.0f, 33},   {1, 69.0f, 69.0f, 138.0f, 138.0f, 20},
    {1, 55.5f, 55.5f, 110.0f, 110.0f, 21},   {1, 61.5f, 61.5f, 123.0f, 123.0f, 32},
    {1, 55.5f, 55.5f, 110.0f, 110.0f, 21},   {1, 61.5f, 61.5f, 123.0f, 123.0f, 32},
    {1, 55.5f, 55.5f, 110.0f, 110.0f, 21},   {1, 61.5f, 61.5f, 123.0f, 123.0f, 30},
    {1, 55.5f, 55.5f, 110.0f, 110.0f, 23},   {1, 61.5f, 61.5f, 123.0f, 123.0f, 30},
    {1, 55.5f, 55.5f, 110.0f, 110.0f, 23},   {1, 69.0f, 69.0f, 138.0f, 138.0f, 20},
    {1, 85.0f, 75.0f, 170.0f, 150.0f, 20},
};

// @ghidraAddress 0x30622c
constexpr int kGroupToSlot[] = {1, 2, 3, 4, 0};

constexpr unsigned int kMaxSharedAtlasKind = 14;

constexpr unsigned int kBackdropSpriteKind = 0;

constexpr unsigned int kChannelWhite = 0xff;
constexpr unsigned int kChannelBlack = 0;

// @ghidraAddress 0x305220, 0x305224, 0x305228, 0x30522c
constexpr float kMeterStartThreshold = 3166.6667f;
constexpr float kMeterClockBias = -3166.6667f;
constexpr float kMeterClockDivisor = 1666.6667f;
constexpr float kMeterFadeThreshold = 4833.3335f;

constexpr int kMeterFanfareSoundEffect = 10;

// @ghidraAddress 0x305130
constexpr S_VECTOR2 kMeterNeedleUv[] = {
    {0.0f, 0.0f},
    {0.16796875f, 0.0f},
    {0.3359375f, 0.0f},
    {0.50390625f, 0.0f},
    {0.671875f, 0.0f},
    {0.0f, 0.1484375f},
    {0.16796875f, 0.1484375f},
    {0.3359375f, 0.1484375f},
    {0.50390625f, 0.1484375f},
    {0.671875f, 0.1484375f},
    {0.0f, 0.296875f},
    {0.16796875f, 0.296875f},
    {0.3359375f, 0.296875f},
    {0.50390625f, 0.296875f},
    {0.671875f, 0.296875f},
    {0.0f, 0.4453125f},
    {0.16796875f, 0.4453125f},
    {0.3359375f, 0.4453125f},
    {0.50390625f, 0.4453125f},
    {0.671875f, 0.4453125f},
    {0.0f, 0.59375f},
    {0.16796875f, 0.59375f},
    {0.3359375f, 0.59375f},
    {0.50390625f, 0.59375f},
    {0.671875f, 0.59375f},
    {0.0f, 0.7421875f},
    {0.16796875f, 0.7421875f},
    {0.3359375f, 0.7421875f},
    {0.50390625f, 0.7421875f},
    {0.671875f, 0.7421875f},
};
constexpr int kMeterNeedleFrameCount = 30;
constexpr int kMeterNeedleLastFrame = kMeterNeedleFrameCount - 1;

constexpr int kRankGlyphCount = 7;
constexpr int kRankGlyphFirstKind = 1;

// @ghidraAddress 0x305230, 0x305234
constexpr float kArDigitsRevealThreshold = 583.33331f;
constexpr float kArDigitsClockOffset = -583.33331f;

constexpr int kRankScaleKnots = 4;
constexpr int kRankAlphaKnots = 4;
constexpr int kRankPositionKnots = 5;

// @ghidraAddress 0x301f78, 0x3052c0, 0x2fe894
constexpr float kSingleSideNearNudgeY = 200.0f;
constexpr float kSingleSideFarOriginY = -200.0f;
constexpr float kSingleSideFarRotation = 3.1415927f;

constexpr int kNearSide = 1;

// @ghidraAddress 0x305434
constexpr float kRankScaleCurve[kRankGlyphCount][kRankScaleKnots * 2] = {
    {183.33333f, 2.8f, 550.0f, 0.95f, 650.0f, 1.05f, 750.0f, 1.0f},
    {250.0f, 2.8f, 616.66669f, 0.95f, 716.66669f, 1.05f, 816.66669f, 1.0f},
    {316.66666f, 2.8f, 683.33331f, 0.95f, 783.33331f, 1.05f, 883.33331f, 1.0f},
    {383.33334f, 2.8f, 750.0f, 0.95f, 850.0f, 1.05f, 950.0f, 1.0f},
    {450.0f, 2.8f, 816.66669f, 0.95f, 916.66669f, 1.05f, 1016.6667f, 1.0f},
    {516.66669f, 2.8f, 883.33331f, 0.95f, 983.33331f, 1.05f, 1083.3334f, 1.0f},
    {583.33331f, 2.8f, 950.0f, 0.95f, 1050.0f, 1.05f, 1150.0f, 1.0f},
};

// @ghidraAddress 0x305514
constexpr float kRankAlphaCurve[kRankGlyphCount][kRankAlphaKnots * 2] = {
    {100.0f, 0.0f, 350.0f, 1.0f, 2000.0f, 1.0f, 2333.3333f, 0.0f},
    {166.66667f, 0.0f, 416.66666f, 1.0f, 2000.0f, 1.0f, 2333.3333f, 0.0f},
    {233.33333f, 0.0f, 483.33334f, 1.0f, 2000.0f, 1.0f, 2333.3333f, 0.0f},
    {300.0f, 0.0f, 550.0f, 1.0f, 2000.0f, 1.0f, 2333.3333f, 0.0f},
    {366.66666f, 0.0f, 616.66669f, 1.0f, 2000.0f, 1.0f, 2333.3333f, 0.0f},
    {433.33334f, 0.0f, 683.33331f, 1.0f, 2000.0f, 1.0f, 2333.3333f, 0.0f},
    {500.0f, 0.0f, 750.0f, 1.0f, 2000.0f, 1.0f, 2333.3333f, 0.0f},
};

// The binary caches these X values minus the layout origin; since the origin is constant, sampling
// the absolute-X curve and subtracting is equivalent.
// @ghidraAddress 0x305238
constexpr float kRankPositionCurve[kRankGlyphCount][kRankPositionKnots * 2] = {
    {100.0f, 598.0f, 300.0f, 409.0f, 433.33334f, 336.0f, 550.0f, 287.0f, 3100.0f, 127.0f},
    {166.66667f, 821.0f, 366.66666f, 579.0f, 500.0f, 456.0f, 616.66669f, 367.0f, 3100.0f, 207.0f},
    {233.33333f,
     977.0f,
     433.33334f,
     692.0f,
     566.66669f,
     540.0f,
     683.33331f,
     427.0f,
     3100.0f,
     267.0f},
    {300.0f, 1211.0f, 500.0f, 857.0f, 633.33331f, 660.0f, 750.0f, 506.0f, 3100.0f, 346.0f},
    {366.66666f, 1444.0f, 566.66669f, 1025.0f, 700.0f, 784.0f, 816.66669f, 593.0f, 3100.0f, 433.0f},
    {433.33334f,
     1571.0f,
     633.33331f,
     1119.0f,
     766.66669f,
     855.0f,
     883.33331f,
     644.0f,
     3100.0f,
     484.0f},
    {500.0f, 1595.0f, 700.0f, 1143.0f, 833.33331f, 879.0f, 950.0f, 668.0f, 3100.0f, 508.0f},
};

// @ghidraAddress 0x30523c
constexpr float kRankGlyphAbsoluteY = 653.0f;

constexpr int kBadgeGlyphCount = 7;
constexpr int kBadgeGlyphFirstKind = 8;
constexpr int kBadgeAlphaKnots = 4;
constexpr int kBadgePositionKnots = 9;

// @ghidraAddress 0x3052c4
constexpr float kBadgeGlyphAbsoluteX[kBadgeGlyphCount] = {
    193.0f, 259.0f, 319.0f, 362.0f, 420.0f, 501.0f, 578.0f};

// @ghidraAddress 0x3055f4
constexpr float kBadgeAlphaCurve[kBadgeGlyphCount][kBadgeAlphaKnots * 2] = {
    {50.0f, 0.0f, 233.33333f, 1.0f, 2000.0f, 1.0f, 2333.3333f, 0.0f},
    {150.0f, 0.0f, 333.33334f, 1.0f, 2000.0f, 1.0f, 2333.3333f, 0.0f},
    {0.0f, 0.0f, 183.33333f, 1.0f, 2000.0f, 1.0f, 2333.3333f, 0.0f},
    {66.666664f, 0.0f, 250.0f, 1.0f, 2000.0f, 1.0f, 2333.3333f, 0.0f},
    {166.66667f, 0.0f, 350.0f, 1.0f, 2000.0f, 1.0f, 2333.3333f, 0.0f},
    {0.0f, 0.0f, 183.33333f, 1.0f, 2000.0f, 1.0f, 2333.3333f, 0.0f},
    {116.66667f, 0.0f, 300.0f, 1.0f, 2000.0f, 1.0f, 2333.3333f, 0.0f},
};

// The binary caches these Y values minus the layout origin; since the origin is constant, sampling
// the absolute-Y curve and subtracting is equivalent.
constexpr float kBadgePositionCurve[kBadgeGlyphCount][kBadgePositionKnots * 2] = {
    {16.66667f,
     581.0f,
     50.0f,
     583.0f,
     233.33333f,
     653.0f,
     400.0f,
     623.0f,
     533.33331f,
     653.0f,
     666.66669f,
     639.0f,
     783.33331f,
     653.0f,
     1133.33337f,
     660.0f,
     3100.0f,
     703.0f},
    {150.0f,
     583.0f,
     333.33334f,
     653.0f,
     500.0f,
     623.0f,
     633.33331f,
     653.0f,
     766.66669f,
     639.0f,
     883.33331f,
     653.0f,
     3100.0f,
     733.0f,
     3116.66675f,
     733.0f,
     3133.33325f,
     733.0f},
    {0.0f,
     583.0f,
     183.33333f,
     653.0f,
     350.0f,
     623.0f,
     483.33334f,
     653.0f,
     616.66669f,
     639.0f,
     733.33331f,
     653.0f,
     3100.0f,
     723.0f,
     3116.66675f,
     723.0f,
     3133.33325f,
     723.0f},
    {66.66666f,
     583.0f,
     250.0f,
     653.0f,
     416.66666f,
     623.0f,
     550.0f,
     653.0f,
     683.33331f,
     639.0f,
     800.0f,
     653.0f,
     3100.0f,
     761.0f,
     3116.66675f,
     761.0f,
     3133.33325f,
     761.0f},
    {166.66667f,
     583.0f,
     350.0f,
     653.0f,
     516.66669f,
     623.0f,
     650.0f,
     653.0f,
     783.33331f,
     639.0f,
     900.0f,
     653.0f,
     3100.0f,
     743.0f,
     3116.66675f,
     743.0f,
     3133.33325f,
     743.0f},
    {0.0f,
     583.0f,
     183.33333f,
     653.0f,
     350.0f,
     623.0f,
     483.33334f,
     653.0f,
     616.66669f,
     639.0f,
     733.33331f,
     653.0f,
     3100.0f,
     723.0f,
     3116.66675f,
     723.0f,
     3133.33325f,
     723.0f},
    {116.66666f,
     621.0f,
     300.0f,
     691.0f,
     466.66666f,
     661.0f,
     600.0f,
     691.0f,
     733.33331f,
     677.0f,
     850.0f,
     691.0f,
     3100.0f,
     791.0f,
     3116.66675f,
     791.0f,
     3133.33325f,
     791.0f},
};

constexpr float kBadgeGlyphScale = 1.0f;

// @ghidraAddress 0x305318, 0x2fd044, 0x300fb0, 0x305324, 0x2eedc8, 0x305328, 0x30532c
constexpr float kMeterAbsoluteX = 204.0f;
constexpr float kMeterAnchorX = 85.0f;
constexpr float kMeterAnchorY = 75.0f;
constexpr float kMeterSizeX = 170.0f;
constexpr float kMeterSizeY = 150.0f;
constexpr float kMeterUvSizeU = 0.166015625f;
constexpr float kMeterUvSizeV = 0.146484375f;
constexpr float kMeterSpriteScale = 1.0f;

constexpr int kSideCount = 2;

// @ghidraAddress 0x30531c, 0x305320
constexpr float kMeterPadAbsoluteY[kSideCount] = {640.0f, 740.0f};
constexpr float kMeterPhoneOffsetY[kSideCount] = {-45.0f, 45.0f};

// @ghidraAddress 0x2fe894
constexpr float kMeterSingleSideOverrideX = 204.0f;
constexpr float kMeterSingleSideRotation = 3.1415927f;

constexpr int kArDigitGlyphCount = 35;
constexpr int kArDigitGlyphFirstKind = 15;
constexpr int kArDigitKnots = 3;

// @ghidraAddress 0x305330
constexpr float kArDigitAbsoluteX[kArDigitGlyphCount] = {
    74.0f,  74.0f,  194.0f, 194.0f, 454.0f, 454.0f, 229.0f, 229.0f, 545.0f, 545.0f, 725.0f, 725.0f,
    564.0f, 564.0f, 234.0f, 234.0f, 657.0f, 657.0f, 464.0f, 464.0f, 593.0f, 593.0f, 593.0f, 593.0f,
    334.0f, 334.0f, 134.0f, 134.0f, 644.0f, 644.0f, 71.0f,  71.0f,  424.0f, 424.0f, 384.0f};

// @ghidraAddress 0x305a1c
constexpr float kArDigitScaleCurve[kArDigitGlyphCount][kArDigitKnots * 2] = {
    {333.333344f, 0.0f, 1000.0f, 0.5f, 1016.666687f, 0.5f},
    {333.333344f, 0.0f, 1000.0f, 0.5f, 1016.666687f, 0.5f},
    {333.333344f, 0.0f, 1000.0f, 0.5f, 1016.666687f, 0.5f},
    {333.333344f, 0.0f, 1000.0f, 0.5f, 1016.666687f, 0.5f},
    {166.666672f, 0.0f, 833.333313f, 0.5f, 850.0f, 0.5f},
    {166.666672f, 0.0f, 833.333313f, 0.5f, 850.0f, 0.5f},
    {333.333344f, 0.0f, 1000.0f, 0.5f, 1016.666687f, 0.5f},
    {333.333344f, 0.0f, 1000.0f, 0.5f, 1016.666687f, 0.5f},
    {333.333344f, 0.0f, 1000.0f, 0.5f, 1016.666687f, 0.5f},
    {333.333344f, 0.0f, 1000.0f, 0.5f, 1016.666687f, 0.5f},
    {333.333344f, 0.0f, 1000.0f, 0.5f, 1016.666687f, 0.5f},
    {333.333344f, 0.0f, 1000.0f, 0.5f, 1016.666687f, 0.5f},
    {166.666672f, 0.0f, 333.333344f, 0.6f, 833.333313f, 0.8f},
    {166.666672f, 0.0f, 333.333344f, 0.6f, 833.333313f, 0.8f},
    {0.0f, 0.0f, 166.666672f, 0.4f, 666.666687f, 0.7f},
    {0.0f, 0.0f, 166.666672f, 0.4f, 666.666687f, 0.7f},
    {0.0f, 0.0f, 166.666672f, 0.5f, 666.666687f, 1.0f},
    {0.0f, 0.0f, 166.666672f, 0.5f, 666.666687f, 1.0f},
    {0.0f, 0.0f, 166.666672f, 0.8f, 666.666687f, 1.0f},
    {0.0f, 0.0f, 166.666672f, 0.8f, 666.666687f, 1.0f},
    {0.0f, 0.0f, 166.666672f, 0.4f, 666.666687f, 1.0f},
    {0.0f, 0.0f, 166.666672f, 0.4f, 666.666687f, 1.0f},
    {0.0f, 0.0f, 166.666672f, 0.4f, 666.666687f, 1.0f},
    {0.0f, 0.0f, 166.666672f, 0.4f, 666.666687f, 1.0f},
    {0.0f, 0.0f, 166.666672f, 0.8f, 666.666687f, 1.0f},
    {0.0f, 0.0f, 166.666672f, 0.8f, 666.666687f, 1.0f},
    {333.333344f, 0.0f, 500.0f, 0.4f, 1000.0f, 0.5f},
    {333.333344f, 0.0f, 500.0f, 0.4f, 1000.0f, 0.5f},
    {250.0f, 0.0f, 416.666656f, 0.4f, 916.666687f, 0.5f},
    {250.0f, 0.0f, 416.666656f, 0.4f, 916.666687f, 0.5f},
    {0.0f, 0.0f, 166.666672f, 0.6f, 666.666687f, 1.0f},
    {0.0f, 0.0f, 166.666672f, 0.6f, 666.666687f, 1.0f},
    {83.333336f, 0.0f, 250.0f, 0.6f, 750.0f, 1.0f},
    {83.333336f, 0.0f, 250.0f, 0.8f, 750.0f, 1.0f},
    {166.666672f, 0.0f, 333.333344f, 0.6f, 833.333313f, 1.0f},
};

// @ghidraAddress 0x3056d4
constexpr float kArDigitAlphaCurve[kArDigitGlyphCount][kArDigitKnots * 2] = {
    {483.333344f, 0.0f, 500.0f, 1.0f, 1000.0f, 0.0f},
    {466.666656f, 0.0f, 483.333344f, 1.0f, 650.0f, 0.0f},
    {483.333344f, 0.0f, 500.0f, 1.0f, 1000.0f, 0.0f},
    {466.666656f, 0.0f, 483.333344f, 1.0f, 650.0f, 0.0f},
    {316.666656f, 0.0f, 333.333344f, 1.0f, 833.333313f, 0.0f},
    {300.0f, 0.0f, 316.666656f, 1.0f, 483.333344f, 0.0f},
    {483.333344f, 0.0f, 500.0f, 1.0f, 1000.0f, 0.0f},
    {466.666656f, 0.0f, 483.333344f, 1.0f, 650.0f, 0.0f},
    {483.333344f, 0.0f, 500.0f, 1.0f, 1000.0f, 0.0f},
    {466.666656f, 0.0f, 483.333344f, 1.0f, 650.0f, 0.0f},
    {483.333344f, 0.0f, 500.0f, 1.0f, 1000.0f, 0.0f},
    {466.666656f, 0.0f, 483.333344f, 1.0f, 650.0f, 0.0f},
    {316.666656f, 0.0f, 333.333344f, 1.0f, 833.333313f, 0.0f},
    {466.666656f, 0.0f, 483.333344f, 1.0f, 650.0f, 0.0f},
    {150.0f, 0.0f, 166.666672f, 1.0f, 666.666687f, 0.0f},
    {133.333328f, 0.0f, 150.0f, 1.0f, 483.333344f, 0.0f},
    {150.0f, 0.0f, 166.666672f, 1.0f, 666.666687f, 0.0f},
    {133.333328f, 0.0f, 150.0f, 1.0f, 483.333344f, 0.0f},
    {150.0f, 0.0f, 166.666672f, 1.0f, 666.666687f, 0.0f},
    {133.333328f, 0.0f, 150.0f, 1.0f, 483.333344f, 0.0f},
    {150.0f, 0.0f, 166.666672f, 1.0f, 666.666687f, 0.0f},
    {133.333328f, 0.0f, 150.0f, 1.0f, 483.333344f, 0.0f},
    {150.0f, 0.0f, 166.666672f, 1.0f, 666.666687f, 0.0f},
    {133.333328f, 0.0f, 150.0f, 1.0f, 483.333344f, 0.0f},
    {150.0f, 0.0f, 166.666672f, 1.0f, 666.666687f, 0.0f},
    {133.333328f, 0.0f, 150.0f, 1.0f, 483.333344f, 0.0f},
    {483.333344f, 0.0f, 500.0f, 1.0f, 1000.0f, 0.0f},
    {466.666656f, 0.0f, 483.333344f, 1.0f, 650.0f, 0.0f},
    {400.0f, 0.0f, 583.333313f, 1.0f, 916.666687f, 0.0f},
    {466.666656f, 0.0f, 483.333344f, 1.0f, 650.0f, 0.0f},
    {150.0f, 0.0f, 166.666672f, 1.0f, 666.666687f, 0.0f},
    {133.333328f, 0.0f, 150.0f, 1.0f, 316.666656f, 0.0f},
    {233.333328f, 0.0f, 250.0f, 1.0f, 750.0f, 0.0f},
    {216.666672f, 0.0f, 233.333328f, 1.0f, 400.0f, 0.0f},
    {216.666672f, 0.0f, 233.333328f, 1.0f, 400.0f, 0.0f},
};

constexpr float kArDigitPositionCurve[kArDigitGlyphCount][kArDigitKnots * 2] = {
    {333.33334f, 738.0f, 500.0f, 730.5f, 1000.0f, 716.5f},
    {333.33334f, 738.0f, 500.0f, 730.5f, 1000.0f, 716.5f},
    {333.33334f, 768.0f, 500.0f, 760.5f, 1000.0f, 746.5f},
    {333.33334f, 768.0f, 500.0f, 760.5f, 1000.0f, 746.5f},
    {166.66667f, 638.0f, 333.33334f, 630.5f, 833.33331f, 616.5f},
    {166.66667f, 638.0f, 333.33334f, 630.5f, 833.33331f, 616.5f},
    {316.66666f, 584.0f, 333.33334f, 584.0f, 1000.0f, 554.0f},
    {316.66666f, 584.0f, 333.33334f, 584.0f, 1000.0f, 554.0f},
    {316.66666f, 590.0f, 333.33334f, 590.0f, 1000.0f, 560.0f},
    {316.66666f, 590.0f, 333.33334f, 590.0f, 1000.0f, 560.0f},
    {316.66666f, 647.0f, 333.33334f, 647.0f, 1000.0f, 617.0f},
    {316.66666f, 647.0f, 333.33334f, 647.0f, 1000.0f, 617.0f},
    {166.66667f, 764.0f, 333.33334f, 739.0f, 833.33331f, 724.0f},
    {166.66667f, 764.0f, 333.33334f, 739.0f, 833.33331f, 724.0f},
    {0.0f, 794.0f, 166.66667f, 744.0f, 666.66669f, 724.0f},
    {0.0f, 794.0f, 166.66667f, 744.0f, 666.66669f, 724.0f},
    {0.0f, 609.0f, 166.66667f, 559.0f, 666.66669f, 539.0f},
    {0.0f, 609.0f, 166.66667f, 559.0f, 666.66669f, 539.0f},
    {0.0f, 815.0f, 166.66667f, 765.0f, 666.66669f, 745.0f},
    {0.0f, 815.0f, 166.66667f, 765.0f, 666.66669f, 745.0f},
    {0.0f, 802.0f, 166.66667f, 752.0f, 666.66669f, 732.0f},
    {0.0f, 802.0f, 166.66667f, 752.0f, 666.66669f, 732.0f},
    {0.0f, 802.0f, 166.66667f, 752.0f, 666.66669f, 732.0f},
    {0.0f, 802.0f, 166.66667f, 752.0f, 666.66669f, 732.0f},
    {0.0f, 704.0f, 166.66667f, 674.0f, 666.66669f, 654.0f},
    {0.0f, 704.0f, 166.66667f, 674.0f, 666.66669f, 654.0f},
    {333.33334f, 704.0f, 500.0f, 674.0f, 1000.0f, 644.0f},
    {333.33334f, 704.0f, 500.0f, 674.0f, 1000.0f, 644.0f},
    {333.33334f, 704.0f, 500.0f, 674.0f, 1000.0f, 644.0f},
    {250.0f, 704.0f, 416.66666f, 674.0f, 916.66669f, 644.0f},
    {0.0f, 709.0f, 166.66667f, 695.0f, 666.66669f, 659.0f},
    {0.0f, 709.0f, 166.66667f, 695.0f, 666.66669f, 659.0f},
    {83.33334f, 594.0f, 250.0f, 564.0f, 750.0f, 544.0f},
    {83.33334f, 594.0f, 250.0f, 564.0f, 750.0f, 544.0f},
    {166.66667f, 574.0f, 333.33334f, 524.0f, 833.33331f, 494.0f},
};

} // namespace

/** @ghidraAddress 0x120630 */
LimelightThemeLayer::LimelightThemeLayer() {
    m_flWidth = kLayoutWidth;
    m_flHeight = kLayoutHeight;
    m_nSideCount = kDefaultSideCount;
    for (int &nValue : m_aGradeValues) {
        nValue = kGradeValueDefault;
    }
}

/** @ghidraAddress 0x1206c8 */
LimelightThemeLayer *LimelightThemeLayer::shared() {
    if (g_pLimelightThemeLayer == nullptr) {
        g_pLimelightThemeLayer = new LimelightThemeLayer();
    }
    return g_pLimelightThemeLayer;
}

/** @ghidraAddress 0x120718 */
void LimelightThemeLayer::InitFullComboLayerTextures() {
    if (m_bBuilt) {
        return;
    }

    BgLayer *pBackgroundLayer = BgLayer::GetBackgroundLayer();
    ne::C_RENDER *pParent = pBackgroundLayer->GetBackgroundRenderObject();

    m_pPartsTexture = ne::C_TEXTURE::FindOrLoadCached(kPartsTextureName);
    m_pEffectTexture = ne::C_TEXTURE::FindOrLoadCached(kEffectTextureName);
    m_pWinTexture = ne::C_TEXTURE::FindOrLoadCached(kWinTextureName);

    ne::C_TEXTURE *const apTextureFields[] = {m_pPartsTexture, m_pEffectTexture, m_pWinTexture};

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

/** @ghidraAddress 0x120900 */
void LimelightThemeLayer::StartGradeAnimation(float flDuration) {
    m_gradeChannel.SetStart(m_gradeChannel.GetCurrent());
    m_gradeChannel.SetEnd(0.0f);
    m_gradeChannel.SetDuration(flDuration);
    m_gradeChannel.SetElapsed(0.0f);
    if (flDuration <= 0.0f) {
        m_gradeChannel.SetCurrent(0.0f);
    }
}

/** @ghidraAddress 0x120a74 */
void LimelightThemeLayer::AdvanceGradeChannel(float flDeltaTime) {
    m_gradeChannel.Advance(flDeltaTime);
}

/** @ghidraAddress 0x120920 */
void LimelightThemeLayer::UpdateGradeDisplay(float flDeltaTime) {
    GameSystem *pGameSystem = GameSystem::GetGameSystem();
    m_flCachedViewportWidth = pGameSystem->GetViewportWidth();
    m_flCachedViewportHeight = pGameSystem->GetViewportHeight();
    m_aSpriteCounts[0] = 0;
    m_aSpriteCounts[1] = 0;
    m_aSpriteCounts[2] = 0;
    m_aSpriteCounts[3] = 0;

    AdvanceGradeChannel(flDeltaTime);

    if (m_bGradeClockActive) {
        // The visible flag only gates the clock; the clock flag gates the whole display.
        if (m_bGradeVisible) {
            m_flGradeRevealClock += flDeltaTime;
        }
        if (m_flGradeRevealClock >= m_flGradeRevealDuration) {
            m_bGradeVisible = false;
        }
        const float flReveal = CalculateCurveInterpolation(
            kGradeRevealCurve, kGradeRevealCurvePairs, m_flGradeRevealClock);
        S_VECTOR2 basePos{0.0f, 0.0f};
        EmitGradeSpriteSlot(
            1.0f,
            1.0f,
            0.0f,
            kGradeBaseKind,
            &basePos,
            static_cast<unsigned int>(flReveal * m_gradeChannel.GetCurrent() * kAlphaByteScale));

        for (int nSide = 0; nSide < kSideCount; ++nSide) {
            if (m_nSideCount == 0 && nSide == 0) {
                continue;
            }
            const int nGrade = m_aGradeValues[nSide];
            const int nRank =
                ScoreTracker::shared()->GetPlayRecordRank(static_cast<unsigned int>(nSide));
            if (nGrade == 0) {
                RenderGradeMeterSprite(static_cast<unsigned int>(nSide));
            }
            if (nRank < kMinRankGlyphs) {
                RenderGradeHighRankBadge(nSide);
            } else {
                RenderGradeRankGlyphs(nSide);
            }
        }
    }

    for (int nSlot = 0; nSlot < kSpriteSlotCount; ++nSlot) {
        m_apSprites[nSlot]->SetSpriteCount(m_aSpriteCounts[nSlot]);
    }
}

/** @ghidraAddress 0x120abc */
void LimelightThemeLayer::EmitGradeSpriteSlot(float flScaleX,
                                              float flScaleY,
                                              float flRotation,
                                              unsigned int nSpriteKind,
                                              const S_VECTOR2 *pPosition,
                                              unsigned int nAlpha) {
    const GradeSpriteLayout &layout = kGradeSpriteLayout[nSpriteKind];
    const SpriteUvEntry &uv = (nSpriteKind >= 1 && nSpriteKind <= kMaxSharedAtlasKind) ?
                                  g_aSpriteUvTable[layout.nAtlasFrame] :
                                  g_aTitlePartUvDefault[layout.nAtlasFrame];

    const int nSlot = kGroupToSlot[layout.nGroup];
    ne::C_SPRITE_INSTANCING_2D *pBatch = m_apSprites[nSlot];
    const int nIndex = m_aSpriteCounts[nSlot];
    if (nIndex >= static_cast<int>(kSlotCapacities[nSlot])) {
        return;
    }

    const float flCentreY = static_cast<float>(g_nPlayfieldFullHeightY / 2);
    pBatch->SetSpritePositionXY(nIndex, pPosition->x, pPosition->y + flCentreY);
    pBatch->SetSpriteAnchor(nIndex, S_VECTOR2{layout.flAnchorX, layout.flAnchorY});
    pBatch->SetSpriteSize(nIndex, S_VECTOR2{layout.flSizeX, layout.flSizeY});
    pBatch->SetSpriteUvOrigin(nIndex, S_VECTOR2{uv.flOriginU, uv.flOriginV});
    pBatch->SetSpriteUvSize(nIndex, S_VECTOR2{uv.flSizeU, uv.flSizeV});
    pBatch->SetSpriteScale(nIndex, flScaleX, flScaleY);
    pBatch->SetSpriteRotation(nIndex, flRotation);

    const unsigned int nChannel =
        nSpriteKind == kBackdropSpriteKind ? kChannelBlack : kChannelWhite;
    pBatch->SetSpriteColor(nIndex, nChannel, nChannel, nChannel, nAlpha);
    ++m_aSpriteCounts[nSlot];
}

/** @ghidraAddress 0x120ca0 */
void LimelightThemeLayer::RenderGradeMeterSprite(unsigned int nSide) {
    if (m_flGradeRevealClock <= kMeterStartThreshold) {
        return;
    }

    if (m_bGradeArmed) {
        SoundEffectManager::GetInstance()->PlayThemedSoundEffect(kMeterFanfareSoundEffect);
        m_bGradeArmed = false;
    }

    // The binary tests the raw index, before the zero clamp, against the frame count.
    const int nRawFrame = static_cast<int>(
        ((m_flGradeRevealClock + kMeterClockBias) / kMeterClockDivisor) * kMeterNeedleFrameCount);
    int nFrame = nRawFrame < 0 ? 0 : nRawFrame;
    if (nRawFrame >= kMeterNeedleFrameCount) {
        nFrame = kMeterNeedleLastFrame;
    }

    const unsigned int nAlpha = m_flGradeRevealClock > kMeterFadeThreshold ? kChannelBlack : 0xff;

    EmitGradeMeterSlot(nSide, &kMeterNeedleUv[nFrame], nAlpha);
}

/** @ghidraAddress 0x121bb8 */
void LimelightThemeLayer::EmitGradeMeterSlot(unsigned int nSide,
                                             const S_VECTOR2 *pUvOrigin,
                                             unsigned int nAlpha) {
    constexpr int nSlot = 3;
    const int nIndex = m_aSpriteCounts[nSlot];
    if (nIndex >= static_cast<int>(kSlotCapacities[nSlot])) {
        return;
    }
    ne::C_SPRITE_INSTANCING_2D *pBatch = m_apSprites[nSlot];

    float flPosX = kMeterAbsoluteX - m_flWidth;
    float flPosY;
    float flRotation = 0.0f;
    if (IsPad()) {
        flPosY = kMeterPadAbsoluteY[nSide] - m_flHeight;
        // The single-side override is a raw position, not made relative to the layout origin.
        if (m_nSideCount == 1 && nSide == 0) {
            flPosX = kMeterSingleSideOverrideX;
            flRotation = kMeterSingleSideRotation;
        }
    } else {
        flPosY = kMeterPhoneOffsetY[nSide];
    }

    flPosY += static_cast<float>(g_nPlayfieldFullHeightY / 2);

    pBatch->SetSpritePositionXY(nIndex, flPosX, flPosY);
    pBatch->SetSpriteAnchor(nIndex, S_VECTOR2{kMeterAnchorX, kMeterAnchorY});
    pBatch->SetSpriteSize(nIndex, S_VECTOR2{kMeterSizeX, kMeterSizeY});
    pBatch->SetSpriteUvOrigin(nIndex, *pUvOrigin);
    pBatch->SetSpriteUvSize(nIndex, S_VECTOR2{kMeterUvSizeU, kMeterUvSizeV});
    pBatch->SetSpriteScale(nIndex, kMeterSpriteScale, kMeterSpriteScale);
    pBatch->SetSpriteRotation(nIndex, flRotation);
    pBatch->SetSpriteColor(nIndex, kChannelWhite, kChannelWhite, kChannelWhite, nAlpha);
    ++m_aSpriteCounts[nSlot];
}

/** @ghidraAddress 0x120e50 */
void LimelightThemeLayer::RenderGradeRankGlyphs(int nSide) {
    if (m_flGradeRevealClock > kArDigitsRevealThreshold) {
        RenderGradeArDigits(m_flGradeRevealClock + kArDigitsClockOffset,
                            static_cast<unsigned int>(nSide));
    }

    const float flClock = m_flGradeRevealClock;
    const float flOriginX = m_flWidth;
    const float flOriginY = m_flHeight;
    const float flGlyphY = kRankGlyphAbsoluteY - flOriginY;

    for (int nGlyph = 0; nGlyph < kRankGlyphCount; ++nGlyph) {
        const float flScale =
            CalculateCurveInterpolation(kRankScaleCurve[nGlyph], kRankScaleKnots, flClock);
        const float flAlpha =
            CalculateCurveInterpolation(kRankAlphaCurve[nGlyph], kRankAlphaKnots, flClock);
        const float flAbsoluteX =
            CalculateCurveInterpolation(kRankPositionCurve[nGlyph], kRankPositionKnots, flClock);

        S_VECTOR2 position{flAbsoluteX - flOriginX, flGlyphY};
        float flRotation = 0.0f;
        if (m_nSideCount == 1) {
            if (nSide == kNearSide) {
                position.y += kSingleSideNearNudgeY;
            } else {
                position.x = -position.x;
                position.y = kSingleSideFarOriginY - position.y;
                flRotation = kSingleSideFarRotation;
            }
        }

        const unsigned int nAlpha = static_cast<unsigned int>(
            static_cast<int>(flAlpha * m_gradeChannel.GetCurrent() * kAlphaByteScale));
        EmitGradeSpriteSlot(flScale,
                            flScale,
                            flRotation,
                            static_cast<unsigned int>(kRankGlyphFirstKind + nGlyph),
                            &position,
                            nAlpha);
    }
}

/** @ghidraAddress 0x1214ec */
void LimelightThemeLayer::RenderGradeHighRankBadge(int nSide) {
    const float flClock = m_flGradeRevealClock;
    const float flOriginX = m_flWidth;
    const float flOriginY = m_flHeight;

    for (int nGlyph = 0; nGlyph < kBadgeGlyphCount; ++nGlyph) {
        const float flAlpha =
            CalculateCurveInterpolation(kBadgeAlphaCurve[nGlyph], kBadgeAlphaKnots, flClock);
        const float flAbsoluteY =
            CalculateCurveInterpolation(kBadgePositionCurve[nGlyph], kBadgePositionKnots, flClock);

        S_VECTOR2 position{kBadgeGlyphAbsoluteX[nGlyph] - flOriginX, flAbsoluteY - flOriginY};
        float flRotation = 0.0f;
        if (m_nSideCount == 1) {
            if (nSide == kNearSide) {
                position.y += kSingleSideNearNudgeY;
            } else {
                position.x = -position.x;
                position.y = kSingleSideFarOriginY - position.y;
                flRotation = kSingleSideFarRotation;
            }
        }

        const unsigned int nAlpha = static_cast<unsigned int>(
            static_cast<int>(flAlpha * m_gradeChannel.GetCurrent() * kAlphaByteScale));
        EmitGradeSpriteSlot(kBadgeGlyphScale,
                            kBadgeGlyphScale,
                            flRotation,
                            static_cast<unsigned int>(kBadgeGlyphFirstKind + nGlyph),
                            &position,
                            nAlpha);
    }
}

/** @ghidraAddress 0x121e14 */
void LimelightThemeLayer::RenderGradeArDigits(float flClock, unsigned int nSide) {
    const float flOriginX = m_flWidth;
    const float flOriginY = m_flHeight;

    for (int nGlyph = 0; nGlyph < kArDigitGlyphCount; ++nGlyph) {
        // The position curve is sampled at the layer's reveal clock, not the digit clock.
        const float flScale =
            CalculateCurveInterpolation(kArDigitScaleCurve[nGlyph], kArDigitKnots, flClock);
        const float flAlpha =
            CalculateCurveInterpolation(kArDigitAlphaCurve[nGlyph], kArDigitKnots, flClock);
        const float flAbsoluteY = CalculateCurveInterpolation(
            kArDigitPositionCurve[nGlyph], kArDigitKnots, m_flGradeRevealClock);

        S_VECTOR2 position{kArDigitAbsoluteX[nGlyph] - flOriginX, flAbsoluteY - flOriginY};
        float flRotation = 0.0f;
        if (m_nSideCount == 1) {
            if (nSide == static_cast<unsigned int>(kNearSide)) {
                position.y += kSingleSideNearNudgeY;
            } else {
                position.x = -position.x;
                position.y = kSingleSideFarOriginY - position.y;
                flRotation = kSingleSideFarRotation;
            }
        }

        // The grade reveal channel is deliberately not applied to the digit strip.
        const unsigned int nAlpha =
            static_cast<unsigned int>(static_cast<int>(flAlpha * kAlphaByteScale));
        EmitGradeSpriteSlot(flScale,
                            flScale,
                            flRotation,
                            static_cast<unsigned int>(kArDigitGlyphFirstKind + nGlyph),
                            &position,
                            nAlpha);
    }
}

/** @ghidraAddress 0x1208c4 */
void LimelightThemeLayer::InitializeGradeValuesFromTracker() {
    for (int nSide = 0; nSide < kSideCount; ++nSide) {
        m_aGradeValues[nSide] =
            ScoreTracker::shared()->GetPlayRecordField10(static_cast<unsigned int>(nSide));
    }
}

/** @ghidraAddress 0x120844 */
void LimelightThemeLayer::InitializeGradeDisplayState() {
    m_gradeChannel.SetStart(kGradeChannelFull);
    m_gradeChannel.SetEnd(kGradeChannelFull);
    m_gradeChannel.SetDuration(0.0f);
    m_gradeChannel.SetElapsed(0.0f);
    m_gradeChannel.SetCurrent(kGradeChannelFull);
    m_flGradeRevealClock = kGradeClockStart;
    m_bGradeVisible = true;
    m_bGradeClockActive = true;
    m_bGradeArmed = true;
    InitializeGradeValuesFromTracker();

    m_flGradeRevealDuration = kGradeRevealDurationDual;
    if (m_nSideCount == 1 || m_aGradeValues[1] == 0) {
        m_flGradeRevealDuration = kGradeRevealDurationSingle;
    }
}
