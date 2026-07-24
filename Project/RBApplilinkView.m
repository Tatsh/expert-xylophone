//
//  RBApplilinkView.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RBApplilinkView). Verified
//  against the arm64 disassembly: -setupView's soft-float web-target frame and corner-radius
//  operands, the activity indicator's transform.scale key-value coding, the advert-area open rect,
//  and the fade duration were recovered from the register moves the decompiler folds into
//  pseudo-variables. This is a plain Objective-C file because the class reaches the
//  RecommendNetwork advert facade through ordinary class-method message sends, with no C++.
//

#import "RBApplilinkView.h"

#import "RBUserSettingData.h"
#import "RecommendNetwork.h"
#import "UIAlertView+RB.h"

// The Applilink variant of the music-menu popup passed to -setMusicMenuPopupViewType:.
static const NSInteger kMusicMenuPopupViewTypeApplilink = 8;

// The web target view's rounded-corner radius and the activity indicator's magnification.
static const CGFloat kWebTargetCornerRadius = 7.0;
static const CGFloat kIndicatorScale = 1.5;

// The web target view's fade-in runs over a quarter of a second.
static const NSTimeInterval kWebTargetFadeDuration = 0.25;

// The advert-model and vertical-alignment identifiers the advert area is opened with.
static const int kApplilinkAdModelDefault = 1;
static const int kApplilinkVerticalAlignDefault = 0;

// The ad location the recommend advert area is opened at.
static NSString *const kApplilinkAdLocation = @"ADL_TOP";

@implementation RBApplilinkView

#pragma mark Lifecycle

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setMusicMenuPopupViewType:kMusicMenuPopupViewTypeApplilink];
        [self setupView];
        self.hideAnimating = NO;
    }
    return self;
}

#pragma mark Layout

- (void)setupView {
    [super setupView];

    (void)[RBUserSettingData sharedInstance].thema; // Yes, the binary discards this read.

    // The base popup's gradation and title chrome are unused by the Applilink overlay.
    self.gradationImageView.hidden = YES;
    self.titleImageView.hidden = YES;

    // The rounded, clipped web target view hosts the advert area. It starts fully transparent and
    // fades in once the advert area has appeared.
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

    // The large spinner is centred on the content view and magnified while the area loads.
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
