#import "StoreDetailHeaderView.h"

#import "StorePackInfo.h"
#import "UIImage+RB.h"

// The reflection height is the artwork height scaled by this shared engine double (0.2), reused
// here from the same global the store detail controller reads.
// @ghidraAddress 0x2eedc0 (0.2)
extern const double g_dMascotMessageAnimDuration;

// Image asset names.
static NSString *const kPackBackgroundImageName = @"09_store/store_pack_bg_0";
static NSString *const kDefaultJacketImageName = @"09_store/store_jacket_80";
static NSString *const kButtonNormalImageName = @"09_store/store_btn_normal_1";
static NSString *const kButtonHighlightedImageName = @"09_store/store_btn_clicked_1";
static NSString *const kButtonDisabledImageName = @"09_store/store_btn_disabled";
static NSString *const kNewMarkerImageName = @"09_store/store_new";

// The pack background stretchable cap inset.
static const NSInteger kBackgroundCapInset = 4;
// The purchase button background stretchable cap inset.
static const NSInteger kButtonCapInset = 6;

// Artwork layout: the jacket is an 80-point square inset 8 points from the top-left; its reflection
// sits directly below it, 16 points tall.
static const CGFloat kArtworkInset = 8.0;
static const CGFloat kArtworkSize = 80.0;
static const CGFloat kReflectionTop = 88.0;
static const CGFloat kReflectionHeight = 16.0;
static const CGFloat kReflectionAlpha = 0.4;

// Name label layout: pinned 96 points from the left, 8 points down, stretching to 106 points shy of
// the view's trailing edge, and a fixed 40 points tall.
static const CGFloat kNameLabelX = 96.0;
static const CGFloat kNameLabelTop = 8.0;
static const CGFloat kNameLabelTrailingInset = 106.0;
static const CGFloat kNameLabelHeight = 40.0;
static const NSInteger kNameLabelLineCount = 2;
static const CGFloat kNameLabelFontSize = 18.0;

// Comment label layout: inset 15 points, drawn 102 points down, stretching to 30 points shy of the
// trailing edge, and initially 10 points tall before it is resized to its measured content.
static const CGFloat kCommentLabelX = 15.0;
static const CGFloat kCommentLabelTop = 102.0;
static const CGFloat kCommentLabelTrailingInset = 30.0;
static const CGFloat kCommentLabelInitialHeight = 10.0;
static const CGFloat kCommentLabelFontSize = 12.0;

// Purchase button layout: 120 by 25 points, pinned 130 points from the trailing edge and 63 points
// down.
static const CGFloat kButtonTrailingInset = 130.0;
static const CGFloat kButtonTop = 63.0;
static const CGFloat kButtonWidth = 120.0;
static const CGFloat kButtonHeight = 25.0;
static const CGFloat kButtonTitleFontSize = 15.0;
static const CGFloat kButtonShadowOffsetY = -1.0;

// The enabled title shadow and disabled title colours (white components): a mid-grey shadow and a
// 158/255 grey for the disabled title.
static const CGFloat kButtonShadowWhite = 0.6;
static const CGFloat kButtonDisabledTitleWhite = 0.6196078431372549;

// The name and comment strings are measured against these effectively-unbounded boxes before their
// labels are resized to fit.
static const CGFloat kNameMeasureWidth = 214.0;
static const CGFloat kNameMeasureHeight = 50.0;
static const CGFloat kCommentMeasureWidth = 290.0;
static const CGFloat kCommentMeasureHeight = 120.0;

// The header is at least this tall; a non-empty comment adds its measured height on top.
static const CGFloat kHeaderBaseHeight = 110.0;

@implementation StoreDetailHeaderView

/** @ghidraAddress 0xec998 */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        UIImageView *background = [[UIImageView alloc] initWithFrame:self.bounds];
        background.image = [[UIImage imageWithName:kPackBackgroundImageName]
            stretchableImageWithLeftCapWidth:kBackgroundCapInset
                                topCapHeight:kBackgroundCapInset];
        background.autoresizingMask =
            UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:background];
        self.bgView = background;

        UIImageView *artwork = [[UIImageView alloc]
            initWithFrame:CGRectMake(kArtworkInset, kArtworkInset, kArtworkSize, kArtworkSize)];
        artwork.image = [UIImage imageWithName:kDefaultJacketImageName];
        [self addSubview:artwork];
        self.artworkView = artwork;

        UIImageView *reflection = [[UIImageView alloc]
            initWithFrame:CGRectMake(
                              kArtworkInset, kReflectionTop, kArtworkSize, kReflectionHeight)];
        reflection.alpha = kReflectionAlpha;
        [self addSubview:reflection];
        self.reflectionArtworkView = reflection;

        UILabel *name = [[UILabel alloc]
            initWithFrame:CGRectMake(kNameLabelX,
                                     kNameLabelTop,
                                     self.frame.size.width - kNameLabelTrailingInset,
                                     kNameLabelHeight)];
        name.backgroundColor = [UIColor clearColor];
        name.numberOfLines = kNameLabelLineCount;
        name.lineBreakMode = NSLineBreakByWordWrapping;
        name.font = [UIFont boldSystemFontOfSize:kNameLabelFontSize];
        name.autoresizingMask =
            UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
        [self addSubview:name];
        self.labelName = name;

        UILabel *comment = [[UILabel alloc]
            initWithFrame:CGRectMake(kCommentLabelX,
                                     kCommentLabelTop,
                                     self.frame.size.width - kCommentLabelTrailingInset,
                                     kCommentLabelInitialHeight)];
        comment.backgroundColor = [UIColor clearColor];
        comment.numberOfLines = 0;
        comment.lineBreakMode = NSLineBreakByWordWrapping;
        comment.font = [UIFont systemFontOfSize:kCommentLabelFontSize];
        comment.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [self addSubview:comment];
        self.labelComment = comment;

        UIButton *purchase = [UIButton buttonWithType:UIButtonTypeCustom];
        purchase.frame = CGRectMake(
            self.frame.size.width - kButtonTrailingInset, kButtonTop, kButtonWidth, kButtonHeight);
        purchase.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        [purchase setBackgroundImage:[[UIImage imageWithName:kButtonNormalImageName]
                                         stretchableImageWithLeftCapWidth:kButtonCapInset
                                                             topCapHeight:kButtonCapInset]
                            forState:UIControlStateNormal];
        [purchase setBackgroundImage:[[UIImage imageWithName:kButtonHighlightedImageName]
                                         stretchableImageWithLeftCapWidth:kButtonCapInset
                                                             topCapHeight:kButtonCapInset]
                            forState:UIControlStateHighlighted];
        [purchase setBackgroundImage:[[UIImage imageWithName:kButtonDisabledImageName]
                                         stretchableImageWithLeftCapWidth:kButtonCapInset
                                                             topCapHeight:kButtonCapInset]
                            forState:UIControlStateDisabled];
        purchase.adjustsImageWhenDisabled = NO;
        purchase.titleLabel.textColor = [UIColor whiteColor];
        purchase.titleLabel.font = [UIFont boldSystemFontOfSize:kButtonTitleFontSize];
        purchase.titleLabel.shadowOffset = CGSizeMake(0.0, kButtonShadowOffsetY);
        [purchase setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [purchase setTitleShadowColor:[UIColor colorWithWhite:0.0 alpha:kButtonShadowWhite]
                             forState:UIControlStateNormal];
        [purchase setTitleColor:[UIColor colorWithWhite:kButtonDisabledTitleWhite alpha:1.0]
                       forState:UIControlStateDisabled];
        [purchase setTitleShadowColor:[UIColor colorWithWhite:1.0 alpha:kButtonShadowWhite]
                             forState:UIControlStateDisabled];
        purchase.exclusiveTouch = YES;
        [self addSubview:purchase];
        self.buttonPurchase = purchase;

        UIImageView *newMarker =
            [[UIImageView alloc] initWithImage:[UIImage imageWithName:kNewMarkerImageName]];
        [self addSubview:newMarker];
        self.iconNewMarker = newMarker;
    }
    return self;
}

/** @ghidraAddress 0xed47c */
- (void)loadPackInfo:(StorePackInfo *)info {
    CGSize nameSize = [info.packName sizeWithFont:self.labelName.font
                                constrainedToSize:CGSizeMake(kNameMeasureWidth, kNameMeasureHeight)
                                    lineBreakMode:self.labelName.lineBreakMode];
    self.labelName.frame = CGRectMake(self.labelName.frame.origin.x,
                                      self.labelName.frame.origin.y,
                                      self.bounds.size.width - kNameLabelTrailingInset,
                                      nameSize.height);
    self.labelName.text = info.packName;

    CGFloat headerHeight = kHeaderBaseHeight;
    if (info.comment == nil) {
        self.labelComment.hidden = YES;
    } else {
        CGSize commentSize =
            [info.comment sizeWithFont:self.labelComment.font
                     constrainedToSize:CGSizeMake(kCommentMeasureWidth, kCommentMeasureHeight)
                         lineBreakMode:self.labelComment.lineBreakMode];
        self.labelComment.frame = CGRectMake(self.labelComment.frame.origin.x,
                                             self.labelComment.frame.origin.y,
                                             self.bounds.size.width - kCommentLabelTrailingInset,
                                             commentSize.height);
        self.labelComment.text = info.comment;
        self.labelComment.hidden = NO;
        headerHeight = commentSize.height + kHeaderBaseHeight;
    }

    self.frame =
        CGRectMake(self.frame.origin.x, self.frame.origin.y, self.frame.size.width, headerHeight);
    self.iconNewMarker.hidden = !info.isNew;
}

/** @ghidraAddress 0xeda24 */
- (void)setArtwork:(UIImage *)artwork {
    if (artwork != nil) {
        self.artworkView.image = artwork;
        self.reflectionArtworkView.image =
            [artwork reflectedImageWithHeight:artwork.size.height * g_dMascotMessageAnimDuration];
    }
}

@end
