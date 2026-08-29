#import "RBApplilinkView.h"

#import "RBUserSettingData.h"
#import "RecommendNetwork.h"
#import "UIAlertView+RB.h"

static const CGFloat kWebTargetCornerRadius = 7.0;
static const CGFloat kIndicatorScale = 1.5;

static const NSTimeInterval kWebTargetFadeDuration = 0.25;

static const int kApplilinkAdModelDefault = 1;
static const int kApplilinkVerticalAlignDefault = 0;

static NSString *const kApplilinkAdLocation = @"ADL_TOP";

@implementation RBApplilinkView

#pragma mark Lifecycle

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setMusicMenuPopupViewType:RBMusicMenuPopupViewTypeApplilink];
        [self setupView];
        self.hideAnimating = NO;
    }
    return self;
}

#pragma mark Layout

- (void)setupView {
    [super setupView];

    (void)[RBUserSettingData sharedInstance].thema; // Yes, the binary discards this read.

    self.gradationImageView.hidden = YES;
    self.titleImageView.hidden = YES;

    self.webTargetView =
        [[UIView alloc] initWithFrame:CGRectMake(0,
                                                 0,
                                                 self.contentView.frame.size.width,
                                                 self.contentView.frame.size.height)];
    self.webTargetView.autoresizingMask =
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight |
        UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
        UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    self.webTargetView.layer.cornerRadius = kWebTargetCornerRadius;
    self.webTargetView.clipsToBounds = YES;
    self.webTargetView.backgroundColor = UIColor.clearColor;
    self.webTargetView.alpha = 0.0;
    [self.contentView addSubview:self.webTargetView];

    self.indicatorView = [[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    [self.indicatorView.layer setValue:@(kIndicatorScale) forKeyPath:@"transform.scale"];
    self.indicatorView.center = self.contentView.center;
    [self.indicatorView startAnimating];
    [self.contentView addSubview:self.indicatorView];

    self.contentView.backgroundColor = UIColor.clearColor;
    self.webTargetAnimating = NO;
}

#pragma mark Presentation

- (void)showAnimation {
    [super showAnimation];
    [RecommendNetwork openAdAreaWithParentView:self.webTargetView
                                          rect:self.webTargetView.frame
                                       adModel:kApplilinkAdModelDefault
                                    adLocation:kApplilinkAdLocation
                                 verticalAlign:kApplilinkVerticalAlignDefault
                                      delegate:self];
}

- (void)hideAnimation {
    if (self.animating) {
        return;
    }
    if (!self.hideAnimating) {
        [RecommendNetwork closeAdAreaWithParentView:self.webTargetView];
    }
    [self.indicatorView removeFromSuperview];
    [self.webTargetView removeFromSuperview];
    [super hideAnimation];
}

#pragma mark RecommendNetwork delegate

- (void)appListDidAppear {
    [self.indicatorView stopAnimating];
    if (self.webTargetAnimating) {
        return;
    }
    self.webTargetAnimating = YES;
    [UIView animateWithDuration:kWebTargetFadeDuration
        animations:^{
          /** @ghidraAddress 0x1be0b0 */
          self.webTargetView.alpha = 1.0;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x1be11c */
          self.webTargetView.alpha = 1.0;
          self.webTargetAnimating = NO;
        }];
}

- (void)appListDidDisappear {
    if (self.hideAnimating) {
        return;
    }
    [RecommendNetwork closeAdAreaWithParentView:self.webTargetView];
    self.hideAnimating = YES;
    [self hideAnimation];
}

- (void)appListFailLoadWithError:(NSError *)error {
    [self.indicatorView stopAnimating];
    [error code]; // Yes, the binary discards this call's result.
    [UIAlertView showNetworkErrorWithDelegate:nil];
}

@end
