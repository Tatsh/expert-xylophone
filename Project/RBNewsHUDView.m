#import "RBNewsHUDView.h"

#import <QuartzCore/QuartzCore.h>

#import "RBUserSettingData.h"

// The dimming cover is the first entry of the global UIColor palette built by
// InitializeUIColorPalette (@0x5517c): 50%-translucent black (red, green, and blue components 0
// with alpha 0.5). It is a cross-file palette global; it is rebuilt here rather than re-declared
// as a shared extern until the palette globals are recovered.
static const CGFloat kCoverAlpha = 0.5;

// The overlay and its loaded image flex in every direction so the HUD tracks its host's bounds.
// @ghidraAddress 0x310450 (g_dwAutoresizingMaskFlexibleAll)
static const UIViewAutoresizing kAutoresizingMaskFlexibleAll =
    UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth |
    UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin |
    UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;

// The loading indicator and the loaded image stay centred: only their margins flex.
// @ghidraAddress 0x310460 (g_dwRBWebViewIndicatorAutoresizingMask)
static const UIViewAutoresizing kIndicatorAutoresizingMask =
    UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
    UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;

// The single-tap dismiss gesture requires exactly one tap of one finger.
static const NSUInteger kDismissTapCount = 1;
static const NSUInteger kDismissTouchCount = 1;

// The centre of the host bounds is at half its width and height.
static const CGFloat kCentreScale = 0.5;

// The show/hide cross-fade runs for a fifth of a second.
// @ghidraAddress 0x2eedc0 (g_dMascotMessageAnimDuration)
static const NSTimeInterval kFadeDuration = 0.2;

// The HUD is fully transparent before it fades in and fully opaque after.
static const CGFloat kAlphaHidden = 0.0;
static const CGFloat kAlphaVisible = 1.0;

// The loaded image scales up from just under half size, overshoots slightly past full size, and
// settles at the identity transform, over half a second.
static const CGFloat kImageScaleStart = 0.5;
static const CGFloat kImageScaleOvershoot = 1.1;
static const NSTimeInterval kImageScaleDuration = 0.5;

// The keyframe times for the three-stage scale-up.
static const CGFloat kImageKeyTimeStart = 0.0;
static const CGFloat kImageKeyTimeOvershoot = 0.4;
static const CGFloat kImageKeyTimeSettle = 0.5;

// The identity Z scale used by both intermediate transforms.
static const CGFloat kImageScaleZ = 1.0;

// The key under which the scale keyframe animation is added to the image layer. The binary names
// it after the bounds even though it drives the transform key path.
static NSString *const kImageAnimationKey = @"boundsAnimation";
static NSString *const kImageAnimationKeyPath = @"transform";

@implementation RBNewsHUDView {
    // Whether the HUD may be dismissed yet; set once the image loads or a download fails.
    BOOL m_CanHide;
    // The news item's information identifier, persisted once the image has been shown.
    int m_InfomationID;
}

#pragma mark - Lifecycle

- (instancetype)initWithFrame:(CGRect)frame {
    /** @ghidraAddress 0xbe3d4 */
    self = [super initWithFrame:frame];
    if (self) {
        [self setupView];
    }
    return self;
}

#pragma mark - Layout

- (void)setupView {
    /** @ghidraAddress 0xbe448 */
    self.backgroundColor = [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:kCoverAlpha];
    self.autoresizingMask = kAutoresizingMaskFlexibleAll;

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                          action:@selector(tapped)];
    tap.numberOfTapsRequired = kDismissTapCount;
    tap.numberOfTouchesRequired = kDismissTouchCount;
    [self addGestureRecognizer:tap];

    UIActivityIndicatorView *indicator = [[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    // Both bounds components are re-read from a fresh call, as the binary does.
    indicator.center =
        CGPointMake(self.bounds.size.width * kCentreScale, self.bounds.size.height * kCentreScale);
    indicator.autoresizingMask = kIndicatorAutoresizingMask;
    [indicator startAnimating];
    [self addSubview:indicator];
}

#pragma mark - Animation

- (void)showAnimation {
    /** @ghidraAddress 0xbe5f0 */
    self.hidden = NO;
    self.alpha = kAlphaHidden;
    [UIView animateWithDuration:kFadeDuration
        animations:^{
          /** @ghidraAddress 0xbe6f4 */
          self.alpha = kAlphaVisible;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0xbe718 */
          self.alpha = kAlphaVisible;
        }];
}

- (void)hideAnimation {
    /** @ghidraAddress 0xbe73c */
    if (m_CanHide) {
        [UIView animateWithDuration:kFadeDuration
            animations:^{
              /** @ghidraAddress 0xbe824 */
              self.alpha = kAlphaHidden;
            }
            completion:^(BOOL finished) {
              /** @ghidraAddress 0xbe848 */
              self.alpha = kAlphaHidden;
              self.hidden = YES;
              [self removeFromSuperview];
            }];
    }
}

#pragma mark - Actions

- (void)tapped {
    /** @ghidraAddress 0xbe8a8 */
    [self hideAnimation];
}

#pragma mark - News image

- (void)showImage:(NSString *)showImage InfomationID:(int)InfomationID {
    /** @ghidraAddress 0xbe8b4 */
    m_CanHide = NO;
    m_InfomationID = InfomationID;

    ImageDownloader *downloader = [[ImageDownloader alloc] init];
    downloader.imageURL = showImage;
    downloader.delegate = self;
    [downloader startDownload];

    [self showAnimation];
}

#pragma mark - ImageDownloaderDelegate

- (void)imageDownloader:(ImageDownloader *)imageDownloader didLoad:(NSIndexPath *)didLoad {
    /** @ghidraAddress 0xbe99c */
    UIImageView *imageView = [[UIImageView alloc] initWithImage:[imageDownloader getImage]];
    // Both bounds components are re-read from a fresh call, as the binary does.
    imageView.center =
        CGPointMake(self.bounds.size.width * kCentreScale, self.bounds.size.height * kCentreScale);
    imageView.autoresizingMask = kIndicatorAutoresizingMask;
    [self addSubview:imageView];

    NSArray *keyTimes = @[
        @(kImageKeyTimeStart),
        @(kImageKeyTimeOvershoot),
        @(kImageKeyTimeSettle),
    ];
    NSArray *timingFunctions = @[
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear],
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear],
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear],
    ];
    CATransform3D startTransform =
        CATransform3DMakeScale(kImageScaleStart, kImageScaleStart, kImageScaleZ);
    CATransform3D overshootTransform =
        CATransform3DMakeScale(kImageScaleOvershoot, kImageScaleOvershoot, kImageScaleZ);
    NSArray *values = @[
        [NSValue valueWithCATransform3D:startTransform],
        [NSValue valueWithCATransform3D:overshootTransform],
        [NSValue valueWithCATransform3D:CATransform3DIdentity],
    ];

    CAKeyframeAnimation *animation =
        [CAKeyframeAnimation animationWithKeyPath:kImageAnimationKeyPath];
    animation.keyTimes = keyTimes;
    animation.values = values;
    animation.timingFunctions = timingFunctions;
    animation.calculationMode = kCAAnimationLinear;
    animation.duration = kImageScaleDuration;
    [imageView.layer addAnimation:animation forKey:kImageAnimationKey];

    m_CanHide = YES;

    if ([[RBUserSettingData sharedInstance] newsInfomationID] < m_InfomationID) {
        [[RBUserSettingData sharedInstance] setNewsInfomationID:m_InfomationID];
        [[RBUserSettingData sharedInstance] save];
    }
}

- (void)imageDownloaderDidFail:(ImageDownloader *)imageDownloaderDidFail
                       didLoad:(NSIndexPath *)didLoad {
    /** @ghidraAddress 0xbeff8 */
    m_CanHide = YES;
    [self hideAnimation];
}

@end
