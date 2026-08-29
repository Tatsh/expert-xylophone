#import "StoreExtendNoteCellPhone.h"

#import "StoreExtendNoteInfo.h"
#import "StoreUtil.h"
#import "UIImage+RB.h"
#import "engineglobals.h"

extern const double g_dLayoutMetricThirtyTwo; // @ghidraAddress 0x2ee9b0 (32.0)

static NSString *const kStoreNewBadgeImageName = @"09_store/store_new";

static NSString *const kStoreEmptyTitle = @""; // @ghidraAddress 0x3cfd10

static NSString *const kLevelLabelFormat = @"LEVEL %d"; // @ghidraAddress 0x362b20

static const CGFloat kJacketLayerLeft = 10.0;
static const CGFloat kJacketLayerTop = 8.0;
static const CGFloat kJacketLayerSize = 64.0;
static const CGFloat kJacketShadowOffset = 1.0;
static const CGFloat kJacketShadowOpacity = 0.6;
static const CGFloat kJacketShadowRadius = 2.0;

static const CGFloat kTextColumnLeft = 85.0;

static const CGFloat kNameLabelTop = 10.0;
static const CGFloat kNameLabelWidthInset = 70.0;
static const CGFloat kNameLabelHeight = 20.0;
static const CGFloat kNameLabelFontSize = 16.0;
static const CGFloat kNameLabelMinimumScaleFactor = 13.0;
static const CGFloat kNameLabelMinimumScaleFactorSecond = 12.0;

static const CGFloat kArtistLabelTop = 32.0;
static const CGFloat kArtistLabelWidthInset = 76.0;
static const CGFloat kArtistLabelHeight = 18.0;
static const CGFloat kArtistLabelFontSize = 14.0;

static const CGFloat kLowerRowTop = 54.0;
static const CGFloat kLowerRowHeight = 18.0;

static const CGFloat kLevelLabelWidth = 80.0;
static const CGFloat kLevelLabelFontSize = 13.0;

static const CGFloat kPurchasedLabelWidthInset = 110.0;
static const CGFloat kPurchasedLabelFontSize = 13.0;

static const CGFloat kSecondaryTextWhite = 0.3; // @ghidraAddress 0x2ec718
static const CGFloat kPurchasedTextWhite = 0.4;

static const StoreExtendNoteButtonState kFirstDownloadedButtonState =
    StoreExtendNoteButtonStateDownloadBin;
static const unsigned int kDownloadedButtonStateCount = 3;

static const UIViewAutoresizing kBackgroundAutoresizing =
    UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
static const UIViewAutoresizing kNameLabelAutoresizing = UIViewAutoresizingFlexibleWidth;
static const UIViewAutoresizing kPurchasedLabelAutoresizing = UIViewAutoresizingFlexibleLeftMargin;

@implementation StoreExtendNoteCellPhone

// The comment label is in the class metadata but has no backing ivar or accessors in the binary.
@dynamic commentLabel;

/** @ghidraAddress 0x1c0abc */
- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

        self.bgImageView = [[UIImageView alloc] initWithFrame:self.bounds];
        self.backgroundView = self.bgImageView;
        self.backgroundView.autoresizingMask = kBackgroundAutoresizing;

        CGRect contentFrame = self.contentView.frame;
        CGFloat contentWidth = contentFrame.size.width;

        self.artworkLayer = [CALayer layer];
        self.artworkLayer.frame =
            CGRectMake(kJacketLayerLeft, kJacketLayerTop, kJacketLayerSize, kJacketLayerSize);
        self.artworkLayer.shadowOffset = CGSizeMake(kJacketShadowOffset, kJacketShadowOffset);
        self.artworkLayer.shadowColor = UIColor.blackColor.CGColor;
        self.artworkLayer.shadowOpacity = kJacketShadowOpacity;
        self.artworkLayer.shadowRadius = kJacketShadowRadius;
        self.artworkLayer.shadowPath =
            [UIBezierPath bezierPathWithRect:self.artworkLayer.bounds].CGPath;

        self.nameLabel =
            [[UILabel alloc] initWithFrame:CGRectMake(kTextColumnLeft,
                                                      kNameLabelTop,
                                                      contentWidth - kNameLabelWidthInset,
                                                      kNameLabelHeight)];
        self.nameLabel.highlightedTextColor = UIColor.whiteColor;
        self.nameLabel.font = [UIFont boldSystemFontOfSize:kNameLabelFontSize];
        self.nameLabel.autoresizingMask = kNameLabelAutoresizing;
        self.nameLabel.adjustsFontSizeToFitWidth = YES;
        // Out of range, but the binary passes 13.0 here.
        self.nameLabel.minimumScaleFactor = kNameLabelMinimumScaleFactor;

        self.artistLabel =
            [[UILabel alloc] initWithFrame:CGRectMake(kTextColumnLeft,
                                                      g_dLayoutMetricThirtyTwo,
                                                      contentWidth - kArtistLabelWidthInset,
                                                      kArtistLabelHeight)];
        self.artistLabel.highlightedTextColor = UIColor.whiteColor;
        self.artistLabel.font = [UIFont boldSystemFontOfSize:kArtistLabelFontSize];
        self.artistLabel.textColor = [UIColor colorWithWhite:g_dAudioManagerResumeFadeInTime
                                                       alpha:1.0];
        self.artistLabel.autoresizingMask = kNameLabelAutoresizing;
        self.artistLabel.adjustsFontSizeToFitWidth = YES;
        // Yes, the binary re-targets the name label from the artist label's setup.
        self.nameLabel.minimumScaleFactor = kNameLabelMinimumScaleFactorSecond;

        self.levelLabel = [[UILabel alloc]
            initWithFrame:CGRectMake(
                              kTextColumnLeft, kLowerRowTop, kLevelLabelWidth, kLowerRowHeight)];
        self.levelLabel.textColor = [UIColor colorWithWhite:kSecondaryTextWhite alpha:1.0];
        self.levelLabel.highlightedTextColor = UIColor.whiteColor;
        self.levelLabel.font = [UIFont boldSystemFontOfSize:kLevelLabelFontSize];

        self.purchasedLabel =
            [[UILabel alloc] initWithFrame:CGRectMake(contentWidth - kPurchasedLabelWidthInset,
                                                      kLowerRowTop,
                                                      g_dCustomizeLayoutMetric100,
                                                      kLowerRowHeight)];
        self.purchasedLabel.autoresizingMask = kPurchasedLabelAutoresizing;
        self.purchasedLabel.textColor = [UIColor colorWithWhite:kPurchasedTextWhite alpha:1.0];
        self.purchasedLabel.highlightedTextColor = UIColor.whiteColor;
        self.purchasedLabel.font = [UIFont boldSystemFontOfSize:kPurchasedLabelFontSize];
        self.purchasedLabel.textAlignment = NSTextAlignmentRight;
        self.purchasedLabel.text = kStoreEmptyTitle;

        UIImage *newBadge = [UIImage imageWithName:kStoreNewBadgeImageName];
        self.iconNewLayer = [CALayer layer];
        self.iconNewLayer.frame = CGRectMake(0.0, 0.0, newBadge.size.width, newBadge.size.height);
        self.iconNewLayer.contents = (__bridge id)newBadge.CGImage;

        [self.contentView.layer addSublayer:self.artworkLayer];
        [self.contentView.layer addSublayer:self.iconNewLayer];
        [self.contentView addSubview:self.nameLabel];
        [self.contentView addSubview:self.artistLabel];
        [self.contentView addSubview:self.levelLabel];
        [self.contentView addSubview:self.purchasedLabel];
    }
    return self;
}

/** @ghidraAddress 0x1c1b78 */
- (BOOL)isPurchased {
    return !self.purchasedLabel.isHidden;
}

/** @ghidraAddress 0x1c1bd8 */
- (void)setIsPurchased:(BOOL)isPurchased {
    self.purchasedLabel.hidden = !isPurchased;
}

/** @ghidraAddress 0x1c1fa0 */
- (void)setBgImage:(UIImage *)bgImage {
    self.bgImageView.image = bgImage;
}

/** @ghidraAddress 0x1c202c */
- (void)setBgColor:(UIColor *)bgColor {
    // The phone cell ignores the tint colour; it exists only for parity with the pad layout.
}

/** @ghidraAddress 0x1c1c34 */
- (void)loadExtendNoteInfo:(StoreExtendNoteInfo *)loadExtendNoteInfo index:(NSUInteger)index {
    self.nameLabel.text = loadExtendNoteInfo.name;
    self.artistLabel.text = loadExtendNoteInfo.artist;
    self.levelLabel.text =
        [NSString stringWithFormat:kLevelLabelFormat, loadExtendNoteInfo.difficulty];
    self.iconNewLayer.hidden = !loadExtendNoteInfo.isNew;
    self.purchasedLabel.hidden = NO;

    // The comparisons are unsigned, so the error state (-1) falls through both arms and leaves
    // the label as it was.
    unsigned int state = (unsigned int)loadExtendNoteInfo.getButtonState;
    if (state - (unsigned int)kFirstDownloadedButtonState < kDownloadedButtonStateCount) {
        self.purchasedLabel.text = kStoreEmptyTitle;
    } else if (state < (unsigned int)kFirstDownloadedButtonState) {
#ifdef ENABLE_PATCHES
        self.purchasedLabel.text = RBStoreExtendNotePriceString(loadExtendNoteInfo);
#else
        self.purchasedLabel.text = [StoreUtil priceString:loadExtendNoteInfo.product];
#endif
    }
}

@end
