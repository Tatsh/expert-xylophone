#import "StorePackCell.h"

#import "RBPurchaseManager.h"
#import "StorePackInfo.h"
#import "StoreUtil.h"
#import "UIImage+RB.h"
#import "neEngineBridge.h"

// A shared layout metric of 60 points, reached by its Ghidra address as the other reconstructed
// views (for example RBSearchMapView) do. The 100-point metric and the 0.3-second short fade come
// from the engine bridge header instead.
extern const double g_dLayoutMetricSixty; // @ghidraAddress 0x2ee948 (60.0)

// Store badge asset names used by the cell.
static NSString *const kStoreNewBadgeImageName = @"09_store/store_new";
static NSString *const kStoreSequenceBadgeImageName = @"09_store/store_sp";

// The owned-state label carries an empty title: it is the shared store-layer empty-string global.
static NSString *const kStoreEmptyTitle = @""; // @ghidraAddress 0x3cfd10

// The jacket layer is a fixed 64-point square inset 10 points from the left and 8 from the top,
// drawn with a soft rasterised drop shadow.
static const CGFloat kJacketLayerLeft = 10.0;
static const CGFloat kJacketLayerTop = 8.0;
static const CGFloat kJacketLayerSize = 64.0;
static const CGFloat kJacketShadowOffset = 1.0;
static const CGFloat kJacketShadowOpacity = 0.6;
static const CGFloat kJacketShadowRadius = 2.0;

// The text column starts 85 points from the left; the name label runs to 90 points shy of the
// content width, the price label is a fixed 60-point column, and the owned-state label is a fixed
// 100-point column pinned 110 points in from the right.
static const CGFloat kTextColumnLeft = 85.0;
static const CGFloat kNameLabelTop = 10.0;
static const CGFloat kNameLabelWidthInset = 90.0;
static const CGFloat kNameLabelHeight = 20.0;
static const CGFloat kNameLabelFontSize = 16.0;
static const CGFloat kNameLabelMinimumScaleFactor = 13.0;

static const CGFloat kPriceLabelTop = 54.0;
static const CGFloat kPriceLabelHeight = 18.0;
static const CGFloat kPriceLabelFontSize = 14.0;
static const CGFloat kPriceLabelWhite = 0.3;

static const CGFloat kPurchasedLabelWidthInset = 110.0;
static const CGFloat kPurchasedLabelFontSize = 13.0;
static const CGFloat kPurchasedLabelWhite = 0.4;

// The background view and the owned-state label track the cell's right and bottom edges.
static const UIViewAutoresizing kBackgroundAutoresizing =
    UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
static const UIViewAutoresizing kNameLabelAutoresizing = UIViewAutoresizingFlexibleWidth;
static const UIViewAutoresizing kPurchasedLabelAutoresizing = UIViewAutoresizingFlexibleLeftMargin;
static const UIViewAutoresizing kIconSpAutoresizing =
    UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin;

@implementation StorePackCell

/** @ghidraAddress 0xf4488 */
- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

        self.bgView = [[UIImageView alloc] initWithFrame:self.bounds];
        self.backgroundView = self.bgView;
        self.backgroundView.autoresizingMask = kBackgroundAutoresizing;

        CGRect contentFrame = self.contentView.frame;
        CGFloat contentWidth = contentFrame.size.width;
        CGFloat contentHeight = contentFrame.size.height;

        self.artworkView = [CALayer layer];
        self.artworkView.frame =
            CGRectMake(kJacketLayerLeft, kJacketLayerTop, kJacketLayerSize, kJacketLayerSize);
        self.artworkView.shadowOffset = CGSizeMake(kJacketShadowOffset, kJacketShadowOffset);
        self.artworkView.shadowColor = UIColor.blackColor.CGColor;
        self.artworkView.shadowOpacity = kJacketShadowOpacity;
        self.artworkView.shadowRadius = kJacketShadowRadius;
        self.artworkView.shadowPath =
            [UIBezierPath bezierPathWithRect:self.artworkView.bounds].CGPath;

        self.labelName =
            [[UILabel alloc] initWithFrame:CGRectMake(kTextColumnLeft,
                                                      kNameLabelTop,
                                                      contentWidth - kNameLabelWidthInset,
                                                      kNameLabelHeight)];
        self.labelName.highlightedTextColor = UIColor.whiteColor;
        self.labelName.font = [UIFont boldSystemFontOfSize:kNameLabelFontSize];
        self.labelName.autoresizingMask = kNameLabelAutoresizing;
        self.labelName.adjustsFontSizeToFitWidth = YES;
        // The binary passes 13.0 here, an out-of-range minimum scale factor; reproduced verbatim.
        self.labelName.minimumScaleFactor = kNameLabelMinimumScaleFactor;

        self.labelPrice = [[UILabel alloc] initWithFrame:CGRectMake(kTextColumnLeft,
                                                                    kPriceLabelTop,
                                                                    g_dLayoutMetricSixty,
                                                                    kPriceLabelHeight)];
        self.labelPrice.textColor = [UIColor colorWithWhite:kPriceLabelWhite alpha:1.0];
        self.labelPrice.highlightedTextColor = UIColor.whiteColor;
        self.labelPrice.font = [UIFont boldSystemFontOfSize:kPriceLabelFontSize];

        self.labelPurchased =
            [[UILabel alloc] initWithFrame:CGRectMake(contentWidth - kPurchasedLabelWidthInset,
                                                      kPriceLabelTop,
                                                      g_dCustomizeLayoutMetric100,
                                                      kPriceLabelHeight)];
        self.labelPurchased.autoresizingMask = kPurchasedLabelAutoresizing;
        self.labelPurchased.textColor = [UIColor colorWithWhite:kPurchasedLabelWhite alpha:1.0];
        self.labelPurchased.highlightedTextColor = UIColor.whiteColor;
        self.labelPurchased.font = [UIFont boldSystemFontOfSize:kPurchasedLabelFontSize];
        self.labelPurchased.textAlignment = NSTextAlignmentRight;
        self.labelPurchased.text = kStoreEmptyTitle;

        UIImage *newBadge = [UIImage imageWithName:kStoreNewBadgeImageName];
        self.iconNew = [CALayer layer];
        self.iconNew.frame = CGRectMake(0.0, 0.0, newBadge.size.width, newBadge.size.height);
        self.iconNew.contents = (__bridge id)newBadge.CGImage;

        UIImage *sequenceBadge = [UIImage imageWithName:kStoreSequenceBadgeImageName];
        self.iconSp = [[UIImageView alloc] initWithImage:sequenceBadge];
        self.iconSp.frame = CGRectMake(0.0,
                                       contentHeight - self.iconSp.frame.size.height,
                                       self.iconSp.frame.size.width,
                                       self.iconSp.frame.size.height);
        self.iconSp.autoresizingMask = kIconSpAutoresizing;

        [self.contentView.layer addSublayer:self.artworkView];
        [self.contentView.layer addSublayer:self.iconNew];
        [self.contentView addSubview:self.iconSp];
        [self.contentView addSubview:self.labelName];
        [self.contentView addSubview:self.labelPrice];
        [self.contentView addSubview:self.labelPurchased];
    }
    return self;
}

/** @ghidraAddress 0xf5528 */
- (BOOL)isPurchased {
    return !self.labelPurchased.isHidden;
}

/** @ghidraAddress 0xf5588 */
- (void)setPurchased:(BOOL)purchased {
    self.labelPurchased.hidden = !purchased;
}

/** @ghidraAddress 0xf5898 */
- (void)setBgImage:(UIImage *)bgImage {
    self.bgView.image = bgImage;
}

/** @ghidraAddress 0xf5924 */
- (void)setBgColor:(UIColor *)bgColor {
    self.labelName.backgroundColor = bgColor;
    self.labelPrice.backgroundColor = bgColor;
    self.labelPurchased.backgroundColor = bgColor;
}

/** @ghidraAddress 0xf55e4 */
- (void)loadPackInfo:(StorePackInfo *)loadPackInfo {
    self.labelName.text = loadPackInfo.packName;
    self.labelPrice.text = loadPackInfo.priceString;
    self.iconNew.hidden = !loadPackInfo.isNew;
    self.iconSp.hidden = (loadPackInfo.extCount == 0);

    NSString *productID = [StoreUtil productIDForPackID:loadPackInfo.packID];
    if ([[RBPurchaseManager sharedManager] isPurchased:productID]) {
        self.labelPurchased.hidden = NO;
    } else {
        self.labelPurchased.hidden = YES;
    }
}

@end
