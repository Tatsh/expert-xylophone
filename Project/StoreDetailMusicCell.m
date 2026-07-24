#import "StoreDetailMusicCell.h"

#import "AppDelegate.h"
#import "RBViewController.h"
#import "UIAlertView+RB.h"
#import "UIImage+RB.h"
#import "neEngineBridge.h"

// Shared layout metrics reached by their Ghidra address as the other reconstructed store cells do;
// they are not yet in the engine bridge header. Eighty is the tune-row height and the label column
// left edge, sixty is the levels-label top, and eighty-two is the levels-label left edge.
extern const double g_dLayoutMetricEighty;      // @ghidraAddress 0x2ec6c8 (80.0)
extern const double g_dLayoutMetricSixty;       // @ghidraAddress 0x2ee948 (60.0)
extern const double g_dCustomizeLayoutMetric82; // @ghidraAddress 0x3011c8 (82.0)

// Store asset names used by the cell.
static NSString *const kStoreDefaultJacketImageName = @"09_store/store_jacket_64";
static NSString *const kStoreItunesImageName = @"09_store/store_itunes";
static NSString *const kStorePlayImageName = @"09_store/store_play";
static NSString *const kStoreSequenceImageName = @"09_store/store_sp";

// The jacket is a fixed 64-point square inset 8 points from the top-left, with a rasterised drop
// shadow.
static const CGFloat kJacketInset = 8.0;
static const CGFloat kJacketSize = 64.0;
static const CGFloat kJacketShadowOffset = 2.0;
static const CGFloat kJacketShadowOpacity = 0.6;
static const CGFloat kJacketShadowRadius = 2.0;

// The name and artist labels share an 80-point left edge and a width 90 points shy of the content
// width; the levels label is a fixed 110-point column 82 points in.
static const CGFloat kTextColumnWidthInset = 90.0;
static const CGFloat kNameLabelTop = 8.0;
static const CGFloat kNameLabelHeight = 18.0;
static const CGFloat kNameLabelFontSize = 15.0;
static const CGFloat kArtistLabelTop = 26.0;
static const CGFloat kArtistLabelHeight = 15.0;
static const CGFloat kArtistLabelFontSize = 12.0;
static const CGFloat kLevelsLabelWidth = 110.0;
static const CGFloat kLevelsLabelHeight = 14.0;
static const CGFloat kLevelsLabelFontSize = 12.0;

// The iTunes link button is pinned 10 points in from the bottom-right corner of the content view.
static const CGFloat kLinkButtonMargin = -10.0;

// The sample overlay is drawn 0.4 white and centred at half its own size.
static const CGFloat kSampleViewWhite = 0.4;
static const CGFloat kCenterScale = 0.5;

// The autoresizing masks the binary applies to each subview.
static const UIViewAutoresizing kBackgroundAutoresizing =
    UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
static const UIViewAutoresizing kLabelAutoresizing = UIViewAutoresizingFlexibleWidth;
static const UIViewAutoresizing kLinkButtonAutoresizing =
    UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin;
static const UIViewAutoresizing kIconSpAutoresizing = UIViewAutoresizingFlexibleRightMargin;

// The confirm-button index of the extend-note offer alert.
static const NSInteger kAlertConfirmButtonIndex = 1;

// The unset extend-note product identifier is any non-positive value.
static const int kNoExtendNotePid = 0;

@implementation StoreDetailMusicCell

/** @ghidraAddress 0xedde8 */
+ (CGFloat)cellHeight {
    return g_dLayoutMetricEighty;
}

/** @ghidraAddress 0xeddf4 */
- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;

        self.bgView = [[UIImageView alloc] initWithFrame:self.bounds];
        self.backgroundView = self.bgView;
        self.backgroundView.autoresizingMask = kBackgroundAutoresizing;

        self.artworkView = [[UIImageView alloc]
            initWithFrame:CGRectMake(kJacketInset, kJacketInset, kJacketSize, kJacketSize)];
        self.artworkView.image = [UIImage imageWithName:kStoreDefaultJacketImageName];
        self.artworkView.layer.shadowOffset = CGSizeMake(kJacketShadowOffset, kJacketShadowOffset);
        self.artworkView.layer.shadowColor = UIColor.blackColor.CGColor;
        self.artworkView.layer.shadowOpacity = kJacketShadowOpacity;
        self.artworkView.layer.shadowRadius = kJacketShadowRadius;
        self.artworkView.layer.shouldRasterize = YES;
        self.artworkView.exclusiveTouch = YES;

        CGFloat contentWidth = self.contentView.frame.size.width;
        CGFloat contentHeight = self.contentView.frame.size.height;
        CGFloat textColumnWidth = contentWidth - kTextColumnWidthInset;

        self.labelName = [[UILabel alloc] initWithFrame:CGRectMake(g_dLayoutMetricEighty,
                                                                   kNameLabelTop,
                                                                   textColumnWidth,
                                                                   kNameLabelHeight)];
        self.labelName.backgroundColor = UIColor.clearColor;
        self.labelName.font = [UIFont boldSystemFontOfSize:kNameLabelFontSize];
        self.labelName.autoresizingMask = kLabelAutoresizing;

        self.labelArtist = [[UILabel alloc] initWithFrame:CGRectMake(g_dLayoutMetricEighty,
                                                                     kArtistLabelTop,
                                                                     textColumnWidth,
                                                                     kArtistLabelHeight)];
        self.labelArtist.backgroundColor = UIColor.clearColor;
        self.labelArtist.font = [UIFont systemFontOfSize:kArtistLabelFontSize];
        self.labelArtist.autoresizingMask = kLabelAutoresizing;

        self.labelLevels = [[UILabel alloc] initWithFrame:CGRectMake(g_dCustomizeLayoutMetric82,
                                                                     g_dLayoutMetricSixty,
                                                                     kLevelsLabelWidth,
                                                                     kLevelsLabelHeight)];
        self.labelLevels.backgroundColor = UIColor.clearColor;
        self.labelLevels.font = [UIFont boldSystemFontOfSize:kLevelsLabelFontSize];
        self.labelLevels.adjustsFontSizeToFitWidth = YES;

        self.buttonLink = [UIButton buttonWithType:UIButtonTypeCustom];
        UIImage *itunesImage = [UIImage imageWithName:kStoreItunesImageName];
        self.buttonLink.frame =
            CGRectMake(contentWidth - itunesImage.size.width + kLinkButtonMargin,
                       contentHeight - itunesImage.size.height + kLinkButtonMargin,
                       itunesImage.size.width,
                       itunesImage.size.height);
        self.buttonLink.autoresizingMask = kLinkButtonAutoresizing;
        [self.buttonLink setBackgroundImage:itunesImage forState:UIControlStateNormal];
        [self.buttonLink addTarget:self
                            action:@selector(handleLink:)
                  forControlEvents:UIControlEventTouchUpInside];
        self.buttonLink.exclusiveTouch = YES;

        self.sampleView = [[UIView alloc] initWithFrame:self.artworkView.frame];
        self.sampleView.opaque = NO;
        self.sampleView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:kSampleViewWhite];
        CGFloat sampleWidth = self.sampleView.frame.size.width;
        CGFloat sampleHeight = self.sampleView.frame.size.height;

        self.indicator = [[UIActivityIndicatorView alloc]
            initWithFrame:CGRectMake(0.0, 0.0, sampleWidth, sampleHeight)];
        CGPoint sampleCenter = CGPointMake(sampleWidth * kCenterScale, sampleHeight * kCenterScale);
        self.indicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhiteLarge;
        self.indicator.hidesWhenStopped = YES;
        self.indicator.center = sampleCenter;
        [self.sampleView addSubview:self.indicator];

        self.playingView =
            [[UIImageView alloc] initWithImage:[UIImage imageWithName:kStorePlayImageName]];
        self.playingView.center = sampleCenter;
        self.playingView.hidden = YES;
        [self.sampleView addSubview:self.playingView];

        [self.contentView addSubview:self.artworkView];
        [self.contentView addSubview:self.sampleView];
        [self.contentView addSubview:self.labelName];
        [self.contentView addSubview:self.labelArtist];
        [self.contentView addSubview:self.labelLevels];
        [self.contentView addSubview:self.buttonLink];

        UIImage *sequenceImage = [UIImage imageWithName:kStoreSequenceImageName];
        self.iconSp = [UIButton buttonWithType:UIButtonTypeCustom];
        CGRect artworkFrame = self.artworkView.frame;
        self.iconSp.frame = CGRectMake(0.0,
                                       0.0,
                                       artworkFrame.origin.x + artworkFrame.size.width,
                                       artworkFrame.origin.y * 2.0 + artworkFrame.size.height);
        [self.iconSp setImage:[UIImage imageWithName:kStoreSequenceImageName]
                     forState:UIControlStateNormal];
        self.iconSp.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        self.iconSp.imageEdgeInsets = UIEdgeInsetsMake(
            self.iconSp.frame.size.height - sequenceImage.size.height, 0.0, 0.0, 0.0);
        self.iconSp.exclusiveTouch = YES;
        self.iconSp.autoresizingMask = kIconSpAutoresizing;
        [self.iconSp addTarget:self
                        action:@selector(tapSp:)
              forControlEvents:UIControlEventTouchUpInside];
        [self.contentView addSubview:self.iconSp];
    }
    self.exclusiveTouch = YES;
    return self;
}

#pragma mark - Content

- (void)setBgImage:(UIImage *)bgImage {
    self.bgView.image = bgImage;
}

- (void)setLink:(NSString *)link {
    self.linkURL = (link == nil) ? nil : [NSURL URLWithString:link];
    self.buttonLink.hidden = (self.linkURL == nil);
}

#pragma mark - Sample state

- (void)samplePlaying {
    [self.indicator stopAnimating];
    self.playingView.hidden = NO;
    self.sampleView.hidden = NO;
}

- (void)sampleDownloading {
    [self.indicator startAnimating];
    self.playingView.hidden = YES;
    self.sampleView.hidden = NO;
}

- (void)sampleStop {
    [self.indicator stopAnimating];
    self.sampleView.hidden = YES;
}

#pragma mark - Actions

- (void)handleLink:(id)sender {
    if (self.linkURL != nil) {
        RBViewController *viewController = [AppDelegate appDelegate].viewController;
        if ([viewController respondsToSelector:@selector(openItunesWithURL:)]) {
            [viewController performSelector:@selector(openItunesWithURL:) withObject:self.linkURL];
        }
    }
}

- (void)tapSp:(id)sender {
    [[UIAlertView showMovePackDetailToExtendDetail:self] show];
}

#pragma mark - Alert view delegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == kAlertConfirmButtonIndex && self.pid > kNoExtendNotePid &&
        [self.parent respondsToSelector:@selector(switchToSpecialStore:)]) {
        [self.parent performSelector:@selector(switchToSpecialStore:) withObject:@(self.pid)];
    }
}

- (void)alertViewCancel:(UIAlertView *)alertView {
    // The binary takes no action on cancellation.
}

- (void)didPresentAlertView:(UIAlertView *)alertView {
    [UIAlertView
        setExclusiveTouchForView:[UIApplication sharedApplication]
                                     .keyWindow.rootViewController.presentedViewController.view];
}

@end
