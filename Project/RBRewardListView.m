//
//  RBRewardListView.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RBRewardListView). Verified against
//  the arm64 disassembly: -setupView's soft-float frame and corner-radius operands, the activity
//  indicator's transform.scale key-value coding, and the fade durations were recovered from the
//  register moves the decompiler folds into pseudo-variables. This is a plain Objective-C file
//  because the class reaches the RewardNetwork advert facade through ordinary class-method message
//  sends, with no C++.
//

#import "RBRewardListView.h"

#import "RBCustomView.h"
#import "RewardNetwork.h"
#import "UIAlertView+RB.h"

// The web target view's rounded-corner radius and the activity indicator's magnification.
static const CGFloat kWebTargetCornerRadius = 7.0;
static const CGFloat kIndicatorScale = 1.5;

// The close button sits at the top left, sized to hold its localised title at eighteen points.
static const CGFloat kBackButtonX = 12.0;
static const CGFloat kBackButtonY = 8.0;
static const CGFloat kBackButtonWidth = 60.0;
static const CGFloat kBackButtonHeight = 30.0;
static const CGFloat kBackButtonFontSize = 18.0;

// The web target view's fade-in runs over a quarter of a second.
static const NSTimeInterval kWebTargetFadeDuration = 0.25;

// The ad location the reward advert screen is opened at.
static NSString *const kRewardAdLocation = @"ADL_TOP";

@implementation RBRewardListView

#pragma mark Lifecycle

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupView];
    }
    return self;
}

#pragma mark Layout

- (void)setupView {
    // The rounded, clipped web target view hosts the advert screen. It starts fully transparent and
    // fades in once the advert list has appeared.
    self.webTargetView = [[UIView alloc] initWithFrame:self.frame];
    self.webTargetView.autoresizingMask =
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight |
        UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
        UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    self.webTargetView.layer.cornerRadius = kWebTargetCornerRadius;
    self.webTargetView.clipsToBounds = YES;
    self.webTargetView.backgroundColor = [UIColor clearColor];
    self.webTargetView.alpha = 0.0;
    [self addSubview:self.webTargetView];

    // The large spinner is centred on the view and magnified while the list loads.
    self.indicatorView = [[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    [self.indicatorView.layer setValue:@(kIndicatorScale) forKeyPath:@"transform.scale"];
    self.indicatorView.center = self.center;
    [self.indicatorView startAnimating];
    [self addSubview:self.indicatorView];

    self.backgroundColor = [UIColor clearColor];
    self.webTargetAnimating = NO;

    // The close button dismisses the advert list. It is hidden and disabled until the list appears.
    self.backButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    self.backButton.frame =
        CGRectMake(kBackButtonX, kBackButtonY, kBackButtonWidth, kBackButtonHeight);
    self.backButton.titleLabel.font = [UIFont systemFontOfSize:kBackButtonFontSize];
    [self.backButton setTitle:NSLocalizedString(@"Close", nil) forState:UIControlStateNormal];
    [self.backButton addTarget:self
                        action:@selector(pushCloseButton)
              forControlEvents:UIControlEventTouchUpInside];
    self.backButton.hidden = YES;
    self.backButton.enabled = NO;
    self.backButton.exclusiveTouch = YES;
    [self addSubview:self.backButton];
}

#pragma mark Presentation

- (void)hideAnimation {
    if (self.animating) {
        return;
    }
    [RewardNetwork closeAdScreen];
    [self.indicatorView removeFromSuperview];
    [self.webTargetView removeFromSuperview];
}

- (void)loadStart {
    self.backButton.hidden = NO;
    self.backButton.enabled = YES;
    [RewardNetwork openAdScreenWithParentView:self.webTargetView
                                   adLocation:kRewardAdLocation
                                     delegate:self];
}

#pragma mark RewardNetwork delegate

- (void)appListDidAppear {
    [self.indicatorView stopAnimating];
    if (self.webTargetAnimating) {
        return;
    }
    self.webTargetAnimating = YES;
    [UIView animateWithDuration:kWebTargetFadeDuration
        animations:^{
          /** @ghidraAddress 0x10da60 */
          self.backButton.hidden = YES;
          self.webTargetView.alpha = 1.0;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x10db18 */
          self.webTargetView.alpha = 1.0;
          self.webTargetAnimating = NO;
        }];
}

- (void)appListDidDisappear {
    [RewardNetwork closeAdScreen];
    self.webTargetView.alpha = 0.0;
    [self.parentCustomView hideRewardList];
    self.backButton.hidden = YES;
    [self.indicatorView startAnimating];
}

- (void)appListFailLoadWithError:(NSError *)error {
    [self.indicatorView stopAnimating];
    [error code];
    [UIAlertView showNetworkErrorWithDelegate:nil];
    if (self.indicatorView.isAnimating) {
        [self appListDidDisappear];
    }
}

#pragma mark Actions

- (void)pushCloseButton {
    [self appListDidDisappear];
}

#pragma mark Parent view alias

- (void)setParentView:(RBCustomView *)parentView {
    self.parentCustomView = parentView;
}

@end
