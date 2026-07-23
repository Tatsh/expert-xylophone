//
//  RBCustomSelectView.mm
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RBCustomSelectView). Verified
//  against the arm64 disassembly: -setupView stacks one item grid per customization category inside
//  a scroll view, and the per-category heights, the start offset, the inter-grid margin, and the
//  final content size are all font-variant- and theme-dependent soft-float values that the
//  decompiler folds into pseudo-variables. This is an Objective-C++ file because -setupView and
//  -prevButtonTap: reach the C++ ShotSoundManager and SoundEffectManager engine singletons.
//

#import "RBCustomSelectView.h"

#import "AppDelegate.h"
#import "RBViewController.h"
#import "UIImage+RB.h"
#import "UIView+RB.h"
#import "neEngineBridge.h"

// The preview button that starts the game preview from the bottom of the stack.
static NSString *const kPreviewButtonImageName = @"04_customize/cus_prev";

// The themed sound-effect slot played when the preview button is tapped.
constexpr int kSoundEffectDecide = 1;

// The button horizontally centres within the scroll view.
constexpr CGFloat kPreviewButtonCentreFactor = 0.5;

// The preview button flexes on every edge so it stays centred as the scroll view resizes.
constexpr UIViewAutoresizing kAutoresizingFull =
    UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth |
    UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin |
    UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;

// The first grid's top offset, chosen by theme then font variant. The Classic theme (0) starts the
// stack higher than the others.
constexpr CGFloat kStartYWideBgm = 40.0;
constexpr CGFloat kStartYWideOther = 70.0;
constexpr CGFloat kStartYNarrowBgm = 21.0;
constexpr CGFloat kStartYNarrowOther = 34.0;

// The gap left between consecutive grids and below the last grid before the preview button.
constexpr CGFloat kMarginWide = 20.0;
constexpr CGFloat kMarginNarrow = 12.0;

// The per-category grid heights. The wide (non-default) font variant and the narrow (default) font
// variant use different heights; the grid width always fills the picker.
constexpr CGFloat kHeightBgmWide = 144.0;
constexpr CGFloat kHeightBgmNarrow = 120.0;
constexpr CGFloat kHeightShotWide = 290.0;
constexpr CGFloat kHeightShotNarrow = 288.0;
constexpr CGFloat kHeightExplosionWide = 234.0;
constexpr CGFloat kHeightExplosionNarrow = 180.0;
constexpr CGFloat kHeightFrameWide = 144.0;
constexpr CGFloat kHeightFrameNarrow = 120.0;
constexpr CGFloat kHeightBgWide = 144.0;
constexpr CGFloat kHeightBgNarrow = 120.0;
constexpr CGFloat kHeightNoteWide = 144.0;
constexpr CGFloat kHeightNoteNarrow = 94.0;
constexpr CGFloat kHeightGaugeWide = 144.0;
constexpr CGFloat kHeightTimingWide = 144.0;
constexpr CGFloat kHeightTimingNarrow = 94.0;

// The scroll view's content height leaves a margin of this many multiples below the preview button;
// a Classic theme uses a shorter tail than the others.
constexpr CGFloat kContentTailMarginFactorClassic = 2.0;
constexpr CGFloat kContentTailMarginFactorOther = 4.0;

@implementation RBCustomSelectView

#pragma mark Lifecycle

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupView];
    }
    return self;
}

// The binary's -.cxx_destruct (0x69b58) only nils the scroll view and the eight grid ivars; under
// ARC the compiler generates that, so no override is reconstructed.

#pragma mark Layout metrics

- (CGFloat)getCollectionViewStartY:(RBUserSettingDataTheme)thema {
    BOOL isBgm = (thema == RBUserSettingDataThemeClassic);
    if (GetFontVariantFlag() != kFontVariantDefault) {
        return isBgm ? kStartYWideBgm : kStartYWideOther;
    }
    return isBgm ? kStartYNarrowBgm : kStartYNarrowOther;
}

- (CGFloat)getCollectionViewMargin {
    return (GetFontVariantFlag() != kFontVariantDefault) ? kMarginWide : kMarginNarrow;
}

#pragma mark Setup

- (void)setupView {
    self.scrollView = [[UIScrollView alloc] initWithFrame:self.bounds];
    [self addSubview:self.scrollView];

    BOOL wideFont = GetFontVariantFlag() != kFontVariantDefault;
    RBUserSettingDataTheme thema = [RBUserSettingData sharedInstance].thema;

    CGFloat width = self.frame.size.width;
    CGFloat startY = [self getCollectionViewStartY:thema];
    CGFloat margin = [self getCollectionViewMargin];

    // The background-music grid tops the stack at the theme-dependent start offset. Each subsequent
    // grid is stacked a margin below the previous grid's bottom.
    CGFloat bgmHeight = wideFont ? kHeightBgmWide : kHeightBgmNarrow;
    self.bgmCollectionView = [[RBCustomSelectCollectionView alloc]
        initWithFrame:CGRectMake(0.0, startY, width, bgmHeight)
        customizeType:RBCustomizeItemTypeBgm];
    [self.scrollView addSubview:self.bgmCollectionView];

    CGFloat shotHeight = wideFont ? kHeightShotWide : kHeightShotNarrow;
    CGFloat shotY = margin + self.bgmCollectionView.bottom;
    self.shotCollectionView = [[RBCustomSelectCollectionView alloc]
        initWithFrame:CGRectMake(0.0, shotY, width, shotHeight)
        customizeType:RBCustomizeItemTypeShot];
    [self.scrollView addSubview:self.shotCollectionView];

    CGFloat explosionHeight = wideFont ? kHeightExplosionWide : kHeightExplosionNarrow;
    CGFloat explosionY = margin + self.shotCollectionView.bottom;
    self.explosionCollectionView = [[RBCustomSelectCollectionView alloc]
        initWithFrame:CGRectMake(0.0, explosionY, width, explosionHeight)
        customizeType:RBCustomizeItemTypeExplosion];
    [self.scrollView addSubview:self.explosionCollectionView];

    CGFloat frameHeight = wideFont ? kHeightFrameWide : kHeightFrameNarrow;
    CGFloat frameY = margin + self.explosionCollectionView.bottom;
    self.frameCollectionView = [[RBCustomSelectCollectionView alloc]
        initWithFrame:CGRectMake(0.0, frameY, width, frameHeight)
        customizeType:RBCustomizeItemTypeFrame];
    [self.scrollView addSubview:self.frameCollectionView];

    CGFloat bgHeight = wideFont ? kHeightBgWide : kHeightBgNarrow;
    self.bgCollectionView = [[RBCustomSelectCollectionView alloc]
        initWithFrame:CGRectMake(0.0, margin + self.frameCollectionView.bottom, width, bgHeight)
        customizeType:RBCustomizeItemTypeBg];
    [self.scrollView addSubview:self.bgCollectionView];

    CGFloat noteHeight = wideFont ? kHeightNoteWide : kHeightNoteNarrow;
    self.noteCollectionView = [[RBCustomSelectCollectionView alloc]
        initWithFrame:CGRectMake(0.0, margin + self.bgCollectionView.bottom, width, noteHeight)
        customizeType:RBCustomizeItemTypeNote];
    [self.scrollView addSubview:self.noteCollectionView];

    // The gauge grid exists only on the wide-font layout; on the narrow-font layout the timing grid
    // follows the note grid directly.
    RBCustomSelectCollectionView *lastGrid;
    if (wideFont) {
        self.gaugeCollectionView = [[RBCustomSelectCollectionView alloc]
            initWithFrame:CGRectMake(
                              0.0, margin + self.noteCollectionView.bottom, width, kHeightGaugeWide)
            customizeType:RBCustomizeItemTypeGauge];
        [self.scrollView addSubview:self.gaugeCollectionView];

        self.timingCollectionView = [[RBCustomSelectCollectionView alloc]
            initWithFrame:CGRectMake(0.0,
                                     margin + self.gaugeCollectionView.bottom,
                                     width,
                                     kHeightTimingWide)
            customizeType:RBCustomizeItemTypeTiming];
        [self.scrollView addSubview:self.timingCollectionView];
        lastGrid = self.timingCollectionView;
    } else {
        self.timingCollectionView = [[RBCustomSelectCollectionView alloc]
            initWithFrame:CGRectMake(0.0,
                                     margin + self.noteCollectionView.bottom,
                                     width,
                                     kHeightTimingNarrow)
            customizeType:RBCustomizeItemTypeTiming];
        [self.scrollView addSubview:self.timingCollectionView];
        lastGrid = self.timingCollectionView;
    }

    // The preview button centres horizontally a margin below the last grid.
    UIImage *previewImage = [UIImage imageWithName:kPreviewButtonImageName];
    UIButton *previewButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [previewButton setImage:previewImage forState:UIControlStateNormal];
    previewButton.frame = CGRectMake((self.scrollView.frame.size.width - previewImage.size.width) *
                                         kPreviewButtonCentreFactor,
                                     margin + lastGrid.bottom,
                                     previewImage.size.width,
                                     previewImage.size.height);
    previewButton.exclusiveTouch = YES;
    previewButton.autoresizingMask = kAutoresizingFull;
    [previewButton addTarget:self
                      action:@selector(prevButtonTap:)
            forControlEvents:UIControlEventTouchUpInside];
    [self.scrollView addSubview:previewButton];

    // The content extends below the preview button by a theme-dependent multiple of the margin.
    CGFloat tailFactor = (thema == RBUserSettingDataThemeClassic) ?
                             kContentTailMarginFactorClassic :
                             kContentTailMarginFactorOther;
    self.scrollView.contentSize =
        CGSizeMake(self.scrollView.frame.size.width, margin * tailFactor + previewButton.bottom);

    // Preload the shot-sound bank so the shot category can audition its items immediately.
    ShotSoundManager::GetInstance()->LoadAll();
}

#pragma mark Content

- (void)reloadData {
    [self.bgmCollectionView reloadData];
    [self.shotCollectionView reloadData];
    [self.explosionCollectionView reloadData];
    [self.frameCollectionView reloadData];
    [self.bgCollectionView reloadData];
    [self.noteCollectionView reloadData];
}

#pragma mark Preview

- (void)prevButtonTap:(id)sender {
    [[AppDelegate appDelegate].viewController startPreview];
    SoundEffectManager::GetInstance()->PlayThemedSoundEffect(kSoundEffectDecide);
}

@end
