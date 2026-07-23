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
#import "neEngineBridge.h"

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

// The framed background image resizes with a symmetric vertical cap inset: the top and bottom insets
// leave a fixed centre stretch region. The wide-font layout uses a larger inset than the narrow one.
constexpr CGFloat kBackgroundCapInsetWide = 36.0;
constexpr CGFloat kBackgroundCapInsetNarrow = 25.0;
// The background image height passed to the cap-inset call.
constexpr CGFloat kBackgroundCapInsetTotal = 25.0;
// The background view centres horizontally within the grid.
constexpr CGFloat kCentreFactor = 0.5;

// The note-size and gauge-style button metrics differ between the wide (non-default) and narrow
// (default) font layouts.
constexpr CGFloat kNoteButtonWidthWide = 200.0;
constexpr CGFloat kNoteButtonWidthNarrow = 62.0;
constexpr CGFloat kNoteButtonHeightWide = 80.0;
constexpr CGFloat kNoteButtonHeightNarrow = 62.0;

// The RBMusicGridLayout item edge length for the paged categories.
constexpr CGFloat kGridItemSizeWide = 68.0;
constexpr CGFloat kGridItemSizeNarrow = 62.0;
// The RBMusicGridLayout page inset: a idiom-dependent left and right inset and fixed top and
// bottom insets.
constexpr CGFloat kGridPageInsetSideWide = 5.0;
constexpr CGFloat kGridPageInsetSideNarrow = 3.0;
constexpr CGFloat kGridPageInsetVertical = 8.0;

// The gauge-style buttons sit lower on the wide layout than the narrow one.
constexpr CGFloat kGaugeButtonInsetNarrow = 3.0;
constexpr CGFloat kGaugeButtonExtraNarrow = -33.0;
constexpr CGFloat kGaugeButtonInsetWideDefault = 66.0;
constexpr CGFloat kGaugeButtonExtraWide = -66.0;
// The gauge buttons' top offset, chosen by theme on the wide layout.
constexpr CGFloat kGaugeButtonTopWideOther = 45.0;
constexpr CGFloat kGaugeButtonTopWideColette = 59.0;
constexpr CGFloat kGaugeButtonTopNarrow = 22.0;

// The timing slider sits a idiom-dependent margin below the page control row.
constexpr CGFloat kTimingSliderMarginWide = 8.0;
constexpr CGFloat kTimingSliderMarginNarrow = 4.0;

// The page control's transform scale and the current-page indicator tint (a per-theme white level;
// the Classic theme is fully opaque white).
constexpr CGFloat kPageControlScale = 0.8;
constexpr CGFloat kPageIndicatorTintClassic = 1.0;
constexpr CGFloat kPageIndicatorTintLimelight = 0.5;
constexpr CGFloat kPageIndicatorTintColette = 0.5;
constexpr CGFloat kPageIndicatorTintWhiteThemed = 0.667;

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

    // The framed background stretches with a symmetric vertical cap inset and centres horizontally.
    UIImage *frameImage = [UIImage imageWithName:kFrameBackgroundImageNames[self.customizeType]];
    CGFloat capInset = wideFont ? kBackgroundCapInsetWide : kBackgroundCapInsetNarrow;
    frameImage = [frameImage
        resizableImageWithCapInsets:UIEdgeInsetsMake(
                                        capInset, 0.0, kBackgroundCapInsetTotal - capInset, 0.0)];
    self.backgroundView = [[UIImageView alloc] initWithImage:frameImage];
    self.backgroundView.frame =
        CGRectMake((self.frame.size.width - frameImage.size.width) * kCentreFactor,
                   0.0,
                   frameImage.size.width,
                   frameImage.size.height);
    [self addSubview:self.backgroundView];

    CGFloat noteButtonWidth = wideFont ? kNoteButtonWidthWide : kNoteButtonWidthNarrow;
    CGFloat noteButtonHeight = wideFont ? kNoteButtonHeightWide : kNoteButtonHeightNarrow;

    // The controls sit below the framed background's top cap inset.
    if (self.customizeType == RBCustomizeItemTypeNote) {
        [self setupNoteButtonsWideFont:wideFont
                       frameImageWidth:frameImage.size.width
                                  topY:capInset
                          buttonHeight:noteButtonHeight];
    } else if (self.customizeType == RBCustomizeItemTypeGauge) {
        [self setupGaugeButtonsWideFont:wideFont
                        frameImageWidth:frameImage.size.width
                            buttonWidth:noteButtonWidth - 2.0
                           buttonHeight:noteButtonHeight];
    } else if (self.customizeType == RBCustomizeItemTypeTiming) {
        [self setupTimingSlider];
    } else {
        [self setupCollectionViewWideFont:wideFont topY:capInset buttonHeight:noteButtonHeight];
    }
}

// Lays out the note category's three fixed size buttons, each embedding a hidden highlight overlay,
// centred horizontally within the framed background.
- (void)setupNoteButtonsWideFont:(BOOL)wideFont
                 frameImageWidth:(CGFloat)frameImageWidth
                            topY:(CGFloat)topY
                    buttonHeight:(CGFloat)buttonHeight {
    [self reloadData];

    UIImage *overlayImage = [UIImage imageWithName:kSelectionOverlayImageName];
    CGFloat noteButtonWidth = overlayImage.size.width;
    CGFloat centre = (self.frame.size.width - frameImageWidth) * kCentreFactor;

    // The three buttons straddle the horizontal centre; the wide layout spreads them one and a half
    // button widths apart, the narrow layout one width apart.
    CGFloat spread = wideFont ? noteButtonWidth * 1.5 : noteButtonWidth;
    CGFloat buttonX[] = {centre - spread, centre, centre + spread};

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
        button.frame = CGRectMake(buttonX[i], topY, buttonImage.size.width, buttonHeight);
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

// Lays out the gauge category's two fixed style buttons, each embedding a hidden highlight overlay.
- (void)setupGaugeButtonsWideFont:(BOOL)wideFont
                  frameImageWidth:(CGFloat)frameImageWidth
                      buttonWidth:(CGFloat)buttonWidth
                     buttonHeight:(CGFloat)buttonHeight {
    UIImage *overlayImage = [UIImage imageWithName:kGaugeStyleOverlayImageName];
    CGFloat centre = (self.frame.size.width - buttonWidth) * kCentreFactor;

    CGFloat buttonX[kGaugeStyleButtonCount];
    CGFloat buttonY;
    if (wideFont) {
        int thema = [RBUserSettingData sharedInstance].thema;
        buttonX[0] = centre + kGaugeButtonInsetWideDefault;
        buttonX[1] = kGaugeButtonExtraWide + centre + kGaugeButtonInsetWideDefault;
        buttonY = (thema == kThemaColette) ? kGaugeButtonTopWideColette : kGaugeButtonTopWideOther;
    } else {
        buttonX[0] = centre + kGaugeButtonInsetNarrow;
        buttonX[1] = kGaugeButtonExtraNarrow + centre + kGaugeButtonInsetNarrow;
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
        button.frame = CGRectMake(buttonX[i], buttonY, buttonWidth, buttonHeight);
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
- (void)setupCollectionViewWideFont:(BOOL)wideFont
                               topY:(CGFloat)topY
                       buttonHeight:(CGFloat)buttonHeight {
    CGFloat itemSize = wideFont ? kGridItemSizeWide : kGridItemSizeNarrow;
    RBMusicGridLayout *layout = [RBMusicGridLayout new];
    layout.itemSize = CGSizeMake(itemSize, itemSize);
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    layout.minimumLineSpacing = 0.0;
    layout.minimumInteritemSpacing = 0.0;
    CGFloat pageInsetSide = wideFont ? kGridPageInsetSideWide : kGridPageInsetSideNarrow;
    layout.pageInset = UIEdgeInsetsMake(
        pageInsetSide, kGridPageInsetVertical, pageInsetSide, kGridPageInsetVertical);
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;

    self.collectionView = [[RBCollectionView alloc]
               initWithFrame:CGRectMake(0.0, topY, self.frame.size.width, buttonHeight)
        collectionViewLayout:layout];
    self.collectionView.backgroundColor = [UIColor clearColor];
    [self.collectionView registerClass:[RBCustomSelectCollectionCell class]
            forCellWithReuseIdentifier:NSStringFromClass([RBCustomSelectCollectionCell class])];
    self.collectionView.customDelegate = self;
    self.collectionView.showsVerticalScrollIndicator = NO;
    self.collectionView.showsHorizontalScrollIndicator = NO;
    self.collectionView.pagingEnabled = YES;
    self.collectionView.delegate = self;
    self.collectionView.dataSource = self;
    [self addSubview:self.collectionView];

    // The current-page indicator tint depends on the theme.
    int thema = [RBUserSettingData sharedInstance].thema;
    CGFloat currentPageTint;
    CGFloat pageIndicatorTint;
    if (thema == kThemaClassic) {
        currentPageTint = kPageIndicatorTintClassic;
        pageIndicatorTint = kPageIndicatorTintClassic;
    } else if (thema == kThemaLimelight) {
        currentPageTint = kPageIndicatorTintLimelight;
        pageIndicatorTint = kPageIndicatorTintWhiteThemed;
    } else if (thema == kThemaColette) {
        currentPageTint = kPageIndicatorTintColette;
        pageIndicatorTint = kPageIndicatorTintWhiteThemed;
    } else {
        currentPageTint = 0.0;
        pageIndicatorTint = 0.0;
    }

    self.pageControl =
        [[UIPageControl alloc] initWithFrame:CGRectMake(0.0, self.collectionView.bottom, 0.0, 0.0)];
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
        slider.frame = CGRectMake((self.frame.size.width - slider.frame.size.width) * kCentreFactor,
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
            forControlEvents:UIControlEventValueChanged];
        slider.tag = kSliderTagShotVolume;
    }

    if (self.customizeType == RBCustomizeItemTypeExplosion) {
        RBEffectSizeSlider *slider = [[RBEffectSizeSlider alloc] initWithDigit:2];
        slider.frame = CGRectMake((self.frame.size.width - slider.frame.size.width) * kCentreFactor,
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
            forControlEvents:UIControlEventValueChanged];
        slider.tag = kSliderTagEffectSize;
    }

    [self reloadData];
}

// Builds the judge-timing category's slider, centred within the framed background.
- (void)setupTimingSlider {
    RBTimingSlider *slider = [[RBTimingSlider alloc] initWithDigit:2];
    CGFloat margin = (IsPad()) ? kTimingSliderMarginWide : kTimingSliderMarginNarrow;
    slider.frame =
        CGRectMake((self.frame.size.width - slider.frame.size.width) * kCentreFactor,
                   (self.frame.size.height - slider.frame.size.height) * kCentreFactor + margin,
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
        forControlEvents:UIControlEventValueChanged];
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

// Shows the highlight overlay on the sibling button whose tag matches the tapped selection and hides
// it on the rest.
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
        EnsurePlayTimer();
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
    float targetPage = (static_cast<float>(rawPage) - static_cast<float>(page) <= kCentreFactor) ?
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
