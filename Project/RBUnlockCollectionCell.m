#import "RBUnlockCollectionCell.h"

#import "ImageDownloader.h"
#import "RBNumberLabel.h"
#import "RBUnlockPackageItemData.h"
#import "UIImage+RB.h"
#import "UIView+RB.h"
#import "deviceenvironment.h"
#import "engineruntime.h"

static NSString *const kBadgeImageName = @"04_customize/cus_restore_badge";
static NSString *const kUnlockDisplayImageName = @"04_customize/cus_unlock_display";

static const int kUnlockItemTypeMusic = 7;

static const RBNumberLabelImageType kPointLabelImageType = RBNumberLabelImageTypeLime;

// @ghidraAddress 0x2ec708 (g_dRBWebViewGrayViewWhite)
static const CGFloat kDisableOverlayAlpha = 0.6;
static const CGFloat kDisableOverlayCornerRadius = 3.0;

// @ghidraAddress 0x2eea20 (g_dCustomizeArtworkNarrowSize)
// @ghidraAddress 0x2eea00 (g_dCustomizeArtworkWideLimelightX)
static const CGFloat kArtworkSizeNarrow = 62.0;
static const CGFloat kArtworkSizeWide = 68.0;

// @ghidraAddress 0x301068 (g_dCustomizeDownloadedArtworkSize)
static const CGFloat kDownloadedArtworkSize = 52.0;

static const CGFloat kDownloadedArtworkInsetNarrow = 6.0;
static const CGFloat kDownloadedArtworkInsetWide = 8.0;

static const CGFloat kDisableOverlayInset = 3.0;
static const CGFloat kDisableOverlayMargin = 6.0;

static const CGFloat kPointLabelHeight = 14.0;

static const CGFloat kBadgeCenterFactor = 0.5;

static const CGFloat kCenterFactor = 0.5;

@implementation RBUnlockCollectionCell

#pragma mark Lifecycle

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundView = [[UIView alloc] initWithFrame:frame];

        self.imageView = [[UIImageView alloc] init];
        [self.backgroundView addSubview:self.imageView];

        self.frameImageView = [[UIImageView alloc] init];
        self.frameImageView.hidden = YES;
        [self.backgroundView addSubview:self.frameImageView];

        self.disableView = [[UIView alloc] init];
        self.disableView.backgroundColor = UIColor.blackColor;
        self.disableView.layer.cornerRadius = kDisableOverlayCornerRadius;
        self.disableView.alpha = 0.0;
        [self.backgroundView addSubview:self.disableView];

        self.pointLabel = [[RBNumberLabel alloc] init];
        self.pointLabel.imageType = kPointLabelImageType;
        [self.backgroundView addSubview:self.pointLabel];

        UIImage *badgeImage = [UIImage imageWithName:kBadgeImageName];
        self.badgeView = [[UIImageView alloc] initWithImage:badgeImage];
        self.badgeView.center = CGPointMake(self.backgroundView.right, 0.0);
        self.badgeView.hidden = YES;
        [self.backgroundView addSubview:self.badgeView];

        UIImage *unlockImage = [UIImage imageWithName:kUnlockDisplayImageName];
        self.unlockView = [[UIImageView alloc] initWithImage:unlockImage];
        self.unlockView.center = self.pointLabel.center;
        self.unlockView.hidden = YES;
        [self.backgroundView addSubview:self.unlockView];

        self.enabled = YES;
        self.exclusiveTouch = YES;
    }
    return self;
}

#pragma mark Layout

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat cellWidth = self.frame.size.width;
    CGFloat frameWidth = self.frameImageView.frame.size.width;
    CGFloat frameHeight = self.frameImageView.frame.size.height;

    self.frameImageView.frame =
        CGRectMake((int)((cellWidth - frameWidth) * kCenterFactor), 0.0, frameWidth, frameHeight);

    CGFloat imageWidth = self.imageView.frame.size.width;
    CGFloat imageHeight = self.imageView.frame.size.height;
    self.imageView.frame = CGRectMake((int)((cellWidth - imageWidth) * kCenterFactor),
                                      (int)((frameHeight - imageHeight) * kCenterFactor),
                                      imageWidth,
                                      imageHeight);

    self.disableView.frame =
        CGRectMake((int)((cellWidth - frameWidth) * kCenterFactor) + kDisableOverlayInset,
                   (int)((frameHeight - frameWidth) * kCenterFactor) + kDisableOverlayInset,
                   frameWidth - kDisableOverlayMargin,
                   frameHeight - kDisableOverlayMargin);

    self.pointLabel.frame = CGRectMake(
        0.0, self.frameImageView.bottom, self.backgroundView.frame.size.width, kPointLabelHeight);

    self.unlockView.center = self.pointLabel.center;

    CGFloat badgeWidth = self.badgeView.frame.size.width;
    CGFloat badgeHeight = self.badgeView.frame.size.height;
    self.badgeView.frame = CGRectMake(
        self.imageView.right - badgeWidth * kBadgeCenterFactor, 0.0, badgeWidth, badgeHeight);
}

#pragma mark Reuse

- (void)prepareForReuse {
    [super prepareForReuse];
    self.enabled = YES;
    self.pointLabel.hidden = NO;
    self.imageView.image = nil;
    self.unlockView.hidden = YES;
}

#pragma mark State

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    if (self.enabled) {
        self.disableView.alpha = highlighted ? kDisableOverlayAlpha : 0.0;
    }
}

- (void)setEnabled:(BOOL)enabled {
    _enabled = enabled;
    self.disableView.alpha = enabled ? 0.0 : kDisableOverlayAlpha;
    self.userInteractionEnabled = enabled;
}

#pragma mark Item data

- (void)setItemData:(RBUnlockPackageItemData *)itemData {
    _itemData = itemData;

    __weak typeof(self) weakSelf = self;

    NSString *iconName = BuildCustomizeAssetPathString(itemData.type, itemData.identity);

    CGFloat artworkSize = (!IsPad()) ? kArtworkSizeNarrow : kArtworkSizeWide;
    self.imageView.frame = CGRectMake(0.0, 0.0, artworkSize, artworkSize);
    CGFloat frameSize = (!IsPad()) ? kArtworkSizeNarrow : kArtworkSizeWide;
    self.frameImageView.frame = CGRectMake(0.0, 0.0, frameSize, frameSize);

    self.pointLabel.number = (float)itemData.point;

    dispatch_async(dispatch_get_global_queue(0, 0), ^{
      /** @ghidraAddress 0x1906e4 */
      UIImage *iconImage = [UIImage imageWithName:iconName];
      dispatch_async(dispatch_get_main_queue(), ^{
        /** @ghidraAddress 0x1907c0 */
        RBUnlockCollectionCell *cell = weakSelf;
        if (itemData.type == kUnlockItemTypeMusic) {
            cell.imageView.image = iconImage;
            cell.imageDownloader = [[ImageDownloader alloc] initWithGetURL:itemData.path
                                                               unUseRetina:NO];
            [cell.imageDownloader
                startDownloadWithProceed:^(ImageDownloader *downloader) {
                }
                success:^(ImageDownloader *downloader) {
                  /** @ghidraAddress 0x190ac8 */
                  RBUnlockCollectionCell *strongCell = weakSelf;
                  strongCell.imageView.image = [strongCell.imageDownloader getImage];

                  CGFloat cellWidth = strongCell.frame.size.width;
                  CGFloat coverWidth = strongCell.imageView.frame.size.width;
                  CGFloat inset =
                      (!IsPad()) ? kDownloadedArtworkInsetNarrow : kDownloadedArtworkInsetWide;
                  strongCell.imageView.frame =
                      CGRectMake((int)((cellWidth - coverWidth) * kCenterFactor) + inset,
                                 inset,
                                 kDownloadedArtworkSize,
                                 kDownloadedArtworkSize);

                  strongCell.frameImageView.image =
                      [UIImage imageWithName:GetCustomizeFrameImagePath(itemData.type)];
                  strongCell.frameImageView.hidden = NO;
                  [strongCell.imageDownloader cancelDownload];
                }
                failure:^(ImageDownloader *downloader) {
                  /** @ghidraAddress 0x190fcc */
                  [weakSelf.imageDownloader cancelDownload];
                }];
        } else {
            cell.imageView.image = iconImage;
        }
      });
    });
}

@end
