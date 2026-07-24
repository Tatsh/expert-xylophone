#import "StoreExtendNoteCellView.h"

#import "StoreExtendNoteInfo.h"
#import "StoreUtil.h"
#import "UIImage+RB.h"
#import "neEngineBridge.h"

// The placeholder artwork shown behind the tune jacket.
static NSString *const kArtworkPlaceholderImageName = @"09_store/store_jacket_64";

// Artwork plate geometry. Both the shadowed backing plate and the jacket occupy the same square.
static const CGFloat kArtworkOriginX = 15.0;
static const CGFloat kArtworkOriginY = 15.0;
static const CGFloat kArtworkSize = 110.0;
static const CGFloat kArtworkBackgroundAlpha = 0.3;
static const CGFloat kArtworkBorderWidth = 1.0;
static const CGFloat kArtworkShadowOffset = 2.0;
static const CGFloat kArtworkShadowOpacity = 0.6;
static const CGFloat kArtworkShadowRadius = 2.0;

// Text-column geometry. The name, artist, and comment labels start at the same x and take the
// cell width less a fixed right inset; the level and purchased labels use fixed sizes.
static const CGFloat kTextColumnX = 140.0;
static const CGFloat kTextColumnWidthInset = -154.0;
static const CGFloat kNameLabelY = 12.0;
static const CGFloat kSingleLineLabelHeight = 20.0;
static const CGFloat kSecondRowY = 110.0;
static const CGFloat kArtistLabelY = 32.0;
static const CGFloat kCommentLabelY = 56.0;
static const CGFloat kCommentLabelHeight = 50.0;
static const CGFloat kLevelLabelWidth = 90.0;
static const CGFloat kPurchasedLabelX = 232.0;
static const CGFloat kPurchasedLabelWidth = 120.0;

// Font sizes.
static const CGFloat kNameFontSize = 17.0;
static const CGFloat kArtistFontSize = 14.0;
static const CGFloat kPurchasedFontSize = 15.0;
static const CGFloat kCommentFontSize = 13.0;
static const CGFloat kLevelFontSize = 15.0;
// The binary passes 11.0 to -setMinimumScaleFactor:, a point size carried over from the pre-iOS-6
// -minimumFontSize meaning; it is reproduced verbatim.
static const CGFloat kLabelMinimumScaleFactor = 11.0;

// Text colours. The level colour is a magenta expressed as 8-bit components over 255.
static const CGFloat kPurchasedTextWhite = 0.3;
static const CGFloat kCommentTextWhite = 50.0 / 255.0;
static const CGFloat kLevelColorRed = 170.0 / 255.0;
static const CGFloat kLevelColorGreen = 9.0 / 255.0;
static const CGFloat kLevelColorBlue = 120.0 / 255.0;

// The comment label wraps to at most this many lines.
static const NSInteger kCommentLabelLineCount = 3;

@implementation StoreExtendNoteCellView

/**
 * Builds one of the two identical artwork image views: a rounded, white-bordered, shadowed square
 * carrying the tune jacket placeholder.
 */
- (UIImageView *)makeArtworkImageView {
    UIImageView *imageView = [[UIImageView alloc]
        initWithFrame:CGRectMake(kArtworkOriginX, kArtworkOriginY, kArtworkSize, kArtworkSize)];
    imageView.contentMode = UIViewContentModeScaleAspectFit;
    imageView.opaque = NO;
    imageView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:kArtworkBackgroundAlpha];
    imageView.image = [UIImage imageWithName:kArtworkPlaceholderImageName];

    CALayer *layer = imageView.layer;
    layer.borderWidth = kArtworkBorderWidth;
    layer.borderColor = UIColor.whiteColor.CGColor;
    layer.shadowOffset = CGSizeMake(kArtworkShadowOffset, kArtworkShadowOffset);
    layer.shadowColor = UIColor.blackColor.CGColor;
    layer.shadowOpacity = kArtworkShadowOpacity;
    layer.shadowRadius = kArtworkShadowRadius;
    layer.shouldRasterize = YES;
    return imageView;
}

/** @ghidraAddress 0x4bcc4 */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.artworkBackImageView = [self makeArtworkImageView];
        self.artworkImageView = [self makeArtworkImageView];

        const CGFloat textColumnWidth = self.frame.size.width + kTextColumnWidthInset;

        UILabel *nameLabel = [[UILabel alloc]
            initWithFrame:CGRectMake(
                              kTextColumnX, kNameLabelY, textColumnWidth, kSingleLineLabelHeight)];
        nameLabel.backgroundColor = UIColor.clearColor;
        nameLabel.font = [UIFont boldSystemFontOfSize:kNameFontSize];
        nameLabel.textColor = [UIColor colorWithWhite:0.0 alpha:1.0];
        nameLabel.adjustsFontSizeToFitWidth = YES;
        nameLabel.minimumScaleFactor = kLabelMinimumScaleFactor;
        self.nameLabel = nameLabel;

        UILabel *artistLabel = [[UILabel alloc] initWithFrame:CGRectMake(kTextColumnX,
                                                                         kArtistLabelY,
                                                                         textColumnWidth,
                                                                         kSingleLineLabelHeight)];
        artistLabel.backgroundColor = UIColor.clearColor;
        artistLabel.font = [UIFont systemFontOfSize:kArtistFontSize];
        artistLabel.textColor = [UIColor colorWithWhite:0.0 alpha:1.0];
        artistLabel.adjustsFontSizeToFitWidth = YES;
        artistLabel.minimumScaleFactor = kLabelMinimumScaleFactor;
        self.artistLabel = artistLabel;

        UILabel *purchasedLabel =
            [[UILabel alloc] initWithFrame:CGRectMake(kPurchasedLabelX,
                                                      kSecondRowY,
                                                      kPurchasedLabelWidth,
                                                      kSingleLineLabelHeight)];
        purchasedLabel.font = [UIFont boldSystemFontOfSize:kPurchasedFontSize];
        purchasedLabel.text = @"";
        purchasedLabel.textColor = [UIColor colorWithWhite:kPurchasedTextWhite alpha:1.0];
        purchasedLabel.textAlignment = NSTextAlignmentRight;
        purchasedLabel.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
        self.purchasedLabel = purchasedLabel;

        UILabel *commentLabel = [[UILabel alloc]
            initWithFrame:CGRectMake(
                              kTextColumnX, kCommentLabelY, textColumnWidth, kCommentLabelHeight)];
        commentLabel.backgroundColor = UIColor.clearColor;
        commentLabel.font = [UIFont systemFontOfSize:kCommentFontSize];
        commentLabel.textColor = [UIColor colorWithWhite:kCommentTextWhite alpha:1.0];
        commentLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        commentLabel.baselineAdjustment = UIBaselineAdjustmentAlignBaselines;
        commentLabel.numberOfLines = kCommentLabelLineCount;
        self.commentLabel = commentLabel;

        UILabel *levelLabel = [[UILabel alloc]
            initWithFrame:CGRectMake(
                              kTextColumnX, kSecondRowY, kLevelLabelWidth, kSingleLineLabelHeight)];
        levelLabel.backgroundColor = UIColor.clearColor;
        levelLabel.font = [UIFont boldSystemFontOfSize:kLevelFontSize];
        levelLabel.textColor = [UIColor colorWithRed:kLevelColorRed
                                               green:kLevelColorGreen
                                                blue:kLevelColorBlue
                                               alpha:1.0];
        levelLabel.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
        self.levelLabel = levelLabel;

        [self addSubview:self.artworkBackImageView];
        [self addSubview:self.artworkImageView];
        [self addSubview:self.nameLabel];
        [self addSubview:self.artistLabel];
        [self addSubview:self.commentLabel];
        [self addSubview:self.levelLabel];
        [self addSubview:self.purchasedLabel];
    }
    return self;
}

/** @ghidraAddress 0x4ca54 */
- (void)dealloc {
    self.delegate = nil;
}

#pragma mark - Content

/** @ghidraAddress 0x4cadc */
- (void)setArtwork:(UIImage *)artwork {
    self.artworkImageView.image = artwork;
}

/** @ghidraAddress 0x4cc28 */
- (void)loadExtendNoteInfo:(StoreExtendNoteInfo *)info index:(NSUInteger)index {
    self.nameLabel.text = info.name;
    self.artistLabel.text = info.artist;
    self.commentLabel.text = info.comment;
    NSString *difficultyText = [NSString stringWithFormat:@"%d", info.difficulty];
    self.levelLabel.text = [NSString stringWithFormat:@"LEVEL %@", difficultyText];
    self.isNew = info.isNew;

    self.purchasedLabel.hidden = NO;
    StoreExtendNoteButtonState state = info.getButtonState;
    if (state >= StoreExtendNoteButtonStateDownloadBin &&
        state <= StoreExtendNoteButtonStateInstalled) {
        // The three download/installed states show the standing "purchased" caption.
        self.purchasedLabel.text = g_pLocalizedPurchased;
    } else if (state == StoreExtendNoteButtonStateMoreInfo ||
               state == StoreExtendNoteButtonStatePurchase) {
        // The not-yet-installed states show the formatted product price. The error state (-1) is
        // excluded: the binary tests the state as unsigned, so a negative value fails both branches.
        self.purchasedLabel.text = [StoreUtil priceString:info.product];
    }

    self.index = index;
}

#pragma mark - Purchased state

/** @ghidraAddress 0x4cb68 */
- (BOOL)isPurchased {
    return !self.purchasedLabel.hidden;
}

/** @ghidraAddress 0x4cbc8 */
- (void)setIsPurchased:(BOOL)isPurchased {
    // The compiled setter ignores its argument and unconditionally sets the standing caption.
    self.purchasedLabel.text = g_pLocalizedPurchased;
}

@end
