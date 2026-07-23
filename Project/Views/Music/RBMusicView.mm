#import "RBMusicView.h"

#import <ctime>

#import "AppDelegate.h"
#import "MusicData.h"
#import "MusicDataExtend.h"
#import "NSFileManager+RB.h"
#import "RBBGMManager.h"
#import "RBCoreDataManager.h"
#import "RBMenuTutorialView.h"
#import "RBMenuView.h"
#import "RBMusicManager.h"
#import "RBTutorialManager.h"
#import "RBUserSettingData.h"
#import "RBViewController.h"
#import "ReplayData.h"
#import "ScoreData.h"
#import "UIImage+RB.h"
#import "neEngineBridge.h"

// The per-difficulty score, achievement-rate, rank, play-count, and full-combo tables are indexed by
// difficulty. Four difficulty slots exist (basic, medium, hard, and the extended chart).
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
    kDifficultyMedium = 1,
    kDifficultyHard = 2,
};

// The extended chart stores its replay under difficulty slot 0.
enum { kExtendedReplayDifficulty = 0 };

// The user theme (the _thema ivar, seeded from RBUserSettingData.thema). It selects the themed
// music-name and jacket artwork variants.
enum {
    kThemeWhite = 0,
    kThemeBlack = 1,
    kThemeBrown = 2,
};

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

// The shared music-view dimming cover colour is the first entry of the global UIColor palette built
// by InitializeUIColorPalette (@0x5517c): 50%-translucent black (red, green, and blue components 0
// with alpha 0.5, decoded from the fmov d3, 0x3fe0000000000000 at @0x55158). It is a cross-file
// palette global; it is cached here rather than re-declared as a shared extern until the palette
// globals are recovered.
static const CGFloat kMusicViewCoverAlpha = 0.5;
static UIColor *MusicViewCoverColor(void) {
    static UIColor *color = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      color = [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:kMusicViewCoverAlpha];
    });
    return color;
}

// The base-view fade opacities used by the show/hide animations.
static const CGFloat kBaseViewAlphaVisible = 1.0;

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

// The play-colour coin-flip threshold: when both colours are allowed, a unit-interval random draw at
// or above this value selects colour 1, otherwise colour 0.
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
static const float kRandSeedScale = 4.2949673e+09f;

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
// (112.0), DAT_1003013f0 (161.0), g_dPopupBaseWidthWide (546.0), and g_dPopupBaseHeightWide (680.0).
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

// The BPM origin literal written by setBpmOrigin: (0x4061e00000000000, both lanes).
static const CGFloat kBpmOrigin = 142.0;

// The two setting-scroll page counts written back to back (five then four).
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

// The dimmed alpha applied to the name images on the single game type (0.7).
static const CGFloat kNameAlphaDim = 0.699999988;
static const CGFloat kNameAlphaFull = 1.0;

// The setting sub-view page indices (page X = index * scroll width). The CPU and other sub-views sit
// at pages 3 and 4 in the arena game type and both at page 3 otherwise.
static const CGFloat kColorPage = 0.0;
static const CGFloat kDifficultyPage = 1.0;
static const CGFloat kSpeedPage = 2.0;
static const CGFloat kCpuPageArena = 3.0;
static const CGFloat kOtherPageArena = 4.0;
static const CGFloat kCpuPageNormal = 3.0;
static const CGFloat kOtherPageNormal = 3.0;

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
static NSString *const kDetDecTable[] = {
    @"02_music_detail/det_dec_ds",
    @"02_music_detail/det_dec_gs",
    @"02_music_detail/det_dec_ps",
    @"02_music_detail/det_dec_s",
    @"02_music_detail/det_dec_dd",
    @"02_music_detail/det_dec_gd",
};
enum { kDetDecFixedIndex = 3 };

// The detail-view geometry per (font variant, game type, theme) leg. Every value was decoded from
// the .const pools referenced by the big geometry block (@0xcca64..@0xccf30) and traced to its
// setFrame:/setCenter:/initWithFrame: consumer. The layout structure holds one leg's values.
namespace {
struct DetailGeometry {
    CGFloat jacketX, jacketY, jacketSize;
    CGFloat nameFrameX, nameFrameY, artistFrameY;         // font-variant (setFrame:) legs
    CGFloat nameCenterX, musicNameCenterY, artistCenterY; // default (setCenter:) legs
    CGFloat scoreX, scoreY, scoreW, scoreH;
    CGFloat rankX, rankY;
    CGFloat fullComboX, fullComboY;
    CGFloat arX, arY;
    CGFloat itunesX, itunesY;
    CGFloat scrollX, scrollY, scrollW, scrollH;
    CGFloat pageX, pageY, pageW, pageH;
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
static const CGFloat kDoubleGap = 0.5;
static const CGFloat kDoubleBaseX = 70.0;
static const CGFloat kDoubleOffsetX = -32.0;
static const CGFloat kDoubleWidthPad = 110.0;
static const CGFloat kWhitePastel2X = 282.0;
static const CGFloat kWhitePastel2Y = 546.0;
static const CGFloat kBlackPastel2X = 282.0;
static const CGFloat kBlackPastel2Y = 546.0;
static const CGFloat kRandomX = 318.0;
static const CGFloat kRandomY = 556.0;
static const CGFloat kHistoryOffsetX = 110.0;
static const CGFloat kHistoryOffsetY = 160.0;
static const CGFloat kFirstInfoCenterY = 40.0;

// The font-variant arena leg (@0xccafc). Uses the setFrame: name path.
static const DetailGeometry kGeometryVariantArena = {
    53.0,  56.0,  180.0,        // jacket
    266.0, 40.0,  84.0,         // name-frame (variant path)
    0.0,   0.0,   0.0,          // name-centre (unused on the variant path)
    268.0, 170.0, 220.0, 33.0,  // score
    430.0, 188.0,               // rank
    412.0, 169.0,               // full combo
    268.0, 240.0,               // ar
    388.0, 108.0,               // itunes
    31.0,  488.0, 322.0, 183.0, // scroll
    152.0, 470.0, 240.0, 20.0,  // page
    214.0, 235.0,               // ghost
};

// The font-variant non-arena leg (@0xccd44). jacketX, nameFrameY, and jacketSize are picked from a
// two-entry theme table (non-white then white); the white values are recorded here and the
// non-white overrides are applied in-line.
static const DetailGeometry kGeometryVariantNormal = {
    53.0,  56.0,  298.0, // jacket (white values; non-white: x 52, size 302)
    263.0, 67.0,  69.0,  // name-frame (white nameFrameY; non-white: 66)
    0.0,   0.0,   0.0,   // name-centre (unused)
    111.0, 102.0, 220.0, 33.0, 252.0, 101.0, 244.0, 97.0,  244.0, 89.0,  263.0,
    55.0,  44.0,  456.0, 0.0,  183.0, 152.0, 246.0, 240.0, 263.0, 214.0, 104.0,
};
static const CGFloat kVariantNormalJacketXNonWhite = 52.0;
static const CGFloat kVariantNormalJacketSizeNonWhite = 302.0;
static const CGFloat kVariantNormalNameFrameYNonWhite = 66.0;

// The default (non-variant) arena leg (@0xccc64). Uses the setCenter: name path.
static const DetailGeometry kGeometryDefaultArena = {
    20.0,  55.0, 90.0, // jacket
    0.0,   0.0,  0.0,  // name-frame (unused on the default path)
    160.0, 22.0, 41.0, // name-centre
    131.0, 98.0, 84.0,  28.0,  251.0, 105.0, 242.0, 95.0,  131.0, 135.0, 222.0,
    56.0,  10.0, 300.0, 176.0, 96.0,  60.0,  257.0, 200.0, 10.0,  214.0, 124.0,
};

// The default non-arena leg (@0xcce50). jacketSize is theme-picked (non-white then white); the
// scroll and page slots partly fall through to the CGPointZero global (both lanes 0.0).
static const DetailGeometry kGeometryDefaultNormal = {
    20.0,  56.0,  147.0,                    // jacket (white size; non-white: 150)
    0.0,   0.0,   0.0,   0.0,  24.0,  45.0, // name-centre (nameCenterX is the 0.0 CGPointZero lane)
    111.0, 102.0, 74.0,  28.0, 252.0, 101.0, 244.0, 97.0, 244.0,
    89.0,  143.0, 55.0,  10.0, 0.0,   0.0,   0.0, // scrollX 10; scrollY/W/H fall through to 0.0 (CGPointZero)
    246.0, 0.0,   0.0,   0.0,                     // pageX 246; pageY/W/H fall through to 0.0
    214.0, 104.0,
};
static const CGFloat kDefaultNormalJacketSizeNonWhite = 150.0;

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
// De-inlined SetupView helper (the binary draws the BPM strip inline via UIGraphics); not a distinct
// selector in the binary.
- (void)buildBpmImageForMin:(int)bpmMin max:(int)bpmMax;
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
        if (self->_thema == kThemeWhite && GetFontVariantFlag() != kFontVariantDefault) {
            [self SetUpLineView];
        }
        [self setExclusiveTouch:YES];
    }
    return self;
}

- (void)dealloc {
    [self.settingScroll.layer removeAllAnimations];
}

#pragma mark View construction

- (void)SetupView {
    // Builds the whole detail panel. Worked from raw arm64 (the decompiler crashes on this method
    // with the known RBCoreDataManager broken-struct error); every geometry constant was decoded from
    // the .const pools. @ghidraAddress 0xcc078
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
    self.backgroundColor = [UIColor clearColor];

    UITapGestureRecognizer *tap =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapGesture:)];
    tap.delegate = self;
    [self addGestureRecognizer:tap];

    int thema = [RBUserSettingData sharedInstance].thema;
    UIImage *basePanelImage = thema > kThemeBlack ?
                                  [UIImage imageWithName:@"02_music_detail/det_mbg"] :
                                  [UIImage imageWithName:kDetMbgTable[frameBonusType]];

    CGSize baseSize = basePanelImage.size;
    self.baseView =
        [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, baseSize.width, baseSize.height)];
    self.baseView.center = self.center;
    self.baseView.autoresizingMask = kLineAutoresizingMask;
    self.baseView.backgroundColor = [UIColor clearColor];
    self.baseView.exclusiveTouch = YES;
    self.baseView.layer.doubleSided = NO;
    [self addSubview:self.baseView];

    UIImageView *bgImageView = [[UIImageView alloc] initWithImage:basePanelImage];
    bgImageView.exclusiveTouch = YES;
    [self.baseView addSubview:bgImageView];

    // The big geometry block: pick the leg for the current font variant, game type, and theme.
    BOOL fontVariant = GetFontVariantFlag() != kFontVariantDefault;
    BOOL themaIsWhite = thema == kThemeWhite;
    DetailGeometry geometry;
    if (fontVariant) {
        if (m_GameType == kGameTypeDouble) {
            geometry = kGeometryVariantArena;
        } else {
            geometry = kGeometryVariantNormal;
            if (!themaIsWhite) {
                geometry.jacketX = kVariantNormalJacketXNonWhite;
                geometry.jacketSize = kVariantNormalJacketSizeNonWhite;
                geometry.nameFrameY = kVariantNormalNameFrameYNonWhite;
            }
        }
    } else {
        if (m_GameType == kGameTypeDouble) {
            geometry = kGeometryDefaultArena;
        } else {
            geometry = kGeometryDefaultNormal;
            if (!themaIsWhite) {
                geometry.jacketSize = kDefaultNormalJacketSizeNonWhite;
            }
        }
    }

    self.bpmOrigin = CGPointMake(kBpmOrigin, kBpmOrigin);

    UIImage *musicNameSrc = nil;
    UIImage *artistNameSrc = nil;
    switch (m_GameType) {
    case kGameTypeSingle:
        musicNameSrc = self.musicData.musicNameImageWhite;
        artistNameSrc = self.musicData.artistNameImageWhite;
        break;
    case kGameTypeDouble:
        musicNameSrc = self.musicData.musicNameImageBrown;
        artistNameSrc = self.musicData.artistNameImageBrown;
        break;
    case kGameTypeReplay:
        musicNameSrc = self.musicData.musicNameImageBlack;
        artistNameSrc = self.musicData.artistNameImageBlack;
        break;
    default:
        break;
    }

    if (thema == kThemeBrown) {
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
    self.musicNameImageView.alpha = m_GameType == kGameTypeSingle ? kNameAlphaDim : kNameAlphaFull;
    if (fontVariant) {
        CGSize size = self.musicNameImageView.frame.size;
        self.musicNameImageView.frame =
            CGRectMake(geometry.nameFrameX, geometry.nameFrameY, size.width, size.height);
    } else {
        self.musicNameImageView.center =
            CGPointMake(geometry.nameCenterX, geometry.musicNameCenterY);
    }
    [self.baseView addSubview:self.musicNameImageView];

    self.artistNameImageView = [[UIImageView alloc] initWithImage:artistNameSrc];
    self.artistNameImageView.alpha = m_GameType == kGameTypeSingle ? kNameAlphaDim : kNameAlphaFull;
    if (fontVariant) {
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
    [self.scoreView UpdateScore:m_Score[kDifficultyBasic]];
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
    [self.arView UpdateScore:m_AR[kDifficultyBasic]];
    [self.baseView addSubview:self.arView];

    self.settingTitleImages = [NSMutableArray array];
    m_SelectedSetting = kSetupInitialSetting;
    for (NSUInteger i = 0; i < kSettingPagesNormal; ++i) {
        UIImageView *titleView =
            [[UIImageView alloc] initWithImage:[UIImage imageWithName:kSettingTitleTable[i]]];
        titleView.hidden = i != static_cast<NSUInteger>(m_SelectedSetting);
        [self.baseView addSubview:titleView];
        self.settingTitleImages[i] = titleView;
    }

    self.settingScroll = [[UIScrollView alloc]
        initWithFrame:CGRectMake(
                          geometry.scrollX, geometry.scrollY, geometry.scrollW, geometry.scrollH)];
    // The binary writes the content size twice (five then four pages).
    self.settingScroll.contentSize =
        CGSizeMake(self.settingScroll.bounds.size.width * kScrollPagesNormal,
                   self.settingScroll.bounds.size.height);
    self.settingScroll.contentSize =
        CGSizeMake(self.settingScroll.bounds.size.width * kScrollPagesAlt,
                   self.settingScroll.bounds.size.height);
    self.settingScroll.contentOffset = CGPointMake(
        self.settingScroll.bounds.size.width * static_cast<CGFloat>(m_SelectedSetting), 0.0);
    self.settingScroll.pagingEnabled = YES;
    self.settingScroll.showsHorizontalScrollIndicator = NO;
    self.settingScroll.delegate = self;
    [self.baseView addSubview:self.settingScroll];

    self.settingPage = [[UIPageControl alloc]
        initWithFrame:CGRectMake(geometry.pageX, geometry.pageY, geometry.pageW, geometry.pageH)];
    self.settingPage.numberOfPages = kSettingPagesNormal;
    self.settingPage.numberOfPages = kSettingPagesAlt;
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
    self.colorView = [[RBMusicColorView alloc] initWithFrame:CGRectMake(kColorPage * pageWidth,
                                                                        scrollBounds.origin.y,
                                                                        pageWidth,
                                                                        scrollBounds.size.height)
                                           MusicSelectedBase:self];
    [self.settingScroll addSubview:self.colorView];
    self.difficultyView =
        [[RBMusicDifficultyView alloc] initWithFrame:CGRectMake(kDifficultyPage * pageWidth,
                                                                scrollBounds.origin.y,
                                                                pageWidth,
                                                                scrollBounds.size.height)
                                   MusicSelectedBase:self];
    [self.settingScroll addSubview:self.difficultyView];
    self.speedView = [[RBMusicSpeedView alloc] initWithFrame:CGRectMake(kSpeedPage * pageWidth,
                                                                        scrollBounds.origin.y,
                                                                        pageWidth,
                                                                        scrollBounds.size.height)
                                           MusicSelectedBase:self];
    [self.settingScroll addSubview:self.speedView];

    CGFloat cpuPage = m_GameType == kGameTypeDouble ? kCpuPageArena : kCpuPageNormal;
    CGFloat otherPage = m_GameType == kGameTypeDouble ? kOtherPageArena : kOtherPageNormal;
    self.cpuView = [[RBMusicCPUView alloc] initWithFrame:CGRectMake(cpuPage * pageWidth,
                                                                    scrollBounds.origin.y,
                                                                    pageWidth,
                                                                    scrollBounds.size.height)
                                       MusicSelectedBase:self];
    [self.settingScroll addSubview:self.cpuView];
    self.otherView = [[RBMusicOtherView alloc] initWithFrame:CGRectMake(otherPage * pageWidth,
                                                                        scrollBounds.origin.y,
                                                                        pageWidth,
                                                                        scrollBounds.size.height)
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
    UIImage *decideImage;
    if (decideThema == kThemeWhite) {
        decideImage = [UIImage imageWithName:@"02_music_detail/det_dec_s"];
    } else if (decideThema == kThemeBlack) {
        decideImage = [UIImage imageWithName:kDetDecTable[frameBonusType]];
    } else {
        decideImage = [UIImage imageWithName:kDetDecTable[kDetDecFixedIndex]];
    }
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
    UIImage *doubleImage = doubleThema == kThemeBrown ?
                               [UIImage imageWithName:@"02_music_detail/det_dec_d"] :
                               [UIImage imageWithName:kDetDecTable[frameBonusType]];
    CGSize doubleSize = doubleImage.size;
    self.doubleButton.frame = CGRectMake(kDoubleBaseX + kDoubleGap * kDoubleOffsetX,
                                         kDecideY,
                                         doubleSize.width + kDoubleWidthPad,
                                         doubleSize.height);
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
    if ([RBUserSettingData sharedInstance].speedType) {
        self.doubleButton.enabled = NO;
        self.doubleButtonCoverView.hidden = NO;
    } else {
        self.doubleButtonCoverView.hidden = YES;
        self.doubleButton.enabled = YES;
    }

    // The binary builds a second pastel pair at a lower position, overwriting the first pair.
    UIImage *whitePastel2Image = [UIImage imageWithName:@"02_music_detail/det_pastelkun"];
    UIButton *whitePastel2Button = [UIButton buttonWithType:UIButtonTypeCustom];
    CGSize whitePastel2Size = whitePastel2Image.size;
    whitePastel2Button.frame =
        CGRectMake(kWhitePastel2X, kWhitePastel2Y, whitePastel2Size.width, whitePastel2Size.height);
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
                       forState:UIControlStateSelected];
    self.randomButton.hidden = YES;
    self.randomButton.tag = 0;
    [self.randomButton addTarget:self.musicMenuView
                          action:@selector(selectRandom:)
                forControlEvents:UIControlEventTouchUpInside];
    self.randomButton.frame = CGRectMake(kRandomX, kRandomY, 0.0, 0.0);
    [self.baseView addSubview:self.randomButton];

    self.historyView =
        [[RBMusicHistoryView alloc] initWithFrame:CGRectMake(geometry.scrollX + kHistoryOffsetX,
                                                             geometry.scrollW + kHistoryOffsetY,
                                                             geometry.scrollY,
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

// Builds the BPM strip image by drawing the digit images (and a range separator when the minimum and
// maximum BPM differ) side by side into a single image. @ghidraAddress 0xcd744
- (void)buildBpmImageForMin:(int)bpmMin max:(int)bpmMax {
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

    self.bpmImageView = [[UIImageView alloc] initWithImage:bpmImage];
    CGPoint origin = self.bpmOrigin;
    CGSize size = bpmImage.size;
    self.bpmImageView.frame = CGRectMake(origin.x, origin.y, size.width, size.height);
    [self.baseView addSubview:self.bpmImageView];
}

- (void)SetUpLineView {
    // Builds the animated select-line overlay: a container inserted below baseView, plus ten
    // select-line images, each wrapped in a UIImageView whose layer anchor point, position, opacity,
    // and contents scale are set inside a zero-duration transaction. On the compact layout every
    // frame and position is halved. @ghidraAddress 0xd2764
    CGRect selfBounds = self.bounds;
    BOOL fontVariant = GetFontVariantFlag() != kFontVariantDefault;

    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(kPopupBaseOriginXWide,
                                                                 kPopupBaseOriginYWide,
                                                                 kPopupBaseWidthWide,
                                                                 kPopupBaseHeightWide)];
    if (!fontVariant) {
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

        if (!fontVariant) {
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
        if (fontVariant) {
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
            [self.arView UpdateScore];
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
        CGRect frame = self.rankView.frame;
        [self.rankView setFrame:frame];
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

// The themed music-name image for the given difficulty, keyed on the current theme. The binary
// inlines the twelve theme-by-difficulty accessor calls; they are factored here for legibility.
- (UIImage *)musicNameImageOfMusic:(MusicData *)music forDifficulty:(int)difficulty {
    switch (self->_thema) {
    case kThemeBlack:
        if (difficulty == kDifficultyMedium) {
            return music.musicNameImageBlackMedium;
        }
        if (difficulty == kDifficultyHard) {
            return music.musicNameImageBlackHard;
        }
        return music.musicNameImageBlackBasic;
    case kThemeBrown:
        if (difficulty == kDifficultyMedium) {
            return music.musicNameImageBrownMedium;
        }
        if (difficulty == kDifficultyHard) {
            return music.musicNameImageBrownHard;
        }
        return music.musicNameImageBrownBasic;
    default: // kThemeWhite
        if (difficulty == kDifficultyMedium) {
            return music.musicNameImageWhiteMedium;
        }
        if (difficulty == kDifficultyHard) {
            return music.musicNameImageWhiteHard;
        }
        return music.musicNameImageWhiteBasic;
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
        __weak RBMusicView *weakSelf = self;
        int selected = ShowSettingView;
        [UIView animateWithDuration:g_dMascotMessageAnimDuration
                         animations:^{
                           /** @ghidraAddress 0xd3464 */
                           RBMusicView *strongSelf = weakSelf;
                           for (int i = 0; i < kSettingPageCount; ++i) {
                               UIView *button = strongSelf.settingButtons[i];
                               button.alpha = i == selected ? kSettingButtonAlphaSelected :
                                                              kSettingButtonAlphaDimmed;
                           }
                           if (selected == kSettingPageColor) {
                               strongSelf.difficultyView.alpha = 0.0;
                               strongSelf.colorView.alpha = kSettingButtonAlphaSelected;
                               strongSelf.cpuView.alpha = 0.0;
                           } else if (selected == kSettingPageDifficulty) {
                               strongSelf.difficultyView.alpha = kSettingButtonAlphaSelected;
                               strongSelf.colorView.alpha = 0.0;
                               strongSelf.cpuView.alpha = 0.0;
                           } else {
                               // The binary asserts on any other index; only the CPU page remains.
                               strongSelf.difficultyView.alpha = 0.0;
                               strongSelf.colorView.alpha = 0.0;
                               strongSelf.cpuView.alpha = kSettingButtonAlphaSelected;
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
        if (GetFontVariantFlag() != kFontVariantDefault) {
            self.doubleButton.hidden = NO;
        }
    } else {
        self.whitePastelButton.hidden = NO;
        self.blackPastelButton.hidden = NO;
        if (GetFontVariantFlag() != kFontVariantDefault) {
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
    GetGameSystem()->SetComboCount([self.cpuView level]);

    GameSystem *gameSystem = GetGameSystem();
    if (self->m_GameType == kGameTypeDouble) {
        gameSystem->ConfigureSheetLayerForScreen(0);
    } else if (GetFontVariantFlag() != kFontVariantDefault) {
        gameSystem->ConfigureSheetLayerForScreen([self.speedView speed]);
    } else {
        gameSystem->ConfigureSheetLayerForScreen(0);
    }

    if (self->_thema < kThemeBlack || self->m_GameType != kGameTypeSingle) {
        GetGameSystem()->SetPastelBonusType(kPastelBonusNone);
    } else {
        srand(static_cast<unsigned int>(time(nullptr)));
        (void)rand(); // The binary discards this first draw.
        if ([self m_IsWhitePastelMode]) {
            GetGameSystem()->SetComboCount(kPastelWhiteCombo);
            GetGameSystem()->SetPastelBonusType(kPastelBonusWhite);
        } else {
            BOOL isBlack = [self m_IsBlackPastelMode];
            GetGameSystem()->SetPastelBonusType(isBlack ? kPastelBonusBlack : kPastelBonusNone);
            if (isBlack) {
                srand(static_cast<unsigned int>(time(nullptr)));
                int roll = rand();
                GetGameSystem()->SetComboCount(roll % kPastelBlackComboRollModulo >
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
    GetGameSystem()->SetComboCount(kTutorialComboCount);
    GetGameSystem()->SetPastelBonusType(kPastelBonusNone);

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
        NSString *musicPre = self.musicData.musicPre;
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
        options:UIViewAnimationOptionCurveEaseOut
        animations:^{
          /** @ghidraAddress 0xd50a0 (ShowBaseViewAlphaBlockInvoke) */
          weakSelf1.baseView.alpha = kBaseViewAlphaVisible;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0xd50a0 (FinishMusicViewIntroBlockInvoke) */
          RBMusicView *strongSelf = weakSelf2;
          strongSelf->m_Animating = NO;
          [strongSelf setEnableButton:YES];
          NSString *musicPre = strongSelf.musicData.musicPre;
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
          /** @ghidraAddress 0xd5680 (ResetMusicViewBackgroundBlockInvoke) */
          weakSelf0.backgroundColor = [UIColor clearColor];
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0xd5680 (PlaySelectedMusicBlockInvoke) */
          [weakSelf1.musicMenuView releaseSelectMusic];
        }];
    PlayThemedSoundEffect(SoundEffectManager::GetInstance(), kSoundEffectCancel);
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
    if (GetFontVariantFlag() != kFontVariantDefault) {
        self->m_FirstInfo = NO;
        return;
    }
    if ([RBUserSettingData sharedInstance].musicSelectedFirstInfo) {
        self->m_FirstInfo = NO;
        return;
    }
    if ([RBUserSettingData sharedInstance].thema == kThemeBrown &&
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
    if (GetFontVariantFlag() == kFontVariantDefault) {
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

// =====================================================================================
// RECONSTRUCTION STATUS AND UNCERTAINTIES
// =====================================================================================
// Every method is reconstructed from the binary. The decompilable methods were taken from their
// Ghidra decompiles; SetupView (the decompiler crashes on it with the known RBCoreDataManager
// broken-struct error), SetUpLineView, and switchWithDifficulty: were worked from the raw arm64
// disassembly, with every soft-float geometry constant decoded from the .const pools.
//
// SetupView residual, specifically disassembly-level, blockers (everything else is decoded):
//   * @0xcca74 loads a runtime-initialised CGPoint global (x8 = *0x100358020 -> 0x100410400) that is
//     not present in the static image. Every slot it feeds is consumed exactly where Ghidra
//     annotates the call as setFrame:CGPointZero, so both lanes are provably 0.0 (the default
//     non-arena name centre X and that leg's scroll width/height and page Y/W/H).
//   * The random button's final frame width and height and the double button's X arithmetic mix a
//     button-image width resolved at run time; all of the literal inputs (kRandomX/Y, kDoubleBaseX,
//     kDoubleOffsetX, kDoubleGap, and kDoubleWidthPad) are decoded.
//
// Collaborator sub-views that this hub messages but that are not yet reconstructed (no header
// exists, so these classes are only @class-forward-declared and the messages to them cannot compile
// until their headers are created): RBMusicScoreView (initWithFrame:, setGrade:, UpdateScore:),
// RBMusicARView (initWithFrame:, UpdateScore, UpdateScore:), RBMusicDifficultyView
// (initWithFrame:MusicSelectedBase:, difficulty, setEnableButton:, getDifficultyButton:),
// RBMusicColorView / RBMusicSpeedView / RBMusicCPUView / RBMusicOtherView
// (initWithFrame:MusicSelectedBase:, plus color/rivalAlpha, speed, and level respectively), and
// RBMusicHistoryView (initWithFrame:, isHidden, hideAnimation, showAnimation:difficulty:). The exact
// selectors are listed in the reviewer report. Two catalogue selectors this file relies on but that
// their existing headers may not yet declare are RBMusicManager -getPurchasedMusicDictionary: and
// ScoreData -getFrameBonusType.
//
// The music-view dimming cover colour (MusicViewCoverColor above) is the first entry of the shared
// UIColor palette (InitializeUIColorPalette @0x5517c): 50%-translucent black; it is cached locally
// until the shared palette globals are recovered.
// =====================================================================================
