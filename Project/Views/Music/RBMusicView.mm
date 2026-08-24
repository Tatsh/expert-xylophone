#import "RBMusicView.h"

#import <ctime>

#import "AppDelegate.h"
#import "MusicData.h"
#import "MusicDataExtend.h"
#import "NSFileManager+RB.h"
#import "RBBGMManager.h"
#import "RBCoreDataManager.h"
#import "RBExtendNoteManager.h"
#import "RBMenuTutorialView.h"
#import "RBMenuView.h"
#import "RBMusicARView.h"
#import "RBMusicCPUView.h"
#import "RBMusicColorView.h"
#import "RBMusicDifficultyView.h"
#import "RBMusicHistoryView.h"
#import "RBMusicManager.h"
#import "RBMusicOtherView.h"
#import "RBMusicScoreView.h"
#import "RBMusicSpeedView.h"
#import "RBTutorialManager.h"
#import "RBUserSettingData.h"
#import "RBViewController.h"
#import "ReplayData.h"
#import "ScoreData.h"
#import "UIColor+RB.h"
#import "UIImage+RB.h"
#import "deviceenvironment.h"
#import "engineglobals.h"
#import "engineruntime.h"
#import "gamesystem.h"
#include "neDebugLog.h"
#import "soundeffectmanager.h"

// @ghidraAddress 0x2eedc0 (the shared g_dMascotMessageAnimDuration engine constant, 0.2)
extern const double g_dMascotMessageAnimDuration;

// The per-difficulty score, achievement-rate, rank, play-count, and full-combo tables are indexed
// by difficulty. Four difficulty slots exist (basic, medium, hard, and the extended chart).
enum { kDifficultyCount = 4 };

// The three setting pages hosted by the paged setting scroll.
enum {
    kSettingPageColor = 0,
    kSettingPageDifficulty = 1,
    kSettingPageCpu = 2,
    kSettingPageCount = 3,
};

// The five setting title images cycled by the setting scroll on the default (non-variant) layout.
enum { kSettingTitleImageCount = 5 };

// The game types written into m_GameType.
enum {
    kGameTypeSingle = 0,
    kGameTypeDouble = 1,
    kGameTypeReplay = 2,
};

// The extended (level 4) difficulty selects the extended music record.
enum { kDifficultyExtended = 3 };
enum {
    kDifficultyBasic = 0,
    kDifficultyMedium = 1,
    kDifficultyHard = 2,
};

// The extended chart stores its replay under difficulty slot 0.
enum { kExtendedReplayDifficulty = 0 };

// The user's ghost style; style 1 shows the ghost fully opaque, any other style dims it.
enum { kGhostStyleReplay = 1 };

// The themed sound-effect slot played by the detail-view close animation.
enum { kSoundEffectCancel = 4 };

// The tutorial song's music id, loaded by playTutorialGame.
static const int kTutorialMusicID = 0x3b9ac9fe;

// The tutorial CPU combo count seeded before the tutorial game.
static const int kTutorialComboCount = 10;

// The pastel bonus type stored on the game system for each pastel selection.
enum {
    kPastelBonusNone = 0,
    kPastelBonusWhite = 1,
    kPastelBonusBlack = 2,
};

// The combo counts the pastel modes seed on the game system.
enum {
    kPastelWhiteCombo = 2,
    kPastelBlackComboLow = 0xb,
    kPastelBlackComboHigh = 0xc,
};

// The two ghost-indicator opacities.
static const CGFloat kGhostAlphaOpaque = 1.0;
static const CGFloat kGhostAlphaDimmed = 0.5;

// The two setting-button highlight opacities.
static const CGFloat kSettingButtonAlphaSelected = 1.0;
static const CGFloat kSettingButtonAlphaDimmed = 0.5;

// The music-view dimming cover colour is the first entry of the shared UIColor palette
// (RBPaletteIndexDimmingCover): 50%-translucent black.
static UIColor *MusicViewCoverColor(void) {
    return [UIColor rbPaletteColorAtIndex:RBPaletteIndexDimmingCover];
}

// The base-view fade opacities used by the show/hide animations.
static const CGFloat kBaseViewAlphaVisible = 1.0;
static const CGFloat kBaseViewAlphaHidden = 0.0;

// The BPM digit column is at most three digits wide.
enum { kBpmDigitCount = 3 };

// The number of animated select-line images and layers.
enum { kLineImageCount = 10 };

// The autoresizing mask applied to the line overlay and its layers: the four flexible margins
// (0x2d = flexible left, right, top, and bottom margins).
static const UIViewAutoresizing kLineAutoresizingMask =
    UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
    UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;

// Background-music fade durations, in seconds: the pause fade applied when the detail view animates
// in, the fade used to retry the select BGM, and the fade of the base-view intro cross-fade.
static const float kBgmPauseFadeDuration = 0.25f;
static const float kBgmReplayFadeDuration = 1.5f;
static const NSTimeInterval kMusicViewCoverFadeDuration = 0.25;

// The delay, in seconds, before the setting-scroll hint advances to its next step.
static const NSTimeInterval kFirstInfoScrollRetryDelay = 0.5;

// The full rival alpha seeded for the tutorial game.
static const float kTutorialRivalAlpha = 1.0f;

// The play-colour coin-flip threshold: when both colours are allowed, a unit-interval random draw
// at or above this value selects colour 1, otherwise colour 0.
static const float kPlayColorRandomThreshold = 0.5f;

// The black-pastel combo roll: a random draw modulo kPastelBlackComboRollModulo above
// kPastelBlackComboRollThreshold seeds the higher combo count, otherwise the lower.
enum {
    kPastelBlackComboRollModulo = 0x65,
    kPastelBlackComboRollThreshold = 0x59,
};

// The setting-scroll page index that shows each setting title image on the default layout. Pages 2
// and 3 map to title images 3 and 4 (images 2 and 5 are shown on other layouts).
enum {
    kSettingTitlePage0 = 0,
    kSettingTitlePage1 = 1,
    kSettingTitlePage2 = 2,
    kSettingTitlePage3 = 3,
};
enum {
    kSettingTitleImagePage0 = 0,
    kSettingTitleImagePage1 = 1,
    kSettingTitleImagePage2 = 3,
    kSettingTitleImagePage3 = 4,
};

// The setting-scroll page-snap rounding threshold: a fractional page above this rounds up.
static const float kSettingPageSnapThreshold = 0.5f;

// 1 / RAND_MAX, used to fold rand() into the unit interval, and the multiplier that expands a unit
// float into the full 32-bit random-seed range.
static const float kInverseRandMax = 1.0f / static_cast<float>(RAND_MAX);
static const float kRandSeedScale = 4294967300.0f;
// The scale SetupView applies to the unit float when it seeds the score readout, giving a
// random value in [0, 9998].
static const float kSeedScoreScale = 9999.0f; // @ghidraAddress 0x3014d4

// The BPM digit image names, indexed by digit value.
static NSString *const kBpmDigitImageNames[] = {
    @"02_music_detail/det_bpm_0",
    @"02_music_detail/det_bpm_1",
    @"02_music_detail/det_bpm_2",
    @"02_music_detail/det_bpm_3",
    @"02_music_detail/det_bpm_4",
    @"02_music_detail/det_bpm_5",
    @"02_music_detail/det_bpm_6",
    @"02_music_detail/det_bpm_7",
    @"02_music_detail/det_bpm_8",
    @"02_music_detail/det_bpm_9",
};

// The rank badge images, indexed by rank code (0 is the highest clear rank). The binary's table
// starts at det_ran_5 and descends.
static NSString *const kRankImageNames[] = {
    @"02_music_detail/det_ran_5",
    @"02_music_detail/det_ran_4",
    @"02_music_detail/det_ran_3",
    @"02_music_detail/det_ran_2",
    @"02_music_detail/det_ran_1",
    @"02_music_detail/det_ran_0",
};

// The animated select-line overlay layer geometry (anchor point and layer position per line),
// decoded from the guard-initialised static table at @0x3dc700 (sourced from @0x301440). Verified
// store-by-store against the disassembly at @0xd27c4..@0xd2868.
namespace {
struct SelLineLayer {
    double anchorX;
    double anchorY;
    double positionX;
    double positionY;
};
} // namespace
static const SelLineLayer kSelLineLayout[] = {
    {1.0, 0.0, 272.0, -1.0},  // 0
    {0.0, 0.0, 0.0, 10.0},    // 1
    {0.0, 0.0, 0.0, 662.0},   // 2
    {0.0, 0.0, 272.0, -1.0},  // 3
    {0.0, 0.0, 535.0, 10.0},  // 4
    {1.0, 0.0, 546.0, 662.0}, // 5
    {1.0, 0.0, 529.0, 20.0},  // 6
    {0.0, 0.0, 15.0, 21.0},   // 7
    {0.0, 0.0, 15.0, 657.0},  // 8
    {0.0, 1.0, 528.0, 657.0}, // 9
};

// The ten select-line overlay images (from the CFString table at @0x35a5f8).
static NSString *const kSelLineImageNames[] = {
    @"01_music_select/sel_line1_1",
    @"01_music_select/sel_line1_2",
    @"01_music_select/sel_line1_3",
    @"01_music_select/sel_line2_1",
    @"01_music_select/sel_line2_2",
    @"01_music_select/sel_line2_3",
    @"01_music_select/sel_line3_1",
    @"01_music_select/sel_line3_2",
    @"01_music_select/sel_line4_1",
    @"01_music_select/sel_line4_2",
};

// The wide-popup base frame the line overlay container uses, decoded from g_dPopupBaseOriginXWide
// (112.0), DAT_1003013f0 (161.0), g_dPopupBaseWidthWide (546.0), and g_dPopupBaseHeightWide
// (680.0).
static const CGFloat kPopupBaseOriginXWide = 112.0;
static const CGFloat kPopupBaseOriginYWide = 161.0;
static const CGFloat kPopupBaseWidthWide = 546.0;
static const CGFloat kPopupBaseHeightWide = 680.0;

// The half scale applied to the line overlay on the compact (non-variant) layout.
static const CGFloat kSelLineHalfScale = 0.5;
// The select-line layer transaction is committed with no animation and the layers start hidden.
static const CFTimeInterval kSelLineAnimationDuration = 0.0;
static const float kSelLineOpacity = 0.0f;

// ---- SetupView constants (all decoded from the raw arm64 of the decompiler-crashing method) ----

// The RBUserSettingData.difficulty sentinel: the "white hard" slot (3) is clamped back to HARD (2).
enum { kDifficultyWhiteHard = 3 };

// The autoresizing masks used by SetupView: the outer view keeps its top and bottom margins
// flexible; the base panel keeps the four flexible margins; the first-info overlay keeps its width
// and height flexible.
static const UIViewAutoresizing kSetupOuterAutoresizingMask =
    UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
static const UIViewAutoresizing kSetupFirstInfoAutoresizingMask =
    UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

// The setting-scroll page counts: the iPad idiom carries a fifth page, every other idiom four.
enum {
    kSettingPagesNormal = 5,
    kSettingPagesAlt = 4,
};
static const CGFloat kScrollPagesNormal = 5.0;
static const CGFloat kScrollPagesAlt = 4.0;

// The page control's transform scale (0.8) and its two indicator tint whites (0.666 and 0.5).
static const CGFloat kPageScale = 0.8;
static const CGFloat kPageTintWhite = 0.6666666865;
static const CGFloat kPageTintWhiteCurrent = 0.5;

// The dimmed alpha applied to the name images on the Limelight theme (0.7).
static const CGFloat kNameAlphaDim = 0.699999988;
static const CGFloat kNameAlphaFull = 1.0;

// The setting sub-view page indices (page X = index * scroll width). The CPU and other sub-views
// sit at pages 3 and 4 on the wide (iPad) layout, and at pages 2 and 3 on the narrow one — the
// narrow CPU view deliberately shares the speed view's page, exactly as the binary lays it out.
static const CGFloat kColorPage = 0.0;
static const CGFloat kDifficultyPage = 1.0;
static const CGFloat kSpeedPage = 2.0;
static const CGFloat kCpuPageWide = 3.0;
static const CGFloat kOtherPageWide = 4.0;
static const CGFloat kCpuPageNarrow = 2.0;
static const CGFloat kOtherPageNarrow = 3.0;

// The theme-2 overlay is centred at half the jacket size; the first-info overlay is centred at half
// the view width.
static const CGFloat kOverlayHalf = 0.5;
static const CGFloat kFirstInfoCenterXFactor = 0.5;

// The initial selected setting page.
enum { kSetupInitialSetting = 1 };

// The base-panel image table (thema 0/1), indexed by frame-bonus type.
static NSString *const kDetMbgTable[] = {
    @"02_music_detail/det_mbg_d",
    @"02_music_detail/det_mbg_g",
    @"02_music_detail/det_mbg_p",
    @"02_music_detail/det_mbg",
    @"02_music_detail/det_mbg_r1",
    @"02_music_detail/det_mbg_r2",
};

// The theme-2 overlay-over-jacket image table (@0x35afa0), indexed by frame-bonus type.
static NSString *const kDetMbgTheme2Table[] = {
    @"02_music_detail/det_mbg_r1",
    @"02_music_detail/det_mbg_r2",
    @"02_music_detail/det_mbg_r3",
    @"02_music_detail/det_sel_col",
    @"02_music_detail/det_sel_dif",
    @"02_music_detail/det_sel_spd",
};

// The setting title images (@0x35afb8): colour, difficulty, speed, level, and other.
static NSString *const kSettingTitleTable[] = {
    @"02_music_detail/det_sel_col",
    @"02_music_detail/det_sel_dif",
    @"02_music_detail/det_sel_spd",
    @"02_music_detail/det_sel_lev",
    @"02_music_detail/det_sel_oth",
};

// The theme decide-button image table (@0x35b010), indexed by frame-bonus type; the brown theme
// picks its fixed index-3 entry (det_dec_s).
// The binary keeps two separate button-image tables, each indexed by the frame-bonus type and each
// followed by the fixed image the Colette theme uses instead. Classic and Limelight index their
// table; Colette takes the fixed entry. The two sets are theme-exclusive on disk: 01_Classic ships
// det_dec_ds/gs/ps and dd/gd/pd but no det_dec_s or det_dec_d, and Colette ships only the latter
// pair, so indexing the wrong table yields a nil image and a zero-sized button.
// @ghidraAddress 0x35b010
static NSString *const kDetDecSingleTable[] = {
    @"02_music_detail/det_dec_ds",
    @"02_music_detail/det_dec_gs",
    @"02_music_detail/det_dec_ps",
};
static NSString *const kDetDecSingleColette =
    @"02_music_detail/det_dec_s"; // @ghidraAddress 0x35b028

// @ghidraAddress 0x35b030
static NSString *const kDetDecDoubleTable[] = {
    @"02_music_detail/det_dec_dd",
    @"02_music_detail/det_dec_gd",
    @"02_music_detail/det_dec_pd",
};
static NSString *const kDetDecDoubleColette =
    @"02_music_detail/det_dec_d"; // @ghidraAddress 0x35b048

// The detail-view geometry per (iPad idiom, theme) leg. The block at @0xcca64..@0xccf30 branches
// on IsPad and then on _thema, giving six legs, and spills the chosen one into callee-saved d
// registers and stack slots; every value below was recovered by running that block per leg and
// chasing each call site's arguments back to the home that fed it. The layout structure holds one
// leg's values. The address trailing each row is the call site that consumes it, not the pool the
// number is stored in, so these are deliberately not @ghidraAddress tags.
namespace {
struct DetailGeometry {
    CGFloat jacketX, jacketY, jacketSize;
    CGFloat nameFrameX, nameFrameY, artistFrameY;         // iPad idiom (setFrame:) legs
    CGFloat nameCenterX, musicNameCenterY, artistCenterY; // default (setCenter:) legs
    CGFloat scoreX, scoreY, scoreW, scoreH;
    CGFloat rankX, rankY;
    CGFloat fullComboX, fullComboY;
    CGFloat arX, arY;
    CGFloat itunesX, itunesY;
    CGFloat bpmX, bpmY;
    CGFloat scrollX, scrollY, scrollW, scrollH;
    CGFloat pageX, pageY, pageW, pageH;
    CGFloat titleX, titleY, titleW, titleH;
    CGFloat ghostX, ghostY;
};
} // namespace

// The standalone (leg-independent) geometry consumed after the big block.
static const CGFloat kDecideX = 44.0;
static const CGFloat kDecideY = 546.0;
static const CGFloat kWhitePastelCenterX = 160.0;
static const CGFloat kWhitePastelCenterY = 297.0;
static const CGFloat kBlackPastelCenterX = 160.0;
static const CGFloat kBlackPastelCenterY = 287.0;
// The right-hand slot of the lower button row, shared by the double-play button and the second
// pastel button, which are alternates for the same position. Both frames take their size straight
// from their background image. @ghidraAddress 0x3013d8 (x) and 0x3013d0 (y).
static const CGFloat kDecideRightX = 282.0;
static const CGFloat kDecideRightY = 546.0;
static const CGFloat kBlackPastel2X = 282.0;
static const CGFloat kBlackPastel2Y = 546.0;
static const CGFloat kHistoryOffsetX = 110.0;
static const CGFloat kHistoryOffsetY = 160.0;
static const CGFloat kFirstInfoCenterY = 40.0;

// The geometry and table identifiers below keep the older theme labels they were first
// reconstructed under: "Brown" and "Theme2" are the Colette theme
// (RBUserSettingDataThemeColette), and "White" is Limelight (RBUserSettingDataThemeLimelight).
// The code and comments use the RBUserSettingDataTheme names; only these identifiers still carry
// the old spelling.

// The iPad idiom Brown-theme leg (@0xccafc). Uses the setFrame: name path.
static const DetailGeometry kGeometryWideBrown = {
    53.0,  56.0,  180.0,        // jacket @0xcd2b8
    266.0, 40.0,  84.0,         // name-frame (variant path) @0xcd468, @0xcd64c
    0.0,   0.0,   0.0,          // name-centre (unused on the variant path)
    268.0, 170.0, 220.0, 33.0,  // score @0xcde0c
    430.0, 188.0,               // rank @0xcdf00
    412.0, 169.0,               // full combo @0xce03c
    268.0, 240.0,               // ar @0xce0ec
    388.0, 108.0,               // itunes @0xcdd48
    266.0, 128.0,               // bpm origin @0xccf40
    31.0,  322.0, 488.0, 183.0, // scroll @0xce31c
    152.0, 470.0, 240.0, 20.0,  // page @0xce5c8
    38.0,  306.0, 122.0, 16.0,  // setting title @0xce274
    387.0, 235.0,               // ghost @0xcf104
};

// The iPad idiom non-Brown leg (@0xccd44). jacketX, jacketY, and the setting-title y are picked
// from two-entry theme tables (non-white then white); the white values are recorded here and the
// non-white overrides are applied in-line. Every other value is shared by both themes.
static const DetailGeometry kGeometryWideOther = {
    53.0,  67.0,  180.0,        // jacket @0xcd2b8 (white; non-white: x 52, y 66)
    263.0, 69.0,  94.0,         // name-frame (variant path) @0xcd468, @0xcd64c
    0.0,   0.0,   0.0,          // name-centre (unused on the variant path)
    263.0, 205.0, 220.0, 33.0,  // score @0xcde0c
    428.0, 206.0,               // rank @0xcdf00
    421.0, 197.0,               // full combo @0xce03c
    429.0, 244.0,               // ar @0xce0ec
    263.0, 140.0,               // itunes @0xcdd48
    293.0, 118.0,               // bpm origin @0xccf40
    44.0,  322.0, 456.0, 183.0, // scroll @0xce31c
    152.0, 470.0, 240.0, 20.0,  // page @0xce5c8
    211.0, 298.0, 122.0, 16.0,  // setting title @0xce274 (white; non-white y 302)
    390.0, 208.0,               // ghost @0xcf104
};
static const CGFloat kWideOtherJacketXNonWhite = 52.0;
static const CGFloat kWideOtherJacketYNonWhite = 66.0;
static const CGFloat kWideOtherTitleYNonWhite = 302.0;

// The narrow Brown-theme leg (@0xccc64). Uses the setCenter: name path.
static const DetailGeometry kGeometryNarrowBrown = {
    20.0,  55.0,  90.0,        // jacket @0xcd2b8
    0.0,   0.0,   0.0,         // name-frame (unused on the default path)
    160.0, 22.0,  41.0,        // name-centre @0xcd498, @0xcd6e0
    131.0, 98.0,  94.0,  28.0, // score @0xcde0c
    251.0, 105.0,              // rank @0xcdf00
    242.0, 95.0,               // full combo @0xce03c
    131.0, 135.0,              // ar @0xce0ec
    222.0, 56.0,               // itunes @0xcdd48
    132.0, 71.0,               // bpm origin @0xccf40
    10.0,  176.0, 300.0, 96.0, // scroll @0xce31c
    60.0,  257.0, 200.0, 10.0, // page @0xce5c8
    12.0,  165.0, 84.0,  12.0, // setting title @0xce274
    220.0, 124.0,              // ghost @0xcf104
};

// The narrow non-Brown leg (@0xcce50). Only the setting-title y is theme-picked, from a two-entry
// table (non-white then white); every other value is shared by both themes.
static const DetailGeometry kGeometryNarrowOther = {
    20.0,  56.0,  74.0,        // jacket @0xcd2b8
    0.0,   0.0,   0.0,         // name-frame (unused on the default path)
    160.0, 24.0,  45.0,        // name-centre @0xcd498, @0xcd6e0
    111.0, 102.0, 94.0,  28.0, // score @0xcde0c
    252.0, 101.0,              // rank @0xcdf00
    244.0, 97.0,               // full combo @0xce03c
    244.0, 89.0,               // ar @0xce0ec
    222.0, 55.0,               // itunes @0xcdd48
    143.0, 75.0,               // bpm origin @0xccf40
    10.0,  160.0, 300.0, 96.0, // scroll @0xce31c
    60.0,  246.0, 200.0, 10.0, // page @0xce5c8
    118.0, 147.0, 84.0,  12.0, // setting title @0xce274 (white; non-white y 150)
    214.0, 104.0,              // ghost @0xcf104
};
static const CGFloat kNarrowOtherTitleYNonWhite = 150.0;

@interface RBMusicView () {
    // Private ivars, named exactly as in the binary's ivar list (some carry a leading m_, some a
    // leading underscore). The score, achievement-rate, rank, play-count, and full-combo tables are
    // indexed by difficulty.
    int m_GameType;
    int m_SelectedSetting;
    int m_Score[kDifficultyCount];      // +0x10, per-difficulty score
    float m_AR[kDifficultyCount];       // +0x20, per-difficulty achievement rate
    int m_Rank[kDifficultyCount];       // +0x30, per-difficulty clear rank (derived from m_AR)
    BOOL m_FullCombo[kDifficultyCount]; // +0x40
    int m_PlayCount[kDifficultyCount];  // +0x44, per-difficulty play count
    BOOL m_Animating;
    BOOL m_FirstInfo;
    int _thema;
}
// The themed music-name image accessor factored out of the switchWithDifficulty: dispatch (the
// binary inlines the twelve theme-by-difficulty accessor calls).
- (nullable UIImage *)musicNameImageOfMusic:(MusicData *)music forDifficulty:(int)difficulty;
// De-inlined SetupView helper (the binary draws the BPM strip inline via UIGraphics); not a
// distinct selector in the binary.
- (void)buildBpmImageForMin:(int)bpmMin max:(int)bpmMax;
- (nullable UIImage *)bpmImageForMin:(int)bpmMin max:(int)bpmMax;
@end

@implementation RBMusicView

#pragma mark Lifecycle

- (instancetype)initWithFrame:(CGRect)frame MusicData:(MusicData *)MusicData {
    self = [super initWithFrame:frame];
    if (self) {
        self->_thema = [RBUserSettingData sharedInstance].thema;
        // The binary sends setMusicData: twice in a row.
        [self setMusicData:MusicData];
        [self setMusicData:MusicData];
        self->m_GameType = kGameTypeSingle;
        [self SetupView];
        [self ShowSelectDifficulty];
        [self ShowSettingView:kSettingPageDifficulty];
        if (self->_thema == RBUserSettingDataThemeClassic && IsPad()) {
            [self SetUpLineView];
        }
        [self setExclusiveTouch:YES];
    }
    return self;
}

- (void)dealloc {
    [self.settingScroll.layer removeAllAnimations];
}

#pragma mark Music data

// The plain background's index in kDetMbgTable, which the non-white themes always take.
enum { kDetMbgPlainIndex = 3 };

- (void)setMusicData:(MusicData *)musicData {
    /** @ghidraAddress 0xca818 */
    // The binary implements this setter rather than letting the property synthesise one, because
    // assigning the music data is what repopulates the card: the jacket, the score readout, the
    // name and artist strips, the background and the BPM strip are all filled here. SetupView
    // builds the subviews; this fills them for the tune being shown, so a synthesised setter
    // leaves every one of them empty.
    _musicData = musicData;
    self.jacketImage = musicData.artwork;

    NSManagedObjectContext *moc = [RBCoreDataManager sharedInstance].managedObjectContext;
    ScoreData *score = [ScoreData getScoreData:self.musicData.MusicID inManagedObjectContext:moc];
    m_Score[kDifficultyBasic] = [score.scoBas intValue];
    m_FullCombo[kDifficultyBasic] = [score.fcBas boolValue];
    m_AR[kDifficultyBasic] = [score.arBas floatValue];
    m_Rank[kDifficultyBasic] = GetClearRank(m_AR[kDifficultyBasic]);
    m_PlayCount[kDifficultyBasic] = [score.pcBas intValue];

    m_Score[kDifficultyMedium] = [score.scoMed intValue];
    m_FullCombo[kDifficultyMedium] = [score.fcMed boolValue];
    m_AR[kDifficultyMedium] = [score.arMed floatValue];
    m_Rank[kDifficultyMedium] = GetClearRank(m_AR[kDifficultyMedium]);
    m_PlayCount[kDifficultyMedium] = [score.pcMed intValue];

    m_Score[kDifficultyHard] = [score.scoHar intValue];
    m_FullCombo[kDifficultyHard] = [score.fcHar boolValue];
    m_AR[kDifficultyHard] = [score.arHar floatValue];
    m_Rank[kDifficultyHard] = GetClearRank(m_AR[kDifficultyHard]);
    m_PlayCount[kDifficultyHard] = [score.pcHar intValue];

    // The extended chart is a separate tune record, and its basic row supplies the extended slot.
    NSArray *extendNotes =
        [[RBExtendNoteManager getInstance] getExtendNoteDataWithMusicID:musicData.MusicID];
    if (extendNotes != nil && extendNotes.count != 0) {
        self.extMusicData = extendNotes[0];
        ScoreData *extendScore = [ScoreData getScoreData:self.extMusicData.ExtMusicID
                                  inManagedObjectContext:moc];
        m_Score[kDifficultyExtended] = [extendScore.scoBas intValue];
        m_FullCombo[kDifficultyExtended] = [extendScore.fcBas boolValue];
        m_AR[kDifficultyExtended] = [extendScore.arBas floatValue];
        m_Rank[kDifficultyExtended] = GetClearRank(m_AR[kDifficultyExtended]);
        m_PlayCount[kDifficultyExtended] = [extendScore.pcBas intValue];
    }

    int frameBonusType = [score getFrameBonusType];

    // Only the two lowest themes vary the background by frame bonus; the rest take the plain one.
    NSString *backgroundName = self->_thema <= RBUserSettingDataThemeLimelight ?
                                   kDetMbgTable[frameBonusType] :
                                   kDetMbgTable[kDetMbgPlainIndex];
    self.bgImageView.image = [UIImage imageWithName:backgroundName];

    // Theme 0 takes the white strips and themes 1 and 2 the black ones; any other theme leaves
    // both images untouched, which is what the binary's fall-through does.
    UIImage *musicNameSrc = nil;
    UIImage *artistNameSrc = nil;
    if (self->_thema == RBUserSettingDataThemeClassic) {
        musicNameSrc = self.musicData.musicNameImageWhite;
        artistNameSrc = self.musicData.artistNameImageWhite;
    } else if (self->_thema == RBUserSettingDataThemeLimelight ||
               self->_thema == RBUserSettingDataThemeColette) {
        musicNameSrc = self.musicData.musicNameImageBlack;
        artistNameSrc = self.musicData.artistNameImageBlack;
    }

    self.jacketImageView.image = self.jacketImage;

    // Each strip keeps its origin and takes the new artwork's size.
    if (musicNameSrc != nil) {
        self.musicNameImageView.image = musicNameSrc;
        CGRect nameFrame = self.musicNameImageView.frame;
        self.musicNameImageView.frame = CGRectMake(nameFrame.origin.x,
                                                   nameFrame.origin.y,
                                                   musicNameSrc.size.width,
                                                   musicNameSrc.size.height);
    }
    if (artistNameSrc != nil) {
        self.artistNameImageView.image = artistNameSrc;
        CGRect artistFrame = self.artistNameImageView.frame;
        self.artistNameImageView.frame = CGRectMake(artistFrame.origin.x,
                                                    artistFrame.origin.y,
                                                    artistNameSrc.size.width,
                                                    artistNameSrc.size.height);
    }

    UIImage *bpmImage = [self bpmImageForMin:self.musicData.bpm_MIN max:self.musicData.bpm_MAX];
    CGPoint bpmOrigin = self.bpmOrigin;
    self.bpmImageView.frame =
        CGRectMake(bpmOrigin.x, bpmOrigin.y, bpmImage.size.width, bpmImage.size.height);
    self.bpmImageView.image = bpmImage;

    [self SetSettingButtonSelected:1];
    [self ShowSelectDifficulty];
    [self ShowSettingView:1];
}

#pragma mark View construction

- (void)SetupView {
    // Builds the whole detail panel. Worked from raw arm64 (the decompiler crashes on this method
    // with the known RBCoreDataManager broken-struct error); every geometry constant was decoded
    // from the .const pools. @ghidraAddress 0xcc078
    NSManagedObjectContext *moc = [RBCoreDataManager sharedInstance].managedObjectContext;
    ScoreData *score = [ScoreData getScoreData:self.musicData.MusicID inManagedObjectContext:moc];

    // Each row: score, full-combo, achievement rate, the clear rank derived from the AR, and the
    // play count. m_Rank holds GetClearRank(m_AR); m_AR keeps the raw achievement-rate float.
    m_Score[kDifficultyBasic] = [score.scoBas intValue];
    m_FullCombo[kDifficultyBasic] = [score.fcBas boolValue];
    m_AR[kDifficultyBasic] = [score.arBas floatValue];
    m_Rank[kDifficultyBasic] = GetClearRank(m_AR[kDifficultyBasic]);
    m_PlayCount[kDifficultyBasic] = [score.pcBas intValue];

    m_Score[kDifficultyMedium] = [score.scoMed intValue];
    m_FullCombo[kDifficultyMedium] = [score.fcMed boolValue];
    m_AR[kDifficultyMedium] = [score.arMed floatValue];
    m_Rank[kDifficultyMedium] = GetClearRank(m_AR[kDifficultyMedium]);
    m_PlayCount[kDifficultyMedium] = [score.pcMed intValue];

    m_Score[kDifficultyHard] = [score.scoHar intValue];
    m_FullCombo[kDifficultyHard] = [score.fcHar boolValue];
    m_AR[kDifficultyHard] = [score.arHar floatValue];
    m_Rank[kDifficultyHard] = GetClearRank(m_AR[kDifficultyHard]);
    m_PlayCount[kDifficultyHard] = [score.pcHar intValue];

    int frameBonusType = [score getFrameBonusType];

    if (self.extMusicData != nil) {
        NSManagedObjectContext *extMoc = [RBCoreDataManager sharedInstance].managedObjectContext;
        ScoreData *extScore = [ScoreData getScoreData:self.extMusicData.ExtMusicID
                               inManagedObjectContext:extMoc];
        m_Score[kDifficultyExtended] = [extScore.scoBas intValue];
        m_FullCombo[kDifficultyExtended] = [extScore.fcBas boolValue];
        m_AR[kDifficultyExtended] = [extScore.arBas floatValue];
        m_Rank[kDifficultyExtended] = GetClearRank(m_AR[kDifficultyExtended]);
        m_PlayCount[kDifficultyExtended] = [extScore.pcBas intValue];
    } else {
        m_Score[kDifficultyExtended] = 0;
        m_FullCombo[kDifficultyExtended] = NO;
        m_AR[kDifficultyExtended] = 0.0f;
        m_Rank[kDifficultyExtended] = GetClearRank(0.0f);
        m_PlayCount[kDifficultyExtended] = 0;
    }

    // A saved "white hard" difficulty is clamped back down to the hard chart.
    if ([RBUserSettingData sharedInstance].difficulty == kDifficultyWhiteHard) {
        [RBUserSettingData sharedInstance].difficulty = kDifficultyHard;
    }

    self.autoresizingMask = kSetupOuterAutoresizingMask;
    self.backgroundColor = UIColor.clearColor;

    UITapGestureRecognizer *tap =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapGesture:)];
    tap.delegate = self;
    [self addGestureRecognizer:tap];

    int thema = [RBUserSettingData sharedInstance].thema;
    UIImage *basePanelImage = thema > RBUserSettingDataThemeLimelight ?
                                  [UIImage imageWithName:@"02_music_detail/det_mbg"] :
                                  [UIImage imageWithName:kDetMbgTable[frameBonusType]];

    CGSize baseSize = basePanelImage.size;
    self.baseView =
        [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, baseSize.width, baseSize.height)];
    self.baseView.center = self.center;
    self.baseView.autoresizingMask = kLineAutoresizingMask;
    self.baseView.backgroundColor = UIColor.clearColor;
    self.baseView.exclusiveTouch = YES;
    self.baseView.layer.doubleSided = NO;
    [self addSubview:self.baseView];

    UIImageView *bgImageView = [[UIImageView alloc] initWithImage:basePanelImage];
    bgImageView.exclusiveTouch = YES;
    [self.baseView addSubview:bgImageView];

    // The big geometry block: pick the leg for the current iPad idiom and theme. The dispatch ivar
    // is _thema (the binary reads it at 0xcca80 through the ivar-offset global at 0x3c8b7c): the
    // Colette theme takes its own leg, and the other legs pick Classic/non-Classic overrides.
    BOOL isPad = IsPad();
    BOOL themaIsClassic = thema == RBUserSettingDataThemeClassic;
    DetailGeometry geometry;
    if (isPad) {
        if (self->_thema == RBUserSettingDataThemeColette) {
            geometry = kGeometryWideBrown;
        } else {
            geometry = kGeometryWideOther;
            if (!themaIsClassic) {
                geometry.jacketX = kWideOtherJacketXNonWhite;
                geometry.jacketY = kWideOtherJacketYNonWhite;
                geometry.titleY = kWideOtherTitleYNonWhite;
            }
        }
    } else {
        if (self->_thema == RBUserSettingDataThemeColette) {
            geometry = kGeometryNarrowBrown;
        } else {
            geometry = kGeometryNarrowOther;
            if (!themaIsClassic) {
                geometry.titleY = kNarrowOtherTitleYNonWhite;
            }
        }
    }

    self.bpmOrigin = CGPointMake(geometry.bpmX, geometry.bpmY);

    // The name artwork variant follows the theme (the binary switches on _thema at 0xccf48).
    UIImage *musicNameSrc = nil;
    UIImage *artistNameSrc = nil;
    switch (self->_thema) {
    case RBUserSettingDataThemeClassic:
        musicNameSrc = self.musicData.musicNameImageWhite;
        artistNameSrc = self.musicData.artistNameImageWhite;
        break;
    case RBUserSettingDataThemeLimelight:
        musicNameSrc = self.musicData.musicNameImageBlack;
        artistNameSrc = self.musicData.artistNameImageBlack;
        break;
    case RBUserSettingDataThemeColette:
        musicNameSrc = self.musicData.musicNameImageBrown;
        artistNameSrc = self.musicData.artistNameImageBrown;
        break;
    default:
        break;
    }

    if (thema == RBUserSettingDataThemeColette) {
        UIImage *overlay = [UIImage imageWithName:kDetMbgTheme2Table[frameBonusType]];
        UIImageView *overlayView = [[UIImageView alloc] initWithImage:overlay];
        overlayView.center = CGPointMake(geometry.jacketX + kOverlayHalf * geometry.jacketSize,
                                         geometry.jacketY + kOverlayHalf * geometry.jacketSize);
        [self.baseView addSubview:overlayView];
    }

    self.jacketImageView = [[UIImageView alloc] initWithImage:self.jacketImage];
    self.jacketImageView.frame =
        CGRectMake(geometry.jacketX, geometry.jacketY, geometry.jacketSize, geometry.jacketSize);
    [self.baseView addSubview:self.jacketImageView];

    self.musicNameImageView = [[UIImageView alloc] initWithImage:musicNameSrc];
    // Only the Limelight theme dims the name artwork (the binary tests _thema == 1 at 0xcd368).
    self.musicNameImageView.alpha =
        self->_thema == RBUserSettingDataThemeLimelight ? kNameAlphaDim : kNameAlphaFull;
    if (isPad) {
        CGSize size = self.musicNameImageView.frame.size;
        self.musicNameImageView.frame =
            CGRectMake(geometry.nameFrameX, geometry.nameFrameY, size.width, size.height);
    } else {
        self.musicNameImageView.center =
            CGPointMake(geometry.nameCenterX, geometry.musicNameCenterY);
    }
    [self.baseView addSubview:self.musicNameImageView];

    self.artistNameImageView = [[UIImageView alloc] initWithImage:artistNameSrc];
    self.artistNameImageView.alpha =
        self->_thema == RBUserSettingDataThemeLimelight ? kNameAlphaDim : kNameAlphaFull;
    if (isPad) {
        CGSize size = self.artistNameImageView.frame.size;
        self.artistNameImageView.frame =
            CGRectMake(geometry.nameFrameX, geometry.artistFrameY, size.width, size.height);
    } else {
        self.artistNameImageView.center = CGPointMake(geometry.nameCenterX, geometry.artistCenterY);
    }
    [self.baseView addSubview:self.artistNameImageView];

    [self buildBpmImageForMin:self.musicData.bpm_MIN max:self.musicData.bpm_MAX];

    NSDictionary *purchased =
        [[RBMusicManager getInstance] getPurchasedMusicDictionary:self.musicData.MusicID];
    NSString *itunesURL = purchased[@"iTunesURL"];
    if (itunesURL != nil) {
        UIButton *itunesButton = [UIButton buttonWithType:UIButtonTypeCustom];
        UIImage *itunesImage = [UIImage imageWithName:@"09_store/store_itunes"];
        [itunesButton setImage:itunesImage forState:UIControlStateNormal];
        CGSize size = itunesImage.size;
        itunesButton.frame =
            CGRectMake(geometry.itunesX, geometry.itunesY, size.width, size.height);
        [itunesButton addTarget:self
                         action:@selector(SelectItunes)
               forControlEvents:UIControlEventTouchUpInside];
        [self.baseView addSubview:itunesButton];
        self.iTunesURL = [NSString stringWithString:itunesURL];
    }

    self.scoreView = [[RBMusicScoreView alloc]
        initWithFrame:CGRectMake(
                          geometry.scoreX, geometry.scoreY, geometry.scoreW, geometry.scoreH)];
    // The binary seeds the readout with a random four-digit value here; ShowSelectDifficulty
    // overwrites it from m_Score before the view is ever displayed.
    int seedScore =
        static_cast<int>(static_cast<float>(rand()) * kInverseRandMax * kSeedScoreScale);
    [self.scoreView UpdateScore:seedScore];
    [self.baseView addSubview:self.scoreView];

    self.rankView =
        [[UIImageView alloc] initWithFrame:CGRectMake(geometry.rankX, geometry.rankY, 0.0, 0.0)];
    [self.baseView addSubview:self.rankView];

    UIImage *fullComboImage = [UIImage imageWithName:@"02_music_detail/det_ran_combo"];
    self.fullComboView = [[UIImageView alloc] initWithImage:fullComboImage];
    CGSize fullComboSize = self.fullComboView.frame.size;
    self.fullComboView.frame = CGRectMake(
        geometry.fullComboX, geometry.fullComboY, fullComboSize.width, fullComboSize.height);
    self.fullComboView.hidden = YES;
    [self.baseView addSubview:self.fullComboView];

    self.arView =
        [[RBMusicARView alloc] initWithFrame:CGRectMake(geometry.arX, geometry.arY, 0.0, 0.0)];
    // The binary seeds the rate readout blank, not from m_AR; ShowSelectDifficulty pushes the
    // real rate immediately afterwards.
    [self.arView UpdateScore:0.0f];
    [self.baseView addSubview:self.arView];

    self.settingTitleImages = [NSMutableArray array];
    m_SelectedSetting = kSetupInitialSetting;
    for (NSUInteger i = 0; i < kSettingPagesNormal; ++i) {
        UIImageView *titleView =
            [[UIImageView alloc] initWithImage:[UIImage imageWithName:kSettingTitleTable[i]]];
        // Every page's title shares one frame, the strip directly above the settings scroll; only
        // the selected page's title is unhidden.
        titleView.frame =
            CGRectMake(geometry.titleX, geometry.titleY, geometry.titleW, geometry.titleH);
        titleView.hidden = i != static_cast<NSUInteger>(m_SelectedSetting);
        [self.baseView addSubview:titleView];
        self.settingTitleImages[i] = titleView;
    }

    self.settingScroll = [[UIScrollView alloc]
        initWithFrame:CGRectMake(
                          geometry.scrollX, geometry.scrollY, geometry.scrollW, geometry.scrollH)];
    // The page count is an idiom branch (the binary calls IsPad() at 0xce340 and branches at
    // 0xce34c), not two successive writes: the iPad idiom carries a fifth settings page.
    self.settingScroll.contentSize = CGSizeMake(self.settingScroll.bounds.size.width *
                                                    (isPad ? kScrollPagesNormal : kScrollPagesAlt),
                                                self.settingScroll.bounds.size.height);
    self.settingScroll.contentOffset = CGPointMake(
        self.settingScroll.bounds.size.width * static_cast<CGFloat>(m_SelectedSetting), 0.0);
    self.settingScroll.pagingEnabled = YES;
    self.settingScroll.showsHorizontalScrollIndicator = NO;
    self.settingScroll.delegate = self;
    [self.baseView addSubview:self.settingScroll];

    self.settingPage = [[UIPageControl alloc]
        initWithFrame:CGRectMake(geometry.pageX, geometry.pageY, geometry.pageW, geometry.pageH)];
    // The same idiom branch as the content size (IsPad() at 0xce5ec, branch at 0xce5f8).
    self.settingPage.numberOfPages = isPad ? kSettingPagesNormal : kSettingPagesAlt;
    self.settingPage.currentPage = m_SelectedSetting;
    self.settingPage.transform = CGAffineTransformMakeScale(kPageScale, kPageScale);
    self.settingPage.pageIndicatorTintColor = [UIColor colorWithWhite:kPageTintWhite alpha:1.0];
    self.settingPage.currentPageIndicatorTintColor = [UIColor colorWithWhite:kPageTintWhiteCurrent
                                                                       alpha:1.0];
    [self.settingPage addTarget:self
                         action:@selector(selectPage:)
               forControlEvents:UIControlEventValueChanged];
    [self.baseView addSubview:self.settingPage];

    CGFloat pageWidth = self.settingScroll.bounds.size.width;
    CGRect scrollBounds = self.settingScroll.bounds;
    self.colorView = [[RBMusicColorView alloc]
            initWithFrame:CGRectMake(
                              kColorPage * pageWidth, 0.0, pageWidth, scrollBounds.size.height)
        MusicSelectedBase:self];
    [self.settingScroll addSubview:self.colorView];
    self.difficultyView = [[RBMusicDifficultyView alloc]
            initWithFrame:CGRectMake(
                              kDifficultyPage * pageWidth, 0.0, pageWidth, scrollBounds.size.height)
        MusicSelectedBase:self];
    [self.settingScroll addSubview:self.difficultyView];
    self.speedView = [[RBMusicSpeedView alloc]
            initWithFrame:CGRectMake(
                              kSpeedPage * pageWidth, 0.0, pageWidth, scrollBounds.size.height)
        MusicSelectedBase:self];
    [self.settingScroll addSubview:self.speedView];

    // The CPU and other sub-view pages split by iPad idiom (IsPad at 0xceaa8): 3 and 4 on the wide
    // layout, 2 and 3 on the narrow one.
    CGFloat cpuPage = isPad ? kCpuPageWide : kCpuPageNarrow;
    CGFloat otherPage = isPad ? kOtherPageWide : kOtherPageNarrow;
    self.cpuView = [[RBMusicCPUView alloc]
            initWithFrame:CGRectMake(cpuPage * pageWidth, 0.0, pageWidth, scrollBounds.size.height)
        MusicSelectedBase:self];
    [self.settingScroll addSubview:self.cpuView];
    self.otherView = [[RBMusicOtherView alloc]
            initWithFrame:CGRectMake(
                              otherPage * pageWidth, 0.0, pageWidth, scrollBounds.size.height)
        MusicSelectedBase:self];
    [self.settingScroll addSubview:self.otherView];

    UIImage *ghostImage = [UIImage imageWithName:@"02_music_detail/det_gst"];
    UIImageView *ghostView = [[UIImageView alloc] initWithImage:ghostImage];
    ghostView.frame = CGRectMake(
        geometry.ghostX, geometry.ghostY, ghostView.frame.size.width, ghostView.frame.size.height);
    [self.baseView addSubview:ghostView];
    self.ghostImageView = ghostView;

    UIButton *decideButton = [UIButton buttonWithType:UIButtonTypeCustom];
    int decideThema = [RBUserSettingData sharedInstance].thema;
    // Classic and Limelight share one arm in the binary; only Colette takes the fixed image.
    UIImage *decideImage = decideThema == RBUserSettingDataThemeColette ?
                               [UIImage imageWithName:kDetDecSingleColette] :
                               [UIImage imageWithName:kDetDecSingleTable[frameBonusType]];
    CGSize decideSize = decideImage.size;
    decideButton.frame = CGRectMake(kDecideX, kDecideY, decideSize.width, decideSize.height);
    decideButton.exclusiveTouch = YES;
    [decideButton setBackgroundImage:decideImage forState:UIControlStateNormal];
    [decideButton addTarget:self
                     action:@selector(SelectDecideButton)
           forControlEvents:UIControlEventTouchUpInside];
    [self.baseView addSubview:decideButton];
    self.decideButton = decideButton;

    UIImage *whitePastelImage = [UIImage imageWithName:@"02_music_detail/det_pastelkun"];
    UIButton *whitePastelButton = [UIButton buttonWithType:UIButtonTypeCustom];
    whitePastelButton.center = CGPointMake(kWhitePastelCenterX, kWhitePastelCenterY);
    whitePastelButton.exclusiveTouch = YES;
    [whitePastelButton setBackgroundImage:whitePastelImage forState:UIControlStateNormal];
    [whitePastelButton addTarget:self
                          action:@selector(SelectWhitePastelButton)
                forControlEvents:UIControlEventTouchUpInside];
    [self.baseView addSubview:whitePastelButton];
    self.whitePastelButton = whitePastelButton;

    UIImage *blackPastelImage = [UIImage imageWithName:@"02_music_detail/det_kuropastelkun"];
    UIButton *blackPastelButton = [UIButton buttonWithType:UIButtonTypeCustom];
    blackPastelButton.center = CGPointMake(kBlackPastelCenterX, kBlackPastelCenterY);
    blackPastelButton.exclusiveTouch = YES;
    [blackPastelButton setBackgroundImage:blackPastelImage forState:UIControlStateNormal];
    [blackPastelButton addTarget:self
                          action:@selector(SelectBlackPastelButton)
                forControlEvents:UIControlEventTouchUpInside];
    [self.baseView addSubview:blackPastelButton];
    self.blackPastelButton = blackPastelButton;

    UIButton *doubleButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.doubleButton = doubleButton;
    int doubleThema = [RBUserSettingData sharedInstance].thema;
    UIImage *doubleImage = doubleThema == RBUserSettingDataThemeColette ?
                               [UIImage imageWithName:kDetDecDoubleColette] :
                               [UIImage imageWithName:kDetDecDoubleTable[frameBonusType]];
    CGSize doubleSize = doubleImage.size;
    self.doubleButton.frame =
        CGRectMake(kDecideRightX, kDecideRightY, doubleSize.width, doubleSize.height);
    self.doubleButton.exclusiveTouch = YES;
    [self.doubleButton setBackgroundImage:doubleImage forState:UIControlStateNormal];
    [self.doubleButton addTarget:self
                          action:@selector(SelectDoublePlayButton)
                forControlEvents:UIControlEventTouchUpInside];
    [self.baseView addSubview:self.doubleButton];

    self.doubleButtonCoverView = [[UIImageView alloc]
        initWithImage:[UIImage imageWithName:@"02_music_detail/det_dec_spd_lock"]];
    self.doubleButtonCoverView.center = self.doubleButton.center;
    [self.baseView addSubview:self.doubleButtonCoverView];
    self.doubleButton.enabled = [RBUserSettingData sharedInstance].speedType == 0;
    self.doubleButtonCoverView.hidden = [RBUserSettingData sharedInstance].speedType == 0;
    // Yes, the binary immediately overrides both of the above, so the speed-lock cross is always
    // hidden and the button always enabled here.
    self.doubleButtonCoverView.hidden = YES;
    self.doubleButton.enabled = YES;

    // The binary builds a second pastel pair at a lower position, overwriting the first pair.
    UIImage *whitePastel2Image = [UIImage imageWithName:@"02_music_detail/det_pastelkun"];
    UIButton *whitePastel2Button = [UIButton buttonWithType:UIButtonTypeCustom];
    CGSize whitePastel2Size = whitePastel2Image.size;
    whitePastel2Button.frame =
        CGRectMake(kDecideRightX, kDecideRightY, whitePastel2Size.width, whitePastel2Size.height);
    whitePastel2Button.exclusiveTouch = YES;
    [whitePastel2Button setBackgroundImage:whitePastel2Image forState:UIControlStateNormal];
    [whitePastel2Button addTarget:self
                           action:@selector(SelectWhitePastelButton)
                 forControlEvents:UIControlEventTouchUpInside];
    [self.baseView addSubview:whitePastel2Button];
    self.whitePastelButton = whitePastel2Button;

    UIImage *blackPastel2Image = [UIImage imageWithName:@"02_music_detail/det_kuropastelkun"];
    UIButton *blackPastel2Button = [UIButton buttonWithType:UIButtonTypeCustom];
    CGSize blackPastel2Size = blackPastel2Image.size;
    blackPastel2Button.frame =
        CGRectMake(kBlackPastel2X, kBlackPastel2Y, blackPastel2Size.width, blackPastel2Size.height);
    blackPastel2Button.exclusiveTouch = YES;
    [blackPastel2Button setBackgroundImage:blackPastel2Image forState:UIControlStateNormal];
    [blackPastel2Button addTarget:self
                           action:@selector(SelectBlackPastelButton)
                 forControlEvents:UIControlEventTouchUpInside];
    [self.baseView addSubview:blackPastel2Button];
    self.blackPastelButton = blackPastel2Button;

    [self SetSettingButtonSelected:YES];

    UIButton *randomButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.randomButton = randomButton;
    [self.randomButton setImage:[UIImage imageWithName:@"01_music_select/sel_random"]
                       forState:UIControlStateNormal];
    [self.randomButton setImage:[UIImage imageWithName:@"01_music_select/sel_random_sel"]
                       forState:UIControlStateHighlighted];
    self.randomButton.hidden = YES;
    self.randomButton.tag = 0;
    [self.randomButton addTarget:self.musicMenuView
                          action:@selector(selectRandom:)
                forControlEvents:UIControlEventTouchUpInside];
    // Added to the view itself rather than to baseView: self is the half-alpha dimming backdrop, so
    // the button layers above it and shows through the dimmed song grid. Its frame arrives from
    // -[RBMenuView selectRandom:], which copies the menu's own random-button frame and unhides it.
    [self addSubview:self.randomButton];

    self.historyView =
        [[RBMusicHistoryView alloc] initWithFrame:CGRectMake(geometry.scrollX + kHistoryOffsetX,
                                                             geometry.scrollY + kHistoryOffsetY,
                                                             geometry.scrollW,
                                                             geometry.scrollH)];
    self.historyView.hidden = YES;
    [self.baseView addSubview:self.historyView];

    if ([RBUserSettingData sharedInstance].musicSelectedFirstInfo) {
        UIImage *infoImage = [UIImage imageWithName:@"11_info/info_1"];
        UIImageView *infoView = [[UIImageView alloc] initWithImage:infoImage];
        infoView.center =
            CGPointMake(self.bounds.size.width * kFirstInfoCenterXFactor, kFirstInfoCenterY);
        infoView.autoresizingMask = kSetupFirstInfoAutoresizingMask;
        [self addSubview:infoView];
        self.firstInfoView = infoView;
    }

    [self updateDecideButton];
}

// Builds the BPM strip image by drawing the digit images (and a range separator when the minimum
// and maximum BPM differ) side by side into a single image. @ghidraAddress 0xcd744
- (void)buildBpmImageForMin:(int)bpmMin max:(int)bpmMax {
    UIImage *bpmImage = [self bpmImageForMin:bpmMin max:bpmMax];
    self.bpmImageView = [[UIImageView alloc] initWithImage:bpmImage];
    CGPoint origin = self.bpmOrigin;
    CGSize size = bpmImage.size;
    self.bpmImageView.frame = CGRectMake(origin.x, origin.y, size.width, size.height);
    [self.baseView addSubview:self.bpmImageView];
}

// The BPM strip itself. SetupView wraps this in a fresh image view; -setMusicData: reuses the one
// already built, so the drawing is shared rather than written twice.
- (UIImage *)bpmImageForMin:(int)bpmMin max:(int)bpmMax {
    NSMutableArray<UIImage *> *digitImages = [NSMutableArray array];
    CGFloat totalWidth = 0.0;
    CGFloat height = 0.0;

    int digits[kBpmDigitCount];
    int value = bpmMin;
    int highest = 0;
    for (int i = 0; i < kBpmDigitCount; ++i) {
        digits[i] = value % 10;
        if (digits[i] > 0) {
            highest = i;
        }
        value /= 10;
    }
    for (int i = highest; i >= 0; --i) {
        UIImage *digitImage = [UIImage imageWithName:kBpmDigitImageNames[digits[i]]];
        [digitImages addObject:digitImage];
        totalWidth += digitImage.size.width;
        height = digitImage.size.height;
    }
    if (bpmMin != bpmMax) {
        UIImage *separator = [UIImage imageWithName:@"02_music_detail/det_bpm_kara"];
        [digitImages addObject:separator];
        totalWidth += separator.size.width;
        value = bpmMax;
        int maxDigits[kBpmDigitCount];
        int maxHighest = 0;
        for (int i = 0; i < kBpmDigitCount; ++i) {
            maxDigits[i] = value % 10;
            if (maxDigits[i] > 0) {
                maxHighest = i;
            }
            value /= 10;
        }
        for (int i = maxHighest; i >= 0; --i) {
            UIImage *digitImage = [UIImage imageWithName:kBpmDigitImageNames[maxDigits[i]]];
            [digitImages addObject:digitImage];
            totalWidth += digitImage.size.width;
        }
    }

    UIGraphicsBeginImageContextWithOptions(CGSizeMake(totalWidth, height), NO, 0.0);
    CGFloat drawX = 0.0;
    for (UIImage *digitImage in digitImages) {
        [digitImage drawAtPoint:CGPointMake(drawX, 0.0)];
        drawX += digitImage.size.width;
    }
    UIImage *bpmImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return bpmImage;
}

- (void)SetUpLineView {
    // Builds the animated select-line overlay: a container inserted below baseView, plus ten
    // select-line images, each wrapped in a UIImageView whose layer anchor point, position,
    // opacity, and contents scale are set inside a zero-duration transaction. On the compact layout
    // every frame and position is halved. @ghidraAddress 0xd2764
    CGRect selfBounds = self.bounds;
    BOOL isPad = IsPad();

    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(kPopupBaseOriginXWide,
                                                                 kPopupBaseOriginYWide,
                                                                 kPopupBaseWidthWide,
                                                                 kPopupBaseHeightWide)];
    if (!isPad) {
        CGRect b = container.bounds;
        b.size.width *= kSelLineHalfScale;
        b.size.height *= kSelLineHalfScale;
        container.bounds = b;
    }
    container.center = CGPointMake(selfBounds.size.width * kSelLineHalfScale,
                                   selfBounds.size.height * kSelLineHalfScale);
    container.autoresizingMask = kLineAutoresizingMask;
    [self insertSubview:container belowSubview:self.baseView];
    [self setLineView:container];

    UIImage *lineImages[kLineImageCount];
    for (int i = 0; i < kLineImageCount; ++i) {
        lineImages[i] = [UIImage imageWithName:kSelLineImageNames[i]];
    }

    [self setLineAnimationLayers:[[NSMutableArray alloc] initWithCapacity:kLineImageCount]];

    for (int i = 0; i < kLineImageCount; ++i) {
        UIImage *image = lineImages[i];
        UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
        CALayer *layer = imageView.layer;
        [self.lineAnimationLayers addObject:layer];

        CGSize imageSize = image.size;
        imageView.frame = CGRectMake(0.0, 0.0, imageSize.width, imageSize.height);
        imageView.autoresizingMask = kLineAutoresizingMask;
        [self.lineView addSubview:imageView];

        if (!isPad) {
            CGRect f = imageView.frame;
            imageView.frame = CGRectMake(f.origin.x * kSelLineHalfScale,
                                         f.origin.y * kSelLineHalfScale,
                                         f.size.width * kSelLineHalfScale,
                                         f.size.height * kSelLineHalfScale);
        }

        const SelLineLayer &geometry = kSelLineLayout[i];
        [CATransaction begin];
        [CATransaction setAnimationDuration:kSelLineAnimationDuration];
        layer.anchorPoint = CGPointMake(geometry.anchorX, geometry.anchorY);
        if (isPad) {
            layer.position = CGPointMake(geometry.positionX, geometry.positionY);
        } else {
            layer.position = CGPointMake(geometry.positionX * kSelLineHalfScale,
                                         geometry.positionY * kSelLineHalfScale);
            layer.contentsScale = kSelLineHalfScale;
        }
        layer.opacity = kSelLineOpacity;
        [CATransaction commit];
    }
}

#pragma mark BPM digit column

- (void)setBpm:(int)bpm Point:(CGPoint *)Point {
    int digits[kBpmDigitCount];
    int highestNonZero = 0;
    for (int i = 0; i < kBpmDigitCount; ++i) {
        digits[i] = bpm % 10;
        if (bpm % 10 > 0) {
            highestNonZero = i;
        }
        bpm /= 10;
    }
    for (int i = highestNonZero; i >= 0; --i) {
        UIImage *digitImage = [UIImage imageWithName:kBpmDigitImageNames[digits[i]]];
        UIImageView *digitView = [[UIImageView alloc] initWithImage:digitImage];
        CGRect digitFrame = digitView.frame;
        CGFloat x = Point->x;
        Point->x = x + digitFrame.size.width + 1.0;
        [digitView setFrame:CGRectMake(x, Point->y, digitFrame.size.width, digitFrame.size.height)];
        [self.baseView addSubview:digitView];
    }
}

#pragma mark Score, rank, and difficulty readout

- (void)ShowSelectDifficulty {
    int difficulty = [self.difficultyView difficulty];
    [self.scoreView setGrade:difficulty];
    if (self->m_GameType == kGameTypeSingle) {
        self.scoreView.hidden = NO;
        if (self->m_Score[difficulty] > 0) {
            [self.scoreView UpdateScore:self->m_Score[difficulty]];
        } else {
            [self.scoreView UpdateScore:0];
        }
        if (self->m_AR[difficulty] > 0.0f) {
            [self.arView UpdateScore:self->m_AR[difficulty]];
        } else {
            // ar <= 0; the binary calls UpdateScore: here too without reloading the arg register.
            [self.arView UpdateScore:self->m_AR[difficulty]];
        }
        self.rankView.hidden = NO;
        int rank = self->m_PlayCount[difficulty] > 0 ? self->m_Rank[difficulty] : -1;
        [self SetRankView:rank];
        self.fullComboView.hidden = self->m_FullCombo[difficulty] == 0 ? YES : NO;
    } else if (self->m_GameType == kGameTypeDouble) {
        self.scoreView.hidden = YES;
        self.arView.hidden = YES;
        self.rankView.hidden = YES;
        self.fullComboView.hidden = YES;
    }
    [self switchWithDifficulty:difficulty];
    [self SetGhostView:difficulty];
}

- (void)SetRankView:(int)SetRankView {
    if (SetRankView == -1) {
        [self.rankView setImage:nil];
        // The badge keeps its origin but collapses to nothing: only d0 and d1 survive the -frame
        // call, and the width and height passed to setFrame: are zeroed at 0xd2f6c and 0xd2f70.
        CGRect frame = self.rankView.frame;
        [self.rankView setFrame:CGRectMake(frame.origin.x, frame.origin.y, 0.0, 0.0)];
    } else {
        UIImage *rankImage = [UIImage imageWithName:kRankImageNames[SetRankView]];
        [self.rankView setImage:rankImage];
        CGRect frame = self.rankView.frame;
        CGSize size = rankImage.size;
        [self.rankView
            setFrame:CGRectMake(frame.origin.x, frame.origin.y, size.width, size.height)];
    }
}

- (void)switchWithDifficulty:(int)switchWithDifficulty {
    MusicData *difficultyMusic;
    if (switchWithDifficulty < kDifficultyExtended) {
        difficultyMusic = self.musicData;
    } else {
        difficultyMusic = self.musicData.ExtMusicData;
    }
    if (difficultyMusic == nil ||
        static_cast<unsigned int>(switchWithDifficulty) > kDifficultyExtended) {
        return;
    }

    // The binary dispatches through a four-entry jump table (@0xd2754) whose difficulty-0 and
    // difficulty-3 arms share the basic artwork. Each arm refreshes the jacket image when the
    // difficulty's artwork differs from the cached default artwork, then the shared tail refreshes
    // the themed music-name image.
    UIImage *artwork;
    switch (switchWithDifficulty) {
    case kDifficultyMedium:
        artwork = difficultyMusic.artworkMedium; // @0xd10d4
        break;
    case kDifficultyHard:
        artwork = difficultyMusic.artworkHard; // @0xd11cc
        break;
    default: // difficulty 0 (basic) and 3 (extended) @0xd0fdc
        artwork = difficultyMusic.artworkBasic;
        break;
    }
    if (artwork != nil && artwork != self.musicData.artwork) {
        self.jacketImageView.image = nil;
        self.jacketImage = nil;
        self.jacketImage = artwork;
        self.jacketImageView.image = self.jacketImage;
    }

    // Shared music-name tail (@0xd13f0/@0xd16c0/@0xd1898): the themed name image keyed on _thema.
    self.musicNameImageView.image = [self musicNameImageOfMusic:difficultyMusic
                                                  forDifficulty:switchWithDifficulty];
}

// The themed music-name image, keyed on the current theme alone. The difficulty argument is kept
// because the binary's three jump-table arms each carry their own copy of this selection, but all
// three call the same base accessor: switchWithDifficulty: sends musicNameImageBlack, ...Brown and
// ...White three times each and never the per-difficulty variants. That distinction matters rather
// than being cosmetic — the per-difficulty accessors read archive members (title_b_b and friends)
// that no .rb file carries, so selecting them returns nil and hands -setColor:withColor: a zero
// size, which throws on a modern iOS.
- (UIImage *)musicNameImageOfMusic:(MusicData *)music forDifficulty:(int)difficulty {
    (void)difficulty; // Yes, the binary ignores it here; every arm picks by theme only.
    switch (self->_thema) {
    case RBUserSettingDataThemeLimelight:
        return music.musicNameImageBlack;
    case RBUserSettingDataThemeColette:
        return music.musicNameImageBrown;
    default: // RBUserSettingDataThemeClassic
        return music.musicNameImageWhite;
    }
}

- (void)SetGhostView:(int)SetGhostView {
    MusicData *music = self.musicData;
    BOOL hasReplay;
    if (SetGhostView == kDifficultyExtended) {
        int musicID = music.ExtMusicData.MusicID;
        hasReplay = [ReplayData isExistReplayData:musicID difficulty:kExtendedReplayDifficulty];
    } else {
        int musicID = music.MusicID;
        hasReplay = [ReplayData isExistReplayData:musicID difficulty:SetGhostView];
    }
    CGFloat alpha = 0.0;
    if (hasReplay) {
        int ghostStyle = [RBUserSettingData sharedInstance].ghostStyle;
        alpha = ghostStyle == kGhostStyleReplay ? kGhostAlphaOpaque : kGhostAlphaDimmed;
    }
    [self.ghostImageView setAlpha:alpha];
}

#pragma mark Setting view

- (BOOL)ShowSettingView:(int)ShowSettingView {
    BOOL changed = self->m_SelectedSetting != ShowSettingView;
    if (changed) {
        self->m_SelectedSetting = ShowSettingView;
        int selected = ShowSettingView;
        // The block captures self strongly: the binary retains it at 0xd3410 and balances that
        // with a release at 0xd3438 once animateWithDuration:animations: has returned.
        [UIView animateWithDuration:g_dMascotMessageAnimDuration
                         animations:^{
                           /** @ghidraAddress 0xd3464 */
                           for (int i = 0; i < kSettingPageCount; ++i) {
                               UIView *button = self.settingButtons[i];
                               button.alpha = i == selected ? kSettingButtonAlphaSelected :
                                                              kSettingButtonAlphaDimmed;
                           }
                           if (selected == kSettingPageColor) {
                               self.difficultyView.alpha = 0.0;
                               self.colorView.alpha = kSettingButtonAlphaSelected;
                               self.cpuView.alpha = 0.0;
                           } else if (selected == kSettingPageDifficulty) {
                               self.difficultyView.alpha = kSettingButtonAlphaSelected;
                               self.colorView.alpha = 0.0;
                               self.cpuView.alpha = 0.0;
                           } else {
                               // The binary asserts on any other index; only the CPU page remains.
                               self.difficultyView.alpha = 0.0;
                               self.colorView.alpha = 0.0;
                               self.cpuView.alpha = kSettingButtonAlphaSelected;
                           }
                         }];
    }
    return changed;
}

- (void)SetSettingButtonSelected:(int)SetSettingButtonSelected {
    for (int i = 0; i < kSettingPageCount; ++i) {
        if (i == SetSettingButtonSelected) {
            [self.settingButtonEffects[i] setHidden:NO];
            [self.settingButtonCovers[i] setHidden:YES];
        } else {
            [self.settingButtonEffects[i] setHidden:YES];
            [self.settingButtonCovers[i] setHidden:NO];
        }
    }
}

- (void)updateDecideButton {
    RBUserSettingData *settings = [RBUserSettingData sharedInstance];
    BOOL hidePastel;
    if (settings.userFullCombo) {
        hidePastel = YES;
    } else if ([RBUserSettingData sharedInstance].fullJustReflec) {
        hidePastel = YES;
    } else if ([RBUserSettingData sharedInstance].ghostStyle == kGhostStyleReplay) {
        hidePastel = YES;
    } else {
        hidePastel = ![RBUserSettingData sharedInstance].vsPastel;
    }
    if (hidePastel) {
        self.whitePastelButton.hidden = YES;
        self.blackPastelButton.hidden = YES;
        if (IsPad()) {
            self.doubleButton.hidden = NO;
        }
    } else {
        self.whitePastelButton.hidden = NO;
        self.blackPastelButton.hidden = NO;
        if (IsPad()) {
            self.doubleButton.hidden = YES;
        }
    }

    BOOL disableDouble;
    if ([RBUserSettingData sharedInstance].speedType == 0) {
        if ([RBUserSettingData sharedInstance].userFullCombo) {
            disableDouble = YES;
        } else if ([RBUserSettingData sharedInstance].ghostStyle == kGhostStyleReplay) {
            disableDouble = YES;
        } else {
            disableDouble = [RBUserSettingData sharedInstance].vsPastel;
        }
    } else {
        disableDouble = YES;
    }
    self.doubleButton.enabled = disableDouble ? NO : YES;
    [self SetGhostView:[self.difficultyView difficulty]];
}

- (void)setEnableButton:(BOOL)enableButton {
    [self.difficultyView setEnableButton:enableButton];
}

- (void)setScrollable:(BOOL)scrollable {
    [self.settingScroll setScrollEnabled:scrollable];
    [self.settingPage setHidden:!scrollable];
}

- (void)selectPage:(id)selectPage {
    NSInteger page = [selectPage currentPage];
    CGRect bounds = self.settingScroll.bounds;
    [self.settingScroll setContentOffset:CGPointMake(page * bounds.size.width, 0) animated:YES];
}

#pragma mark Button actions

- (void)SelectDecideButton {
    if (self->m_Animating) {
        return;
    }
    [self setM_IsBlackPastelMode:NO];
    [self setM_IsWhitePastelMode:NO];
    self->m_GameType = kGameTypeSingle;
    if ([RBUserSettingData sharedInstance].ghostStyle == kGhostStyleReplay) {
        int difficulty = [self.difficultyView difficulty];
        if (difficulty == kDifficultyExtended) {
            int musicID = self.musicData.ExtMusicData.MusicID;
            if (![ReplayData isExistReplayData:musicID difficulty:kExtendedReplayDifficulty]) {
                [AppDelegate appDelegate].replayData = nil;
            } else {
                self->m_GameType = kGameTypeReplay;
                int replayID = self.musicData.ExtMusicData.MusicID;
                [AppDelegate appDelegate].replayData =
                    [ReplayData loadReplayData:replayID difficulty:kExtendedReplayDifficulty];
            }
        } else {
            int musicID = self.musicData.MusicID;
            if (![ReplayData isExistReplayData:musicID difficulty:difficulty]) {
                [AppDelegate appDelegate].replayData = nil;
            } else {
                self->m_GameType = kGameTypeReplay;
                int replayID = self.musicData.MusicID;
                [AppDelegate appDelegate].replayData = [ReplayData loadReplayData:replayID
                                                                       difficulty:difficulty];
            }
        }
    } else {
        [AppDelegate appDelegate].replayData = nil;
    }
    if ([RBTutorialManager needStartTutorialPlay]) {
        [self playTutorialGame];
    } else {
        [self playGame];
    }
}

- (void)SelectDoublePlayButton {
    if (self->m_Animating) {
        return;
    }
    [self setM_IsBlackPastelMode:NO];
    [self setM_IsWhitePastelMode:NO];
    self->m_GameType = kGameTypeDouble;
    [self playGame];
}

- (void)SelectWhitePastelButton {
    [self setM_IsBlackPastelMode:NO];
    [self setM_IsWhitePastelMode:YES];
    if (self->m_Animating) {
        return;
    }
    self->m_GameType = kGameTypeSingle;
    [self playGame];
}

- (void)SelectBlackPastelButton {
    [self setM_IsBlackPastelMode:YES];
    [self setM_IsWhitePastelMode:NO];
    if (self->m_Animating) {
        return;
    }
    self->m_GameType = kGameTypeSingle;
    [self playGame];
}

- (void)SelectHistory {
    if (!self.historyView.isHidden) {
        [self.historyView hideAnimation];
    } else {
        int musicID = self.musicData.MusicID;
        int difficulty = [self.difficultyView difficulty];
        [self.historyView showAnimation:musicID difficulty:difficulty];
    }
}

- (void)SelectItunes {
    if (self.iTunesURL != nil) {
        RBViewController *viewController = self.musicMenuView.viewController;
        [viewController openItunesWithURL:[NSURL URLWithString:self.iTunesURL]];
    }
}

- (void)playGame {
    [RBUserSettingData sharedInstance].gameType = self->m_GameType;
    [RBUserSettingData sharedInstance].playerColor = [self.colorView color];
    [RBUserSettingData sharedInstance].difficulty = [self.difficultyView difficulty];
    [RBUserSettingData sharedInstance].rivalAlpha = [self.colorView rivalAlpha];

    unsigned int playColor = static_cast<unsigned int>([self.colorView color]);
    if (playColor > 1) {
        playColor =
            kPlayColorRandomThreshold <= static_cast<float>(rand()) * kInverseRandMax ? 1 : 0;
    }
    [RBUserSettingData sharedInstance].playColor = playColor;

    [RBUserSettingData sharedInstance].cpuLevel = [self.cpuView level];
    GameSystem::GetGameSystem()->SetComboCount([self.cpuView level]);

    GameSystem *gameSystem = GameSystem::GetGameSystem();
    // The play field builds with g_nPlayfieldCentreSplit still zero, and this is the only path
    // that sets it: ConfigureSheetLayerForScreen is the sole caller of ComputePlayfieldLayoutY,
    // which holds the only three stores to those globals in the whole binary.
    neDebugLog("playGame enter gameType=%d isPad=%d speed=%d splitBefore=%d",
               self->m_GameType,
               IsPad() ? 1 : 0,
               [self.speedView speed],
               g_nPlayfieldCentreSplit);
    if (self->m_GameType == kGameTypeDouble) {
        gameSystem->ConfigureSheetLayerForScreen(0);
    } else if (IsPad()) {
        gameSystem->ConfigureSheetLayerForScreen([self.speedView speed]);
    } else {
        gameSystem->ConfigureSheetLayerForScreen(0);
    }
    neDebugLog("playGame configured scale=%.3f fieldHeight=%d split=%d fullHeightY=%d",
               static_cast<double>(gameSystem->GetPlayfieldScale()),
               g_nPlayfieldFieldHeight,
               g_nPlayfieldCentreSplit,
               g_nPlayfieldFullHeightY);

    if (self->_thema < RBUserSettingDataThemeLimelight || self->m_GameType != kGameTypeSingle) {
        GameSystem::GetGameSystem()->SetPastelBonusType(kPastelBonusNone);
    } else {
        srand(static_cast<unsigned int>(time(nullptr)));
        (void)rand(); // The binary discards this first draw.
        if ([self m_IsWhitePastelMode]) {
            GameSystem::GetGameSystem()->SetComboCount(kPastelWhiteCombo);
            GameSystem::GetGameSystem()->SetPastelBonusType(kPastelBonusWhite);
        } else {
            BOOL isBlack = [self m_IsBlackPastelMode];
            GameSystem::GetGameSystem()->SetPastelBonusType(isBlack ? kPastelBonusBlack :
                                                                      kPastelBonusNone);
            if (isBlack) {
                srand(static_cast<unsigned int>(time(nullptr)));
                int roll = rand();
                GameSystem::GetGameSystem()->SetComboCount(roll % kPastelBlackComboRollModulo >
                                                                   kPastelBlackComboRollThreshold ?
                                                               kPastelBlackComboHigh :
                                                               kPastelBlackComboLow);
            }
        }
    }

    int seedRoll = rand();
    RBViewController *viewController = [AppDelegate appDelegate].viewController;
    unsigned int seed =
        static_cast<unsigned int>(static_cast<float>(seedRoll) * kInverseRandMax * kRandSeedScale);
    [viewController playGameWithMusicData:self.musicData RandSeed:seed];
}

- (void)playTutorialGame {
    [RBUserSettingData sharedInstance].gameType = kGameTypeSingle;
    [RBUserSettingData sharedInstance].playerColor = 0;
    [RBUserSettingData sharedInstance].difficulty = 0;
    [RBUserSettingData sharedInstance].rivalAlpha = kTutorialRivalAlpha;
    GameSystem::GetGameSystem()->SetComboCount(kTutorialComboCount);
    GameSystem::GetGameSystem()->SetPastelBonusType(kPastelBonusNone);

    NSString *path = [RBMusicManager getPathFromBundle:kTutorialMusicID];
    if ([NSFileManager isFileExist:path]) {
        [self setMusicData:[MusicData dataWithPath:path ID:kTutorialMusicID]];
    }
    [self.musicMenuView.tutorialView hideAnimation];

    RBViewController *viewController = [AppDelegate appDelegate].viewController;
    int seedRoll = rand();
    unsigned int seed =
        static_cast<unsigned int>(static_cast<float>(seedRoll) * kInverseRandMax * kRandSeedScale);
    [viewController playGameWithMusicData:self.musicData RandSeed:seed];
}

#pragma mark Presentation

- (void)showAnimation:(BOOL)showAnimation {
    if (self->m_Animating) {
        return;
    }
    self->m_Animating = YES;
    [self setEnableButton:NO];
    if (showAnimation) {
        [[RBBGMManager getInstance] PauseMusic:kBgmPauseFadeDuration];
    } else {
        [[RBBGMManager getInstance] PauseMusic:0.0];
    }
    self.baseView.alpha = kBaseViewAlphaVisible;
    if (!showAnimation) {
        self.backgroundColor = MusicViewCoverColor();
        self.baseView.alpha = kBaseViewAlphaVisible;
        self->m_Animating = NO;
        [self setEnableButton:YES];
        NSMutableData *musicPre = self.musicData.musicPre;
        [[RBBGMManager getInstance] LoadMusicWithPush:musicPre Loop:YES];
        [[RBBGMManager getInstance] PlayMusic:0.0];
        [self firstInfoAnimationCheck];
        return;
    }
    (void)self.baseView.alpha;
    __weak RBMusicView *weakSelf0 = self;
    [UIView animateWithDuration:kMusicViewCoverFadeDuration
                     animations:^{
                       /** @ghidraAddress 0xd50a0 (SetCapturedViewBackgroundColorBlockInvoke) */
                       weakSelf0.backgroundColor = MusicViewCoverColor();
                     }];
    __weak RBMusicView *weakSelf1 = self;
    __weak RBMusicView *weakSelf2 = self;
    [UIView animateWithDuration:g_dMascotMessageAnimDuration
        delay:g_dMascotMoveAnimDuration
        options:UIViewAnimationOptionLayoutSubviews
        animations:^{
          /** @ghidraAddress 0xd50a0 (ShowBaseViewAlphaBlockInvoke) */
          weakSelf1.baseView.alpha = kBaseViewAlphaVisible;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0xd50a0 (FinishMusicViewIntroBlockInvoke) */
          RBMusicView *strongSelf = weakSelf2;
          strongSelf->m_Animating = NO;
          [strongSelf setEnableButton:YES];
          NSMutableData *musicPre = strongSelf.musicData.musicPre;
          [[RBBGMManager getInstance] LoadMusicWithPush:musicPre Loop:YES];
          [[RBBGMManager getInstance] PlayMusic:0.0];
          [strongSelf firstInfoAnimationCheck];
        }];
}

- (void)hideAnimation {
    if (self->m_Animating) {
        return;
    }
    self->m_Animating = YES;
    self->m_FirstInfo = NO;
    [RBUserSettingData sharedInstance].difficulty = [self.difficultyView difficulty];
    [RBUserSettingData sharedInstance].playerColor = [self.colorView color];
    [RBUserSettingData sharedInstance].rivalAlpha = [self.colorView rivalAlpha];
    [RBUserSettingData sharedInstance].cpuLevel = [self.cpuView level];
    [RBUserSettingData sharedInstance].gameType = self->m_GameType;
    [self.historyView hideAnimation];
    [self setEnableButton:NO];
    RBBGMManager *bgm = [RBBGMManager getInstance];
    [bgm StopMusic:0.0];
    [bgm popMusic];
    __weak RBMusicView *weakSelf0 = self;
    __weak RBMusicView *weakSelf1 = self;
    [UIView animateWithDuration:kMusicViewCoverFadeDuration
        animations:^{
          /** @ghidraAddress 0xd5a50 (ResetMusicViewBackgroundBlockInvoke) */
          weakSelf0.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.0];
          weakSelf0.baseView.alpha = kBaseViewAlphaHidden;
          if (weakSelf0.firstInfoView != nil) {
              weakSelf0.firstInfoView.alpha = kBaseViewAlphaHidden;
          }
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0xd5b88 (PlaySelectedMusicBlockInvoke) */
          // Resume the select BGM that showAnimation: paused, retrying shortly if the pop has not
          // finished restoring it yet.
          if (![[RBBGMManager getInstance] PlayMusic:kBgmReplayFadeDuration]) {
              [weakSelf1 performSelector:@selector(ReplayMusic)
                              withObject:nil
                              afterDelay:g_dMascotMessageAnimDuration];
          }
          [weakSelf1.musicMenuView releaseSelectMusic];
          weakSelf1.musicMenuView.selectedView = nil;
        }];
    SoundEffectManager::GetInstance()->PlayThemedSoundEffect(kSoundEffectCancel);
}

- (void)ReplayMusic {
    if (![[RBBGMManager getInstance] PlayMusic:kBgmReplayFadeDuration]) {
        [self performSelector:@selector(ReplayMusic)
                   withObject:nil
                   afterDelay:g_dMascotMessageAnimDuration];
    }
}

#pragma mark First-info hint animation

- (void)firstInfoAnimation {
    self->m_FirstInfo = YES;
    __weak RBMusicView *weakSelf0 = self;
    __weak RBMusicView *weakSelf1 = self;
    [UIView animateWithDuration:g_dAudioManagerResumeFadeInTime
        animations:^{
          /** @ghidraAddress 0xd5d4c (ScrollSettingViewBlockInvoke) */
          CGFloat width = weakSelf0.settingScroll.bounds.size.width;
          weakSelf0.settingScroll.contentOffset = CGPointMake(width + width, 0);
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0xd5d4c (ScheduleFirstScrollAnimationBlockInvoke) */
          [weakSelf1 setFirstScrollAnimation];
        }];
}

- (void)firstInfoAnimationCheck {
    if (IsPad()) {
        self->m_FirstInfo = NO;
        return;
    }
    if ([RBUserSettingData sharedInstance].musicSelectedFirstInfo) {
        self->m_FirstInfo = NO;
        return;
    }
    if ([RBUserSettingData sharedInstance].thema == RBUserSettingDataThemeColette &&
        [RBTutorialManager isTutorialMusicselect]) {
        self->m_FirstInfo = NO;
        return;
    }
    [RBUserSettingData sharedInstance].musicSelectedFirstInfo = YES;
    [[RBUserSettingData sharedInstance] save];
    [self firstInfoAnimation];
}

- (void)firstInfoScrollEnd {
    if (self->m_FirstInfo) {
        [self performSelector:@selector(setFirstScrollAnimation)
                   withObject:nil
                   afterDelay:kFirstInfoScrollRetryDelay];
    }
}

- (void)setFirstScrollAnimation {
    if (!self->m_FirstInfo) {
        return;
    }
    CGPoint offset = self.settingScroll.contentOffset;
    CGRect bounds = self.settingScroll.bounds;
    if (offset.x == bounds.size.width + bounds.size.width) {
        __weak RBMusicView *weakSelf0 = self;
        __weak RBMusicView *weakSelf1 = self;
        [UIView animateWithDuration:g_dAudioManagerResumeFadeInTime
            animations:^{
              /** @ghidraAddress 0xd61e0 (ResetSettingScrollOffsetBlockInvoke) */
              weakSelf0.settingScroll.contentOffset = CGPointZero;
            }
            completion:^(BOOL finished) {
              /** @ghidraAddress 0xd61e0 (NotifyFirstInfoScrollEndBlockInvoke) */
              [weakSelf1 firstInfoScrollEnd];
            }];
    } else if (self.settingScroll.contentOffset.x == 0.0) {
        __weak RBMusicView *weakSelf0 = self;
        __weak RBMusicView *weakSelf1 = self;
        [UIView animateWithDuration:g_dAudioManagerResumeFadeInTime
            animations:^{
              /** @ghidraAddress 0xd61e0 (ScrollSettingViewToOffsetBlockInvoke) */
              CGFloat width = weakSelf0.settingScroll.bounds.size.width;
              weakSelf0.settingScroll.contentOffset = CGPointMake(width + width, 0);
            }
            completion:^(BOOL finished) {
              /** @ghidraAddress 0xd61e0 (NotifyFirstInfoScrollEnd2BlockInvoke) */
              [weakSelf1 firstInfoScrollEnd];
            }];
    } else {
        self->m_FirstInfo = NO;
    }
}

#pragma mark UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollViewDidScroll {
    if (self.settingScroll != scrollViewDidScroll) {
        return;
    }
    CGPoint offset = scrollViewDidScroll.contentOffset;
    CGRect bounds = scrollViewDidScroll.bounds;
    double fractionalPage = offset.x / bounds.size.width;
    int page = static_cast<int>(fractionalPage);
    float snappedPage =
        static_cast<float>(fractionalPage) - static_cast<float>(page) <= kSettingPageSnapThreshold ?
            static_cast<float>(page) :
            static_cast<float>(page + 1);
    if (static_cast<float>(self.settingPage.currentPage) != snappedPage) {
        self.settingPage.currentPage = static_cast<NSInteger>(snappedPage);
    }
    if (!IsPad()) {
        for (int i = 0; i < kSettingTitleImageCount; ++i) {
            [self.settingTitleImages[i] setHidden:YES];
        }
        switch (static_cast<int>(snappedPage)) {
        case kSettingTitlePage0:
            [self.settingTitleImages[kSettingTitleImagePage0] setHidden:NO];
            break;
        case kSettingTitlePage1:
            [self.settingTitleImages[kSettingTitleImagePage1] setHidden:NO];
            break;
        case kSettingTitlePage2:
            [self.settingTitleImages[kSettingTitleImagePage2] setHidden:NO];
            break;
        case kSettingTitlePage3:
            [self.settingTitleImages[kSettingTitleImagePage3] setHidden:NO];
            break;
        }
    } else {
        for (int i = 0; i < kSettingTitleImageCount; ++i) {
            [self.settingTitleImages[i] setHidden:static_cast<float>(i) == snappedPage ? NO : YES];
        }
    }
}

#pragma mark UIGestureRecognizerDelegate

- (void)tapGesture:(UITapGestureRecognizer *)tapGesture {
    CGRect panelFrame = self.baseView.frame;
    CGPoint location = [tapGesture locationInView:self];
    if (!CGRectContainsPoint(panelFrame, location)) {
        [self hideAnimation];
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
       shouldReceiveTouch:(UITouch *)shouldReceiveTouch {
    if (shouldReceiveTouch.view == gestureRecognizer.view) {
        return YES;
    }
    return ![shouldReceiveTouch.view isKindOfClass:[UIControl class]];
}

#pragma mark Tutorial accessors

- (UIButton *)getDecideButton {
    return self.decideButton;
}

- (UIButton *)getDoubleButton {
    if (self.doubleButton == nil) {
        return nil;
    }
    return self.doubleButton;
}

- (UIButton *)getDifficultyButton:(int)getDifficultyButton {
    return [self.difficultyView getDifficultyButton:getDifficultyButton];
}

@end
