//
//  RBMusicMenuPopupView.mm
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RBMusicMenuPopupView). Verified
//  against the arm64 disassembly: -setupView's theme- and font-variant-dependent frame maths were
//  recovered from the soft-float register moves that the decompiler folds into pseudo-variables.
//  This is an Objective-C++ file because -hideAnimation reaches the C++ SoundEffectManager engine
//  singleton.
//

#import "RBMusicMenuPopupView.h"

#import "RBMenuView.h"
#import "RBUserSettingData.h"
#import "UIImage+RB.h"
#import "neEngineBridge.h"

// The music-menu popups all fade over a quarter second.
static const NSTimeInterval kPopupAnimationDuration = 0.25;

// The themed sound-effect slot played when a popup is dismissed.
static const int kSoundEffectCancel = 4;

// Autoresizing masks used across the popup chrome. The full mask keeps a subview pinned to its
// superview's bounds; the centring mask keeps the base panel centred as the popup resizes.
static const UIViewAutoresizing kAutoresizingFull =
    UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth |
    UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin |
    UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;
static const UIViewAutoresizing kAutoresizingCentred =
    UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
    UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;

// Base-panel geometry for the wide font variant. The narrow variant uses a square panel centred on
// the popup instead.
static const CGRect kWideBaseFrame = {{112.0, 160.0}, {552.0, 680.0}};
static const CGFloat kNarrowBaseSize = 320.0;

// Vertical reference heights used to place the title bar and content view relative to the base
// panel's frame origin.
static const CGFloat kWideContentTopReference = 188.0;
static const CGFloat kNarrowTitleTopReference = 186.0;
static const CGFloat kTitleTopOffsetWide = 174.0;

// Common inset and corner metrics for the content view and its chrome.
static const CGFloat kContentInset = 2.0;
static const CGFloat kContentEdgeShrink = 1.0;
static const CGFloat kCornerRadiusThemed = 5.0;
static const CGFloat kCornerRadiusDefault = 10.0;
static const CGFloat kNarrowTitleTopThemed = 5.0;
static const CGFloat kNarrowBackgroundTopOffset = 10.0;

// The title-bar and background artwork for each popup type. A title-bar name of nil means the type
// draws no title bar. The tutorial type sizes the base panel to its background image.
static NSString *const kTitleBarImageNames[] = {
    @"03_howtoplay/how_bar",           // RBMusicMenuPopupViewTypeHowTo
    @"04_customize/cus_bar",           // RBMusicMenuPopupViewTypeCustomize
    @"05_theme/theme_bar",             // RBMusicMenuPopupViewTypeTheme
    @"07_credits/cre_bar",             // RBMusicMenuPopupViewTypeCredits
    @"06_search/sear_bar",             // RBMusicMenuPopupViewTypeSearch
    @"08_ranking/rank_bar",            // RBMusicMenuPopupViewTypeRanking
    nil,                               // RBMusicMenuPopupViewTypeTutorial
    @"21_information/information_bar", // RBMusicMenuPopupViewTypeInformation
    nil,                               // RBMusicMenuPopupViewTypeApplilink
    @"23_terms/tos_title",             // RBMusicMenuPopupViewTypeTerms
};
static NSString *const kBackgroundImageNameDefault = @"01_music_select/set_bg_1";
static NSString *const kBackgroundImageNameCustomize = @"01_music_select/set_bg_2";
static NSString *const kBackgroundImageNameTutorial = @"10_tutorial/tu_bg";
static NSString *const kGradationImageName = @"01_music_select/set_grad";

@implementation RBMusicMenuPopupView

#pragma mark - Lifecycle

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setMusicMenuPopupViewType:RBMusicMenuPopupViewTypeHowTo];
        [self setExclusiveTouch:YES];
    }
    return self;
}

#pragma mark - Layout

- (void)setupView {
    BOOL wide = GetFontVariantFlag() != 0;
    NSInteger thema = [RBUserSettingData sharedInstance].thema;

    [self setAlpha:0.0];
    [self setBackgroundColor:nil];
    self.autoresizingMask = kAutoresizingFull;
    [self addTarget:self action:@selector(tap:) forControlEvents:UIControlEventTouchUpInside];

    // The base-panel origin and the base width and height that the chrome is laid out against. The
    // wide variant fixes the panel origin; the narrow variant leaves it at zero and centres later.
    CGPoint baseOrigin;
    CGFloat baseWidth;
    CGFloat baseHeight;
    if (wide) {
        baseOrigin = kWideBaseFrame.origin;
        baseWidth = kWideBaseFrame.size.width;
        baseHeight = kWideBaseFrame.size.height;
    } else {
        baseOrigin = CGPointZero;
        baseWidth = kNarrowBaseSize;
        baseHeight = kNarrowBaseSize;
    }

    // Select the title-bar and background artwork for the current popup type. The tutorial type has
    // no title bar and sizes the base panel to its background image instead.
    UIImage *titleImage = nil;
    UIImage *backgroundImage = nil;
    RBMusicMenuPopupViewType type = self.musicMenuPopupViewType;
    switch (type) {
    case RBMusicMenuPopupViewTypeHowTo:
        titleImage = [UIImage imageWithName:kTitleBarImageNames[type]];
        backgroundImage = [UIImage imageWithName:kBackgroundImageNameDefault];
        break;
    case RBMusicMenuPopupViewTypeCustomize:
        titleImage = [UIImage imageWithName:kTitleBarImageNames[type]];
        backgroundImage = [UIImage imageWithName:kBackgroundImageNameCustomize];
        break;
    case RBMusicMenuPopupViewTypeTheme:
    case RBMusicMenuPopupViewTypeCredits:
    case RBMusicMenuPopupViewTypeSearch:
    case RBMusicMenuPopupViewTypeRanking:
    case RBMusicMenuPopupViewTypeInformation:
    case RBMusicMenuPopupViewTypeTerms:
        titleImage = [UIImage imageWithName:kTitleBarImageNames[type]];
        backgroundImage = [UIImage imageWithName:kBackgroundImageNameDefault];
        break;
    case RBMusicMenuPopupViewTypeTutorial:
        backgroundImage = [UIImage imageWithName:kBackgroundImageNameTutorial];
        baseWidth = backgroundImage.size.width;
        baseHeight = backgroundImage.size.height;
        break;
    case RBMusicMenuPopupViewTypeApplilink:
        backgroundImage = [UIImage imageWithName:kBackgroundImageNameDefault];
        break;
    }

    // The base panel hosts the whole popup chrome. The narrow variant centres it on the popup; the
    // wide variant leaves it at its fixed origin. The tutorial type takes its size from the
    // background image above.
    self.baseView = [[UIView alloc]
        initWithFrame:CGRectMake(baseOrigin.x, baseOrigin.y, baseWidth, baseHeight)];
    if (!wide) {
        self.baseView.center = self.center;
    }
    self.baseView.autoresizingMask = kAutoresizingCentred;
    self.baseView.backgroundColor = [UIColor clearColor];
    [self addSubview:self.baseView];

    // The title bar sits at the top of the base panel; its offset from the panel origin depends on
    // the theme and font variant.
    CGFloat titleX = 0.0;
    CGFloat titleY = 0.0;
    if (wide) {
        if (thema == RBUserSettingDataThemeClassic) {
            titleX = kWideBaseFrame.origin.x - self.baseView.frame.origin.x;
            titleY = kNarrowTitleTopReference - self.baseView.frame.origin.y;
        } else if (thema == RBUserSettingDataThemeColette ||
                   thema == RBUserSettingDataThemeLimelight) {
            titleX = kWideBaseFrame.origin.x - self.baseView.frame.origin.x;
            titleY = kWideBaseFrame.origin.y - self.baseView.frame.origin.y;
        }
    } else if (thema == RBUserSettingDataThemeClassic) {
        titleY = kNarrowBackgroundTopOffset;
    }

    // The background panel fills the base panel below the title bar. Only the narrow default theme
    // shortens it by the title inset.
    UIImageView *background = [[UIImageView alloc] initWithImage:backgroundImage];
    if (thema == RBUserSettingDataThemeClassic && !wide) {
        background.frame = CGRectMake(titleX, titleY, baseWidth, baseHeight - titleY);
    } else {
        background.frame = CGRectMake(titleX, titleY, baseWidth, baseHeight);
    }
    background.autoresizingMask = kAutoresizingFull;
    [self.baseView addSubview:background];
    self.backgroundImageView = background;

    // The rounded, clipped content view is where subclasses lay their own content.
    CGRect contentFrame = CGRectZero;
    CGFloat cornerRadius = wide ? kCornerRadiusDefault : kCornerRadiusThemed;
    if (thema == RBUserSettingDataThemeClassic) {
        if (wide) {
            contentFrame = CGRectMake(kContentInset,
                                      kWideContentTopReference - self.baseView.frame.origin.y,
                                      baseWidth - kContentEdgeShrink,
                                      baseHeight - kContentEdgeShrink);
            cornerRadius = kCornerRadiusDefault;
        } else {
            contentFrame = CGRectMake(kContentInset,
                                      titleY + kContentInset,
                                      baseWidth - kContentEdgeShrink,
                                      baseHeight - kContentEdgeShrink - titleY);
            cornerRadius = kCornerRadiusDefault;
        }
    } else if (thema == RBUserSettingDataThemeColette || thema == RBUserSettingDataThemeLimelight) {
        contentFrame = CGRectMake(kContentInset,
                                  kContentInset,
                                  baseWidth - kContentEdgeShrink,
                                  baseHeight - kContentEdgeShrink);
    }

    self.contentView = [[UIView alloc] initWithFrame:contentFrame];
    self.contentView.layer.cornerRadius = cornerRadius;
    self.contentView.clipsToBounds = YES;
    [self.baseView addSubview:self.contentView];

    // The customize and theme popups draw a gradation overlay at the top of the content.
    if (thema == RBUserSettingDataThemeColette || thema == RBUserSettingDataThemeLimelight) {
        UIImage *gradation = [UIImage imageWithName:kGradationImageName];
        UIImageView *gradationView = [[UIImageView alloc] initWithImage:gradation];
        gradationView.frame =
            CGRectMake(kContentInset, kContentInset, gradation.size.width, gradation.size.height);
        gradationView.autoresizingMask = kAutoresizingFull;
        self.gradationImageView = gradationView;
        [self.baseView addSubview:gradationView];
    }

    // The title bar, centred horizontally within the base panel's bounds.
    UIImageView *title = [[UIImageView alloc] initWithImage:titleImage];
    CGFloat titleWidth = titleImage.size.width;
    CGFloat titleHeight = titleImage.size.height;
    CGFloat centredX = (self.baseView.bounds.size.width - titleWidth) * 0.5;
    if (wide) {
        if (thema == RBUserSettingDataThemeClassic) {
            title.frame = CGRectMake(centredX,
                                     kWideBaseFrame.origin.y - self.baseView.frame.origin.y,
                                     titleWidth,
                                     titleHeight);
        } else {
            title.frame = CGRectMake(centredX,
                                     kTitleTopOffsetWide - self.baseView.frame.origin.y,
                                     titleWidth,
                                     titleHeight);
        }
    } else if (thema == RBUserSettingDataThemeClassic) {
        title.frame = CGRectMake(centredX, 0.0, titleWidth, titleHeight);
    } else {
        title.frame = CGRectMake(centredX, kNarrowTitleTopThemed, titleWidth, titleHeight);
    }
    title.autoresizingMask = kAutoresizingFull;
    self.titleImageView = title;
    [self.baseView addSubview:title];
}

#pragma mark - Animation

- (void)showAnimation {
    if (self.animating) {
        return;
    }
    self.animating = YES;
    __weak RBMusicMenuPopupView *weakSelf = self;
    [UIView animateWithDuration:kPopupAnimationDuration
        animations:^{
          /** @ghidraAddress 0x1a001c */
          weakSelf.alpha = 1.0;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x1a0040 */
          weakSelf.alpha = 1.0;
          weakSelf.animating = NO;
        }];
}

- (void)hideAnimation {
    if (self.animating) {
        return;
    }
    SoundEffectManager::GetInstance()->PlayThemedSoundEffect(kSoundEffectCancel);
    self.animating = YES;
    __weak RBMusicMenuPopupView *weakSelf = self;
    [UIView animateWithDuration:kPopupAnimationDuration
        animations:^{
          /** @ghidraAddress 0x1a019c */
          weakSelf.alpha = 0.0;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x1a01c0 */
          weakSelf.alpha = 0.0;
          [weakSelf removeFromSuperview];
          weakSelf.animating = NO;
          [weakSelf.musicMenuView setShowView:nil];
          weakSelf.musicMenuView = nil;
        }];
}

- (void)tap:(id)sender {
    [self hideAnimation];
}

@end
