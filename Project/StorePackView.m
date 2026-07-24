#import "StorePackView.h"

#import "RBPurchaseManager.h"
#import "StorePackInfo.h"
#import "StoreUtil.h"
#import "UIImage+RB.h"
#import "neEngineBridge.h"

// Layout metrics shared with other screens but not declared in the engine bridge header. Reached
// by their Ghidra addresses, matching how the other reconstructed views (for example
// RBSearchMapView) pull them in. The 100.0-point and 0.3-second metrics come from the bridge
// header instead.
extern const double g_dLayoutMetricThirtyTwo;   // @ghidraAddress 0x2ee9b0 (32.0)
extern const CGFloat g_dRBWebViewGrayViewWhite; // @ghidraAddress 0x2ec708 (0.6)

// Store asset names used by the tile.
static NSString *const kStoreJacketPlaceholderImageName = @"09_store/store_jacket_64";
static NSString *const kStoreButtonDisabledImageName = @"09_store/store_btn_disabled";
static NSString *const kStoreNewBadgeImageName = @"09_store/store_new";
static NSString *const kStoreSequenceBadgeImageName = @"09_store/store_sp";

// The owned-state overlay button carries an empty title: it is a shared store-layer string global.
static NSString *const kStoreEmptyTitle = @""; // @ghidraAddress 0x3cfd10

// The two framed jacket image views are a fixed 110-point square inset 15 points from the tile's
// top left corner.
static const CGFloat kJacketFrameInset = 15.0;
static const CGFloat kJacketFrameSize = 110.0;

// The jacket backing view is faintly darkened and drawn with a bright border and a soft drop
// shadow.
static const CGFloat kJacketBackgroundWhite = 0.0;
static const CGFloat kJacketBorderWidth = 1.0;
static const CGFloat kJacketShadowOffset = 2.0;
static const CGFloat kJacketShadowOpacity = 0.6;
static const CGFloat kJacketShadowRadius = 2.0;

// The name label sits to the right of the jacket, 145 points narrower than the tile.
static const CGFloat kTextColumnLeft = 140.0;
static const CGFloat kNameLabelTop = 12.0;
static const CGFloat kNameLabelWidthInset = 145.0;
static const CGFloat kNameLabelHeight = 20.0;
static const CGFloat kNameLabelFontSize = 17.0;
static const CGFloat kNameLabelMinimumScaleFactor = 11.0;

// The comment label is 144 points narrower than the tile and starts below the name label.
static const CGFloat kCommentLabelWidthInset = 144.0;
static const CGFloat kCommentLabelFontSize = 13.0;
static const int kCommentLabelNumberOfLines = 4;

// The price label is a fixed 100-point wide column aligned with the owned-state button's top.
static const CGFloat kPriceLabelFontSize = 15.0;

// The owned-state overlay button is stretched from a 6-point cap image, sized to fit its (empty)
// title, then padded and pinned near the tile's bottom-right corner.
static const int kButtonStretchCap = 6;
static const CGFloat kButtonFontSize = 15.0;
static const CGFloat kButtonTitleWhite = 0.62;
static const CGFloat kButtonWidthPadding = 10.0;
static const CGFloat kButtonHeightPadding = 4.0;
static const CGFloat kButtonRightInset = 15.0;
static const CGFloat kButtonBottomInset = 5.0;
static const CGFloat kButtonShadowOffsetY = -1.0;

// The comment label's bottom is pulled a further 30 points above the owned-state button's top.
static const CGFloat kCommentLabelBottomLift = 30.0;

@interface StorePackView ()

// De-inlined initialiser helpers; the binary inlines both blocks into -initWithFrame:.
- (UIImageView *)makeJacketImageViewWithImageName:(nullable NSString *)imageName;
- (UIButton *)makePurchasedButton;

@end

@implementation StorePackView

/** @ghidraAddress 0xfd858 */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backGroundImageView = [[UIImageView alloc] initWithFrame:self.bounds];
        self.backGroundImageView.userInteractionEnabled = YES;
        self.backGroundImageView.exclusiveTouch = YES;
        UITapGestureRecognizer *tap =
            [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
        [self.backGroundImageView addGestureRecognizer:tap];

        self.artworkBackImageView =
            [self makeJacketImageViewWithImageName:kStoreJacketPlaceholderImageName];
        self.artworkImageView = [self makeJacketImageViewWithImageName:nil];

        self.nameLabel =
            [[UILabel alloc] initWithFrame:CGRectMake(kTextColumnLeft,
                                                      kNameLabelTop,
                                                      self.frame.size.width - kNameLabelWidthInset,
                                                      kNameLabelHeight)];
        self.nameLabel.backgroundColor = UIColor.clearColor;
        self.nameLabel.font = [UIFont boldSystemFontOfSize:kNameLabelFontSize];
        self.nameLabel.textColor = [UIColor colorWithWhite:kJacketBackgroundWhite alpha:1.0];
        self.nameLabel.adjustsFontSizeToFitWidth = YES;
        // The binary passes 11.0 here, an out-of-range minimum scale factor; reproduced verbatim.
        self.nameLabel.minimumScaleFactor = kNameLabelMinimumScaleFactor;

        self.purchasedButton = [self makePurchasedButton];

        CGFloat buttonHeight = self.purchasedButton.frame.size.height;
        CGFloat buttonTop = self.purchasedButton.frame.origin.y;

        self.commentLabel = [[UILabel alloc]
            initWithFrame:CGRectMake(kTextColumnLeft,
                                     g_dLayoutMetricThirtyTwo,
                                     self.frame.size.width - kCommentLabelWidthInset,
                                     buttonTop - kCommentLabelBottomLift)];
        self.commentLabel.backgroundColor = UIColor.clearColor;
        self.commentLabel.font = [UIFont systemFontOfSize:kCommentLabelFontSize];
        self.commentLabel.textColor = [UIColor colorWithWhite:g_dRBWebViewGrayViewWhite alpha:1.0];
        self.commentLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        self.commentLabel.baselineAdjustment = UIBaselineAdjustmentAlignBaselines;
        self.commentLabel.numberOfLines = kCommentLabelNumberOfLines;

        self.priceLabel = [[UILabel alloc] initWithFrame:CGRectMake(kTextColumnLeft,
                                                                    buttonTop,
                                                                    g_dCustomizeLayoutMetric100,
                                                                    buttonHeight)];
        self.priceLabel.backgroundColor = UIColor.clearColor;
        self.priceLabel.font = [UIFont boldSystemFontOfSize:kPriceLabelFontSize];
        self.priceLabel.textColor = [UIColor colorWithWhite:g_dRBWebViewGrayViewWhite alpha:1.0];

        UIImage *newBadge = [UIImage imageWithName:kStoreNewBadgeImageName];
        self.iconNew = [[UIImageView alloc] initWithImage:newBadge];

        UIImage *sequenceBadge = [UIImage imageWithName:kStoreSequenceBadgeImageName];
        self.iconSp = [[UIImageView alloc] initWithImage:sequenceBadge];
        self.iconSp.frame = CGRectMake(0.0,
                                       self.frame.size.height - self.iconSp.frame.size.height,
                                       self.iconSp.frame.size.width,
                                       self.iconSp.frame.size.height);

        [self addSubview:self.backGroundImageView];
        [self addSubview:self.artworkBackImageView];
        [self addSubview:self.artworkImageView];
        [self addSubview:self.nameLabel];
        [self addSubview:self.commentLabel];
        [self addSubview:self.priceLabel];
        [self addSubview:self.purchasedButton];
        [self addSubview:self.iconNew];
        [self addSubview:self.iconSp];
    }
    return self;
}

// Builds one of the two framed jacket image views: a 110-point square, inset 15 points, faintly
// darkened, with a white border and a rasterised drop shadow. The backing view shows the
// placeholder jacket; the front view is left empty for the downloaded artwork.
- (UIImageView *)makeJacketImageViewWithImageName:(nullable NSString *)imageName {
    UIImageView *jacket = [[UIImageView alloc] initWithFrame:CGRectMake(kJacketFrameInset,
                                                                        kJacketFrameInset,
                                                                        kJacketFrameSize,
                                                                        kJacketFrameSize)];
    jacket.contentMode = UIViewContentModeScaleAspectFit;
    jacket.opaque = NO;
    jacket.backgroundColor = [UIColor colorWithWhite:kJacketBackgroundWhite
                                               alpha:g_dAudioManagerResumeFadeInTime];
    if (imageName != nil) {
        jacket.image = [UIImage imageWithName:imageName];
    }
    jacket.layer.borderWidth = kJacketBorderWidth;
    jacket.layer.borderColor = UIColor.whiteColor.CGColor;
    jacket.layer.shadowOffset = CGSizeMake(kJacketShadowOffset, kJacketShadowOffset);
    jacket.layer.shadowColor = UIColor.blackColor.CGColor;
    jacket.layer.shadowOpacity = kJacketShadowOpacity;
    jacket.layer.shadowRadius = kJacketShadowRadius;
    jacket.layer.shouldRasterize = YES;
    return jacket;
}

// Builds the owned-state overlay button: a custom button whose disabled state shows a stretched
// cover image and an empty title, sized to fit and pinned near the tile's bottom-right corner.
- (UIButton *)makePurchasedButton {
    UIImage *cover = [[UIImage imageWithName:kStoreButtonDisabledImageName]
        stretchableImageWithLeftCapWidth:kButtonStretchCap
                            topCapHeight:kButtonStretchCap];
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button setBackgroundImage:cover forState:UIControlStateDisabled];
    button.exclusiveTouch = YES;
    button.adjustsImageWhenDisabled = NO;
    button.titleLabel.textColor = [UIColor colorWithWhite:kButtonTitleWhite alpha:1.0];
    button.titleLabel.font = [UIFont boldSystemFontOfSize:kButtonFontSize];
    button.titleLabel.shadowOffset = CGSizeMake(0.0, kButtonShadowOffsetY);
    [button setTitleColor:[UIColor colorWithWhite:kButtonTitleWhite alpha:1.0]
                 forState:UIControlStateDisabled];
    [button setTitleShadowColor:[UIColor colorWithWhite:1.0 alpha:g_dRBWebViewGrayViewWhite]
                       forState:UIControlStateDisabled];
    [button setTitle:kStoreEmptyTitle forState:UIControlStateDisabled];
    button.enabled = NO;
    [button sizeToFit];

    CGFloat width = button.frame.size.width + kButtonWidthPadding;
    CGFloat height = button.frame.size.height + kButtonHeightPadding;
    CGFloat x = (self.frame.size.width - width) - kButtonRightInset;
    CGFloat y = (self.frame.size.height - height) - kButtonBottomInset;
    button.frame = CGRectMake(x, y, width, height);
    return button;
}

/** @ghidraAddress 0xfe958 */
- (void)dealloc {
    // ARC synthesises the ivar teardown; only the delegate detach is reproduced here.
    self.delegate = nil;
}

/** @ghidraAddress 0xfe9e0 */
- (void)setBgImage:(UIImage *)bgImage {
    self.backGroundImageView.image = bgImage;
}

/** @ghidraAddress 0xfea6c */
- (void)setArtwork:(UIImage *)artwork {
    self.artworkImageView.image = artwork;
}

/** @ghidraAddress 0xfeaf8 */
- (void)handleTap:(UITapGestureRecognizer *)sender {
    if ([self.delegate respondsToSelector:@selector(packViewSelected:)]) {
        [self.delegate performSelector:@selector(packViewSelected:) withObject:self];
    }
}

/** @ghidraAddress 0xfebd8 */
- (BOOL)isPurchased {
    return !self.purchasedButton.isHidden;
}

/** @ghidraAddress 0xfec38 */
- (void)setIsPurchased:(BOOL)isPurchased {
    self.purchasedButton.hidden = !isPurchased;
}

/** @ghidraAddress 0xfec94 */
- (void)loadPackInfo:(StorePackInfo *)loadPackInfo index:(NSUInteger)index {
    self.nameLabel.text = loadPackInfo.packName;
    self.commentLabel.text = loadPackInfo.s_comment;
    self.priceLabel.text = loadPackInfo.priceString;
    self.iconNew.hidden = !loadPackInfo.isNew;
    self.iconSp.hidden = (loadPackInfo.extCount == 0);

    NSString *productID = [StoreUtil productIDForPackID:loadPackInfo.packID];
    if ([[RBPurchaseManager sharedManager] isPurchased:productID]) {
        self.purchasedButton.hidden = NO;
    } else {
        self.purchasedButton.hidden = YES;
    }

    _index = index;
}

@end
