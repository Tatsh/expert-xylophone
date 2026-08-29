#import "RBCustomInfoPopupView.h"

#import "ImageDownloader.h"
#import "RBNumberLabel.h"
#import "RBUnlockPackageItemData.h"
#import "RBUserSettingData.h"
#import "UIImage+RB.h"
#import "deviceenvironment.h"
#import "engineruntime.h"
#import "soundeffectmanager.h"

static NSString *const kPanelBackgroundImageName = @"04_customize/cus_unlock_bg";
static NSString *const kYesButtonImageName = @"04_customize/cus_unlock_yes";
static NSString *const kNoButtonImageName = @"04_customize/cus_unlock_no";

constexpr int kUnlockItemTypeMusic = 7;

constexpr int kSoundEffectPopupOpen = 3;

constexpr CGFloat kContentCornerRadius = 5.0;

constexpr NSTimeInterval kFadeAnimationDuration = 0.25;

constexpr CGFloat kArtworkScaleNarrow = 0.5;
constexpr CGFloat kArtworkNarrowLimelightX = 34.0;
constexpr CGFloat kArtworkNarrowLimelightY = 41.0;
constexpr CGFloat kArtworkNarrowColetteXY = 53.0;
constexpr CGFloat kArtworkWideLimelightX = 68.0;
constexpr CGFloat kArtworkWideLimelightY = 82.0;
constexpr CGFloat kArtworkWideColetteX = 100.0;
constexpr CGFloat kArtworkWideColetteY = 102.0;

constexpr CGFloat kCostNarrowLimelightX = 83.0;
constexpr CGFloat kCostNarrowLimelightY = 53.0;
constexpr CGFloat kCostNarrowColetteX = 83.0;
constexpr CGFloat kCostNarrowColetteY = 63.0;
constexpr CGFloat kCostNarrowWidth = 70.0;
constexpr CGFloat kCostNarrowHeight = 20.0;

constexpr CGFloat kBalanceNarrowLimelightX = 70.0;
constexpr CGFloat kBalanceNarrowLimelightY = 132.0;
constexpr CGFloat kBalanceNarrowLimelightWidth = 130.0;
constexpr CGFloat kBalanceNarrowColetteX = 251.0;
constexpr CGFloat kBalanceNarrowColetteY = 131.0;
constexpr CGFloat kBalanceNarrowColetteWidth = 105.0;
constexpr CGFloat kBalanceNarrowHeight = 20.0;

constexpr CGFloat kButtonNarrowY = 160.0;
constexpr CGFloat kYesButtonNarrowX = 11.0;
constexpr CGFloat kNoButtonNarrowX = 121.0;

constexpr CGFloat kCostWideLimelightX = 74.0;
constexpr CGFloat kCostWideLimelightY = 109.0;
constexpr CGFloat kCostWideColetteX = 74.0;
constexpr CGFloat kCostWideColetteY = 126.0;
constexpr CGFloat kCostWideWidth = 230.0;
constexpr CGFloat kCostWideLimelightHeight = 36.0;
constexpr CGFloat kCostWideColetteHeight = 40.0;

constexpr CGFloat kBalanceWideLimelightX = 168.0;
constexpr CGFloat kBalanceWideLimelightY = 267.0;
constexpr CGFloat kBalanceWideColetteX = 162.0;
constexpr CGFloat kBalanceWideColetteY = 264.0;

constexpr CGFloat kYesButtonWideX = 15.0;
constexpr CGFloat kButtonWideLimelightY = 325.0;
constexpr CGFloat kButtonWideColetteY = 323.0;
constexpr CGFloat kNoButtonWideX = 249.0;

@implementation RBCustomInfoPopupView

#pragma mark Lifecycle

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.isPad = (IsPad());
        [self setupView];
        self.exclusiveTouch = YES;
    }
    return self;
}

// ARC clears the strong subview ivars through .cxx_destruct.
// @ghidraAddress 0x19bd00

#pragma mark Layout

- (void)setupView {
    BOOL isPad = IsPad();

    self.alpha = 0.0;
    self.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.5];
    self.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth |
                            UIViewAutoresizingFlexibleRightMargin |
                            UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleHeight |
                            UIViewAutoresizingFlexibleBottomMargin;
    [self addTarget:self action:@selector(tap:) forControlEvents:UIControlEventTouchUpInside];

    UIImage *panelImage = [UIImage imageWithName:kPanelBackgroundImageName];
    self.baseView = [[UIView alloc]
        initWithFrame:CGRectMake(0.0, 0.0, panelImage.size.width, panelImage.size.height)];
    self.baseView.center = self.center;
    self.baseView.autoresizingMask =
        UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
        UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    self.baseView.backgroundColor = UIColor.clearColor;
    [self addSubview:self.baseView];

    UIImageView *backgroundView = [[UIImageView alloc] initWithImage:panelImage];
    backgroundView.frame = self.baseView.bounds;
    backgroundView.autoresizingMask =
        UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth |
        UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin |
        UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;
    [self.baseView addSubview:backgroundView];

    self.contentView = [[UIView alloc] initWithFrame:self.baseView.bounds];
    self.contentView.layer.cornerRadius = kContentCornerRadius;
    self.contentView.clipsToBounds = YES;
    [self.baseView addSubview:self.contentView];

    self.imageView = [[UIImageView alloc] initWithFrame:CGRectZero];
    [self.baseView addSubview:self.imageView];
    self.frameImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
    [self.baseView addSubview:self.frameImageView];

    self.usePointLabel = [[RBNumberLabel alloc] init];
    self.usePointLabel.imageType = RBNumberLabelImageTypeNormal;
    [self.contentView addSubview:self.usePointLabel];

    self.pointLabel = [[RBNumberLabel alloc] init];
    self.pointLabel.imageType = RBNumberLabelImageTypeDecimal;
    [self.contentView addSubview:self.pointLabel];

    self.yesButton = [UIButton buttonWithType:UIButtonTypeCustom];
    UIImage *yesImage = [UIImage imageWithName:kYesButtonImageName];
    [self.yesButton setImage:yesImage forState:UIControlStateNormal];
    self.yesButton.exclusiveTouch = YES;
    [self.contentView addSubview:self.yesButton];

    self.noButton = [UIButton buttonWithType:UIButtonTypeCustom];
    UIImage *noImage = [UIImage imageWithName:kNoButtonImageName];
    [self.noButton setImage:noImage forState:UIControlStateNormal];
    self.noButton.exclusiveTouch = YES;
    [self.contentView addSubview:self.noButton];

    if (!isPad) {
        RBUserSettingDataTheme theme = [RBUserSettingData sharedInstance].thema;
        if (theme == RBUserSettingDataThemeLimelight) {
            self.usePointLabel.frame = CGRectMake(
                kCostNarrowLimelightX, kCostNarrowLimelightY, kCostNarrowWidth, kCostNarrowHeight);
            self.pointLabel.frame = CGRectMake(kBalanceNarrowLimelightX,
                                               kBalanceNarrowLimelightY,
                                               kBalanceNarrowLimelightWidth,
                                               kBalanceNarrowHeight);
            self.yesButton.frame = CGRectMake(
                kYesButtonNarrowX, kButtonNarrowY, yesImage.size.width, yesImage.size.height);
            self.noButton.frame = CGRectMake(
                kNoButtonNarrowX, kButtonNarrowY, noImage.size.width, noImage.size.height);
        } else if (theme == RBUserSettingDataThemeColette) {
            self.usePointLabel.frame = CGRectMake(
                kCostNarrowColetteX, kCostNarrowColetteY, kCostNarrowWidth, kCostNarrowHeight);
            self.pointLabel.frame = CGRectMake(kBalanceNarrowColetteX,
                                               kBalanceNarrowColetteY,
                                               kBalanceNarrowColetteWidth,
                                               kBalanceNarrowHeight);
            self.yesButton.frame = CGRectMake(
                kYesButtonNarrowX, kButtonNarrowY, yesImage.size.width, yesImage.size.height);
            self.noButton.frame = CGRectMake(
                kNoButtonNarrowX, kButtonNarrowY, noImage.size.width, noImage.size.height);
        }
    } else {
        RBUserSettingDataTheme theme = [RBUserSettingData sharedInstance].thema;
        if (theme == RBUserSettingDataThemeLimelight) {
            self.usePointLabel.frame = CGRectMake(
                kCostWideLimelightX, kCostWideLimelightY, kCostWideWidth, kCostWideLimelightHeight);
            self.pointLabel.frame = CGRectMake(kBalanceWideLimelightX,
                                               kBalanceWideLimelightY,
                                               kCostWideWidth,
                                               kCostWideLimelightHeight);
            self.yesButton.frame = CGRectMake(
                kYesButtonWideX, kButtonWideLimelightY, yesImage.size.width, yesImage.size.height);
            self.noButton.frame = CGRectMake(
                kNoButtonWideX, kButtonWideLimelightY, noImage.size.width, noImage.size.height);
        } else if (theme == RBUserSettingDataThemeColette) {
            self.usePointLabel.frame = CGRectMake(
                kCostWideColetteX, kCostWideColetteY, kCostWideWidth, kCostWideColetteHeight);
            self.pointLabel.frame = CGRectMake(
                kBalanceWideColetteX, kBalanceWideColetteY, kCostWideWidth, kCostWideColetteHeight);
            self.yesButton.frame = CGRectMake(
                kYesButtonWideX, kButtonWideColetteY, yesImage.size.width, yesImage.size.height);
            self.noButton.frame = CGRectMake(
                kNoButtonWideX, kButtonWideColetteY, noImage.size.width, noImage.size.height);
        }
    }
}

#pragma mark Item

- (void)setItemData:(RBUnlockPackageItemData *)itemData {
    _itemData = itemData;
    __weak RBCustomInfoPopupView *weakSelf = self;

    UIImage *artwork =
        [UIImage imageWithName:BuildCustomizeAssetPathString(itemData.type, itemData.identity)];
    [self.imageView setImage:artwork];
    if (!self.isPad) {
        RBUserSettingDataTheme theme = [RBUserSettingData sharedInstance].thema;
        if (theme == RBUserSettingDataThemeLimelight) {
            self.imageView.frame = CGRectMake(kArtworkNarrowLimelightX,
                                              kArtworkNarrowLimelightY,
                                              artwork.size.width * kArtworkScaleNarrow,
                                              artwork.size.height * kArtworkScaleNarrow);
        } else if (theme == RBUserSettingDataThemeColette) {
            self.imageView.frame = CGRectMake(kArtworkNarrowColetteXY,
                                              kArtworkNarrowColetteXY,
                                              artwork.size.width * kArtworkScaleNarrow,
                                              artwork.size.height * kArtworkScaleNarrow);
        }
    } else {
        RBUserSettingDataTheme theme = [RBUserSettingData sharedInstance].thema;
        if (theme == RBUserSettingDataThemeLimelight) {
            self.imageView.frame = CGRectMake(kArtworkWideLimelightX,
                                              kArtworkWideLimelightY,
                                              artwork.size.width,
                                              artwork.size.height);
        } else if (theme == RBUserSettingDataThemeColette) {
            self.imageView.frame = CGRectMake(kArtworkWideColetteX,
                                              kArtworkWideColetteY,
                                              artwork.size.width,
                                              artwork.size.height);
        }
    }

    self.usePointLabel.number = (float)itemData.point;

    if (itemData.type == kUnlockItemTypeMusic) {
        [weakSelf.imageView setImage:artwork];
        weakSelf.imageDownloader = [[ImageDownloader alloc] initWithGetURL:itemData.path
                                                               unUseRetina:NO];
        int itemType = itemData.type;
        [weakSelf.imageDownloader
            startDownloadWithProceed:^(ImageDownloader *downloader) {
            }
            success:^(ImageDownloader *downloader) {
              /** @ghidraAddress 0x19d584 */
              dispatch_async(dispatch_get_main_queue(), ^{
                /** @ghidraAddress 0x19d658 */
                [weakSelf.frameImageView
                    setImage:[UIImage imageWithName:GetCustomizeFrameImagePath(itemType)]];

                RBUserSettingDataTheme theme = [RBUserSettingData sharedInstance].thema;
                if (!IsPad()) {
                    constexpr CGFloat kFrameInsetNarrow = 4.0;
                    if (theme == RBUserSettingDataThemeLimelight) {
                        weakSelf.imageView.frame = CGRectMake(
                            kArtworkNarrowLimelightX,
                            kArtworkNarrowLimelightY,
                            artwork.size.width * kArtworkScaleNarrow - kFrameInsetNarrow,
                            artwork.size.height * kArtworkScaleNarrow - kFrameInsetNarrow);
                        weakSelf.frameImageView.frame =
                            CGRectMake(kArtworkNarrowLimelightX,
                                       kArtworkNarrowLimelightY,
                                       artwork.size.width * kArtworkScaleNarrow,
                                       artwork.size.height * kArtworkScaleNarrow);
                    } else if (theme == RBUserSettingDataThemeColette) {
                        weakSelf.imageView.frame = CGRectMake(
                            kArtworkNarrowColetteXY,
                            kArtworkNarrowColetteXY,
                            artwork.size.width * kArtworkScaleNarrow - kFrameInsetNarrow,
                            artwork.size.height * kArtworkScaleNarrow - kFrameInsetNarrow);
                        weakSelf.frameImageView.frame =
                            CGRectMake(kArtworkNarrowColetteXY,
                                       kArtworkNarrowColetteXY,
                                       artwork.size.width * kArtworkScaleNarrow,
                                       artwork.size.height * kArtworkScaleNarrow);
                    }
                } else {
                    constexpr CGFloat kFrameInsetWide = 16.0;
                    if (theme == RBUserSettingDataThemeLimelight) {
                        weakSelf.imageView.frame =
                            CGRectMake(kArtworkWideLimelightX,
                                       kArtworkWideLimelightY,
                                       artwork.size.width - kFrameInsetWide,
                                       artwork.size.height - kFrameInsetWide);
                        weakSelf.frameImageView.frame = CGRectMake(kArtworkWideLimelightX,
                                                                   kArtworkWideLimelightY,
                                                                   artwork.size.width,
                                                                   artwork.size.height);
                    } else if (theme == RBUserSettingDataThemeColette) {
                        weakSelf.imageView.frame =
                            CGRectMake(kArtworkWideColetteX,
                                       kArtworkWideColetteY,
                                       artwork.size.width - kFrameInsetWide,
                                       artwork.size.height - kFrameInsetWide);
                        weakSelf.frameImageView.frame = CGRectMake(kArtworkWideColetteX,
                                                                   kArtworkWideColetteY,
                                                                   artwork.size.width,
                                                                   artwork.size.height);
                    }
                }

                [weakSelf.imageView setImage:weakSelf.imageDownloader.getImage];
                weakSelf.frameImageView.hidden = NO;
                [weakSelf.imageDownloader cancelDownload];
              });
            }
            failure:^(ImageDownloader *downloader) {
              /** @ghidraAddress 0x19de44 */
              [weakSelf.imageDownloader cancelDownload];
            }];
    }
}

#pragma mark Animation

- (void)showAnimation {
    if (self.animating) {
        return;
    }
    SoundEffectManager::GetInstance()->PlayThemedSoundEffect(kSoundEffectPopupOpen);
    self.animating = YES;
    [UIView animateWithDuration:kFadeAnimationDuration
        animations:^{
          /** @ghidraAddress 0x19dfe4 */
          self.alpha = 1.0;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x19e008 */
          self.alpha = 1.0;
          self.animating = NO;
        }];
}

- (void)hideAnimation {
    if (self.animating) {
        return;
    }
    self.animating = YES;
    [UIView animateWithDuration:kFadeAnimationDuration
        animations:^{
          /** @ghidraAddress 0x19e158 */
          self.alpha = 0.0;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x19e17c */
          self.alpha = 0.0;
          [self removeFromSuperview];
          self.animating = NO;
        }];
}

- (void)tap:(id)sender {
    [self hideAnimation];
}

@end
