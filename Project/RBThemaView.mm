//
//  RBThemaView.mm
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RBThemaView). Verified against
//  the arm64 disassembly: -setupView's per-theme page geometry, gradation-overlay placement, and
//  OK button centring were recovered from the soft-float register moves that the decompiler folds
//  into pseudo-variables. This is an Objective-C++ file because the OK-button handler reaches the
//  C++ SoundEffectManager engine singleton.
//

#import "RBThemaView.h"

#import "AppDelegate.h"
#import "RBExperienceData.h"
#import "RBUserSettingData.h"
#import "UIImage+RB.h"
#import "neEngineBridge.h"

// The themed sound-effect slot played when the OK button is pressed.
constexpr int kSoundEffectDecide = 1;

// The theme popup fades fully transparent over one tenth of a second.
// @ghidraAddress 0x2ec778 (g_flThemaFadeOutDuration)
constexpr NSTimeInterval kThemaFadeOutDuration = 0.1;

// The OK button rests a small gap above the bottom of the content view. The Colette theme uses a
// shorter gap than the other themes because its gradation overlay already occupies the lower edge.
constexpr CGFloat kOkButtonBottomGapColette = 5.0;
constexpr CGFloat kOkButtonBottomGapDefault = 10.0;

// The OK button is centred horizontally within the content view.
constexpr CGFloat kHalf = 0.5;

// The per-theme artwork asset names, one full-page image per theme.
static NSString *const kClassicImageName = @"05_theme/thema_classic";
static NSString *const kLimelightImageName = @"05_theme/thema_limelight";
static NSString *const kColetteImageName = @"05_theme/thema_colette";

// The Colette gradation overlay drawn along the bottom of the content view.
static NSString *const kGradationImageName = @"04_customize/set_grad_down";

// The OK button face.
static NSString *const kOkButtonImageName = @"05_theme/theme_ok";

@implementation RBThemaView

#pragma mark Lifecycle

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        [self setMusicMenuPopupViewType:RBMusicMenuPopupViewTypeTheme];
        [self setupView];
        self.exclusiveTouch = YES;
    }
    return self;
}

- (void)setupView {
    [super setupView];
    self.unlockedThemaCount = 0;
    self.thema = [RBUserSettingData sharedInstance].thema;

    self.scrollView = [[UIScrollView alloc] initWithFrame:self.contentView.frame];
    self.scrollView.delegate = self;
    self.scrollView.pagingEnabled = YES;
    self.scrollView.showsHorizontalScrollIndicator = NO;
    self.scrollView.showsVerticalScrollIndicator = NO;
    self.scrollView.bounces = NO;
    self.scrollView.exclusiveTouch = YES;
    [self.contentView addSubview:self.scrollView];

    CGFloat pageWidth = self.scrollView.frame.size.width;
    CGFloat pageHeight = self.scrollView.frame.size.height;

    if ([[RBExperienceData sharedInstance] unlockWithThemaID:RBUserSettingDataThemeClassic]) {
        self.classicView =
            [[UIImageView alloc] initWithImage:[UIImage imageWithName:kClassicImageName]];
        self.classicView.frame = self.scrollView.bounds;
        self.classicView.contentMode = UIViewContentModeScaleAspectFit;
        [self.scrollView addSubview:self.classicView];
        self.unlockedThemaCount = self.unlockedThemaCount + 1;
    }

    if ([[RBExperienceData sharedInstance] unlockWithThemaID:RBUserSettingDataThemeLimelight]) {
        self.limelightView =
            [[UIImageView alloc] initWithImage:[UIImage imageWithName:kLimelightImageName]];
        self.limelightView.frame = CGRectMake(pageWidth, 0.0, pageWidth, pageHeight);
        self.limelightView.contentMode = UIViewContentModeScaleAspectFit;
        [self.scrollView addSubview:self.limelightView];
        self.unlockedThemaCount = self.unlockedThemaCount + 1;
    }

    self.coletteView =
        [[UIImageView alloc] initWithImage:[UIImage imageWithName:kColetteImageName]];
    self.coletteView.frame = CGRectMake(pageWidth + pageWidth, 0.0, pageWidth, pageHeight);
    self.coletteView.contentMode = UIViewContentModeScaleAspectFit;
    [self.scrollView addSubview:self.coletteView];
    self.unlockedThemaCount = self.unlockedThemaCount + 1;

    if (self.thema == RBUserSettingDataThemeColette) {
        UIImage *gradationImage = [UIImage imageWithName:kGradationImageName];
        UIImageView *gradationView = [[UIImageView alloc] initWithImage:gradationImage];
        // The font-variant branches in the binary compute the same overlay placement.
        CGFloat gradationY = self.contentView.frame.size.height - gradationImage.size.height;
        gradationView.frame =
            CGRectMake(0.0, gradationY, gradationImage.size.width, gradationImage.size.height);
        gradationView.exclusiveTouch = YES;
        [self.contentView addSubview:gradationView];
    }

    self.okButton = [UIButton buttonWithType:UIButtonTypeCustom];
    UIImage *okImage = [UIImage imageWithName:kOkButtonImageName];
    [self.okButton setImage:okImage forState:UIControlStateNormal];
    [self.okButton addTarget:self
                      action:@selector(yesButtonTouch:)
            forControlEvents:UIControlEventTouchUpInside];
    self.okButton.exclusiveTouch = YES;
    [self.contentView addSubview:self.okButton];

    CGFloat okX = self.contentView.frame.size.width * kHalf - okImage.size.width * kHalf;
    if (self.thema == RBUserSettingDataThemeColette) {
        self.okButton.frame = CGRectMake(okX,
                                         self.contentView.frame.size.height - okImage.size.height -
                                             kOkButtonBottomGapColette,
                                         okImage.size.width,
                                         okImage.size.height);
    } else {
        self.okButton.frame = CGRectMake(okX,
                                         self.contentView.frame.size.height - okImage.size.height -
                                             kOkButtonBottomGapDefault,
                                         okImage.size.width,
                                         okImage.size.height);
    }

    self.scrollView.contentSize =
        CGSizeMake(self.scrollView.frame.size.width * static_cast<double>(self.unlockedThemaCount),
                   self.scrollView.frame.size.height);
    self.okButton.enabled = NO;

    if (self.thema == RBUserSettingDataThemeClassic) {
        self.scrollView.contentOffset = CGPointMake(self.contentView.frame.size.width * 0.0, 0.0);
    } else if (self.thema == RBUserSettingDataThemeLimelight) {
        self.scrollView.contentOffset = CGPointMake(self.contentView.frame.size.width, 0.0);
    } else if (self.thema == RBUserSettingDataThemeColette) {
        CGFloat contentWidth = self.contentView.frame.size.width;
        self.scrollView.contentOffset = CGPointMake(contentWidth + contentWidth, 0.0);
    }
}

#pragma mark Layout

- (void)layoutSubviews {
    [super layoutSubviews];
    [self scrollViewDidScroll:self.scrollView];
}

#pragma mark Actions

- (void)yesButtonTouch:(id)yesButtonTouch {
    SoundEffectManager::GetInstance()->PlayThemedSoundEffect(kSoundEffectDecide);
    __weak RBThemaView *weakSelf = self;
    self.okButton.enabled = NO;
    [UIView animateWithDuration:kThemaFadeOutDuration
        animations:^{
          /** @ghidraAddress 0x85c4 */
          weakSelf.alpha = 0.0;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x8624 */
          [RBUserSettingData sharedInstance].thema =
              static_cast<RBUserSettingDataTheme>(weakSelf.thema);
          [[RBUserSettingData sharedInstance] save];
          [[AppDelegate appDelegate] resetGame];
        }];
}

#pragma mark Scroll view delegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollViewDidScroll {
    CGFloat offsetX = scrollViewDidScroll.contentOffset.x;
    CGFloat pageWidth = scrollViewDidScroll.bounds.size.width;
    double rawPage = offsetX / pageWidth;
    int page = static_cast<int>(rawPage);
    float lowerPage = static_cast<float>(page);
    float snappedPage = static_cast<float>(page + 1);
    if (static_cast<float>(rawPage) - lowerPage <= kHalf) {
        snappedPage = lowerPage;
    }

    int selectedThema = [RBUserSettingData sharedInstance].thema;
    if (snappedPage == 0.0f) {
        selectedThema = RBUserSettingDataThemeClassic;
    } else if (snappedPage == 1.0f) {
        selectedThema = RBUserSettingDataThemeLimelight;
    } else if (snappedPage == 2.0f) {
        selectedThema = RBUserSettingDataThemeColette;
    }

    if (selectedThema != self.thema) {
        self.thema = selectedThema;
        self.okButton.enabled = self.thema != [RBUserSettingData sharedInstance].thema;
    }
}

@end
