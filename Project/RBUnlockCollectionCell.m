//
//  RBUnlockCollectionCell.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RBUnlockCollectionCell). The
//  soft-float subview geometry of -layoutSubviews and -setItemData:, and the idiom-dependent
//  sizing in the asynchronous artwork-loading blocks, were recovered from the arm64 disassembly,
//  where the decompiler folds the floating-point register moves into pseudo-variables.
//

#import "RBUnlockCollectionCell.h"

#import "ImageDownloader.h"
#import "RBNumberLabel.h"
#import "RBUnlockPackageItemData.h"
#import "UIImage+RB.h"
#import "UIView+RB.h"
#import "neEngineBridge.h"

// The restore/"new" badge and the unlocked-state overlay artwork bundled with the app.
static NSString *const kBadgeImageName = @"04_customize/cus_restore_badge";
static NSString *const kUnlockDisplayImageName = @"04_customize/cus_unlock_display";

// The item type granted to a downloadable music cover; only this type fetches its artwork remotely.
enum {
    kUnlockItemTypeMusic = 7,
};

// The point label is drawn with the lime digit-glyph style.
static const RBNumberLabelImageType kPointLabelImageType = RBNumberLabelImageTypeLime;

// The dimming overlay is a black rounded rectangle faded to this alpha while the cell is
// non-interactive; an enabled cell dims to the same value only while it is pressed.
// @ghidraAddress 0x2ec708 (g_dRBWebViewGrayViewWhite)
static const CGFloat kDisableOverlayAlpha = 0.6;
static const CGFloat kDisableOverlayCornerRadius = 3.0;

// The square artwork side lengths, chosen by device idiom.
// @ghidraAddress 0x2eea20 (g_dCustomizeArtworkNarrowSize)
// @ghidraAddress 0x2eea00 (g_dCustomizeArtworkWideLimelightX)
static const CGFloat kArtworkSizeNarrow = 62.0;
static const CGFloat kArtworkSizeWide = 68.0;

// The square artwork side length once a downloaded music cover has been applied.
// @ghidraAddress 0x301068 (g_dCustomizeDownloadedArtworkSize)
static const CGFloat kDownloadedArtworkSize = 52.0;

// The downloaded music cover is inset from the top-left of the framed backdrop by these
// idiom-dependent offsets.
static const CGFloat kDownloadedArtworkInsetNarrow = 6.0;
static const CGFloat kDownloadedArtworkInsetWide = 8.0;

// The dimming overlay is inset from the frame image by this margin on every side.
static const CGFloat kDisableOverlayInset = 3.0;
static const CGFloat kDisableOverlayMargin = 6.0;

// The point label spans the framed backdrop at this fixed height, just below the frame image.
static const CGFloat kPointLabelHeight = 14.0;

// The badge sits centred on the artwork's right edge.
static const CGFloat kBadgeCentreFactor = 0.5;

// Each subview is centred by halving the surrounding gap; the offset is truncated to a whole point.
static const CGFloat kCentreFactor = 0.5;

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
        self.disableView.backgroundColor = [UIColor blackColor];
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

    // Centre the frame image horizontally at the top of the cell, keeping its own size.
    self.frameImageView.frame =
        CGRectMake((int)((cellWidth - frameWidth) * kCentreFactor), 0.0, frameWidth, frameHeight);

    // Centre the artwork within the frame image.
    CGFloat imageWidth = self.imageView.frame.size.width;
    CGFloat imageHeight = self.imageView.frame.size.height;
    self.imageView.frame = CGRectMake((int)((cellWidth - imageWidth) * kCentreFactor),
                                      (int)((frameHeight - imageHeight) * kCentreFactor),
                                      imageWidth,
                                      imageHeight);

    // Inset the dimming overlay inside the frame image.
    self.disableView.frame =
        CGRectMake((int)((cellWidth - frameWidth) * kCentreFactor) + kDisableOverlayInset,
                   (int)((frameHeight - frameWidth) * kCentreFactor) + kDisableOverlayInset,
                   frameWidth - kDisableOverlayMargin,
                   frameHeight - kDisableOverlayMargin);

    // The point label spans the framed backdrop just below the frame image.
    self.pointLabel.frame = CGRectMake(
        0.0, self.frameImageView.bottom, self.backgroundView.frame.size.width, kPointLabelHeight);

    // The unlock overlay sits over the point label.
    self.unlockView.center = self.pointLabel.center;

    // The badge sits centred on the artwork's right edge.
    CGFloat badgeWidth = self.badgeView.frame.size.width;
    CGFloat badgeHeight = self.badgeView.frame.size.height;
    self.badgeView.frame = CGRectMake(
        self.imageView.right - badgeWidth * kBadgeCentreFactor, 0.0, badgeWidth, badgeHeight);
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

    // The artwork asset path for the item's type and variant; loaded asynchronously below.
    NSString *iconName = BuildCustomizeAssetPathString(itemData.type, itemData.identity);

    // Size the artwork and frame views as squares chosen by device idiom.
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
            // Show the placeholder artwork immediately, then download the real cover.
            cell.imageView.image = iconImage;
            cell.imageDownloader = [[ImageDownloader alloc] initWithGetURL:itemData.path
                                                               unUseRetina:NO];
            [cell.imageDownloader
                startDownloadWithProceed:^{
                  // No-op progress callback.
                }
                success:^{
                  /** @ghidraAddress 0x190ac8 */
                  RBUnlockCollectionCell *strongCell = weakSelf;
                  strongCell.imageView.image = [strongCell.imageDownloader getImage];

                  // Centre the downloaded cover within the cell, inset by device idiom.
                  CGFloat cellWidth = strongCell.frame.size.width;
                  CGFloat coverWidth = strongCell.imageView.frame.size.width;
                  CGFloat inset =
                      (!IsPad()) ? kDownloadedArtworkInsetNarrow : kDownloadedArtworkInsetWide;
                  strongCell.imageView.frame =
                      CGRectMake((int)((cellWidth - coverWidth) * kCentreFactor) + inset,
                                 inset,
                                 kDownloadedArtworkSize,
                                 kDownloadedArtworkSize);

                  // Apply the item's variant-specific frame overlay and reveal it.
                  strongCell.frameImageView.image =
                      [UIImage imageWithName:GetCustomizeFrameImagePath(itemData.type)];
                  strongCell.frameImageView.hidden = NO;
                  [strongCell.imageDownloader cancelDownload];
                }
                failure:^{
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
