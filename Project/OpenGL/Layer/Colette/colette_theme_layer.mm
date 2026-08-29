#include "colette_theme_layer.h"

#include "../Share/bg_layer.h"
#import "RBUserSettingData.h"
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

static ColetteThemeLayer *g_pColetteThemeLayer = nullptr; // @ghidraAddress 0x3def58

namespace {

// @ghidraAddress 0x3ceaa8 and 0x3ceaf0
constexpr const char *kPartsTextureName = "00_texture/gm_parts2";
constexpr const char *kEffectTextureName = "00_texture/ti_parts_eff";

// @ghidraAddress 0x30e84c
constexpr unsigned int kSlotCapacities[] = {1, 100, 100, 2};

// The 4 is the binary's own dead value: slot 0 binds no texture, so its entry is never read.
// @ghidraAddress 0x30e85c
constexpr int kSlotTextureField[] = {4, 0, 1, 2};

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

constexpr unsigned int kColorMax = 255;

struct FcSpriteDescriptor {
    int nBatchKind;    // +0x00: the batch-kind selector (indexes the batch-index table).
    float flAnchorX;   // +0x04: the sprite's anchor X.
    float flAnchorY;   // +0x08: the sprite's anchor Y.
    float flSizeX;     // +0x0c: the sprite's pixel width.
    float flSizeY;     // +0x10: the sprite's pixel height.
    int nUvFrameIndex; // +0x14: the frame into the shared sprite UV atlas.
};

// @ghidraAddress 0x30f494
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

// @ghidraAddress 0x30f6d4
constexpr unsigned int kFcBatchIndex[] = {1, 2, 3, 4, 0};

constexpr unsigned int kFcShadowSlot = 0;

// @ghidraAddress 0x30e86c
constexpr unsigned int kFcBaseSlot = 0;
constexpr int kFcBaseCurvePairs = 2;
constexpr float kFcBaseCurve[] = {-500.0f, 0.0f, -333.33334f, 0.75f};
constexpr int kFcClearRankMax = 1;

constexpr int kMissSpriteCount = 6;
constexpr int kMissScaleCurvePairs = 0xe;
constexpr int kMissScaleCurveFloats = kMissScaleCurvePairs * 2;
constexpr int kMissRotCurvePairs = 2;
constexpr int kMissRotCurveFloats = kMissRotCurvePairs * 2;
constexpr int kBannerCurvePairs4 = 4;
constexpr int kBannerCurvePairs2 = 2;
constexpr unsigned int kMissSpriteSlotBase = 2;
constexpr unsigned int kMissBannerSlot = 1;

// @ghidraAddress 0x30e800, @ghidraAddress 0x301f78, @ghidraAddress 0x3052c0,
// @ghidraAddress 0x2fe894, @ghidraAddress 0x2eed00
constexpr float kMissReferenceY = 663.0f;
constexpr float kMissSecondSideShiftY = 200.0f;
constexpr float kMissFirstSideReflectY = -200.0f;
constexpr float kMissMirrorRotation = 3.1415927f;
constexpr float kFcAlphaByteScale = 255.0f;

constexpr int kSingleSide = 1;
constexpr int kSecondSide = 1;

// @ghidraAddress 0x3defa0
constexpr float kMissSpriteX[kMissSpriteCount] = {-177.0f, -106.0f, -38.0f, 40.0f, 118.0f, 185.0f};

constexpr int kRankMedalCount = 7;
constexpr int kRankScaleCurvePairs = 9;
constexpr int kRankScaleCurveFloats = kRankScaleCurvePairs * 2;
constexpr int kRankAlphaCurvePairs = 3;
constexpr int kRankAlphaCurveFloats = kRankAlphaCurvePairs * 2;
constexpr int kRankRotCurvePairs = 2;
constexpr int kRankRotCurveFloats = kRankRotCurvePairs * 2;
constexpr int kRankOffsetCurvePairs = 3;
constexpr int kRankOffsetCurveFloats = kRankOffsetCurvePairs * 2;
constexpr unsigned int kRankSpriteSlotBase = 0x11;

// @ghidraAddress 0x305220 start, 0x30522c end, 0x305224 offset
constexpr float kRankWindowStart = 3166.6667f;
constexpr float kRankWindowEnd = 4833.3335f;
constexpr float kRankTimerOffset = -3166.6667f;

// @ghidraAddress 0x2ec6b0, 0x2fcfec
constexpr float kRankSecondSideShiftY = 100.0f;
constexpr float kRankFirstSideReflectY = -100.0f;
constexpr int kRankSoundEffect = 10;

// Double precision, as the binary computes it (@ghidraAddress 0x2f85a0).
constexpr double kRankMirrorRotation = 3.141592653589793;

// @ghidraAddress 0x30e804
constexpr int kResultSpriteCount = 9;
constexpr int kResultAlphaCurvePairs = 2;
constexpr int kResultAlphaCurveFloats = kResultAlphaCurvePairs * 2;
constexpr int kResultScaleCurvePairs = 9;
constexpr int kResultScaleCurveFloats = kResultScaleCurvePairs * 2;
constexpr int kResultPosCurvePairs = 7;
constexpr int kResultPosCurveFloats = kResultPosCurvePairs * 2;
constexpr unsigned int kResultSpriteSlotBase = 8;
constexpr float kResultReferenceY = 860.0f;

// @ghidraAddress 0x30f17c
constexpr float kResultAlphaCurve[kResultSpriteCount][kResultAlphaCurveFloats] = {
    {2000.0f, 1.0f, 2333.3333f, 0.0f},
    {2000.0f, 1.0f, 2333.3333f, 0.0f},
    {2000.0f, 1.0f, 2333.3333f, 0.0f},
    {2000.0f, 1.0f, 2333.3333f, 0.0f},
    {2000.0f, 1.0f, 2333.3333f, 0.0f},
    {2000.0f, 1.0f, 2333.3333f, 0.0f},
    {2000.0f, 1.0f, 2333.3333f, 0.0f},
    {2000.0f, 1.0f, 2333.3333f, 0.0f},
    {2000.0f, 1.0f, 2333.3333f, 0.0f},
};

// @ghidraAddress 0x30f20c
constexpr float kResultScaleCurve[kResultSpriteCount][kResultScaleCurveFloats] = {
    {633.3333f,
     0.0f,
     800.0f,
     1.1f,
     883.3333f,
     1.0f,
     966.6667f,
     1.05f,
     1016.6667f,
     1.0f,
     1066.6666f,
     1.02f,
     1100.0f,
     1.0f,
     1133.3334f,
     1.02f,
     1166.6666f,
     1.0f},
    {433.33334f,
     0.0f,
     600.0f,
     1.1f,
     683.3333f,
     1.0f,
     766.6667f,
     1.05f,
     816.6667f,
     1.0f,
     866.6667f,
     1.02f,
     900.0f,
     1.0f,
     933.3333f,
     1.02f,
     966.6667f,
     1.0f},
    {216.66667f,
     0.0f,
     383.33334f,
     1.1f,
     466.66666f,
     1.0f,
     550.0f,
     1.05f,
     600.0f,
     1.0f,
     650.0f,
     1.02f,
     683.3333f,
     1.0f,
     716.6667f,
     1.02f,
     750.0f,
     1.0f},
    {0.0f,
     0.0f,
     166.66667f,
     1.1f,
     250.0f,
     1.0f,
     333.33334f,
     1.05f,
     383.33334f,
     1.0f,
     433.33334f,
     1.02f,
     466.66666f,
     1.0f,
     500.0f,
     1.02f,
     533.3333f,
     1.0f},
    {133.33333f,
     0.0f,
     300.0f,
     1.1f,
     383.33334f,
     1.0f,
     466.66666f,
     1.05f,
     516.6667f,
     1.0f,
     566.6667f,
     1.02f,
     600.0f,
     1.0f,
     633.3333f,
     1.02f,
     666.6667f,
     1.0f},
    {333.33334f,
     0.0f,
     500.0f,
     1.1f,
     583.3333f,
     1.0f,
     666.6667f,
     1.05f,
     716.6667f,
     1.0f,
     766.6667f,
     1.02f,
     800.0f,
     1.0f,
     833.3333f,
     1.02f,
     866.6667f,
     1.0f},
    {516.6667f,
     0.0f,
     683.3333f,
     1.1f,
     766.6667f,
     1.0f,
     850.0f,
     1.05f,
     900.0f,
     1.0f,
     950.0f,
     1.02f,
     983.3333f,
     1.0f,
     1016.6667f,
     1.02f,
     1050.0f,
     1.0f},
    {733.3333f,
     0.0f,
     900.0f,
     1.1f,
     983.3333f,
     1.0f,
     1066.6666f,
     1.05f,
     1116.6666f,
     1.0f,
     1166.6666f,
     1.02f,
     1200.0f,
     1.0f,
     1233.3334f,
     1.02f,
     1266.6666f,
     1.0f},
    {950.0f,
     0.0f,
     1116.6666f,
     1.1f,
     1200.0f,
     1.0f,
     1283.3334f,
     1.05f,
     1333.3334f,
     1.0f,
     1383.3334f,
     1.02f,
     1416.6666f,
     1.0f,
     1450.0f,
     1.02f,
     1483.3334f,
     1.0f},
};

// @ghidraAddress 0x3defd8
constexpr float kResultSpriteX[kResultSpriteCount] = {
    -190.0f, -128.0f, -76.0f, -31.0f, 37.0f, 109.0f, 157.0f, 183.0f, 209.0f};
// @ghidraAddress 0x3df028
constexpr float kResultPosCurveBase[kResultSpriteCount][kResultPosCurveFloats] = {
    {916.6667f,
     760.0f,
     1100.0f,
     900.0f,
     1266.6666f,
     800.0f,
     1416.6666f,
     900.0f,
     1550.0f,
     860.0f,
     1666.6666f,
     900.0f,
     2333.3333f,
     950.0f},
    {716.6667f,
     757.0f,
     900.0f,
     898.0f,
     1066.6666f,
     798.0f,
     1216.6666f,
     898.0f,
     1350.0f,
     858.0f,
     1466.6666f,
     898.0f,
     2333.3333f,
     948.0f},
    {500.0f,
     757.0f,
     683.3333f,
     898.0f,
     850.0f,
     798.0f,
     1000.0f,
     898.0f,
     1133.3334f,
     858.0f,
     1250.0f,
     898.0f,
     2333.3333f,
     948.0f},
    {283.33334f,
     757.0f,
     466.66666f,
     897.0f,
     633.3333f,
     797.0f,
     783.3333f,
     897.0f,
     916.6667f,
     857.0f,
     1033.3334f,
     897.0f,
     2333.3333f,
     947.0f},
    {416.66666f,
     758.0f,
     600.0f,
     898.0f,
     766.6667f,
     798.0f,
     916.6667f,
     898.0f,
     1050.0f,
     858.0f,
     1166.6666f,
     898.0f,
     2333.3333f,
     948.0f},
    {616.6667f,
     760.0f,
     800.0f,
     898.0f,
     966.6667f,
     798.0f,
     1116.6666f,
     898.0f,
     1250.0f,
     858.0f,
     1366.6666f,
     898.0f,
     2333.3333f,
     948.0f},
    {800.0f,
     806.0f,
     983.3333f,
     943.0f,
     1150.0f,
     843.0f,
     1300.0f,
     943.0f,
     1433.3334f,
     903.0f,
     1550.0f,
     943.0f,
     2333.3333f,
     993.0f},
    {1016.6667f,
     806.0f,
     1200.0f,
     943.0f,
     1366.6666f,
     843.0f,
     1516.6666f,
     943.0f,
     1650.0f,
     903.0f,
     1766.6666f,
     943.0f,
     2333.3333f,
     993.0f},
    {1233.3334f,
     806.0f,
     1416.6666f,
     943.0f,
     1583.3334f,
     843.0f,
     1733.3334f,
     943.0f,
     1866.6666f,
     903.0f,
     1983.3334f,
     943.0f,
     2333.3333f,
     993.0f},
};

// @ghidraAddress 0x3def60
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

constexpr int kRankMedalVariantSkip1 = 1;
constexpr int kRankMedalVariantSkip2 = 2;

// @ghidraAddress 0x30e924
constexpr float kRankScaleXCurve[kRankMedalCount][kRankScaleCurveFloats] = {
    {0.0f,
     0.0f,
     166.66667f,
     1.5f,
     250.0f,
     1.0f,
     500.0f,
     5.0f,
     500.0f,
     5.0f,
     500.0f,
     5.0f,
     500.0f,
     5.0f,
     500.0f,
     5.0f,
     500.0f,
     5.0f},
    {250.0f,
     0.0f,
     416.66666f,
     -1.5f,
     1250.0f,
     -2.0f,
     1250.0f,
     -2.0f,
     1250.0f,
     -2.0f,
     1250.0f,
     -2.0f,
     1250.0f,
     -2.0f,
     1250.0f,
     -2.0f,
     1250.0f,
     -2.0f},
    {250.0f,
     0.0f,
     416.66666f,
     -1.5f,
     1250.0f,
     -2.0f,
     1250.0f,
     -2.0f,
     1250.0f,
     -2.0f,
     1250.0f,
     -2.0f,
     1250.0f,
     -2.0f,
     1250.0f,
     -2.0f,
     1250.0f,
     -2.0f},
    {250.0f,
     0.0f,
     416.66666f,
     1.1f,
     500.0f,
     1.0f,
     583.3333f,
     1.05f,
     633.3333f,
     1.0f,
     683.3333f,
     1.02f,
     716.6667f,
     1.0f,
     750.0f,
     1.02f,
     783.3333f,
     1.0f},
    {250.0f,
     0.0f,
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
    {250.0f,
     0.0f,
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
    {250.0f,
     0.0f,
     416.66666f,
     0.8f,
     916.6667f,
     1.0f,
     916.6667f,
     1.0f,
     916.6667f,
     1.0f,
     916.6667f,
     1.0f,
     916.6667f,
     1.0f,
     916.6667f,
     1.0f,
     916.6667f,
     1.0f},
};

// @ghidraAddress 0x30eb1c
constexpr float kRankScaleYCurve[kRankMedalCount][kRankScaleCurveFloats] = {
    {0.0f,
     0.0f,
     166.66667f,
     1.5f,
     250.0f,
     1.0f,
     500.0f,
     1.0f,
     500.0f,
     1.0f,
     500.0f,
     1.0f,
     500.0f,
     1.0f,
     500.0f,
     1.0f,
     500.0f,
     1.0f},
    {250.0f,
     0.0f,
     416.66666f,
     -1.5f,
     1250.0f,
     -1.33f,
     1250.0f,
     -1.33f,
     1250.0f,
     -1.33f,
     1250.0f,
     -1.33f,
     1250.0f,
     -1.33f,
     1250.0f,
     -1.33f,
     1250.0f,
     -1.33f},
    {250.0f,
     0.0f,
     416.66666f,
     -1.5f,
     1250.0f,
     -1.33f,
     1250.0f,
     -1.33f,
     1250.0f,
     -1.33f,
     1250.0f,
     -1.33f,
     1250.0f,
     -1.33f,
     1250.0f,
     -1.33f,
     1250.0f,
     -1.33f},
    {250.0f,
     0.0f,
     416.66666f,
     1.1f,
     500.0f,
     1.0f,
     583.3333f,
     1.05f,
     633.3333f,
     1.0f,
     683.3333f,
     1.02f,
     716.6667f,
     1.0f,
     750.0f,
     1.02f,
     783.3333f,
     1.0f},
    {250.0f,
     0.0f,
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
    {250.0f,
     0.0f,
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
    {250.0f,
     0.0f,
     416.66666f,
     0.8f,
     916.6667f,
     1.0f,
     916.6667f,
     1.0f,
     916.6667f,
     1.0f,
     916.6667f,
     1.0f,
     916.6667f,
     1.0f,
     916.6667f,
     1.0f,
     916.6667f,
     1.0f},
};

// @ghidraAddress 0x30ed14
constexpr float kRankAlphaCurve[kRankMedalCount][kRankAlphaCurveFloats] = {
    {250.0f, 1.0f, 500.0f, 0.0f, 500.0f, 0.0f},
    {250.0f, 1.0f, 1250.0f, 0.0f, 1250.0f, 0.0f},
    {250.0f, 1.0f, 1250.0f, 0.0f, 1250.0f, 0.0f},
    {0.0f, 1.0f, 16.666666f, 1.0f, 16.666666f, 1.0f},
    {400.0f, 0.0f, 416.66666f, 1.0f, 916.6667f, 0.0f},
    {400.0f, 0.0f, 416.66666f, 1.0f, 916.6667f, 0.0f},
    {400.0f, 0.0f, 416.66666f, 1.0f, 916.6667f, 0.0f},
};

// @ghidraAddress 0x30edbc
constexpr float kRankRotCurve[kRankMedalCount][kRankRotCurveFloats] = {
    {0.0f, 0.0f, 16.666666f, 0.0f},
    {250.0f, 0.0f, 1250.0f, 0.7853982f},
    {250.0f, 0.0f, 1250.0f, 0.7853982f},
    {0.0f, 0.0f, 16.666666f, 0.0f},
    {0.0f, 0.0f, 16.666666f, 0.0f},
    {0.0f, 0.0f, 16.666666f, 0.0f},
    {0.0f, 0.0f, 16.666666f, 0.0f},
};

// @ghidraAddress 0x30e87c
constexpr float kRankOffsetYCurve[kRankMedalCount][kRankOffsetCurveFloats] = {
    {0.0f, 0.0f, 16.666666f, 0.0f, 16.666666f, 0.0f},
    {0.0f, 0.0f, 16.666666f, 0.0f, 16.666666f, 0.0f},
    {0.0f, 0.0f, 16.666666f, 0.0f, 16.666666f, 0.0f},
    {0.0f, 0.0f, 16.666666f, 0.0f, 16.666666f, 0.0f},
    {250.0f, 0.0f, 916.6667f, -30.0f, 916.6667f, -30.0f},
    {250.0f, 0.0f, 416.66666f, -50.0f, 916.6667f, -70.0f},
    {250.0f, 0.0f, 416.66666f, -30.0f, 916.6667f, -50.0f},
};

// @ghidraAddress 0x30ee2c
constexpr float kMissScaleCurve[kMissSpriteCount][kMissScaleCurveFloats] = {
    {350.0f,     0.0f,  516.6667f, 1.1f, 600.0f,     1.0f,  683.3333f,  1.05f, 733.3333f,  1.0f,
     783.3333f,  1.02f, 816.6667f, 1.0f, 850.0f,     1.02f, 883.3333f,  1.0f,  1066.6666f, 1.0f,
     1133.3334f, 1.02f, 1200.0f,   1.0f, 1266.6666f, 1.02f, 1316.6666f, 1.0f},
    {300.0f,     0.0f,  466.66666f, 1.1f, 550.0f,     1.0f,  633.3333f,  1.05f, 683.3333f,  1.0f,
     733.3333f,  1.02f, 766.6667f,  1.0f, 800.0f,     1.02f, 833.3333f,  1.0f,  1116.6666f, 1.0f,
     1183.3334f, 1.02f, 1250.0f,    1.0f, 1316.6666f, 1.02f, 1366.6666f, 1.0f},
    {250.0f,     0.0f,  416.66666f, 1.1f, 500.0f,     1.0f,  583.3333f,  1.05f, 633.3333f,  1.0f,
     683.3333f,  1.02f, 716.6667f,  1.0f, 750.0f,     1.02f, 783.3333f,  1.0f,  1166.6666f, 1.0f,
     1233.3334f, 1.02f, 1300.0f,    1.0f, 1366.6666f, 1.02f, 1416.6666f, 1.0f},
    {250.0f,     0.0f,  416.66666f, 1.1f, 500.0f,     1.0f,  583.3333f,  1.05f, 633.3333f,  1.0f,
     683.3333f,  1.02f, 716.6667f,  1.0f, 750.0f,     1.02f, 783.3333f,  1.0f,  1216.6666f, 1.0f,
     1283.3334f, 1.02f, 1350.0f,    1.0f, 1416.6666f, 1.02f, 1466.6666f, 1.0f},
    {300.0f,     0.0f,  466.66666f, 1.1f, 550.0f,     1.0f,  633.3333f,  1.05f, 683.3333f,  1.0f,
     733.3333f,  1.02f, 766.6667f,  1.0f, 800.0f,     1.02f, 833.3333f,  1.0f,  1266.6666f, 1.0f,
     1333.3334f, 1.02f, 1400.0f,    1.0f, 1466.6666f, 1.02f, 1516.6666f, 1.0f},
    {350.0f,     0.0f,  516.6667f, 1.1f, 600.0f,     1.0f,  683.3333f,  1.05f, 733.3333f,  1.0f,
     783.3333f,  1.02f, 816.6667f, 1.0f, 850.0f,     1.02f, 883.3333f,  1.0f,  1316.6666f, 1.0f,
     1383.3334f, 1.02f, 1450.0f,   1.0f, 1516.6666f, 1.02f, 1566.6666f, 1.0f},
};

// @ghidraAddress 0x30f0cc
constexpr float kMissRotCurve[kMissSpriteCount][kMissRotCurveFloats] = {
    {2000.0f, 1.0f, 2333.3333f, 0.0f},
    {2000.0f, 1.0f, 2333.3333f, 0.0f},
    {2000.0f, 1.0f, 2333.3333f, 0.0f},
    {2000.0f, 1.0f, 2333.3333f, 0.0f},
    {2000.0f, 1.0f, 2333.3333f, 0.0f},
    {2000.0f, 1.0f, 2333.3333f, 0.0f},
};

// @ghidraAddress 0x30f12c/0x30f14c/0x30f16c
constexpr float kBannerScaleXCurve[] = {0.0f, 0.0f, 166.66667f, 1.5f, 250.0f, 1.0f, 500.0f, 5.0f};
constexpr float kBannerScaleYCurve[] = {0.0f, 0.0f, 166.66667f, 1.5f, 250.0f, 1.0f, 500.0f, 1.5f};
constexpr float kBannerAlphaCurve[] = {250.0f, 1.0f, 500.0f, 0.0f};
} // namespace

/** @ghidraAddress 0x187484 */
ColetteThemeLayer::ColetteThemeLayer() {
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
        g_pColetteThemeLayer = new ColetteThemeLayer();
    }
    return g_pColetteThemeLayer;
}

/** @ghidraAddress 0x18756c */
void ColetteThemeLayer::CreateFcEffectSprites() {
    if (m_bBuilt) {
        return;
    }

    BgLayer *pBackgroundLayer = BgLayer::GetBackgroundLayer();
    ne::C_RENDER *pParent = pBackgroundLayer->GetBackgroundRenderObject();

    m_pPartsTexture = ne::C_TEXTURE::FindOrLoadCached(kPartsTextureName);
    m_pEffectTexture = ne::C_TEXTURE::FindOrLoadCached(kEffectTextureName);
    m_pPartsTexture2 = ne::C_TEXTURE::FindOrLoadCached(kPartsTextureName);

    ne::C_TEXTURE *const apTextureFields[] = {m_pPartsTexture, m_pEffectTexture, m_pPartsTexture2};

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

/** @ghidraAddress 0x18776c */
void ColetteThemeLayer::Update(float flDelta) {
    GameSystem *pGameSystem = GameSystem::GetGameSystem();
    m_flViewportWidth = pGameSystem->GetViewportWidth();
    m_flViewportHeight = pGameSystem->GetViewportHeight();
    for (int &nCount : m_aSpriteCounts) {
        nCount = 0;
    }

    AdvanceFadeInterp(flDelta);

    if (!m_bGradeClockActive) {
        return;
    }

    float flClock = m_flGradeRevealClock;
    if (m_bGradeVisible) {
        flClock += flDelta;
        m_flGradeRevealClock = flClock;
    }
    if (flClock >= m_flGradeRevealDuration) {
        m_bGradeVisible = false;
    }

    // The binary loads 1.0 into both scale registers, so the curve drives only the alpha.
    const float flBaseCurve = CalculateCurveInterpolation(kFcBaseCurve, kFcBaseCurvePairs, flClock);
    const S_VECTOR2 origin{0.0f, 0.0f};
    EmitFcSprite(1.0f,
                 1.0f,
                 0.0f,
                 kFcBaseSlot,
                 &origin,
                 static_cast<int>(flBaseCurve * m_gradeChannel.GetCurrent() * kFcAlphaByteScale));

    for (int nSide = 0; nSide < kSideCount; ++nSide) {
        if ((m_nSideCount | nSide) == 0) {
            continue;
        }

        const int nBestRank = m_aGradeValues[nSide];
        const bool bLowRank = ScoreTracker::shared()->GetPlayRecordRank(nSide) > kFcClearRankMax;
        const bool bChallenge = GameSystem::GetGameSystem()->GetMenuTutorialActive();

        if (nBestRank == 0) {
            const int nColorVariant = [RBUserSettingData sharedInstance].playColor;
            if (nSide != 0) {
                EmitFcRankSprites(nSide, nColorVariant);
            } else {
                EmitFcRankSprites(0, nColorVariant == 0);
            }
        }

        if (bLowRank || bChallenge) {
            EmitFcMissSprites(nSide);
        } else {
            EmitFcResultSprites(nSide);
        }
    }

    for (int nBatch = 0; nBatch < kSpriteSlotCount; ++nBatch) {
        m_apSprites[nBatch]->SetSpriteCount(m_aSpriteCounts[nBatch]);
    }
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

    // The play-field half-height, rounded toward zero.
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

    const unsigned int nChannel = nSpriteSlot == kFcShadowSlot ? 0 : kColorMax;
    pBatch->SetSpriteColor(nIndex, nChannel, nChannel, nChannel, static_cast<unsigned int>(nAlpha));

    m_aSpriteCounts[nBatch] = nIndex + 1;
}

/** @ghidraAddress 0x187ea4 */
void ColetteThemeLayer::EmitFcMissSprites(int nSide) {
    const float flClock = m_flGradeRevealClock;
    const float flCurveScale = m_gradeChannel.GetCurrent();
    const float flBaseY = kMissReferenceY - m_flHeight;

    for (int nSprite = 0; nSprite < kMissSpriteCount; ++nSprite) {
        const float flScale =
            CalculateCurveInterpolation(kMissScaleCurve[nSprite], kMissScaleCurvePairs, flClock);
        const float flAlphaCurve =
            CalculateCurveInterpolation(kMissRotCurve[nSprite], kMissRotCurvePairs, flClock);

        S_VECTOR2 position{kMissSpriteX[nSprite], flBaseY};
        float flRotation = 0.0f;
        if (m_nSideCount == kSingleSide) {
            if (nSide == kSecondSide) {
                position.y = flBaseY + kMissSecondSideShiftY;
            } else {
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

    const float flBannerScaleX =
        CalculateCurveInterpolation(kBannerScaleXCurve, kBannerCurvePairs4, flClock);
    const float flBannerScaleY =
        CalculateCurveInterpolation(kBannerScaleYCurve, kBannerCurvePairs4, flClock);
    const float flBannerAlpha =
        CalculateCurveInterpolation(kBannerAlphaCurve, kBannerCurvePairs2, flClock);

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
    const float flClock = m_flGradeRevealClock;
    if (flClock <= kRankWindowStart || flClock >= kRankWindowEnd) {
        return;
    }

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
            position.x = -position.x;
            flRotation = static_cast<float>(static_cast<double>(flRotation) + kRankMirrorRotation);
            position.y = kRankFirstSideReflectY - position.y;
        }

        bool bEmit = true;
        if (nMedal == kRankMedalVariantSkip1) {
            bEmit = nColorVariant == 0;
        } else if (nMedal == kRankMedalVariantSkip2) {
            bEmit = nColorVariant == 1;
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

/** @ghidraAddress 0x188114 */
void ColetteThemeLayer::EmitFcResultSprites(int nSide) {
    static float aPosCurve[kResultSpriteCount][kResultPosCurveFloats];
    static bool bPosCurveBuilt = false;
    if (!bPosCurveBuilt) {
        for (int nSprite = 0; nSprite < kResultSpriteCount; ++nSprite) {
            for (int nFloat = 0; nFloat < kResultPosCurveFloats; ++nFloat) {
                const float flValue = kResultPosCurveBase[nSprite][nFloat];
                aPosCurve[nSprite][nFloat] = (nFloat & 1) ? flValue - m_flHeight : flValue;
            }
        }
        bPosCurveBuilt = true;
    }

    const float flCurveScale = m_gradeChannel.GetCurrent();
    const float flClock = m_flGradeRevealClock;

    for (int nSprite = 0; nSprite < kResultSpriteCount; ++nSprite) {
        const float flAlpha = CalculateCurveInterpolation(
            kResultAlphaCurve[nSprite], kResultAlphaCurvePairs, flClock);
        const float flScale = CalculateCurveInterpolation(
            kResultScaleCurve[nSprite], kResultScaleCurvePairs, flClock);
        const float flPosY =
            CalculateCurveInterpolation(aPosCurve[nSprite], kResultPosCurvePairs, flClock);

        S_VECTOR2 position{kResultSpriteX[nSprite], kResultReferenceY - m_flHeight};
        float flRotation = 0.0f;
        if (m_nSideCount == kSingleSide) {
            if (nSide == kSecondSide) {
                position.y = flPosY + kRankSecondSideShiftY;
            } else {
                position.x = -position.x;
                position.y = kRankFirstSideReflectY - flPosY;
                flRotation = kMissMirrorRotation;
            }
        } else {
            position.y = flPosY - position.y;
        }

        EmitFcSprite(flScale,
                     flScale,
                     flRotation,
                     kResultSpriteSlotBase + nSprite,
                     &position,
                     static_cast<int>(flAlpha * flCurveScale * kFcAlphaByteScale));
    }
}
