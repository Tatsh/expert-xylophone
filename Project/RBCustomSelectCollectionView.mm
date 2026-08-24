//
//  RBCustomSelectCollectionView.mm
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RBCustomSelectCollectionView).
//  Verified against the arm64 disassembly. This is an Objective-C++ file because -setupView,
//  -sliderChanged:, -reloadData, and the tap handlers reach the C++ engine singletons
//  (ShotSoundManager, SoundEffectManager, LevelTables, GameSystem, and the play timer).
//
//  The class is a UIView hosting one customize category. Most categories build a paged
//  RBCollectionView of RBCustomSelectCollectionCell items with a UIPageControl; the note (5) and
//  gauge (6) categories instead lay out fixed image buttons; and the shot (1), explosion (2), and
//  timing (8) categories add a slider control. -reloadData builds the item catalogue for the
//  current theme from either the level-threshold takeover tables (Classic theme) or the
//  experience-data unlock tables (the two other themes).
//

#import "RBCustomSelectCollectionView.h"

#import "RBBGMManager.h"
#import "RBCollectionView.h"
#import "RBCustomSelectCollectionCell.h"
#import "RBEffectSizeSlider.h"
#import "RBExperienceData.h"
#import "RBMacros.h"
#import "RBMusicGridLayout.h"
#import "RBTimingSlider.h"
#import "RBUserSettingData.h"
#import "RBVolumeSlider.h"
#import "UIImage+RB.h"
#import "UIImageView+RB.h"
#import "UIView+RB.h"
#import "deviceenvironment.h"
#import "engineglobals.h"
#import "engineruntime.h"
#import "gamesystem.h"
#import "leveltables.h"
#import "playtimer.h"
#import "shotsoundmanager.h"
#import "soundeffectmanager.h"

// The player theme identifiers -reloadData branches on.
enum {
    kThemaClassic = 0,
    kThemaLimelight = 1,
    kThemaColette = 2,
};

// The tag stamped on the highlight overlay image view that each button embeds; -viewWithTag: finds
// it again when refreshing the highlight state.
constexpr NSInteger kHighlightOverlayTag = 10000;

// The themed sound-effect slot played when a note-size or gauge-style button changes the selection.
constexpr int kSoundEffectDecide = 1;

// The mixer channel a shot-sound audition plays on.
constexpr unsigned long kShotPreviewChannel = 1;

// The fade/preview time passed to RBBGMManager when auditioning a newly selected background-music
// item. The binary reads this from g_flFlashTimingControlPointX2 (0x2f856c = 0.8).
// @ghidraAddress 0x2f856c (g_flFlashTimingControlPointX2)
constexpr float kBgmPreviewTime = 0.8f;

// The control tags used to route -sliderChanged: to the setting each slider edits. They match the
// slider's RBCustomizeItemType.
constexpr NSInteger kSliderTagShotVolume = RBCustomizeItemTypeShot;
constexpr NSInteger kSliderTagEffectSize = RBCustomizeItemTypeExplosion;
constexpr NSInteger kSliderTagTiming = RBCustomizeItemTypeTiming;

// The note-skin category lays out three fixed size buttons, and the gauge category two fixed style
// buttons.
constexpr int kNoteSizeButtonCount = 3;
constexpr int kGaugeStyleButtonCount = 2;

// The framed background image name for each category, indexed by RBCustomizeItemType.
// @ghidraAddress 0x35b158 (g_pFrameBackgroundImageNames)
static NSString *const kFrameBackgroundImageNames[] = {
    @"04_customize/cus_fram_bgm",
    @"04_customize/cus_fram_shot",
    @"04_customize/cus_fram_exp",
    @"04_customize/cus_fram_frm",
    @"04_customize/cus_fram_bg",
    @"04_customize/cus_fram_obj",
    @"04_customize/cus_fram_gs",
    @"04_customize/cus_fram_unlock",
    @"04_customize/cus_fram_time",
};

// The note-size button highlight overlay image.
static NSString *const kSelectionOverlayImageName = @"04_customize/cus_sel_2";
// The gauge-style button images (unselected style 0, selected style 1) and its highlight overlay.
static NSString *const kGaugeStyleButtonImageName0 = @"04_customize/cus_gs_bt_0";
static NSString *const kGaugeStyleButtonImageName1 = @"04_customize/cus_gs_bt_1";
static NSString *const kGaugeStyleOverlayImageName = @"04_customize/cus_gs_bt_eff";
// The note-item button image name format (the item id fills the placeholder).
static NSString *const kNoteItemImageNameFormat = @"04_customize/cus_iobj_%@";

// The framed background image stretches vertically below its top cap: the top inset is the
// idiom-dependent cap and the bottom inset is the rest of the image
// (UIEdgeInsetsMake(capInset, 0, imageHeight - capInset, 0)). The cap also serves as the top edge
// of the content laid out inside the frame. The wide value is read from the pool at 0x301158.
constexpr CGFloat kBackgroundCapInsetWide = 36.0; // @ghidraAddress 0x301158
constexpr CGFloat kBackgroundCapInsetNarrow = 25.0;
// The background view centres horizontally within the grid.
constexpr CGFloat kCenterFactor = 0.5;

// The paged collection's height, indexed by RBCustomizeItemType, by device idiom. The shot
// category is taller to make room for the volume slider; the note category is slightly taller
// than the default; the gauge and timing rows are short fixed heights. Mirrors the stack table
// -setupView builds at 0x1558c8 from the pool floats at 0x30be70/0x2f855c/0x301f78/0x2eedc8/
// 0x30be74.
constexpr float kCollectionHeightsWide[] = {
    80.0f, 150.0f, 80.0f, 80.0f, 80.0f, 90.0f, 51.0f, 0.0f, 51.0f};
constexpr float kCollectionHeightsNarrow[] = {
    72.0f, 200.0f, 72.0f, 72.0f, 72.0f, 72.0f, 51.0f, 0.0f, 51.0f};

// The RBMusicGridLayout item edge length for the paged categories.
constexpr CGFloat kGridItemSizeWide = 68.0;   // @ghidraAddress 0x2eea00
constexpr CGFloat kGridItemSizeNarrow = 62.0; // @ghidraAddress 0x2eea20
// The RBMusicGridLayout page inset: a idiom-dependent top and bottom inset and fixed left and
// right insets.
constexpr CGFloat kGridPageInsetSideWide = 5.0;
constexpr CGFloat kGridPageInsetSideNarrow = 3.0;
constexpr CGFloat kGridPageInsetHorizontal = 8.0;

// The gauge-style buttons are inset from the button area's two ends by a idiom-dependent amount:
// the left button sits the inset right of the area's left edge, the right button the inset left of
// the area's right edge.
constexpr CGFloat kGaugeButtonEndInsetWide = 66.0;   // @ghidraAddress 0x30be60
constexpr CGFloat kGaugeButtonEndInsetNarrow = 33.0; // @ghidraAddress 0x2eeeb8
// The gauge buttons' top offset: on the wide layout a theme-indexed pair (default, Colette) read
// from the table at 0x30be80; a fixed offset on the narrow layout.
constexpr CGFloat kGaugeButtonTopWideOther = 45.0;   // @ghidraAddress 0x30be80
constexpr CGFloat kGaugeButtonTopWideColette = 59.0; // @ghidraAddress 0x30be88
constexpr CGFloat kGaugeButtonTopNarrow = 22.0;
// The gauge-button area and the paged collection are both centred against the framed background's
// width less this shave.
constexpr CGFloat kFrameContentWidthShave = 2.0;

// The timing slider sits a idiom-dependent margin below the vertical centre.
constexpr CGFloat kTimingSliderMarginWide = 8.0;
constexpr CGFloat kTimingSliderMarginNarrow = 4.0;

// The page control row's fixed height.
constexpr CGFloat kPageControlHeight = 20.0;

// The page control's transform scale and the per-theme indicator tints (white levels). On the
// Classic theme the binary never writes the page-indicator tint register, so the dots inherit the
// 0.5 left over from the frame maths; keep that value to match.
constexpr CGFloat kPageControlScale = 0.8; // @ghidraAddress 0x2eea40
constexpr CGFloat kCurrentPageTintClassic = 1.0;
constexpr CGFloat kPageIndicatorTintClassic = 0.5;
constexpr CGFloat kCurrentPageTintThemed = 0.5;
constexpr CGFloat kPageIndicatorTintThemed = 0.667; // @ghidraAddress 0x2eea48

// The page control hides when the content spans fewer than this many pages.
constexpr long kPageControlMinPageCount = 2;

@interface RBCustomSelectCollectionView ()

// The backing store for the customize category; the binary keeps an int ivar with explicit
// accessors rather than a declared property.
@property(nonatomic, assign) RBCustomizeItemType customizeType;

@end

@implementation RBCustomSelectCollectionView

#pragma mark Lifecycle

- (instancetype)initWithFrame:(CGRect)frame customizeType:(RBCustomizeItemType)customizeType {
    self = [super initWithFrame:frame];
    if (self) {
        self.customizeType = customizeType;
        [self setupView];
    }
    return self;
}

// The binary's -.cxx_destruct (0x15a050) only nils the four object ivars; under ARC the compiler
// generates that, so no override is reconstructed.

#pragma mark Setup

- (void)setupView {
    BOOL wideFont = IsPad();

    // The framed background stretches below its idiom-dependent top cap and centres horizontally.
    UIImage *originalImage = [UIImage imageWithName:kFrameBackgroundImageNames[self.customizeType]];
    CGFloat capInset = wideFont ? kBackgroundCapInsetWide : kBackgroundCapInsetNarrow;
    UIImage *frameImage = [originalImage
        resizableImageWithCapInsets:UIEdgeInsetsMake(
                                        capInset, 0.0, originalImage.size.height - capInset, 0.0)];
    self.backgroundView = [[UIImageView alloc] initWithImage:frameImage];
    self.backgroundView.frame =
        CGRectMake((self.frame.size.width - frameImage.size.width) * kCenterFactor,
                   0.0,
                   frameImage.size.width,
                   self.frame.size.height);
    [self addSubview:self.backgroundView];

    // The controls sit below the framed background's top cap inset.
    if (self.customizeType == RBCustomizeItemTypeNote) {
        [self setupNoteButtonsWideFont:wideFont topY:capInset];
    } else if (self.customizeType == RBCustomizeItemTypeGauge) {
        [self setupGaugeButtonsWideFont:wideFont
                        buttonAreaWidth:frameImage.size.width - kFrameContentWidthShave];
    } else if (self.customizeType == RBCustomizeItemTypeTiming) {
        [self setupTimingSlider];
    } else {
        [self setupCollectionViewWideFont:wideFont
                                     topY:capInset
                                    width:frameImage.size.width - kFrameContentWidthShave];
    }
}

// Lays out the note category's three fixed size buttons, each embedding a hidden highlight
// overlay. Every button is the size of the overlay artwork, and the row straddles the horizontal
// centre of the view against that overlay width.
- (void)setupNoteButtonsWideFont:(BOOL)wideFont topY:(CGFloat)topY {
    [self reloadData];

    UIImage *overlayImage = [UIImage imageWithName:kSelectionOverlayImageName];
    CGFloat overlayWidth = overlayImage.size.width;
    CGFloat center = (self.frame.size.width - overlayWidth) * kCenterFactor;

    // The three buttons straddle the horizontal centre; the wide layout spreads them one and a half
    // overlay widths apart, the narrow layout one width apart.
    CGFloat spread = wideFont ? overlayWidth * 1.5 : overlayWidth;
    CGFloat buttonX[] = {center - spread, center, center + spread};

    int selectedNoteType = [RBUserSettingData sharedInstance].noteType;
    for (NSUInteger i = 0; i < self.items.count; ++i) {
        int itemID = self.items[i].intValue;
        NSString *imageName = [NSString stringWithFormat:kNoteItemImageNameFormat, @(itemID)];
        UIImage *buttonImage = [UIImage imageWithName:imageName];

        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.tag = itemID;
        [button addTarget:self
                      action:@selector(noteSizeTap:)
            forControlEvents:UIControlEventTouchUpInside];
        [button setImage:buttonImage forState:UIControlStateNormal];
        button.frame = CGRectMake(buttonX[i], topY, overlayWidth, overlayImage.size.height);
        [self addSubview:button];

        UIImageView *overlay = [[UIImageView alloc] initWithImage:overlayImage];
        overlay.tag = kHighlightOverlayTag;
        [button addSubview:overlay];
        if (selectedNoteType == itemID) {
            overlay.hidden = NO;
            [overlay SetFlashEffectFast];
        } else {
            overlay.hidden = YES;
            [overlay RemoveFlashEffect];
        }
        button.exclusiveTouch = YES;
    }
}

// Lays out the gauge category's two fixed style buttons, each embedding a hidden highlight
// overlay. Each button is the size of the overlay artwork; the pair is inset from the two ends of
// the button area, which is the framed background's width less the shave, centred in the view.
- (void)setupGaugeButtonsWideFont:(BOOL)wideFont buttonAreaWidth:(CGFloat)buttonAreaWidth {
    UIImage *overlayImage = [UIImage imageWithName:kGaugeStyleOverlayImageName];
    CGFloat areaLeft = (self.frame.size.width - buttonAreaWidth) * kCenterFactor;
    CGFloat endInset = wideFont ? kGaugeButtonEndInsetWide : kGaugeButtonEndInsetNarrow;

    CGFloat buttonX[] = {
        areaLeft + endInset,
        (areaLeft + buttonAreaWidth) - overlayImage.size.width - endInset,
    };
    CGFloat buttonY;
    if (wideFont) {
        int thema = [RBUserSettingData sharedInstance].thema;
        buttonY = (thema == kThemaColette) ? kGaugeButtonTopWideColette : kGaugeButtonTopWideOther;
    } else {
        buttonY = kGaugeButtonTopNarrow;
    }

    int selectedGaugeStyle = [RBUserSettingData sharedInstance].gaugeStyle;
    NSString *const imageNames[] = {kGaugeStyleButtonImageName0, kGaugeStyleButtonImageName1};
    for (int i = 0; i < kGaugeStyleButtonCount; ++i) {
        UIImage *buttonImage = [UIImage imageWithName:imageNames[i]];
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.tag = i;
        [button addTarget:self
                      action:@selector(gaugeStyleTap:)
            forControlEvents:UIControlEventTouchUpInside];
        [button setImage:buttonImage forState:UIControlStateNormal];
        button.frame =
            CGRectMake(buttonX[i], buttonY, overlayImage.size.width, overlayImage.size.height);
        [self addSubview:button];

        UIImageView *overlay = [[UIImageView alloc] initWithImage:overlayImage];
        overlay.tag = kHighlightOverlayTag;
        [button addSubview:overlay];
        if (selectedGaugeStyle == i) {
            overlay.hidden = NO;
            [overlay SetFlashEffectFast];
        } else {
            overlay.hidden = YES;
            [overlay RemoveFlashEffect];
        }
        button.exclusiveTouch = YES;
    }
}

// Builds the paged RBCollectionView of item cells, the page control below it, and (for the shot and
// explosion categories) the slider that edits the associated setting.
- (void)setupCollectionViewWideFont:(BOOL)wideFont topY:(CGFloat)topY width:(CGFloat)width {
    CGFloat itemSize = wideFont ? kGridItemSizeWide : kGridItemSizeNarrow;
    RBMusicGridLayout *layout = [RBMusicGridLayout new];
    layout.itemSize = CGSizeMake(itemSize, itemSize);
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    layout.minimumLineSpacing = 0.0;
    layout.minimumInteritemSpacing = 0.0;
    CGFloat pageInsetSide = wideFont ? kGridPageInsetSideWide : kGridPageInsetSideNarrow;
    layout.pageInset = UIEdgeInsetsMake(
        pageInsetSide, kGridPageInsetHorizontal, pageInsetSide, kGridPageInsetHorizontal);
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;

    // The collection is the width of the framed background less the shave, centred in the view, at
    // the per-category height.
    const float *heights = wideFont ? kCollectionHeightsWide : kCollectionHeightsNarrow;
    self.collectionView = [[RBCollectionView alloc]
               initWithFrame:CGRectMake((self.frame.size.width - width) * kCenterFactor,
                                        topY,
                                        width,
                                        heights[self.customizeType])
        collectionViewLayout:layout];
    self.collectionView.backgroundColor = UIColor.clearColor;
    [self.collectionView registerClass:[RBCustomSelectCollectionCell class]
            forCellWithReuseIdentifier:NSStringFromClass([RBCustomSelectCollectionCell class])];
    self.collectionView.customDelegate = self;
    self.collectionView.showsVerticalScrollIndicator = NO;
    self.collectionView.showsHorizontalScrollIndicator = NO;
    self.collectionView.pagingEnabled = YES;
    self.collectionView.delegate = self;
    self.collectionView.dataSource = self;
    [self addSubview:self.collectionView];

    // The page indicator tints depend on the theme. The Classic arm only sets the current-page
    // tint; its dot tint keeps the 0.5 left in the register by the frame maths (see the constants).
    int thema = [RBUserSettingData sharedInstance].thema;
    CGFloat currentPageTint;
    CGFloat pageIndicatorTint;
    if (thema == kThemaClassic) {
        currentPageTint = kCurrentPageTintClassic;
        pageIndicatorTint = kPageIndicatorTintClassic;
    } else if (thema == kThemaLimelight || thema == kThemaColette) {
        currentPageTint = kCurrentPageTintThemed;
        pageIndicatorTint = kPageIndicatorTintThemed;
    } else {
        currentPageTint = 0.0;
        pageIndicatorTint = 0.0;
    }

    self.pageControl = [[UIPageControl alloc] initWithFrame:CGRectMake(0.0,
                                                                       self.collectionView.bottom,
                                                                       self.frame.size.width,
                                                                       kPageControlHeight)];
    self.pageControl.numberOfPages = 1;
    self.pageControl.currentPage = 0;
    self.pageControl.transform = CGAffineTransformMakeScale(kPageControlScale, kPageControlScale);
    self.pageControl.pageIndicatorTintColor = [UIColor colorWithWhite:pageIndicatorTint alpha:1.0];
    self.pageControl.currentPageIndicatorTintColor = [UIColor colorWithWhite:currentPageTint
                                                                       alpha:1.0];
    self.pageControl.userInteractionEnabled = NO;
    [self addSubview:self.pageControl];

    if (self.customizeType == RBCustomizeItemTypeShot) {
        RBVolumeSlider *slider = [[RBVolumeSlider alloc] init];
        slider.frame = CGRectMake((self.frame.size.width - slider.frame.size.width) * kCenterFactor,
                                  self.pageControl.bottom,
                                  slider.frame.size.width,
                                  slider.frame.size.height);
        slider.exclusiveTouch = YES;
        [self addSubview:slider];
        slider.value = [RBUserSettingData sharedInstance].shotVolume;
        ShotSoundManager::GetInstance()->SetVolume(slider.value);
        [self commitUserSettingsToGameSystem];
        [slider addTarget:self
                      action:@selector(sliderChanged:)
            forControlEvents:UIControlEventTouchUpInside];
        [slider addTarget:self
                      action:@selector(sliderChanged:)
            forControlEvents:UIControlEventTouchUpOutside];
        slider.tag = kSliderTagShotVolume;
    }

    if (self.customizeType == RBCustomizeItemTypeExplosion) {
        RBEffectSizeSlider *slider = [[RBEffectSizeSlider alloc] initWithDigit:2];
        slider.frame = CGRectMake((self.frame.size.width - slider.frame.size.width) * kCenterFactor,
                                  self.pageControl.bottom,
                                  slider.frame.size.width,
                                  slider.frame.size.height);
        slider.exclusiveTouch = YES;
        [self addSubview:slider];
        slider.value = [RBUserSettingData sharedInstance].boundsEffectSize;
        [self commitUserSettingsToGameSystem];
        [slider addTarget:self
                      action:@selector(sliderChanged:)
            forControlEvents:UIControlEventTouchUpInside];
        [slider addTarget:self
                      action:@selector(sliderChanged:)
            forControlEvents:UIControlEventTouchUpOutside];
        slider.tag = kSliderTagEffectSize;
    }

    [self reloadData];
}

// Builds the judge-timing category's slider, centred within the framed background.
- (void)setupTimingSlider {
    RBTimingSlider *slider = [[RBTimingSlider alloc] initWithDigit:2];
    CGFloat margin = (IsPad()) ? kTimingSliderMarginWide : kTimingSliderMarginNarrow;
    slider.frame =
        CGRectMake((self.frame.size.width - slider.frame.size.width) * kCenterFactor,
                   (self.frame.size.height - slider.frame.size.height) * kCenterFactor + margin,
                   slider.frame.size.width,
                   slider.frame.size.height);
    slider.exclusiveTouch = YES;
    [self addSubview:slider];
    slider.value = static_cast<float>([RBUserSettingData sharedInstance].delayFrame);
    [slider addTarget:self
                  action:@selector(sliderChanged:)
        forControlEvents:UIControlEventTouchUpInside];
    [slider addTarget:self
                  action:@selector(sliderChanged:)
        forControlEvents:UIControlEventTouchUpOutside];
    slider.tag = kSliderTagTiming;
}

// Copies the current user settings into the global GameSystem so a live preview reflects them. The
// binary inlines this block; it is de-inlined here because -setupView and -sliderChanged: both use
// it.
- (void)commitUserSettingsToGameSystem {
    GameSystem *gameSystem = GameSystem::GetGameSystem();
    RBUserSettingData *settings = [RBUserSettingData sharedInstance];
    gameSystem->SetGameType(settings.gameType);
    gameSystem->SetDifficulty(settings.difficulty);
    gameSystem->SetDifficultyLevel(settings.difficultyLevel);
    gameSystem->SetPlayColor(settings.playColor);
    gameSystem->SetPlayerColor(settings.playerColor);
    gameSystem->SetRivalAlpha(settings.rivalAlpha);
    gameSystem->SetShotVolume(settings.shotVolume);
    gameSystem->SetBackgroundBrightness(settings.backgroundBrighness);
    gameSystem->SetShotType(settings.shotType);
    gameSystem->SetBgmType(settings.bgmType);
    gameSystem->SetFrameType(settings.frameType);
    gameSystem->SetExplosionType(settings.explosionType);
    gameSystem->SetBackgroundType(settings.backgroundType);
    gameSystem->SetNoteType(settings.noteType);
    gameSystem->SetCpuFullCombo(settings.cpuFullCombo);
    gameSystem->SetUserFullCombo(settings.userFullCombo);
    gameSystem->SetFullJustReflec(settings.fullJustReflec);
}

#pragma mark Content

- (void)reloadData {
    LevelTables *levelTables = LevelTables::GetInstance();
    int thema = [RBUserSettingData sharedInstance].thema;
    if (thema == kThemaClassic) {
        [self buildClassicItemsWithLevelTables:levelTables];
    } else if (thema == kThemaLimelight) {
        [self buildUnlockItemsForLimelight];
    } else if (thema == kThemaColette) {
        [self buildUnlockItemsForColette];
    }
    [self.collectionView reloadData];
}

// The Classic theme offers the level-threshold takeover items for each category.
- (void)buildClassicItemsWithLevelTables:(LevelTables *)levelTables {
    // @ghidraAddress 0x2ef190 (g_anTakeoverBgmTypeIds)
    static const int takeoverBgmTypeIds[] = {0, 2, 3, 4, 5, 6};
    // @ghidraAddress 0x2ef274 (g_anTakeoverShotTypeIds)
    static const int takeoverShotTypeIds[] = {0,  1,  2,  3,  4,  5,  6,  7,  8,  9,  10,
                                              11, 12, 14, 15, 16, 17, 18, 19, 20, 21, 22};
    // @ghidraAddress 0x2ef3c4 (g_anTakeoverExprosionTypeIds)
    static const int takeoverExprosionTypeIds[] = {0, 2, 3, 4, 5, 9, 10};
    // @ghidraAddress 0x2ef45c (g_anTakeoverFrameTypeIds)
    static const int takeoverFrameTypeIds[] = {0, 1, 2, 3, 4, 5, 6};
    // @ghidraAddress 0x2ef52c (g_anTakeoverBackgroundTypeIds)
    static const int takeoverBackgroundTypeIds[] = {0, 1, 2, 3, 4, 5};

    switch (self.customizeType) {
    case RBCustomizeItemTypeBgm:
        [self buildLevelGatedItems:takeoverBgmTypeIds
                             count:ARRAY_SIZE(takeoverBgmTypeIds)
                       levelTables:levelTables];
        break;
    case RBCustomizeItemTypeShot:
        [self buildLevelGatedItems:takeoverShotTypeIds
                             count:ARRAY_SIZE(takeoverShotTypeIds)
                       levelTables:levelTables];
        break;
    case RBCustomizeItemTypeExplosion:
        [self buildLevelGatedItems:takeoverExprosionTypeIds
                             count:ARRAY_SIZE(takeoverExprosionTypeIds)
                       levelTables:levelTables];
        break;
    case RBCustomizeItemTypeFrame:
        [self buildLevelGatedItems:takeoverFrameTypeIds
                             count:ARRAY_SIZE(takeoverFrameTypeIds)
                       levelTables:levelTables];
        break;
    case RBCustomizeItemTypeBg:
        [self buildLevelGatedItems:takeoverBackgroundTypeIds
                             count:ARRAY_SIZE(takeoverBackgroundTypeIds)
                       levelTables:levelTables];
        break;
    case RBCustomizeItemTypeNote:
        [self buildNoteItems];
        break;
    default:
        break;
    }
}

// Fills the item list with the identifiers whose level threshold the player has reached.
- (void)buildLevelGatedItems:(const int *)itemIDs
                       count:(NSUInteger)count
                 levelTables:(LevelTables *)levelTables {
    self.items = [NSMutableArray arrayWithCapacity:count];
    for (NSUInteger i = 0; i < count; ++i) {
        if (levelTables->CheckThresholdReached(self.customizeType, itemIDs[i])) {
            [self.items addObject:@(itemIDs[i])];
        }
    }
}

// The note category always offers its three fixed sizes.
- (void)buildNoteItems {
    self.items = [NSMutableArray arrayWithCapacity:kNoteSizeButtonCount];
    for (int i = 0; i < kNoteSizeButtonCount; ++i) {
        [self.items addObject:@(i)];
    }
}

// The Limelight theme offers the experience-data unlock catalogue for each category.
- (void)buildUnlockItemsForLimelight {
    RBExperienceData *experience = [RBExperienceData sharedInstance];
    // @ghidraAddress 0x2ef1a8 (g_anLimelightBgmTypeIds)
    static const int bgmTypeIds[] = {1, 7, 8, 9, 10, 11, 12, 13, 14, 0, 2, 3, 4, 5, 6};
    // @ghidraAddress 0x2ef2cc (g_anLimelightShotTypeIds)
    static const int shotTypeIds[] = {0,  1,  2,  3,  4,  5,  6,  7,  8,  9,  10, 11, 12, 13, 14,
                                      15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28};
    // @ghidraAddress 0x2ef3e0 (g_anLimelightExprosionTypeIds)
    static const int exprosionTypeIds[] = {1, 6, 7, 8, 11, 0, 2, 3, 4, 5, 9, 10};
    // @ghidraAddress 0x2ef478 (g_anLimelightFrameTypeIds)
    static const int frameTypeIds[] = {7, 8, 9, 10, 11, 12, 13, 0, 1, 2, 3, 4, 5, 6};
    // @ghidraAddress 0x2ef544 (g_anLimelightBackgroundTypeIds)
    static const int backgroundTypeIds[] = {6, 7, 8, 9, 10, 11, 12, 0, 1, 2, 3, 4, 5};

    switch (self.customizeType) {
    case RBCustomizeItemTypeBgm:
        [self buildUnlockedItems:bgmTypeIds
                           count:ARRAY_SIZE(bgmTypeIds)
                        category:RBExperienceItemTypeBGM
                      experience:experience];
        break;
    case RBCustomizeItemTypeShot:
        [self buildUnlockedItems:shotTypeIds
                           count:ARRAY_SIZE(shotTypeIds)
                        category:RBExperienceItemTypeShot
                      experience:experience];
        break;
    case RBCustomizeItemTypeExplosion:
        [self buildUnlockedItems:exprosionTypeIds
                           count:ARRAY_SIZE(exprosionTypeIds)
                        category:RBExperienceItemTypeExprosion
                      experience:experience];
        break;
    case RBCustomizeItemTypeFrame:
        [self buildUnlockedItems:frameTypeIds
                           count:ARRAY_SIZE(frameTypeIds)
                        category:RBExperienceItemTypeFrame
                      experience:experience];
        break;
    case RBCustomizeItemTypeBg:
        [self buildUnlockedItems:backgroundTypeIds
                           count:ARRAY_SIZE(backgroundTypeIds)
                        category:RBExperienceItemTypeBackground
                      experience:experience];
        break;
    case RBCustomizeItemTypeNote:
        [self buildNoteItems];
        break;
    default:
        break;
    }
}

// The Colette theme offers a larger experience-data unlock catalogue for each category.
- (void)buildUnlockItemsForColette {
    RBExperienceData *experience = [RBExperienceData sharedInstance];
    // @ghidraAddress 0x2ef1e4 (g_anColetteBgmTypeIds)
    static const int bgmTypeIds[] = {15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26,
                                     27, 28, 29, 30, 31, 32, 33, 34, 35, 1,  7,  8,
                                     9,  10, 11, 12, 13, 14, 0,  2,  3,  4,  5,  6};
    // @ghidraAddress 0x2ef340 (g_anColetteShotTypeIds)
    static const int shotTypeIds[] = {0,  1,  2,  3,  4,  5,  6,  7,  8,  9,  10,
                                      11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21,
                                      22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32};
    // @ghidraAddress 0x2ef410 (g_anColetteExprosionTypeIds)
    static const int exprosionTypeIds[] = {
        12, 13, 14, 15, 16, 17, 18, 1, 6, 7, 8, 11, 0, 2, 3, 4, 5, 9, 10};
    // @ghidraAddress 0x2ef4b0 (g_anColetteFrameTypeIds)
    static const int frameTypeIds[] = {14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24,
                                       25, 26, 27, 28, 29, 30, 7,  8,  9,  10, 11,
                                       12, 13, 0,  1,  2,  3,  4,  5,  6};
    // @ghidraAddress 0x2ef578 (g_anColetteBackgroundTypeIds)
    static const int backgroundTypeIds[] = {13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26,
                                            27, 6,  7,  8,  9,  10, 11, 12, 0,  1,  2,  3,  4,  5};

    switch (self.customizeType) {
    case RBCustomizeItemTypeBgm:
        [self buildUnlockedItems:bgmTypeIds
                           count:ARRAY_SIZE(bgmTypeIds)
                        category:RBExperienceItemTypeBGM
                      experience:experience];
        break;
    case RBCustomizeItemTypeShot:
        [self buildUnlockedItems:shotTypeIds
                           count:ARRAY_SIZE(shotTypeIds)
                        category:RBExperienceItemTypeShot
                      experience:experience];
        break;
    case RBCustomizeItemTypeExplosion:
        [self buildUnlockedItems:exprosionTypeIds
                           count:ARRAY_SIZE(exprosionTypeIds)
                        category:RBExperienceItemTypeExprosion
                      experience:experience];
        break;
    case RBCustomizeItemTypeFrame:
        [self buildUnlockedItems:frameTypeIds
                           count:ARRAY_SIZE(frameTypeIds)
                        category:RBExperienceItemTypeFrame
                      experience:experience];
        break;
    case RBCustomizeItemTypeBg:
        [self buildUnlockedItems:backgroundTypeIds
                           count:ARRAY_SIZE(backgroundTypeIds)
                        category:RBExperienceItemTypeBackground
                      experience:experience];
        break;
    case RBCustomizeItemTypeNote:
        [self buildNoteItems];
        break;
    default:
        break;
    }
}

// Fills the item list with the identifiers the experience data reports as unlocked.
- (void)buildUnlockedItems:(const int *)itemIDs
                     count:(NSUInteger)count
                  category:(RBExperienceItemType)category
                experience:(RBExperienceData *)experience {
    self.items = [NSMutableArray arrayWithCapacity:count];
    for (NSUInteger i = 0; i < count; ++i) {
        BOOL unlocked = NO;
        switch (category) {
        case RBExperienceItemTypeBGM:
            unlocked = [experience unlockWithBGMtype:itemIDs[i]];
            break;
        case RBExperienceItemTypeShot:
            unlocked = [experience unlockWithShotType:itemIDs[i]];
            break;
        case RBExperienceItemTypeExprosion:
            unlocked = [experience unlockWithExprosionType:itemIDs[i]];
            break;
        case RBExperienceItemTypeFrame:
            unlocked = [experience unlockWithFrameType:itemIDs[i]];
            break;
        case RBExperienceItemTypeBackground:
            unlocked = [experience unlockWithBackgroundType:itemIDs[i]];
            break;
        default:
            break;
        }
        if (unlocked) {
            [self.items addObject:@(itemIDs[i])];
        }
    }
}

#pragma mark Button actions

- (void)noteSizeTap:(id)sender {
    UIButton *button = sender;
    int tappedType = static_cast<int>(button.tag);
    if (tappedType == [RBUserSettingData sharedInstance].noteType) {
        return;
    }
    [[RBUserSettingData sharedInstance] resetNoteType:tappedType];
    [self refreshButtonHighlightsForTappedTag:tappedType inSuperviewOf:button];
    SoundEffectManager::GetInstance()->PlayThemedSoundEffect(kSoundEffectDecide);
}

- (void)gaugeStyleTap:(id)sender {
    UIButton *button = sender;
    int tappedStyle = static_cast<int>(button.tag);
    if (tappedStyle == [RBUserSettingData sharedInstance].gaugeStyle) {
        return;
    }
    [[RBUserSettingData sharedInstance] resetGaugeStyle:tappedStyle];
    [self refreshButtonHighlightsForTappedTag:tappedStyle inSuperviewOf:button];
    SoundEffectManager::GetInstance()->PlayThemedSoundEffect(kSoundEffectDecide);
}

// Shows the highlight overlay on the sibling button whose tag matches the tapped selection and
// hides it on the rest.
- (void)refreshButtonHighlightsForTappedTag:(NSInteger)tappedTag inSuperviewOf:(UIView *)button {
    for (UIView *sibling in button.superview.subviews) {
        UIView *overlay = [sibling viewWithTag:kHighlightOverlayTag];
        if (sibling.tag == tappedTag) {
            overlay.hidden = NO;
            [overlay SetFlashEffectFast];
        } else {
            overlay.hidden = YES;
            [overlay RemoveFlashEffect];
        }
    }
}

- (void)sliderChanged:(id)sender {
    UISlider *slider = sender;
    if (slider.tag == kSliderTagShotVolume) {
        ShotSoundManager::GetInstance()->SetVolume(slider.value);
        [[RBUserSettingData sharedInstance] resetShotVolume:slider.value];
        [self commitUserSettingsToGameSystem];
    } else if (slider.tag == kSliderTagTiming) {
        [RBUserSettingData sharedInstance].delayFrame = static_cast<int>(slider.value);
        PlayTimer::shared();
        g_pPlayTimer->SetDelayFrameOffset(
            static_cast<float>([RBUserSettingData sharedInstance].delayFrame) *
            g_flDelayFrameToSeconds);
    } else if (slider.tag == kSliderTagEffectSize) {
        RBUserSettingData *settings = [RBUserSettingData sharedInstance];
        settings.boundsEffectSize = slider.value;
        settings.damageEffectSize = slider.value;
        settings.explosionEffectSize = slider.value * g_flDefaultExplosionEffectSize;
    }
}

#pragma mark RBCollectionView delegate

- (void)didLayoutSubviews:(RBCollectionView *)collectionView {
    long pageCount =
        static_cast<long>(collectionView.contentSize.width / collectionView.frame.size.width);
    self.pageControl.numberOfPages = pageCount;
    self.pageControl.hidden = pageCount < kPageControlMinPageCount;
}

#pragma mark UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    CGFloat rawPage = scrollView.contentOffset.x / scrollView.bounds.size.width;
    int page = static_cast<int>(rawPage);
    // Round to the nearest page: snap up only once the offset passes the halfway point.
    float targetPage = (static_cast<float>(rawPage) - static_cast<float>(page) <= kCenterFactor) ?
                           static_cast<float>(page) :
                           static_cast<float>(page + 1);
    if (static_cast<float>(self.pageControl.currentPage) != targetPage) {
        self.pageControl.currentPage = static_cast<long>(targetPage);
    }
}

#pragma mark UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView
    didHighlightItemAtIndexPath:(NSIndexPath *)indexPath {
    [collectionView cellForItemAtIndexPath:indexPath].highlighted = YES;
}

- (void)collectionView:(UICollectionView *)collectionView
    didUnhighlightItemAtIndexPath:(NSIndexPath *)indexPath {
    [collectionView cellForItemAtIndexPath:indexPath].highlighted = NO;
}

- (void)collectionView:(UICollectionView *)collectionView
    didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    // Clear every visible cell's selection, then mark the tapped cell.
    for (RBCustomSelectCollectionCell *cell in collectionView.visibleCells) {
        cell.itemSelected = NO;
    }
    RBCustomSelectCollectionCell *cell = static_cast<RBCustomSelectCollectionCell *>(
        [collectionView cellForItemAtIndexPath:indexPath]);
    cell.itemSelected = YES;
    int tappedType = static_cast<int>(cell.tag);

    switch (self.customizeType) {
    case RBCustomizeItemTypeBgm:
        if ([RBUserSettingData sharedInstance].bgmType != tappedType) {
            [[RBUserSettingData sharedInstance] resetBgmType:tappedType];
            [[RBBGMManager getInstance] LoadMusicSelect];
            [[RBBGMManager getInstance] PlayMusic:kBgmPreviewTime];
        }
        break;
    case RBCustomizeItemTypeShot:
        [[RBUserSettingData sharedInstance] resetShotType:tappedType];
        break;
    case RBCustomizeItemTypeExplosion:
        [[RBUserSettingData sharedInstance] resetExplosionType:tappedType];
        break;
    case RBCustomizeItemTypeFrame:
        [[RBUserSettingData sharedInstance] resetFrameType:tappedType];
        break;
    case RBCustomizeItemTypeBg:
        [[RBUserSettingData sharedInstance] resetBackgroundType:tappedType];
        break;
    case RBCustomizeItemTypeNote:
        [[RBUserSettingData sharedInstance] resetNoteType:tappedType];
        break;
    default:
        break;
    }

    if (self.customizeType == RBCustomizeItemTypeShot) {
        ShotSoundManager::GetInstance()->PlaySlot(kShotPreviewChannel, tappedType, 0);
    } else {
        SoundEffectManager::GetInstance()->PlayThemedSoundEffect(kSoundEffectDecide);
    }
}

#pragma mark UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView
     numberOfItemsInSection:(NSInteger)section {
    return self.items.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *reuseIdentifier;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      reuseIdentifier = NSStringFromClass([RBCustomSelectCollectionCell class]);
    });

    RBCustomSelectCollectionCell *cell =
        [collectionView dequeueReusableCellWithReuseIdentifier:reuseIdentifier
                                                  forIndexPath:indexPath];
    int itemID = self.items[indexPath.row].intValue;
    cell.tag = itemID;

    int selectedType;
    switch (self.customizeType) {
    case RBCustomizeItemTypeBgm:
        selectedType = [RBUserSettingData sharedInstance].bgmType;
        break;
    case RBCustomizeItemTypeShot:
        selectedType = [RBUserSettingData sharedInstance].shotType;
        break;
    case RBCustomizeItemTypeExplosion:
        selectedType = [RBUserSettingData sharedInstance].explosionType;
        break;
    case RBCustomizeItemTypeFrame:
        selectedType = [RBUserSettingData sharedInstance].frameType;
        break;
    case RBCustomizeItemTypeBg:
        selectedType = [RBUserSettingData sharedInstance].backgroundType;
        break;
    case RBCustomizeItemTypeNote:
        selectedType = [RBUserSettingData sharedInstance].noteType;
        break;
    default:
        selectedType = 0;
        break;
    }
    cell.itemSelected = (selectedType == itemID);

    // Load the item image off the main queue and apply it to the cell's button on the main queue
    // once it is ready.
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
      /** @ghidraAddress 0x1596dc */
      NSString *imagePath = BuildCustomizeAssetPathString(self.customizeType, itemID);
      UIImage *image = [UIImage imageWithName:imagePath];
      dispatch_async(dispatch_get_main_queue(), ^{
        /** @ghidraAddress 0x1597d8 */
        [cell.itemButton setImage:image forState:UIControlStateNormal];
        cell.itemButton.frame = CGRectMake(0.0, 0.0, image.size.width, image.size.height);
      });
    });
    return cell;
}

@end
