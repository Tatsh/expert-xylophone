#import "StoreExtendNoteCellPhone.h"

#import "StoreExtendNoteInfo.h"
#import "StoreUtil.h"
#import "UIImage+RB.h"
#import "neEngineBridge.h"

// A shared layout metric of 32 points, reached by its Ghidra address as the other reconstructed
// views (for example RBSearchMapView and StorePackView) do. The 100-point metric and the 0.3
// white value (shared with the short UI fade) come from the engine bridge header instead.
extern const double g_dLayoutMetricThirtyTwo; // @ghidraAddress 0x2ee9b0 (32.0)

// Store badge asset name used by the cell.
static NSString *const kStoreNewBadgeImageName = @"09_store/store_new";

// The purchased label carries an empty title while the item is installed: it is the shared
// store-layer empty-string global.
static NSString *const kStoreEmptyTitle = @""; // @ghidraAddress 0x3cfd10

// The level label shows the extend note's difficulty as a formatted line.
static NSString *const kLevelLabelFormat = @"LEVEL %d"; // @ghidraAddress 0x362b20

// The jacket layer is a fixed 64-point square inset 10 points from the left and 8 from the top,
// drawn with a soft rasterised drop shadow.
static const CGFloat kJacketLayerLeft = 10.0;
static const CGFloat kJacketLayerTop = 8.0;
static const CGFloat kJacketLayerSize = 64.0;
static const CGFloat kJacketShadowOffset = 1.0;
static const CGFloat kJacketShadowOpacity = 0.6;
static const CGFloat kJacketShadowRadius = 2.0;

// The text column starts 85 points from the left. The name label runs to 70 points shy of the
// content width, the artist label to 76 points shy, the level label is a fixed 80-point column,
// and the purchased label is a fixed 100-point column pinned 110 points in from the right.
static const CGFloat kTextColumnLeft = 85.0;

static const CGFloat kNameLabelTop = 10.0;
static const CGFloat kNameLabelWidthInset = 70.0;
static const CGFloat kNameLabelHeight = 20.0;
static const CGFloat kNameLabelFontSize = 16.0;
static const CGFloat kNameLabelMinimumScaleFactor = 13.0;
// The binary sets the name label's minimum scale factor a second time, from the artist label's
// setup block, to a smaller value; reproduced verbatim.
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

// The secondary-text labels are drawn in a mid grey; the purchased label uses a slightly lighter
// grey.
static const CGFloat kSecondaryTextWhite = 0.3; // g_dAudioManagerResumeFadeInTime (0x2ec718)
static const CGFloat kPurchasedTextWhite = 0.4;

// The lowest extend-note button state at which the tune archive is already downloaded, so the
// purchased label is blanked rather than showing a price.
static const StoreExtendNoteButtonState kFirstDownloadedButtonState =
    StoreExtendNoteButtonStateDownloadBin;
// The three contiguous states from @c kFirstDownloadedButtonState onward (download-archive,
// download-note, and installed) at which the purchased label is blanked.
static const unsigned int kDownloadedButtonStateCount = 3;

static const UIViewAutoresizing kBackgroundAutoresizing =
    UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
static const UIViewAutoresizing kNameLabelAutoresizing = UIViewAutoresizingFlexibleWidth;
static const UIViewAutoresizing kPurchasedLabelAutoresizing = UIViewAutoresizingFlexibleLeftMargin;

@implementation StoreExtendNoteCellPhone

// The comment label appears in the class metadata but has no backing ivar or accessors in the
// binary, so it stays dynamic.
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
        // The binary passes 13.0 here, an out-of-range minimum scale factor; reproduced verbatim.
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
        // The binary re-targets the name label here, lowering its minimum scale factor a second
        // time; reproduced verbatim.
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
    // The phone cell ignores the tint colour; the method exists only for call-site parity with
    // the pad layout.
}

/** @ghidraAddress 0x1c1c34 */
- (void)loadExtendNoteInfo:(StoreExtendNoteInfo *)loadExtendNoteInfo index:(NSInteger)index {
    self.nameLabel.text = loadExtendNoteInfo.name;
    self.artistLabel.text = loadExtendNoteInfo.artist;
    self.levelLabel.text =
        [NSString stringWithFormat:kLevelLabelFormat, loadExtendNoteInfo.difficulty];
    self.iconNewLayer.hidden = !loadExtendNoteInfo.isNew;
    self.purchasedLabel.hidden = NO;

    // The binary switches on the button state with unsigned comparisons, so the error state
    // (-1, which is a large unsigned value) falls through both arms and leaves the label as-is:
    // the archive-present states (download or installed) blank the label, and the still-
    // purchasable states (more-info or purchase) show a price.
    unsigned int state = (unsigned int)loadExtendNoteInfo.getButtonState;
    if (state - (unsigned int)kFirstDownloadedButtonState < kDownloadedButtonStateCount) {
        self.purchasedLabel.text = kStoreEmptyTitle;
    } else if (state < (unsigned int)kFirstDownloadedButtonState) {
        self.purchasedLabel.text = [StoreUtil priceString:loadExtendNoteInfo.product];
    }
}

@end
