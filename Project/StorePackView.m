#import "StorePackView.h"

#import "RBPurchaseManager.h"
#import "StorePackInfo.h"
#import "StoreUtil.h"
#import "UIImage+RB.h"
#import "engineglobals.h"

extern const double g_dLayoutMetricThirtyTwo; // @ghidraAddress 0x2ee9b0 (32.0)

static NSString *const kStoreJacketPlaceholderImageName = @"09_store/store_jacket_64";
static NSString *const kStoreButtonDisabledImageName = @"09_store/store_btn_disabled";
static NSString *const kStoreNewBadgeImageName = @"09_store/store_new";
static NSString *const kStoreSequenceBadgeImageName = @"09_store/store_sp";

static NSString *const kStoreEmptyTitle = @""; // @ghidraAddress 0x3cfd10

static const CGFloat kJacketFrameInset = 15.0;
static const CGFloat kJacketFrameSize = 110.0;

static const CGFloat kJacketBackgroundWhite = 0.0;
static const CGFloat kJacketBorderWidth = 1.0;
static const CGFloat kJacketShadowOffset = 2.0;
static const CGFloat kJacketShadowOpacity = 0.6;
static const CGFloat kJacketShadowRadius = 2.0;

static const CGFloat kTextColumnLeft = 140.0;
static const CGFloat kNameLabelTop = 12.0;
static const CGFloat kNameLabelWidthInset = 145.0;
static const CGFloat kNameLabelHeight = 20.0;
static const CGFloat kNameLabelFontSize = 17.0;
static const CGFloat kNameLabelMinimumScaleFactor = 11.0;

static const CGFloat kCommentLabelWidthInset = 144.0;
static const CGFloat kCommentLabelFontSize = 13.0;
static const int kCommentLabelNumberOfLines = 4;

static const CGFloat kPriceLabelFontSize = 15.0;

static const int kButtonStretchCap = 6;
static const CGFloat kButtonFontSize = 15.0;
static const CGFloat kButtonTitleWhite = 0.62;

// @ghidraAddress 0xfe2f8 (song list)
// @ghidraAddress 0xfe424 (price)
static const CGFloat kBodyLabelWhite = 0.196078;
static const CGFloat kButtonWidthPadding = 10.0;
static const CGFloat kButtonHeightPadding = 4.0;
static const CGFloat kButtonRightInset = 15.0;
static const CGFloat kButtonBottomInset = 5.0;
static const CGFloat kButtonShadowOffsetY = -1.0;

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
        // The original builds this with colorWithWhite:0.0 alpha:1.0.
        self.nameLabel.textColor = UIColor.blackColor;
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
        self.commentLabel.textColor = [UIColor colorWithWhite:kBodyLabelWhite alpha:1.0];
        self.commentLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        self.commentLabel.baselineAdjustment = UIBaselineAdjustmentAlignBaselines;
        self.commentLabel.numberOfLines = kCommentLabelNumberOfLines;

        self.priceLabel = [[UILabel alloc] initWithFrame:CGRectMake(kTextColumnLeft,
                                                                    buttonTop,
                                                                    g_dCustomizeLayoutMetric100,
                                                                    buttonHeight)];
        self.priceLabel.backgroundColor = UIColor.clearColor;
        self.priceLabel.font = [UIFont boldSystemFontOfSize:kPriceLabelFontSize];
        self.priceLabel.textColor = [UIColor colorWithWhite:kBodyLabelWhite alpha:1.0];

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
