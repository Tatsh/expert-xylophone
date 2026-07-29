//
//  title_screen_layer2.mm
//  REFLEC BEAT plus
//
//  The parts-based title-screen scene layer (TitleLimelightScene). Reconstructed from Ghidra
//  project rb458, program rb458. @ghidraAddress values are relative to the program image base.
//

#include "titlelimelightscene.h"

#include <cstdint>

#import "AppDelegate.h"
#import "AudioManager.h"
#import "RBBGMManager.h"
#import "RBViewController.h"
#include "curve.h"
#include "game_scene.h"
#include "gamesystem.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#include "s_vector2.h"
#include "shotsoundmanager.h"
#include "soundeffectmanager.h"
#include "title_part_layout.h"
#include "titlecolettescene.h"
#include "touch_point.h"
#include "touchmanager.h"

namespace {
// The value the constructor seeds into the fade value (the fully-shown level).
constexpr float kInitialFadeValue = 1.0f;

// The sentinel the constructor writes into the tracked-touch id (no touch tracked).
constexpr int kNoTrackedTouch = -1;

// The dispatch states OnFrame selects between.
constexpr int kStateLoad = 0;
constexpr int kStateStartMusic = 1;
constexpr int kStateRender = 2;
constexpr int kStateFinish = 3;

// The fade-in time, in seconds, the title BGM begins playing with (@ghidraAddress 0x2ee910).
constexpr float kTitleBgmFadeInTime = 0.3f;

// The three title textures, in load order (indices into m_apTextures).
constexpr const char *kTitleTextureNames[rb::TitleLimelightScene::kTextureCount] = {
    "00_texture/ti_bg",
    "00_texture/ti_parts",
    "00_texture/ti_parts_eff",
};

// The part-layout record's texture index marking an instancer that binds no texture.
constexpr int kUntexturedTextureIndex = 4;

// The ready-delay timer the title screen counts down before the start prompt, and the fade-curve
// duration, in milliseconds.
constexpr int kTitleReadyDelay = 0x708;
constexpr float kTitleFadeDuration = 500.0f;

// The themed voice bank the title screen loads.
constexpr int kTitleVoiceId = 0;

// The maximum value of an opaque colour channel, and the half factor for a size-to-anchor centre.
constexpr unsigned int kColorMax = 255;
constexpr float kHalf = 0.5f;

// The part-layout anchor mode that draws from the per-device lettered/logo UV atlas; every other
// mode draws from the shared default title-part atlas.
constexpr int kPartAnchorModeAtlas = 1;

// The screen-space transform the default-device parts apply: the X and Y offsets and the scale that
// map a part's layout position into screen space (@ghidraAddress 0x2f8568 X offset, 0x301f94 Y
// offset, 0x301108 scale), plus the layer's own half-anchor origins.
constexpr float kPartScreenOffsetX = -384.0f;
constexpr float kPartScreenOffsetY = -680.0f;
constexpr float kPartScreenScale = 0.4f;

// The interactive part kinds whose screen rectangles are recorded for the title touch tests.
constexpr unsigned int kPartKindHit0 = 0x2b;
constexpr unsigned int kPartKindHit1 = 0x32;
constexpr unsigned int kPartKindHit2 = 0x34;
constexpr unsigned int kPartKindHit3 = 0x3e;
constexpr unsigned int kPartKindHit4 = 0x50;

// The extra offsets the default-device hit-rect for kind 0x50 (the start prompt) is nudged by
// (@ghidraAddress 0x2f855c width, 0x2f8574 X, 0x2f8578 height, plus an inline -30 Y).
constexpr float kStartPromptWidthPad = 80.0f;
constexpr float kStartPromptOffsetX = -40.0f;
constexpr float kStartPromptHeightPad = 60.0f;
constexpr float kStartPromptOffsetY = -30.0f;

// The star-field particle burst: the number of particles, the number of {time, value} pairs each
// animation curve holds (and its float count), the part-kind base the particles emit at, and the
// unit-interval-to-alpha scale.
constexpr int kBurstParticleCount = 0x23;
constexpr int kBurstCurvePairs = 3;
constexpr int kBurstCurveFloats = kBurstCurvePairs * 2;
constexpr unsigned int kBurstPartKindBase = 5;
constexpr float kBurstAlphaByteScale = 255.0f;

// The 35 burst particles' fixed X columns. @ghidraAddress 0x30b3b0
constexpr float kBurstParticleX[kBurstParticleCount] = {
    74.0f,  74.0f,  194.0f, 194.0f, 454.0f, 454.0f, 229.0f, 229.0f, 545.0f, 545.0f, 725.0f, 725.0f,
    564.0f, 564.0f, 234.0f, 234.0f, 657.0f, 657.0f, 464.0f, 464.0f, 593.0f, 593.0f, 593.0f, 593.0f,
    334.0f, 334.0f, 134.0f, 134.0f, 644.0f, 644.0f, 71.0f,  71.0f,  424.0f, 424.0f, 384.0f,
};

// the particles' Y-position curves (three {time, value} pairs each). @ghidraAddress 0x30b43c
constexpr float kBurstYCurve[kBurstParticleCount][kBurstCurveFloats] = {
    {333.33334f, 738.0f, 500.0f, 730.5f, 1000.0f, 716.5f},
    {333.33334f, 738.0f, 500.0f, 730.5f, 1000.0f, 716.5f},
    {333.33334f, 768.0f, 500.0f, 760.5f, 1000.0f, 746.5f},
    {333.33334f, 768.0f, 500.0f, 760.5f, 1000.0f, 746.5f},
    {166.66667f, 638.0f, 333.33334f, 630.5f, 833.3333f, 616.5f},
    {166.66667f, 638.0f, 333.33334f, 630.5f, 833.3333f, 616.5f},
    {316.66666f, 584.0f, 333.33334f, 584.0f, 1000.0f, 554.0f},
    {316.66666f, 584.0f, 333.33334f, 584.0f, 1000.0f, 554.0f},
    {316.66666f, 590.0f, 333.33334f, 590.0f, 1000.0f, 560.0f},
    {316.66666f, 590.0f, 333.33334f, 590.0f, 1000.0f, 560.0f},
    {316.66666f, 647.0f, 333.33334f, 647.0f, 1000.0f, 617.0f},
    {316.66666f, 647.0f, 333.33334f, 647.0f, 1000.0f, 617.0f},
    {166.66667f, 764.0f, 333.33334f, 739.0f, 833.3333f, 724.0f},
    {166.66667f, 764.0f, 333.33334f, 739.0f, 833.3333f, 724.0f},
    {0.0f, 794.0f, 166.66667f, 744.0f, 666.6667f, 724.0f},
    {0.0f, 794.0f, 166.66667f, 744.0f, 666.6667f, 724.0f},
    {0.0f, 609.0f, 166.66667f, 559.0f, 666.6667f, 539.0f},
    {0.0f, 609.0f, 166.66667f, 559.0f, 666.6667f, 539.0f},
    {0.0f, 815.0f, 166.66667f, 765.0f, 666.6667f, 745.0f},
    {0.0f, 815.0f, 166.66667f, 765.0f, 666.6667f, 745.0f},
    {0.0f, 802.0f, 166.66667f, 752.0f, 666.6667f, 732.0f},
    {0.0f, 802.0f, 166.66667f, 752.0f, 666.6667f, 732.0f},
    {0.0f, 802.0f, 166.66667f, 752.0f, 666.6667f, 732.0f},
    {0.0f, 802.0f, 166.66667f, 752.0f, 666.6667f, 732.0f},
    {0.0f, 704.0f, 166.66667f, 674.0f, 666.6667f, 654.0f},
    {0.0f, 704.0f, 166.66667f, 674.0f, 666.6667f, 654.0f},
    {333.33334f, 704.0f, 500.0f, 674.0f, 1000.0f, 644.0f},
    {333.33334f, 704.0f, 500.0f, 674.0f, 1000.0f, 644.0f},
    {333.33334f, 704.0f, 500.0f, 674.0f, 1000.0f, 644.0f},
    {250.0f, 704.0f, 416.66666f, 674.0f, 916.6667f, 644.0f},
    {0.0f, 709.0f, 166.66667f, 695.0f, 666.6667f, 659.0f},
    {0.0f, 709.0f, 166.66667f, 695.0f, 666.6667f, 659.0f},
    {83.333336f, 594.0f, 250.0f, 564.0f, 750.0f, 544.0f},
    {83.333336f, 594.0f, 250.0f, 564.0f, 750.0f, 544.0f},
    {166.66667f, 574.0f, 333.33334f, 524.0f, 833.3333f, 494.0f},
};

// the particles' alpha curves (three {time, value} pairs each). @ghidraAddress 0x30b784
constexpr float kBurstAlphaCurve[kBurstParticleCount][kBurstCurveFloats] = {
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
    {483.33334f, 0.0f, 500.0f, 1.0f, 1000.0f, 0.0f},
    {466.66666f, 0.0f, 483.33334f, 1.0f, 650.0f, 0.0f},
    {400.0f, 0.0f, 583.3333f, 1.0f, 916.6667f, 0.0f},
    {466.66666f, 0.0f, 483.33334f, 1.0f, 650.0f, 0.0f},
    {150.0f, 0.0f, 166.66667f, 1.0f, 666.6667f, 0.0f},
    {133.33333f, 0.0f, 150.0f, 1.0f, 316.66666f, 0.0f},
    {233.33333f, 0.0f, 250.0f, 1.0f, 750.0f, 0.0f},
    {216.66667f, 0.0f, 233.33333f, 1.0f, 400.0f, 0.0f},
    {216.66667f, 0.0f, 233.33333f, 1.0f, 400.0f, 0.0f},
};

// the particles' scale curves (three {time, value} pairs each). @ghidraAddress 0x30bacc
constexpr float kBurstScaleCurve[kBurstParticleCount][kBurstCurveFloats] = {
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
    {333.33334f, 0.0f, 500.0f, 0.4f, 1000.0f, 0.5f},
    {333.33334f, 0.0f, 500.0f, 0.4f, 1000.0f, 0.5f},
    {250.0f, 0.0f, 416.66666f, 0.4f, 916.6667f, 0.5f},
    {250.0f, 0.0f, 416.66666f, 0.4f, 916.6667f, 0.5f},
    {0.0f, 0.0f, 166.66667f, 0.6f, 666.6667f, 1.0f},
    {0.0f, 0.0f, 166.66667f, 0.6f, 666.6667f, 1.0f},
    {83.333336f, 0.0f, 250.0f, 0.6f, 750.0f, 1.0f},
    {83.333336f, 0.0f, 250.0f, 0.8f, 750.0f, 1.0f},
    {166.66667f, 0.0f, 333.33334f, 0.6f, 833.3333f, 1.0f},
};

// The state-2 render sweep's animation curves. Each is a flat run of {time, value} pairs sampled at
// the layer's animation clock. The whole block runs contiguously from 0x30a510 up to 0x30b3b0,
// where the burst tables above begin, so no curve in the region is unaccounted for.

// Part 0x2b is the only rotated part: it flies in along a 32-keyframe path while a decaying
// rotation oscillation (in radians, opening at 100 degrees) settles to zero, then holds until its
// alpha drops out.
constexpr int kPart2bPathPairs = 32;
constexpr int kPart2bRotationPairs = 15;
constexpr int kPart2bAlphaPairs = 3;

/** @ghidraAddress 0x30a510 */
constexpr float kPart2bPosXCurve[] = {
    0.0f,       771.0f, 33.333332f, 717.0f, 66.666664f, 684.0f, 116.666664f, 662.0f,
    166.66667f, 646.0f, 216.66667f, 636.0f, 250.0f,     632.0f, 300.0f,      618.0f,
    350.0f,     603.0f, 400.0f,     587.0f, 450.0f,     571.0f, 500.0f,      554.0f,
    550.0f,     540.0f, 600.0f,     527.0f, 650.0f,     517.0f, 700.0f,      508.0f,
    750.0f,     498.0f, 800.0f,     486.0f, 850.0f,     475.0f, 900.0f,      464.0f,
    950.0f,     453.0f, 1000.0f,    443.0f, 1050.0f,    434.0f, 1083.3334f,  431.0f,
    1133.3334f, 425.0f, 1183.3334f, 418.0f, 1233.3334f, 411.0f, 1283.3334f,  403.0f,
    1333.3334f, 395.0f, 1383.3334f, 389.0f, 1416.6666f, 386.0f, 1450.0f,     384.0f,
};

/** @ghidraAddress 0x30a610 */
constexpr float kPart2bPosYCurve[] = {
    0.0f,       517.0f, 33.333332f, 529.0f, 66.666664f, 545.0f, 116.666664f, 567.0f,
    166.66667f, 595.0f, 216.66667f, 624.0f, 250.0f,     645.0f, 300.0f,      634.0f,
    350.0f,     626.0f, 400.0f,     622.0f, 450.0f,     622.0f, 500.0f,      627.0f,
    550.0f,     635.0f, 600.0f,     646.0f, 650.0f,     659.0f, 700.0f,      652.0f,
    750.0f,     651.0f, 800.0f,     654.0f, 850.0f,     659.0f, 900.0f,      667.0f,
    950.0f,     654.0f, 1000.0f,    659.0f, 1050.0f,    667.0f, 1083.3334f,  674.0f,
    1133.3334f, 669.0f, 1183.3334f, 665.0f, 1233.3334f, 663.0f, 1283.3334f,  662.0f,
    1333.3334f, 665.0f, 1383.3334f, 669.0f, 1416.6666f, 674.0f, 1450.0f,     679.0f,
};

/** @ghidraAddress 0x30a710 */
constexpr float kPart2bRotationCurve[] = {
    0.0f,       1.7453293f,   1450.0f, 0.0f,         1566.6666f, -0.17453292f,
    1683.3334f, 0.17453292f,  1800.0f, -0.17453292f, 1916.6666f, 0.17453292f,
    2033.3334f, -0.15707964f, 2150.0f, 0.13962634f,  2266.6667f, -0.12217305f,
    2383.3333f, 0.10471976f,  2500.0f, -0.08726646f, 2616.6667f, 0.06981317f,
    2733.3333f, -0.05235988f, 2850.0f, 0.034906585f, 2966.6667f, 0.0f,
};

/** @ghidraAddress 0x30a788 */
constexpr float kPart2bAlphaCurve[] = {0.0f, 1.0f, 2966.6667f, 1.0f, 3100.0f, 0.0f};

// Parts 0x2c..0x35: ten parts on a fixed row of X columns, each rising into place on its own
// staggered Y curve and fading in behind it.
constexpr int kPart2cCount = 10;
constexpr int kPart2cPosYPairs = 4;
constexpr int kPart2cAlphaPairs = 2;

/** @ghidraAddress 0x30a7a0 */
constexpr float kPart2cPosX[kPart2cCount] = {
    93.0f,
    150.0f,
    204.0f,
    257.0f,
    310.0f,
    382.0f,
    487.0f,
    544.0f,
    610.0f,
    664.0f,
};

/** @ghidraAddress 0x30a7c8 */
constexpr float kPart2cPosYCurve[kPart2cCount][kPart2cPosYPairs * 2] = {
    {2700.0f, 585.0f, 2900.0f, 641.0f, 3000.0f, 624.0f, 3100.0f, 635.0f},
    {2800.0f, 585.0f, 3000.0f, 641.0f, 3100.0f, 624.0f, 3200.0f, 635.0f},
    {2750.0f, 615.0f, 2950.0f, 671.0f, 3050.0f, 654.0f, 3150.0f, 635.0f},
    {2833.3333f, 585.0f, 3033.3333f, 641.0f, 3133.3333f, 624.0f, 3233.3333f, 635.0f},
    {2716.6667f, 585.0f, 2916.6667f, 641.0f, 3016.6667f, 624.0f, 3116.6667f, 635.0f},
    // The sixth part's Y curve is flat: every keyframe sits at time zero and the resting height.
    {0.0f, 635.0f, 0.0f, 635.0f, 0.0f, 635.0f, 0.0f, 635.0f},
    {2783.3333f, 585.0f, 2983.3333f, 641.0f, 3083.3333f, 624.0f, 3183.3333f, 635.0f},
    {2750.0f, 585.0f, 2950.0f, 641.0f, 3050.0f, 624.0f, 3150.0f, 635.0f},
    {2683.3333f, 585.0f, 2883.3333f, 641.0f, 2983.3333f, 624.0f, 3083.3333f, 635.0f},
    {2783.3333f, 585.0f, 2983.3333f, 641.0f, 3083.3333f, 624.0f, 3183.3333f, 635.0f},
};

/** @ghidraAddress 0x30a908 */
constexpr float kPart2cAlphaCurve[kPart2cCount][kPart2cAlphaPairs * 2] = {
    {2700.0f, 0.0f, 2800.0f, 1.0f},
    {2800.0f, 0.0f, 2900.0f, 1.0f},
    {2750.0f, 0.0f, 2850.0f, 1.0f},
    {2833.3333f, 0.0f, 2933.3333f, 1.0f},
    {2716.6667f, 0.0f, 2816.6667f, 1.0f},
    {2916.6667f, 0.0f, 3016.6667f, 1.0f},
    {2783.3333f, 0.0f, 2883.3333f, 1.0f},
    {2750.0f, 0.0f, 2850.0f, 1.0f},
    {2683.3333f, 0.0f, 2783.3333f, 1.0f},
    {2783.3333f, 0.0f, 2883.3333f, 1.0f},
};

// Parts 0x36..0x39: four parts at fixed points that pop in with an overshoot and then join the
// shared ambient breathing. Parts 0x3a..0x3d sit at their own four points and share the alpha
// curves below with them, taking the ambient scale from the outset.
constexpr int kPart36Count = 4;
constexpr int kPart36ScalePairs = 8;
constexpr int kPart36AlphaPairs = 2;

/** @ghidraAddress 0x3094d0 */
constexpr float kPart36PosX[kPart36Count] = {697.0f, 727.0f, 420.0f, 459.0f};
/** @ghidraAddress 0x3094e0 */
constexpr float kPart36PosY[kPart36Count] = {674.0f, 690.0f, 703.0f, 727.0f};
/** @ghidraAddress 0x3094f0 */
constexpr float kPart3aPosX[kPart36Count] = {494.0f, 477.0f, 471.0f, 460.0f};
/** @ghidraAddress 0x309500 */
constexpr float kPart3aPosY[kPart36Count] = {705.0f, 705.0f, 705.0f, 705.0f};

/** @ghidraAddress 0x30a9a8 */
constexpr float kPart36ScaleCurve[kPart36Count][kPart36ScalePairs * 2] = {
    {2733.3333f,
     0.6f,
     2850.0f,
     1.1f,
     2950.0f,
     0.9f,
     3033.3333f,
     1.0f,
     3300.0f,
     1.0f,
     3450.0f,
     1.1f,
     3566.6667f,
     0.95f,
     3683.3333f,
     1.0f},
    {2633.3333f,
     0.6f,
     2750.0f,
     1.1f,
     2850.0f,
     0.9f,
     2933.3333f,
     1.0f,
     3300.0f,
     1.0f,
     3450.0f,
     1.1f,
     3566.6667f,
     0.95f,
     3683.3333f,
     1.0f},
    {2600.0f,
     0.6f,
     2716.6667f,
     1.1f,
     2816.6667f,
     0.9f,
     2900.0f,
     1.0f,
     3300.0f,
     1.0f,
     3450.0f,
     1.1f,
     3566.6667f,
     0.95f,
     3683.3333f,
     1.0f},
    {2750.0f,
     0.6f,
     2866.6667f,
     1.1f,
     2966.6667f,
     0.9f,
     3050.0f,
     1.0f,
     3300.0f,
     1.0f,
     3450.0f,
     1.1f,
     3566.6667f,
     0.95f,
     3683.3333f,
     1.0f},
};

/** @ghidraAddress 0x30aaa8 */
constexpr float kPart36AlphaCurve[kPart36Count][kPart36AlphaPairs * 2] = {
    {2733.3333f, 0.0f, 2900.0f, 1.0f},
    {2633.3333f, 0.0f, 2800.0f, 1.0f},
    {2600.0f, 0.0f, 2766.6667f, 1.0f},
    {2750.0f, 0.0f, 2916.6667f, 1.0f},
};

// Parts 0x3f and 0x40 are the two fully opaque parts: each slides along its own dense position path
// and shares one scale curve.
constexpr int kPart3fPathPairs = 12;
constexpr int kPart40PathPairs = 11;
constexpr int kPart3fScalePairs = 6;

/** @ghidraAddress 0x30aae8 */
constexpr float kPart3fPosXCurve[] = {
    2766.6667f, 605.0f, 2816.6667f, 595.0f, 2866.6667f, 586.0f, 2916.6667f, 576.0f,
    2950.0f,    570.0f, 2983.3333f, 563.0f, 3033.3333f, 555.0f, 3066.6667f, 550.0f,
    3100.0f,    546.0f, 3133.3333f, 540.0f, 3166.6667f, 537.0f, 3216.6667f, 532.0f,
};

/** @ghidraAddress 0x30ab48 */
constexpr float kPart3fPosYCurve[] = {
    2766.6667f, 669.0f, 2816.6667f, 674.0f, 2866.6667f, 680.0f, 2916.6667f, 686.0f,
    2950.0f,    690.0f, 2983.3333f, 693.0f, 3033.3333f, 688.0f, 3066.6667f, 683.0f,
    3100.0f,    679.0f, 3133.3333f, 681.0f, 3166.6667f, 685.0f, 3216.6667f, 692.0f,
};

/** @ghidraAddress 0x30aba8 */
constexpr float kPart40PosXCurve[] = {
    2766.6667f, 680.0f, 2833.3333f, 669.0f, 2883.3333f, 660.0f, 2933.3333f, 651.0f,
    2966.6667f, 646.0f, 3016.6667f, 639.0f, 3050.0f,    634.0f, 3083.3333f, 629.0f,
    3133.3333f, 623.0f, 3166.6667f, 620.0f, 3216.6667f, 615.0f,
};

/** @ghidraAddress 0x30ac00 */
constexpr float kPart40PosYCurve[] = {
    2766.6667f, 668.0f, 2833.3333f, 676.0f, 2883.3333f, 683.0f, 2933.3333f, 688.0f,
    2966.6667f, 686.0f, 3016.6667f, 682.0f, 3050.0f,    682.0f, 3083.3333f, 682.0f,
    3133.3333f, 685.0f, 3166.6667f, 688.0f, 3216.6667f, 693.0f,
};

/** @ghidraAddress 0x30ac58 */
constexpr float kPart3fScaleCurve[] = {
    2766.6667f,
    0.0f,
    2883.3333f,
    1.0f,
    3300.0f,
    1.0f,
    3450.0f,
    1.1f,
    3566.6667f,
    0.95f,
    3683.3333f,
    1.0f,
};

// Parts 0x41..0x4f: fifteen parts arranged around a small ring, each blinking on its own long
// schedule. The last two sit off the ring and use a longer scale curve that pops them in.
constexpr int kPart41Count = 15;
constexpr int kPart41AlphaPairs = 5;
constexpr int kPart41LateScalePairs = 7;
// The first index of the two parts that take the longer scale curve, and how many there are.
constexpr int kPart41LateFirst = 13;
constexpr int kPart41LateCount = 2;

/** @ghidraAddress 0x30ac88 */
constexpr float kPart41PosX[kPart41Count] = {
    384.0f,
    394.0f,
    399.0f,
    400.0f,
    398.0f,
    394.0f,
    385.0f,
    375.0f,
    371.0f,
    369.0f,
    370.0f,
    375.0f,
    384.0f,
    415.0f,
    416.0f,
};

/** @ghidraAddress 0x30acc4 */
constexpr float kPart41PosY[kPart41Count] = {
    620.0f,
    621.0f,
    626.0f,
    636.0f,
    644.0f,
    649.0f,
    650.0f,
    649.0f,
    644.0f,
    635.0f,
    626.0f,
    621.0f,
    635.0f,
    594.0f,
    600.0f,
};

/** @ghidraAddress 0x30ad00 */
constexpr float kPart41AlphaCurve[kPart41Count][kPart41AlphaPairs * 2] = {
    {2966.6667f, 1.0f, 8700.0f, 1.0f, 9466.667f, 0.0f, 9983.333f, 0.0f, 10050.0f, 1.0f},
    {2966.6667f, 1.0f, 8766.667f, 1.0f, 9533.333f, 0.0f, 10000.0f, 0.0f, 10066.667f, 1.0f},
    {2966.6667f, 1.0f, 8833.333f, 1.0f, 9600.0f, 0.0f, 10016.667f, 0.0f, 10083.333f, 1.0f},
    {2966.6667f, 1.0f, 8900.0f, 1.0f, 9666.667f, 0.0f, 10033.333f, 0.0f, 10100.0f, 1.0f},
    {2966.6667f, 1.0f, 8966.667f, 1.0f, 9733.333f, 0.0f, 10050.0f, 0.0f, 10116.667f, 1.0f},
    {2966.6667f, 1.0f, 9033.333f, 1.0f, 9800.0f, 0.0f, 10066.667f, 0.0f, 10133.333f, 1.0f},
    {2966.6667f, 1.0f, 9100.0f, 1.0f, 9866.667f, 0.0f, 10083.333f, 0.0f, 10150.0f, 1.0f},
    {2966.6667f, 1.0f, 9166.667f, 1.0f, 9933.333f, 0.0f, 10100.0f, 0.0f, 10166.667f, 1.0f},
    {2966.6667f, 1.0f, 9200.0f, 1.0f, 9966.667f, 0.0f, 10116.667f, 0.0f, 10183.333f, 1.0f},
    {2966.6667f, 1.0f, 9233.333f, 1.0f, 10000.0f, 0.0f, 10133.333f, 0.0f, 10200.0f, 1.0f},
    {2966.6667f, 1.0f, 9266.667f, 1.0f, 10033.333f, 0.0f, 10150.0f, 0.0f, 10216.667f, 1.0f},
    {2966.6667f, 1.0f, 9300.0f, 1.0f, 10066.667f, 0.0f, 10166.667f, 0.0f, 10233.333f, 1.0f},
    {2966.6667f, 1.0f, 9333.333f, 1.0f, 10100.0f, 0.0f, 10183.333f, 0.0f, 10250.0f, 1.0f},
    {2966.6667f, 1.0f, 8700.0f, 1.0f, 9333.333f, 0.0f, 10083.333f, 0.0f, 10100.0f, 1.0f},
    {2966.6667f, 1.0f, 8833.333f, 1.0f, 9466.667f, 0.0f, 10133.333f, 0.0f, 10150.0f, 1.0f},
};

/** @ghidraAddress 0x30af58 */
constexpr float kPart41LateScaleCurve[] = {
    2966.6667f,
    0.0f,
    3100.0f,
    1.2f,
    3200.0f,
    1.0f,
    3300.0f,
    1.0f,
    3450.0f,
    1.1f,
    3566.6667f,
    0.95f,
    3683.3333f,
    1.0f,
};

// The ambient breathing scale every settled part shares: a slow swell and dip back to unity.
constexpr int kAmbientScalePairs = 4;
/** @ghidraAddress 0x30af90 */
constexpr float kAmbientScaleCurve[] = {
    3300.0f,
    1.0f,
    3450.0f,
    1.1f,
    3566.6667f,
    0.95f,
    3683.3333f,
    1.0f,
};

// Parts 0x29 and 0x28: the two parts stacked over the fixed point below, each with its own scale
// curve that repeats the ambient swell once more near the end of the loop.
constexpr int kPart29ScalePairs = 8;
constexpr int kPart29AlphaPairs = 2;
constexpr int kPart2aAlphaPairs = 2;
constexpr int kPart28AlphaPairs = 6;
constexpr int kPart28ScalePairs = 3;

/** @ghidraAddress 0x30afb0 */
constexpr float kPart29ScaleCurve[] = {
    3300.0f,
    1.0f,
    3450.0f,
    1.1f,
    3566.6667f,
    0.95f,
    3683.3333f,
    1.0f,
    10266.667f,
    1.0f,
    10416.667f,
    1.1f,
    10533.333f,
    0.95f,
    10650.0f,
    1.0f,
};

/** @ghidraAddress 0x30aff0 */
constexpr float kPart28AlphaCurve[] = {
    3566.6667f,
    0.0f,
    3683.3333f,
    1.0f,
    10266.667f,
    1.0f,
    10416.667f,
    0.1f,
    10533.333f,
    0.75f,
    10650.0f,
    1.0f,
};

/** @ghidraAddress 0x30b020 */
constexpr float kPart28ScaleCurve[] = {10416.667f, 1.0f, 10533.333f, 0.95f, 10650.0f, 1.0f};

/** @ghidraAddress 0x309510 */
constexpr float kPart3ePosXCurve[] = {2666.6667f, 594.0f, 2833.3333f, 604.0f};
/** @ghidraAddress 0x309520 */
constexpr float kPart3ePosYCurve[] = {2666.6667f, 708.0f, 2833.3333f, 708.0f};
/** @ghidraAddress 0x309530 */
constexpr float kPart3eAlphaCurve[] = {2666.6667f, 0.0f, 2833.3333f, 1.0f};
/** @ghidraAddress 0x309540 */
constexpr float kPart52PosXCurve[] = {3416.6667f, 578.0f, 3600.0f, 588.0f};
/** @ghidraAddress 0x309550 */
constexpr float kPart52AlphaCurve[] = {3416.6667f, 0.0f, 3600.0f, 1.0f};
/** @ghidraAddress 0x309560 */
constexpr float kPart2aAlphaCurve[] = {3300.0f, 1.0f, 3416.6667f, 0.0f};
/** @ghidraAddress 0x309570 */
constexpr float kPart29AlphaCurve[] = {3233.3333f, 0.0f, 3300.0f, 1.0f};
constexpr int kPart3eCurvePairs = 2;
constexpr int kPart52CurvePairs = 2;

// Parts 1..4 sweep across the screen once per particle-burst window: their three fade-in/fade-out
// windows line up exactly with the three burst gates below.
constexpr int kPart01Count = 4;
constexpr int kPart01PathPairs = 6;
constexpr int kPart01AlphaPairs = 9;
constexpr int kPart01ScalePairs = 6;
// The first part kind the sweep emits. The binary runs its counter from -4 to -1 and adds 5.
constexpr unsigned int kPartKindSweepFirst = 1;

/** @ghidraAddress 0x30b038 */
constexpr float kPart01PosXCurve[kPart01Count][kPart01PathPairs * 2] = {
    {3583.3333f,
     102.0f,
     6566.6665f,
     102.0f,
     10533.333f,
     260.0f,
     13233.333f,
     260.0f,
     15500.0f,
     154.0f,
     18483.334f,
     56.0f},
    {3583.3333f,
     260.0f,
     6283.3335f,
     260.0f,
     10533.333f,
     476.0f,
     12816.667f,
     476.0f,
     15500.0f,
     292.0f,
     18200.0f,
     156.0f},
    {3583.3333f,
     624.0f,
     6800.0f,
     624.0f,
     10533.333f,
     102.0f,
     13516.667f,
     102.0f,
     15500.0f,
     624.0f,
     18716.666f,
     704.0f},
    {3583.3333f,
     476.0f,
     5866.6665f,
     476.0f,
     10533.333f,
     624.0f,
     13750.0f,
     624.0f,
     15500.0f,
     476.0f,
     17783.334f,
     602.0f},
};

/** @ghidraAddress 0x30b0f8 */
constexpr float kPart01PosYCurve[kPart01Count][kPart01PathPairs * 2] = {
    {3583.3333f,
     574.0f,
     6566.6665f,
     534.0f,
     10533.333f,
     674.0f,
     13233.333f,
     634.0f,
     15500.0f,
     586.0f,
     18483.334f,
     788.0f},
    {3583.3333f,
     674.0f,
     6283.3335f,
     634.0f,
     10533.333f,
     684.0f,
     12816.667f,
     644.0f,
     15500.0f,
     632.0f,
     18200.0f,
     524.0f},
    {3583.3333f,
     580.0f,
     6800.0f,
     540.0f,
     10533.333f,
     574.0f,
     13516.667f,
     534.0f,
     15500.0f,
     580.0f,
     18716.666f,
     514.0f},
    {3583.3333f,
     684.0f,
     5866.6665f,
     644.0f,
     10533.333f,
     580.0f,
     13750.0f,
     540.0f,
     15500.0f,
     684.0f,
     17783.334f,
     752.0f},
};

/** @ghidraAddress 0x30b1b8 */
constexpr float kPart01AlphaCurve[kPart01Count][kPart01AlphaPairs * 2] = {
    {3583.3333f,
     0.0f,
     3683.3333f,
     0.6f,
     6566.6665f,
     0.0f,
     10533.333f,
     0.0f,
     10633.333f,
     0.6f,
     13233.333f,
     0.0f,
     15500.0f,
     0.0f,
     15600.0f,
     0.6f,
     18483.334f,
     0.0f},
    {3583.3333f,
     0.0f,
     3683.3333f,
     0.6f,
     6283.3335f,
     0.0f,
     10533.333f,
     0.0f,
     10633.333f,
     0.6f,
     12816.667f,
     0.0f,
     15500.0f,
     0.0f,
     15600.0f,
     0.6f,
     18200.0f,
     0.0f},
    {3583.3333f,
     0.0f,
     3683.3333f,
     0.6f,
     6800.0f,
     0.0f,
     10533.333f,
     0.0f,
     10633.333f,
     0.6f,
     13516.667f,
     0.0f,
     15500.0f,
     0.0f,
     15600.0f,
     0.6f,
     18733.334f,
     0.0f},
    {3583.3333f,
     0.0f,
     3683.3333f,
     0.6f,
     5866.6665f,
     0.0f,
     10533.333f,
     0.0f,
     10633.333f,
     0.6f,
     13750.0f,
     0.0f,
     15500.0f,
     0.0f,
     15600.0f,
     0.6f,
     17783.334f,
     0.0f},
};

/** @ghidraAddress 0x30b2d8 */
constexpr float kPart01ScaleCurve[kPart01Count][kPart01ScalePairs * 2] = {
    {3600.0f,
     1.0f,
     6566.6665f,
     1.8f,
     10550.0f,
     1.0f,
     13233.333f,
     1.8f,
     15516.667f,
     1.0f,
     18483.334f,
     2.2f},
    {3600.0f,
     1.0f,
     6283.3335f,
     1.8f,
     10550.0f,
     1.0f,
     12733.333f,
     1.8f,
     15516.667f,
     1.0f,
     18200.0f,
     2.2f},
    {3600.0f,
     1.0f,
     6800.0f,
     1.8f,
     10550.0f,
     1.0f,
     13516.667f,
     1.8f,
     15516.667f,
     1.0f,
     18733.334f,
     2.2f},
    {3600.0f,
     1.0f,
     5866.6665f,
     1.8f,
     10550.0f,
     1.0f,
     13750.0f,
     1.8f,
     15516.667f,
     1.0f,
     17783.334f,
     2.2f},
};

// Part 0x51 pulses over the corner button's own clock rather than the animation clock: a triangular
// ramp up to the half-second mark and back down over one second.
constexpr int kPart51AlphaPairs = 3;
/** @ghidraAddress 0x30b398 */
constexpr float kPart51AlphaCurve[] = {0.0f, 0.0f, 500.0f, 1.0f, 1000.0f, 0.0f};

// The fixed part positions the sweep does not curve. @ghidraAddress 0x30949c, 0x3094a0, 0x305350,
// 0x3094a4, 0x3094a8, 0x3094b8, 0x3094bc
constexpr float kPart52PosY = 748.0f;
constexpr float kPart29PosX = 399.0f;
constexpr float kPart29PosY = 657.0f;
constexpr float kPart28PosX = 404.0f;
constexpr float kPart28PosY = 662.0f;
constexpr float kPart50PosX = 389.0f;
constexpr float kPart50PosY = 991.0f;

// The three particle-burst windows: the animation time each opens at, how long each stays open, and
// the offset added to the animation clock to give the burst its own zero-based time.
constexpr int kBurstWindowCount = 3;
constexpr int kBurstWindowStart[kBurstWindowCount] = {0xe00, 0x2926, 0x3c9d};
constexpr int kBurstWindowSpan = 0x79e;
/** @ghidraAddress 0x3094ac */
constexpr float kBurstTimeOffset[kBurstWindowCount] = {-3583.3333f, -10533.333f, -15516.667f};

// The animation clock's loop: past the end it rewinds to where the intro curves finish, so only the
// ambient portion repeats.
constexpr int kAnimationLoopEnd = 0x492e;
constexpr int kAnimationLoopStart = 0xe63;

// The animation times each gated group waits for.
constexpr int kPart2cGate = 0xa6a;
constexpr int kPart41Gate = 0xb96;
constexpr int kPart2aGateStart = 0xbeb;
constexpr int kPart2aGateSpan = 0x7bf;
constexpr int kPart29Gate = 0xca1;

// The part kinds the sweep emits, in program order.
constexpr unsigned int kPartKindBackdrop = 0;
constexpr unsigned int kPartKindLead = 0x2b;
constexpr unsigned int kPartKindRowFirst = 0x2c;
constexpr unsigned int kPartKindPopFirst = 0x36;
constexpr unsigned int kPartKindRestFirst = 0x3a;
constexpr unsigned int kPartKindSolo = 0x3e;
constexpr unsigned int kPartKindOpaqueA = 0x3f;
constexpr unsigned int kPartKindOpaqueB = 0x40;
constexpr unsigned int kPartKindStrip = 0x52;
constexpr unsigned int kPartKindRingFirst = 0x41;
constexpr unsigned int kPartKindStackMid = 0x2a;
constexpr unsigned int kPartKindStackLow = 0x29;
constexpr unsigned int kPartKindStackTop = 0x28;
constexpr unsigned int kPartKindCornerBase = 0x50;
constexpr unsigned int kPartKindCornerPulse = 0x51;

// The unit scale and zero rotation most emits pass, and the fully-opaque alpha.
constexpr float kUnitScale = 1.0f;
constexpr float kNoRotation = 0.0f;
constexpr unsigned int kOpaqueAlpha = 255;

// The leave transition: the fade curve the start prompt seeds, the BGM fade-out time, the corporate
// button's target alpha, and the fade value that hands over to the finish state.
// @ghidraAddress 0x3094c0 (the four-float fade seed)
constexpr float kLeaveFadeEnd = 1.0f;
constexpr float kLeaveFadeDuration = 1500.0f;
constexpr float kLeaveFadeElapsed = 0.0f;
constexpr float kLeaveFadeStartDelay = 1000.0f;
constexpr float kLeaveMusicFadeTime = 0.5f;
constexpr float kCorporateButtonAlpha = 0.0f;
constexpr float kFadeComplete = 1.0f;

// The corner button's pulse clock: its one-second period, the step that wraps it, and how many
// extra times the frame delta is added once the title is leaving.
// @ghidraAddress 0x2f8540 (g_flAchievementRateHashScale), 0x2f8544
constexpr float kCornerPulsePeriod = 1000.0f;
constexpr float kCornerPulseWrapStep = -1000.0f;
constexpr int kCornerPulseLeavingExtra = 5;

// How far a drag must travel on its longer axis to register as a flick.
constexpr float kSwipeDeadZone = 25.0f;

// The audition shot sound the lead part plays.
constexpr unsigned long kShotAuditionChannel = 1;
constexpr int kShotAuditionVariant = 0;

// The hit rectangles the part emitter records, by the role each one drives.
constexpr int kHitRectStart = 0;
constexpr int kHitRectShotSound = 1;
constexpr int kHitRectSecretA = 2;
constexpr int kHitRectSecretB = 3;
constexpr int kHitRectVoice = 4;

// The hidden-code sound effect, and the animation time the completed code rewinds the clock to.
constexpr int kSoundEffectTitleSecret = 0xd;
constexpr int kSecretReplayTimerValue = 0x24fa;

// The inputs the hidden-code sequence accepts.
enum TitleSwipeInput {
    kTitleSwipeUp = 0,      // An upward flick.
    kTitleSwipeDown = 1,    // A downward flick.
    kTitleSwipeLeft = 2,    // A leftward flick.
    kTitleSwipeRight = 3,   // A rightward flick.
    kTitleSwipeButtonA = 4, // The "A" confirm input that completes the sequence.
    kTitleSwipeButtonB = 5, // The "B" input, the penultimate step.
};

// How far through the sequence the player has got.
enum TitleSwipeStep {
    kSwipeStepNone = 0,      // No input entered yet.
    kSwipeStepUp1 = 1,       // First up entered.
    kSwipeStepUp2 = 2,       // Second up entered.
    kSwipeStepDown1 = 3,     // First down entered.
    kSwipeStepDown2 = 4,     // Second down entered.
    kSwipeStepLeft1 = 5,     // First left entered.
    kSwipeStepRight1 = 6,    // First right entered.
    kSwipeStepLeft2 = 7,     // Second left entered.
    kSwipeStepRight2 = 8,    // Second right entered.
    kSwipeStepButtonB = 9,   // B entered; the next A completes the sequence.
    kSwipeStepComplete = 10, // The sequence completed.
};

// Samples one animation curve at the frame's animation time. The binary inlines this conversion at
// each of the sweep's curve sites.
inline float SampleCurve(const float *pPairs, int nPairs, int nTime) {
    return CalculateCurveInterpolation(pPairs, nPairs, static_cast<float>(nTime));
}

// Converts a sampled unit-interval curve value into a colour-channel alpha.
inline unsigned int CurveToAlpha(float flCurve) {
    return static_cast<unsigned int>(flCurve * kBurstAlphaByteScale);
}

// Whether a touch point lies inside one of the hit rectangles the part emitter records.
inline bool IsInsideHitRect(const rb::TitleLimelightScene::HitRect &rect, float flX, float flY) {
    return (flX >= rect.x) && (flX <= rect.x + rect.width) && (flY >= rect.y) &&
           (flY <= rect.y + rect.height);
}

} // namespace

namespace rb {

/** @ghidraAddress 0x152de8 */
TitleLimelightScene::TitleLimelightScene() {
    // The UI-layer base constructor ran first and the compiler installed the title dispatch vtable;
    // the presentation state is otherwise zero-initialised by the member initialisers.
    m_flFadeValue = kInitialFadeValue;
    m_nTrackedTouchId = kNoTrackedTouch;
}

/**
 * @ghidraAddress 0x152e90
 * @ghidraAddress 0x152f4c
 */
TitleLimelightScene::~TitleLimelightScene() {
    ReleaseResources();
}

/** @ghidraAddress 0x152edc */
void TitleLimelightScene::ReleaseResources() {
    // Release and null each cached texture.
    for (ne::C_TEXTURE *&pTexture : m_apTextures) {
        if (pTexture != nullptr) {
            pTexture->Release();
            pTexture = nullptr;
        }
    }
    // The part instancers are owned by the scene graph; flag each for the scene walker and null it.
    for (ne::C_SPRITE_INSTANCING_2D *&pSprite : m_apSprites) {
        if (pSprite != nullptr) {
            pSprite->RequestDelete();
            pSprite = nullptr;
        }
    }
}

/** @ghidraAddress 0x152f84 */
void TitleLimelightScene::OnFrame(int nElapsedMs) {
    switch (m_nState) {
    case kStateLoad:
        LoadResources();
        return;
    case kStateStartMusic:
        StartMusic();
        return;
    case kStateRender:
        RenderFrame(nElapsedMs);
        return;
    case kStateFinish:
        FinishAndOpenList();
        return;
    default:
        return;
    }
}

/** @ghidraAddress 0x152fc8 */
void TitleLimelightScene::LoadResources() {
    m_nAnimationTime = 0;

    // Load the three title textures.
    for (int nTexture = 0; nTexture < kTextureCount; ++nTexture) {
        m_apTextures[nTexture] = ne::C_TEXTURE::FindOrLoadCached(kTitleTextureNames[nTexture]);
    }

    // Build the part sprite instancers (each holds one sprite): register each in the global scene
    // tree, make it visible, bind its texture from the per-device part-layout table (unless the
    // record marks it untextured), and seed its sprite count.
    const TitlePartLayoutRecord *pLayout =
        IsPad() ? g_aTitle2PartLayoutAltFrame : g_aTitle2PartLayoutDefault;
    for (int nSlot = 0; nSlot < kSpriteSlotCount; ++nSlot) {
        ne::C_SPRITE_INSTANCING_2D *pSprite = ne::CreateSpriteInstancer(1);
        pSprite->RegisterGlobal();
        pSprite->SetVisible(true);
        if (pLayout[nSlot].nTextureIndex != kUntexturedTextureIndex) {
            pSprite->SetRefCountedMember(m_apTextures[pLayout[nSlot].nTextureIndex]);
        }
        pSprite->SetSpriteCount(m_aSpriteCount[nSlot]);
        m_apSprites[nSlot] = pSprite;
    }

    // Start the title BGM and load the title voice and shot-sound banks.
    [RBBGMManager.getInstance LoadMusicTitleWithLoop:NO];
    SoundEffectManager::GetInstance()->LoadThemedVoiceData(kTitleVoiceId);
    ShotSoundManager::GetInstance()->LoadSlotVariants(GameSystem::GetGameSystem()->GetShotType());

    // Seed the fade curve from the current fade value and arm the ready-delay timer, then advance.
    m_flFadeStart = m_flFadeValue;
    m_flFadeEnd = 0.0f;
    m_flFadeDuration = kTitleFadeDuration;
    m_flFadeElapsed = 0.0f;
    m_nReadyDelay = kTitleReadyDelay;
    m_nState = kStateStartMusic;
}

/** @ghidraAddress 0x153190 */
void TitleLimelightScene::StartMusic() {
    m_nState = kStateRender;
    [RBBGMManager.getInstance PlayMusic:kTitleBgmFadeInTime];
}

/** @ghidraAddress 0x1531fc */
void TitleLimelightScene::RenderFrame(int nElapsedMs) {
    const int nDeltaFrames = nElapsedMs;

    // Cache the viewport size the part emitter halves into the part layout's screen origin.
    const GameSystem *pGameSystem = GameSystem::GetGameSystem();
    m_flViewportWidth = pGameSystem->GetViewportWidth();
    m_flViewportHeight = pGameSystem->GetViewportHeight();

    // Advance the animation clock, rewinding it to the end of the intro once it runs off the end so
    // that only the ambient portion repeats. The ready delay is read before the clock moves.
    const int nReadyDelay = m_nReadyDelay;
    const int nAdvanced = m_nAnimationTime + nDeltaFrames;
    m_nAnimationTime = (nAdvanced < kAnimationLoopEnd) ? nAdvanced : kAnimationLoopStart;
    const int nTime = m_nAnimationTime;

    // Start the frame with every part instancer empty; each emit appends to its own instancer.
    for (ne::C_SPRITE_INSTANCING_2D *pSprite : m_apSprites) {
        pSprite->SetSpriteCount(0);
    }

    // Count the ready delay down and fire the title voice on the frame it expires.
    if (nReadyDelay > 0) {
        m_nReadyDelay = nReadyDelay - nDeltaFrames;
        if (m_nReadyDelay < 1) {
            SoundEffectManager::GetInstance()->PlayThemedVoice(kTitleVoiceId);
        }
    }

    AdvanceFadeValue(nDeltaFrames);

    // The backdrop fills the viewport from its centre.
    RenderPartsElement(kPartKindBackdrop,
                       kOpaqueAlpha,
                       m_flViewportWidth * kHalf,
                       m_flViewportHeight * kHalf,
                       kUnitScale,
                       kNoRotation);

    // The lead part flies in along its own path; it is the only emit that takes a rotation.
    {
        const float flPosX = SampleCurve(kPart2bPosXCurve, kPart2bPathPairs, nTime);
        const float flPosY = SampleCurve(kPart2bPosYCurve, kPart2bPathPairs, nTime);
        const float flRotation = SampleCurve(kPart2bRotationCurve, kPart2bRotationPairs, nTime);
        const float flAlpha = SampleCurve(kPart2bAlphaCurve, kPart2bAlphaPairs, nTime);
        RenderPartsElement(
            kPartKindLead, CurveToAlpha(flAlpha), flPosX, flPosY, kUnitScale, flRotation);
    }

    // The row of ten parts rises into place once the intro reaches its gate. The binary restages
    // this group's two curve tables onto the stack on every iteration; because the tables are
    // read-only they are indexed in place here instead.
    if (nTime > kPart2cGate) {
        for (int nPart = 0; nPart < kPart2cCount; ++nPart) {
            const float flPosY = SampleCurve(kPart2cPosYCurve[nPart], kPart2cPosYPairs, nTime);
            const float flAlpha = SampleCurve(kPart2cAlphaCurve[nPart], kPart2cAlphaPairs, nTime);
            const float flScale = SampleCurve(kAmbientScaleCurve, kAmbientScalePairs, nTime);
            RenderPartsElement(kPartKindRowFirst + static_cast<unsigned int>(nPart),
                               CurveToAlpha(flAlpha),
                               kPart2cPosX[nPart],
                               flPosY,
                               flScale,
                               kNoRotation);
        }
    }

    // Four parts pop in at their fixed points with an overshoot before settling.
    for (int nPart = 0; nPart < kPart36Count; ++nPart) {
        const float flScale = SampleCurve(kPart36ScaleCurve[nPart], kPart36ScalePairs, nTime);
        const float flAlpha = SampleCurve(kPart36AlphaCurve[nPart], kPart36AlphaPairs, nTime);
        RenderPartsElement(kPartKindPopFirst + static_cast<unsigned int>(nPart),
                           CurveToAlpha(flAlpha),
                           kPart36PosX[nPart],
                           kPart36PosY[nPart],
                           flScale,
                           kNoRotation);
    }

    // Four more parts share those fade-in curves but take the ambient scale from the outset.
    for (int nPart = 0; nPart < kPart36Count; ++nPart) {
        const float flAlpha = SampleCurve(kPart36AlphaCurve[nPart], kPart36AlphaPairs, nTime);
        const float flScale = SampleCurve(kAmbientScaleCurve, kAmbientScalePairs, nTime);
        RenderPartsElement(kPartKindRestFirst + static_cast<unsigned int>(nPart),
                           CurveToAlpha(flAlpha),
                           kPart3aPosX[nPart],
                           kPart3aPosY[nPart],
                           flScale,
                           kNoRotation);
    }

    // The solo part slides a short distance as it fades in.
    {
        const float flPosX = SampleCurve(kPart3ePosXCurve, kPart3eCurvePairs, nTime);
        const float flPosY = SampleCurve(kPart3ePosYCurve, kPart3eCurvePairs, nTime);
        const float flAlpha = SampleCurve(kPart3eAlphaCurve, kPart3eCurvePairs, nTime);
        const float flScale = SampleCurve(kAmbientScaleCurve, kAmbientScalePairs, nTime);
        RenderPartsElement(
            kPartKindSolo, CurveToAlpha(flAlpha), flPosX, flPosY, flScale, kNoRotation);
    }

    // The two fully opaque parts each travel their own dense path and share one scale curve.
    {
        const float flPosX = SampleCurve(kPart3fPosXCurve, kPart3fPathPairs, nTime);
        const float flPosY = SampleCurve(kPart3fPosYCurve, kPart3fPathPairs, nTime);
        const float flScale = SampleCurve(kPart3fScaleCurve, kPart3fScalePairs, nTime);
        RenderPartsElement(kPartKindOpaqueA, kOpaqueAlpha, flPosX, flPosY, flScale, kNoRotation);
    }
    {
        const float flPosX = SampleCurve(kPart40PosXCurve, kPart40PathPairs, nTime);
        const float flPosY = SampleCurve(kPart40PosYCurve, kPart40PathPairs, nTime);
        const float flScale = SampleCurve(kPart3fScaleCurve, kPart3fScalePairs, nTime);
        RenderPartsElement(kPartKindOpaqueB, kOpaqueAlpha, flPosX, flPosY, flScale, kNoRotation);
    }

    // The strip part slides horizontally along a fixed line.
    {
        const float flPosX = SampleCurve(kPart52PosXCurve, kPart52CurvePairs, nTime);
        const float flAlpha = SampleCurve(kPart52AlphaCurve, kPart52CurvePairs, nTime);
        RenderPartsElement(
            kPartKindStrip, CurveToAlpha(flAlpha), flPosX, kPart52PosY, kUnitScale, kNoRotation);
    }

    // The ring of fifteen parts, each blinking on its own long schedule. The last two sit off the
    // ring and pop in on a longer scale curve than the shared ambient one.
    if (nTime > kPart41Gate) {
        for (int nPart = 0; nPart < kPart41Count; ++nPart) {
            const bool bIsLate =
                (nPart >= kPart41LateFirst) && (nPart < kPart41LateFirst + kPart41LateCount);
            const float flScale =
                bIsLate ? SampleCurve(kPart41LateScaleCurve, kPart41LateScalePairs, nTime) :
                          SampleCurve(kAmbientScaleCurve, kAmbientScalePairs, nTime);
            const float flAlpha = SampleCurve(kPart41AlphaCurve[nPart], kPart41AlphaPairs, nTime);
            RenderPartsElement(kPartKindRingFirst + static_cast<unsigned int>(nPart),
                               CurveToAlpha(flAlpha),
                               kPart41PosX[nPart],
                               kPart41PosY[nPart],
                               flScale,
                               kNoRotation);
        }
    }

    // The three stacked parts over one fixed point. The middle one shows only inside its window.
    if (static_cast<unsigned int>(nTime - kPart2aGateStart) < kPart2aGateSpan) {
        const float flScale = SampleCurve(kAmbientScaleCurve, kAmbientScalePairs, nTime);
        const float flAlpha = SampleCurve(kPart2aAlphaCurve, kPart2aAlphaPairs, nTime);
        RenderPartsElement(kPartKindStackMid,
                           CurveToAlpha(flAlpha),
                           kPart29PosX,
                           kPart29PosY,
                           flScale,
                           kNoRotation);
    }
    if (nTime > kPart29Gate) {
        const float flAlpha = SampleCurve(kPart29AlphaCurve, kPart29AlphaPairs, nTime);
        const float flScale = SampleCurve(kPart29ScaleCurve, kPart29ScalePairs, nTime);
        RenderPartsElement(kPartKindStackLow,
                           CurveToAlpha(flAlpha),
                           kPart29PosX,
                           kPart29PosY,
                           flScale,
                           kNoRotation);
        // The binary re-tests the same gate here; nothing changes the clock in between.
        if (nTime > kPart29Gate) {
            const float flTopAlpha = SampleCurve(kPart28AlphaCurve, kPart28AlphaPairs, nTime);
            const float flTopScale = SampleCurve(kPart28ScaleCurve, kPart28ScalePairs, nTime);
            RenderPartsElement(kPartKindStackTop,
                               CurveToAlpha(flTopAlpha),
                               kPart28PosX,
                               kPart28PosY,
                               flTopScale,
                               kNoRotation);
        }
    }

    // The four sweeping parts, whose three fade windows line up with the three burst windows below.
    for (int nPart = 0; nPart < kPart01Count; ++nPart) {
        const float flPosX = SampleCurve(kPart01PosXCurve[nPart], kPart01PathPairs, nTime);
        const float flPosY = SampleCurve(kPart01PosYCurve[nPart], kPart01PathPairs, nTime);
        const float flAlpha = SampleCurve(kPart01AlphaCurve[nPart], kPart01AlphaPairs, nTime);
        const float flScale = SampleCurve(kPart01ScaleCurve[nPart], kPart01ScalePairs, nTime);
        RenderPartsElement(kPartKindSweepFirst + static_cast<unsigned int>(nPart),
                           CurveToAlpha(flAlpha),
                           flPosX,
                           flPosY,
                           flScale,
                           kNoRotation);
    }

    // Each burst window replays the star field from its own zero-based time.
    for (int nWindow = 0; nWindow < kBurstWindowCount; ++nWindow) {
        if (static_cast<unsigned int>(nTime - kBurstWindowStart[nWindow]) < kBurstWindowSpan) {
            RenderParticleBurst(static_cast<float>(nTime) + kBurstTimeOffset[nWindow]);
        }
    }

    // The corner button: an always-opaque base with a pulsing overlay on top of it. The overlay
    // rides its own one-second clock, which runs six times as fast once the title is leaving.
    RenderPartsElement(
        kPartKindCornerBase, kOpaqueAlpha, kPart50PosX, kPart50PosY, kUnitScale, kNoRotation);

    m_flCornerButtonClock += static_cast<float>(nDeltaFrames);
    if (m_bLeaving) {
        m_flCornerButtonClock += static_cast<float>(nDeltaFrames * kCornerPulseLeavingExtra);
    }
    while (m_flCornerButtonClock >= kCornerPulsePeriod) {
        m_flCornerButtonClock += kCornerPulseWrapStep;
    }
    {
        const float flAlpha = CalculateCurveInterpolation(
            kPart51AlphaCurve, kPart51AlphaPairs, m_flCornerButtonClock);
        RenderPartsElement(kPartKindCornerPulse,
                           CurveToAlpha(flAlpha),
                           kPart50PosX,
                           kPart50PosY,
                           kUnitScale,
                           kNoRotation);
    }

    // Once the start prompt has been taken the frame stops accepting input and only waits out the
    // fade.
    if (!m_bLeaving) {
        TouchManager *pTouchManager = TouchManager::FetchSharedSingleton();
        if (m_nTrackedTouchId == kNoTrackedTouch) {
            if (pTouchManager->GetActiveTouchCount() > 0) {
                // The terms sheet takes priority over the title's own hit rectangles.
                if ([AppDelegate.appDelegate needUpdateTerms]) {
                    [AppDelegate.appDelegate showTerms];
                    return;
                }
                // Only the first freshly-added touch counts, whether or not it hits anything.
                for (int nTouch = 0; nTouch < pTouchManager->GetActiveTouchCount(); ++nTouch) {
                    TouchPoint *pTouch = pTouchManager->GetActiveTouch(nTouch);
                    if (!pTouch->bIsNew) {
                        continue;
                    }
                    m_nTrackedTouchId = pTouch->nId;
                    const auto flTouchX = static_cast<float>(pTouch->nCurrentX);
                    const auto flTouchY = static_cast<float>(pTouch->nCurrentY);
                    if (IsInsideHitRect(m_aHitRects[kHitRectStart], flTouchX, flTouchY)) {
                        // Commit: seed the leave fade, stop the BGM, and hand the corporate button
                        // off to the view controller.
                        m_flFadeStart = m_flFadeValue;
                        m_flFadeEnd = kLeaveFadeEnd;
                        m_flFadeDuration = kLeaveFadeDuration;
                        m_flFadeElapsed = kLeaveFadeElapsed;
                        m_flFadeStartDelay = kLeaveFadeStartDelay;
                        [RBBGMManager.getInstance StopMusic:kLeaveMusicFadeTime];
                        m_bLeaving = true;
                        SoundEffectManager::GetInstance()->PlaySharedSoundEffect();
                        [AppDelegate.appDelegate.viewController
                            fadeCorporateButton:kCorporateButtonAlpha];
                    } else if (IsInsideHitRect(m_aHitRects[kHitRectSecretA], flTouchX, flTouchY)) {
                        AdvanceSwipeState(kTitleSwipeButtonA);
                    } else if (IsInsideHitRect(m_aHitRects[kHitRectSecretB], flTouchX, flTouchY)) {
                        // The compiler inlined this one input; the other button keeps its call.
                        AdvanceSwipeState(kTitleSwipeButtonB);
                    } else if (IsInsideHitRect(
                                   m_aHitRects[kHitRectShotSound], flTouchX, flTouchY)) {
                        ShotSoundManager::GetInstance()->PlaySlot(
                            kShotAuditionChannel,
                            GameSystem::GetGameSystem()->GetShotType(),
                            kShotAuditionVariant);
                    } else if (IsInsideHitRect(m_aHitRects[kHitRectVoice], flTouchX, flTouchY)) {
                        SoundEffectManager::GetInstance()->PlayThemedVoice(kTitleVoiceId);
                    }
                    break;
                }
            }
        } else {
            // A tracked touch: when it ends, its net travel is read as a flick.
            TouchPoint *pTouch = pTouchManager->FindTouchById(m_nTrackedTouchId);
            if (pTouch == nullptr) {
                m_nTrackedTouchId = kNoTrackedTouch;
            } else if (pTouch->bEnded) {
                m_nTrackedTouchId = kNoTrackedTouch;
                const float flDragX =
                    static_cast<float>(pTouch->nCurrentX) - static_cast<float>(pTouch->nBeginX);
                const float flDragY =
                    static_cast<float>(pTouch->nCurrentY) - static_cast<float>(pTouch->nBeginY);
                const float flAbsX = (flDragX > 0.0f) ? flDragX : -flDragX;
                const float flAbsY = (flDragY > 0.0f) ? flDragY : -flDragY;
                // The longer axis wins; a drag shorter than the dead zone on it registers as
                // nothing. The compiler inlined each of these four calls.
                if (flAbsX <= flAbsY) {
                    if (flDragY > kSwipeDeadZone) {
                        AdvanceSwipeState(kTitleSwipeDown);
                    } else if (flDragY < -kSwipeDeadZone) {
                        AdvanceSwipeState(kTitleSwipeUp);
                    }
                } else if (flDragX > kSwipeDeadZone) {
                    AdvanceSwipeState(kTitleSwipeRight);
                } else if (flDragX < -kSwipeDeadZone) {
                    AdvanceSwipeState(kTitleSwipeLeft);
                }
            }
        }

        // Until the start prompt is taken the frame ends here.
        if (!m_bLeaving) {
            return;
        }
    }

    if (m_flFadeValue >= kFadeComplete) {
        m_nState = kStateFinish;
    }
}

/** @ghidraAddress 0x154288 */
void TitleLimelightScene::FinishAndOpenList() {
    // Wait until the fade-out audio has fully stopped before tearing down.
    if (![AudioManager.sharedManager isStart]) {
        return;
    }
    ReleaseResources();
    // Construct the gameplay scene into the game system's leading scene slot, then open the music
    // list through the app's root view controller.
    rb::GameScene::GetInstance(GameSystem::GetGameSystem()->GetCurrentSceneSlot());
    [AppDelegate.appDelegate.viewController showMusicListView];
    MarkDead();
}

/** @ghidraAddress 0x154380 */
void TitleLimelightScene::AdvanceFadeValue(int nDeltaFrames) {
    // Past the fade duration, snap to the end value.
    if (m_flFadeElapsed >= m_flFadeDuration) {
        m_flFadeValue = m_flFadeEnd;
        return;
    }

    // Accumulate the elapsed frames, clamping to the duration.
    m_flFadeElapsed += static_cast<float>(nDeltaFrames);
    if (m_flFadeElapsed < m_flFadeStartDelay) {
        return;
    }
    if (m_flFadeElapsed > m_flFadeDuration) {
        m_flFadeElapsed = m_flFadeDuration;
    }

    // Interpolate from the start to the end value over the span past the start delay.
    float flProgress;
    if (m_flFadeDuration == 0.0f) {
        flProgress = 1.0f;
    } else {
        flProgress =
            (m_flFadeElapsed - m_flFadeStartDelay) / (m_flFadeDuration - m_flFadeStartDelay);
    }
    m_flFadeValue = m_flFadeStart + flProgress * (m_flFadeEnd - m_flFadeStart);
}

/** @ghidraAddress 0x1543fc */
void TitleLimelightScene::RenderPartsElement(unsigned int nKind,
                                             unsigned int nColorAlpha,
                                             float flTransformX,
                                             float flTransformY,
                                             float flSize,
                                             float flRotation) {
    if (nKind >= static_cast<unsigned int>(kSpriteSlotCount)) {
        return;
    }
    ne::C_SPRITE_INSTANCING_2D *pInstancer = m_apSprites[nKind];
    const int nSlot = pInstancer->GetSpriteCount();
    if (nSlot >= static_cast<int>(pInstancer->GetCapacity())) {
        return;
    }

    if (nKind == 0) {
        // The background: a full-texture quad sized from the instancer's bound texture.
        ne::C_TEXTURE *pTexture = pInstancer->GetBoundTexture();
        const float flScale = pTexture->GetScale();
        const float flPointWidth = static_cast<float>(pTexture->GetImageWidth()) / flScale;
        const float flPointHeight = static_cast<float>(pTexture->GetImageHeight()) / flScale;

        pInstancer->SetSpriteAnchor(nSlot, S_VECTOR2{flPointWidth * kHalf, flPointHeight * kHalf});
        pInstancer->SetSpriteSize(nSlot, S_VECTOR2{flPointWidth, flPointHeight});
        pInstancer->SetSpriteUvOrigin(nSlot, S_VECTOR2{0.0f, 0.0f});
        pInstancer->SetSpriteUvSize(
            nSlot,
            S_VECTOR2{static_cast<float>(pTexture->GetImageWidth()) / pTexture->GetAllocWidth(),
                      static_cast<float>(pTexture->GetImageHeight()) / pTexture->GetAllocHeight()});
        pInstancer->SetSpritePosition(nSlot, S_VECTOR2{flTransformX, flTransformY});
        // The background draws at the texture's retina scale, not the caller's scale.
        pInstancer->SetSpriteScale(nSlot, flScale, flScale);
    } else {
        // A lettered or logo part: its anchor, size, and atlas frame come from the per-device
        // layout record (the record's position/size fields serve as the sprite anchor and size
        // here).
        const bool bIsPad = IsPad();
        const TitlePartLayoutRecord &layout =
            bIsPad ? g_aTitle2PartLayoutAltFrame[nKind] : g_aTitle2PartLayoutDefault[nKind];
        const float flAnchorX = layout.flPosX;
        const float flAnchorY = layout.flPosY;
        const float flSizeX = layout.flWidth;
        const float flSizeY = layout.flHeight;

        // The anchor mode selects the atlas: mode one draws from the per-device lettered/logo
        // atlas, any other mode from the shared default title-part atlas.
        const SpriteUvEntry *pUvTable;
        if (layout.nTextureIndex != kPartAnchorModeAtlas) {
            pUvTable = g_aTitlePartUvDefault;
        } else if (bIsPad) {
            pUvTable = g_aTitle2PartUvAlt;
        } else {
            pUvTable = g_aTitle2PartUvMain;
        }
        const SpriteUvEntry &uv = pUvTable[layout.nUvIndex];
        pInstancer->SetSpriteUvOrigin(nSlot, S_VECTOR2{uv.flOriginU, uv.flOriginV});
        pInstancer->SetSpriteUvSize(nSlot, S_VECTOR2{uv.flSizeU, uv.flSizeV});

        // Map the part's transform into screen space. The iPad layout is already in screen units
        // barring the Y offset; the default device also scales about the screen offsets.
        float flPosX;
        float flPosY;
        if (bIsPad) {
            flPosX = flTransformX;
            flPosY = (flTransformY + kPartScreenOffsetY) + m_flViewportHeight * kHalf;
        } else {
            flPosX =
                (flTransformX + kPartScreenOffsetX) * kPartScreenScale + m_flViewportWidth * kHalf;
            flPosY =
                (flTransformY + kPartScreenOffsetY) * kPartScreenScale + m_flViewportHeight * kHalf;
        }
        pInstancer->SetSpritePosition(nSlot, S_VECTOR2{flPosX, flPosY});
        pInstancer->SetSpriteAnchor(nSlot, S_VECTOR2{flAnchorX, flAnchorY});
        pInstancer->SetSpriteSize(nSlot, S_VECTOR2{flSizeX, flSizeY});
        pInstancer->SetSpriteScale(nSlot, flSize, flSize);

        // Record the interactive parts' touch rectangles (top-left corner, then size) for the title
        // touch tests. Kind 0x50 (the start prompt) is padded outwards on the default device.
        const float flRectX = flPosX - flAnchorX;
        const float flRectY = flPosY - flAnchorY;
        switch (nKind) {
        case kPartKindHit0:
            m_aHitRects[1] = {flRectX, flRectY, flSizeX, flSizeY};
            break;
        case kPartKindHit1:
            m_aHitRects[3] = {flRectX, flRectY, flSizeX, flSizeY};
            break;
        case kPartKindHit2:
            m_aHitRects[2] = {flRectX, flRectY, flSizeX, flSizeY};
            break;
        case kPartKindHit3:
            m_aHitRects[4] = {flRectX, flRectY, flSizeX, flSizeY};
            break;
        case kPartKindHit4:
            if (bIsPad) {
                m_aHitRects[0] = {flRectX, flRectY, flSizeX, flSizeY};
            } else {
                m_aHitRects[0] = {flRectX + kStartPromptOffsetX,
                                  flRectY + kStartPromptOffsetY,
                                  flSizeX + kStartPromptWidthPad,
                                  flSizeY + kStartPromptHeightPad};
            }
            break;
        default:
            break;
        }
    }

    pInstancer->SetSpriteRotation(nSlot, flRotation);

    // Tint by the intro-fade complement: a grey (1 - fade) with the caller's alpha scaled by it.
    const float flIntensity = 1.0f - m_flFadeValue;
    const auto nChannel = static_cast<unsigned int>(flIntensity * kColorMax);
    const auto nAlpha = static_cast<unsigned int>(static_cast<float>(nColorAlpha) * flIntensity);
    pInstancer->SetSpriteColor(nSlot, nChannel, nChannel, nChannel, nAlpha);

    pInstancer->SetSpriteCount(nSlot + 1);
}

/** @ghidraAddress 0x15484c */
void TitleLimelightScene::RenderParticleBurst(float flTime) {
    for (int nParticle = 0; nParticle < kBurstParticleCount; ++nParticle) {
        const float flPosY =
            CalculateCurveInterpolation(kBurstYCurve[nParticle], kBurstCurvePairs, flTime);
        const float flAlpha =
            CalculateCurveInterpolation(kBurstAlphaCurve[nParticle], kBurstCurvePairs, flTime);
        float flScale =
            CalculateCurveInterpolation(kBurstScaleCurve[nParticle], kBurstCurvePairs, flTime);
        // The hidden code doubles every particle's scale.
        if (m_bSecretActive) {
            flScale += flScale;
        }
        RenderPartsElement(kBurstPartKindBase + static_cast<unsigned int>(nParticle),
                           static_cast<unsigned int>(flAlpha * kBurstAlphaByteScale),
                           kBurstParticleX[nParticle],
                           flPosY,
                           flScale,
                           0.0f);
    }
}

/** @ghidraAddress 0x1549b8 */
void TitleLimelightScene::AdvanceSwipeState(int nSwipeEvent) {
    switch (nSwipeEvent) {
    case kTitleSwipeUp:
        if (m_nSwipeState != kSwipeStepUp1) {
            if (m_nSwipeState != kSwipeStepNone) {
                return;
            }
            m_nSwipeState = kSwipeStepUp1;
        }
        m_nSwipeState = kSwipeStepUp2;
        return;
    case kTitleSwipeDown:
        if (m_nSwipeState != kSwipeStepDown1) {
            if (m_nSwipeState != kSwipeStepUp2) {
                return;
            }
            m_nSwipeState = kSwipeStepDown1;
        }
        m_nSwipeState = kSwipeStepDown2;
        return;
    case kTitleSwipeLeft:
        if (m_nSwipeState == kSwipeStepRight1) {
            m_nSwipeState = kSwipeStepLeft2;
        } else if (m_nSwipeState == kSwipeStepDown2) {
            m_nSwipeState = kSwipeStepLeft1;
        }
        return;
    case kTitleSwipeRight:
        if (m_nSwipeState == kSwipeStepLeft2) {
            m_nSwipeState = kSwipeStepRight2;
        } else if (m_nSwipeState == kSwipeStepLeft1) {
            m_nSwipeState = kSwipeStepRight1;
        }
        return;
    case kTitleSwipeButtonA:
        // The final A completes the code: fire the secret effect, latch the flag, rewind the timer.
        if (m_nSwipeState == kSwipeStepButtonB) {
            m_nSwipeState = kSwipeStepComplete;
            SoundEffectManager::GetInstance()->PlayThemedSoundEffect(kSoundEffectTitleSecret);
            m_bSecretActive = true;
            m_nAnimationTime = kSecretReplayTimerValue;
        }
        return;
    case kTitleSwipeButtonB:
        if (m_nSwipeState == kSwipeStepRight2) {
            m_nSwipeState = kSwipeStepButtonB;
        }
        return;
    default:
        return;
    }
}

} // namespace rb
