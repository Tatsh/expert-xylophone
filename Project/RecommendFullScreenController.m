//
//  RecommendFullScreenController.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RecommendFullScreenController).
//  The layout maths in -setViewSize and the rotation transform in -rotateWebViewWithDuration: were
//  recovered from the arm64 disassembly, whose soft-float register moves the decompiler folds into
//  pseudo-variables. This is a plain Objective-C file: the class is a pure UIViewController
//  subclass that reaches its collaborators through ordinary message sends, with no C++.
//

#import "RecommendFullScreenController.h"

#import <UIKit/UIKit.h>

#import "ApplilinkCore.h"
#import "ApplilinkNetworkError.h"
#import "ApplilinkParameters.h"
#import "RecommendAdAreaView.h"
#import "RecommendAdCache.h"
#import "ShadeView.h"

// The advert-type identifier the interstitial always opens its advert area with (external area).
static const int kRecommendInterstitialAdType = 5;

// The Applilink error code reported when the advert HTML body could not be created on disk.
static const NSInteger kApplilinkErrorHtmlFileCreate = 1035;

// Below this screen edge length (in points) the interstitial base view uses half-size factors.
static const CGFloat kRecommendNarrowScreenThreshold = 320.0;

// The base-view sizing factors, indexed by whether the interface orientation is landscape. Each
// pair is {portrait, landscape}.
static const CGFloat kRecommendBaseWidthFactor[] = {608.0, 632.0};
static const CGFloat kRecommendBaseHeightFactor[] = {844.0, 784.0};
static const CGFloat kRecommendBaseMargin1[] = {24.0, 4.0};
static const CGFloat kRecommendBaseMargin2[] = {8.0, 4.0};

// The system version at and above which the SDK trusts the Xcode 6 orientation-aware bounds.
static const CGFloat kRecommendXcode6SystemVersion = 8.0;

// The system version below which the status bar height must be subtracted from the shade origin.
static const CGFloat kRecommendStatusBarInsetSystemVersion = 7.0;

// The interstitial base view fades into place a tenth of a second after the advert appears.
static const int64_t kRecommendShowBaseViewDelayNanoseconds = 100000000;

// The supported interface orientation mask: portrait, upside down, and both landscapes.
static const UIInterfaceOrientationMask kRecommendSupportedOrientations =
    UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown |
    UIInterfaceOrientationMaskLandscapeLeft | UIInterfaceOrientationMaskLandscapeRight;

// The class metadata declares conformance to the closed-SDK ApplilinkViewDelegate and
// ShadeViewDelegate protocols. ApplilinkViewDelegate is only forward-declared in the reconstructed
// tree, so its callbacks are implemented here and dispatched dynamically; ShadeViewDelegate is
// defined in ShadeView.h and is adopted formally.
@interface RecommendFullScreenController () <ShadeViewDelegate>

// The advert base view that hosts the advert area, sized for the current orientation.
@property(nonatomic, strong, nullable) UIView *baseView;
// The full-screen shade view that dims the screen behind the advert.
@property(nonatomic, strong, nullable) ShadeView *shadeView;
// The large loading spinner shown while the advert area loads.
@property(nonatomic, strong, nullable) UIActivityIndicatorView *indicator;
// The advert request parameters the interstitial was opened with.
@property(nonatomic, strong, nullable) ApplilinkParameters *applilinkParams;
// The advert delegate notified of the advert lifecycle and failures.
@property(nonatomic, weak, nullable) id applilinkDelegate;
// The full-view delegate (the presenting RecommendCore) asked to release this controller on close.
@property(nonatomic, weak, nullable) id applilinkFullViewDelegate;

@end

@implementation RecommendFullScreenController

#pragma mark - Lifecycle

/** @ghidraAddress 0x246804 */
- (instancetype)init {
    return [super init];
}

/** @ghidraAddress 0x246840 */
- (void)loadView {
    [super loadView];
    self.view.userInteractionEnabled = YES;
    self.view.backgroundColor = [UIColor clearColor];
}

/** @ghidraAddress 0x246934 */
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

/** @ghidraAddress 0x248164 */
- (void)dealloc {
    if (self.indicator) {
        [self.indicator stopAnimating];
        [self.indicator removeFromSuperview];
    }
    self.indicator = nil;
    self.baseView = nil;
    self.shadeView = nil;
    self.applilinkDelegate = nil;
    self.applilinkFullViewDelegate = nil;
}

#pragma mark - Presentation

/** @ghidraAddress 0x246970 */
- (void)openAdViewWithAdModel:(int)adModel
                   adLocation:(NSString *)adLocation
                verticalAlign:(int)verticalAlign
              applilinkParams:(ApplilinkParameters *)applilinkParams
                     delegate:(id)delegate
                closeDelegate:(id)closeDelegate {
    self.applilinkParams = applilinkParams;
    self.isVisible = NO;
    [self setViewSize];
    [self rotateWebViewWithDuration:0.0];
    (void)self.baseView.frame; // Yes, the binary reads and discards this frame.
    self.applilinkDelegate = delegate;
    self.applilinkFullViewDelegate = closeDelegate;

    NSError *createError = [RecommendAdCache createHtmlWithAdModel:adModel
                                                       adLocation:adLocation
                                                    verticalAlign:verticalAlign];
    if (createError) {
        [ApplilinkCore toDelegateFailOpenWithError:createError
                                          appParam:self.applilinkParams
                                          delegate:delegate];
        [self releaseInterstitialView];
        return;
    }

    NSString *contentPath = [[RecommendAdCache getContentsPath]
        stringByAppendingPathComponent:[NSString stringWithFormat:@"%d_%@.html", adModel,
                                                                   adLocation]];
    BOOL isDirectory = NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath:contentPath isDirectory:&isDirectory]) {
        NSError *missingError = [ApplilinkNetworkError
            localizedApplilinkErrorWithCode:kApplilinkErrorHtmlFileCreate
                                   userInfo:@{@"html file create error": @"Error"}];
        [ApplilinkCore toDelegateFailOpenWithError:missingError
                                          appParam:applilinkParams
                                          delegate:self.applilinkDelegate];
        [self releaseInterstitialView];
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
      /** @ghidraAddress 0x246d84 */
      RecommendAdAreaView *adView =
          [[RecommendAdAreaView alloc] initWithFrame:self.baseView.frame];
      [adView setAdModel:adModel
              adLocation:adLocation
                  adType:kRecommendInterstitialAdType
             requestCode:self.applilinkParams.requestCode
                delegate:self];
      [adView startPath:contentPath];
      [self.baseView addSubview:adView];
      [self webViewDidStartLoad];
    });
}

/**
 * Lay out the shade view over the whole screen and the advert base view centred within it, sized
 * for the current interface orientation, the status bar, and the running iOS version.
 * @ghidraAddress 0x246fb4
 */
- (void)setViewSize {
    UIInterfaceOrientation orientation =
        [UIApplication sharedApplication].statusBarOrientation;
    (void)[UIScreen mainScreen].bounds; // Yes, the binary reads and discards these bounds.
    CGRect screenBounds = [UIScreen mainScreen].bounds;
    CGFloat screenWidth = screenBounds.size.width;
    CGFloat screenHeight = screenBounds.size.height;

    // The status bar thickness is the smaller of its reported frame's height and width, so it is
    // correct in either orientation.
    CGFloat statusBar = [UIApplication sharedApplication].statusBarFrame.size.height;
    CGFloat statusBarWidth = [UIApplication sharedApplication].statusBarFrame.size.width;
    if (statusBar > statusBarWidth) {
        statusBar = [UIApplication sharedApplication].statusBarFrame.size.width;
    }

    BOOL isLandscape = (orientation == UIInterfaceOrientationLandscapeLeft ||
                        orientation == UIInterfaceOrientationLandscapeRight);
    NSUInteger factor = isLandscape ? 1 : 0;
    CGFloat baseWidthFactor = kRecommendBaseWidthFactor[factor];
    CGFloat baseHeightFactor = kRecommendBaseHeightFactor[factor];
    CGFloat margin1 = kRecommendBaseMargin1[factor];
    CGFloat margin2 = kRecommendBaseMargin2[factor];
    if (screenWidth <= kRecommendNarrowScreenThreshold ||
        screenHeight <= kRecommendNarrowScreenThreshold) {
        baseWidthFactor *= 0.5;
        baseHeightFactor *= 0.5;
        margin1 *= 0.5;
        margin2 *= 0.5;
    }

    BOOL isXcode6 = [ApplilinkCore isBuildXcode6];
    CGFloat systemVersion = [[UIDevice currentDevice].systemVersion floatValue];

    CGRect shadeFrame = CGRectMake(screenBounds.origin.x, screenBounds.origin.y,
                                   screenWidth, screenHeight);
    CGRect baseFrame;
    if (isLandscape) {
        if (isXcode6 && systemVersion >= kRecommendXcode6SystemVersion) {
            // The Xcode 6 SDK reports orientation-aware bounds, so the height spans the long edge.
            CGFloat scale =
                (float)(((screenHeight - statusBar) - margin1 - margin2) / baseWidthFactor);
            CGFloat baseW = (float)(baseHeightFactor * scale);
            CGFloat baseH = (float)(baseWidthFactor * scale);
            CGFloat baseX = (screenWidth - baseW) * 0.5;
            CGFloat baseY = statusBar + ((screenHeight - baseH) - statusBar) * 0.5;
            baseFrame = CGRectMake(baseX, baseY, baseW, baseH);
        } else {
            // The legacy SDK reports portrait bounds, so the width and height roles are swapped.
            CGFloat scale =
                (float)(((screenWidth - statusBar) - margin1 - margin2) / baseWidthFactor);
            CGFloat baseW = (float)(baseHeightFactor * scale);
            CGFloat baseH = (float)(baseWidthFactor * scale);
            CGFloat baseX = (screenHeight - baseW) * 0.5;
            CGFloat baseY = statusBar + ((screenWidth - baseH) - statusBar) * 0.5;
            baseFrame = CGRectMake(baseX, baseY, baseW, baseH);
            // The shade fills the reported (portrait) bounds, rotated by the transform later.
            shadeFrame.size = CGSizeMake(screenHeight, screenWidth);
            if (systemVersion < kRecommendStatusBarInsetSystemVersion) {
                shadeFrame.origin.y = statusBar;
            }
        }
    } else {
        CGFloat scale =
            (float)(((screenWidth - statusBar) - margin1 - margin2) / baseWidthFactor);
        CGFloat baseW = (float)(baseWidthFactor * scale);
        CGFloat baseH = (float)(baseHeightFactor * scale);
        CGFloat baseX = (screenWidth - baseW) * 0.5;
        CGFloat baseY = statusBar + ((screenHeight - baseH) - statusBar) * 0.5;
        baseFrame = CGRectMake(baseX, baseY, baseW, baseH);
        if (systemVersion < kRecommendStatusBarInsetSystemVersion) {
            shadeFrame.origin.y = statusBar;
        }
    }

    if (self.shadeView) {
        [self.shadeView setFrame:shadeFrame];
    } else {
        self.shadeView = [[ShadeView alloc] initWithFrame:shadeFrame];
        self.shadeView.delegate = self;
        self.shadeView.hidden = YES;
        self.shadeView.userInteractionEnabled = NO;
        [self.view addSubview:self.shadeView];
    }

    if (self.baseView) {
        [self.baseView setFrame:baseFrame];
        return;
    }
    self.baseView = [[UIView alloc] initWithFrame:baseFrame];
    self.baseView.backgroundColor = [UIColor clearColor];
    self.baseView.hidden = YES;
    [self.shadeView addSubview:self.baseView];
}

/**
 * Rotate and resize the controller's view to match the current interface orientation over the
 * given duration, animating the transform on the legacy status-bar path only.
 * @ghidraAddress 0x247674
 */
- (void)rotateWebViewWithDuration:(double)duration {
    [self setViewSize];
    BOOL isXcode6 = [ApplilinkCore isBuildXcode6];
    CGFloat systemVersion = [[UIDevice currentDevice].systemVersion floatValue];
    if (systemVersion >= kRecommendXcode6SystemVersion && isXcode6) {
        // The Xcode 6 SDK lays the shade out in the reported orientation; no transform is needed.
        return;
    }

    UIInterfaceOrientation orientation =
        [UIApplication sharedApplication].statusBarOrientation;
    CGFloat systemVersionAgain = [[UIDevice currentDevice].systemVersion floatValue];
    CGFloat statusBarInset = 0.0;
    if (systemVersionAgain < kRecommendStatusBarInsetSystemVersion) {
        CGFloat statusBarWidth = [UIApplication sharedApplication].statusBarFrame.size.width;
        CGFloat statusBarHeight = [UIApplication sharedApplication].statusBarFrame.size.height;
        BOOL isLandscape = (orientation == UIInterfaceOrientationLandscapeLeft ||
                            orientation == UIInterfaceOrientationLandscapeRight);
        statusBarInset = isLandscape ? statusBarWidth : statusBarHeight;
    }

    CGRect shadeFrame = self.shadeView.frame;
    CGAffineTransform transform;
    switch (orientation) {
        case UIInterfaceOrientationPortraitUpsideDown:
            transform = CGAffineTransformMakeRotation(M_PI);
            break;
        case UIInterfaceOrientationLandscapeLeft:
            transform = CGAffineTransformMakeRotation(M_PI_2);
            break;
        case UIInterfaceOrientationLandscapeRight:
            transform = CGAffineTransformMakeRotation(-M_PI_2);
            break;
        default:
            transform = CGAffineTransformMakeRotation(0.0);
            break;
    }

    [UIView animateWithDuration:duration
                     animations:^{
                       /** @ghidraAddress 0x2479c4 */
                       self.view.transform = transform;
                       [self.view setBounds:CGRectMake(shadeFrame.origin.x, statusBarInset,
                                                       shadeFrame.size.width,
                                                       shadeFrame.size.height)];
                     }];
}

/** @ghidraAddress 0x2480a8 */
- (void)releaseInterstitialView {
    if (self.applilinkFullViewDelegate) {
        if ([self.applilinkFullViewDelegate
                respondsToSelector:@selector(releaseInterstitialViewController)]) {
            [self.applilinkFullViewDelegate
                performSelector:@selector(releaseInterstitialViewController)];
            self.applilinkFullViewDelegate = nil;
        }
    }
    self.isVisible = NO;
}

/** @ghidraAddress 0x248010 */
- (void)closeShadeView {
    [ApplilinkCore toDelegateDidDisappear:self.applilinkParams delegate:self.applilinkDelegate];
    self.applilinkDelegate = nil;
    [self releaseInterstitialView];
}

#pragma mark - Rotation

/** @ghidraAddress 0x246efc */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orientation {
    if (![self shouldAutorotate]) {
        return NO;
    }
    UIInterfaceOrientationMask mask;
    switch (orientation) {
        case UIInterfaceOrientationPortrait:
            mask = UIInterfaceOrientationMaskPortrait;
            break;
        case UIInterfaceOrientationPortraitUpsideDown:
            mask = UIInterfaceOrientationMaskPortraitUpsideDown;
            break;
        case UIInterfaceOrientationLandscapeLeft:
            mask = UIInterfaceOrientationMaskLandscapeLeft;
            break;
        case UIInterfaceOrientationLandscapeRight:
            mask = UIInterfaceOrientationMaskLandscapeRight;
            break;
        default:
            return NO;
    }
    return ([self supportedInterfaceOrientations] & mask) != 0;
}

/** @ghidraAddress 0x246fa4 */
- (BOOL)shouldAutorotate {
    return YES;
}

/** @ghidraAddress 0x246fac */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return kRecommendSupportedOrientations;
}

/** @ghidraAddress 0x247a90 */
- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)orientation
                                         duration:(NSTimeInterval)duration {
    [self rotateWebViewWithDuration:duration];
}

#pragma mark - ApplilinkViewDelegate

/** @ghidraAddress 0x247aa0 */
- (void)webViewDidStartLoad {
    self.shadeView.hidden = NO;
    [RecommendFullScreenController cancelPreviousPerformRequestsWithTarget:self];
    [[ApplilinkCore mainWindow] addSubview:self.view];
    self.isVisible = YES;
    [ApplilinkCore toDelegateDidStart:self.applilinkParams delegate:self.applilinkDelegate];
}

/** @ghidraAddress 0x247bc0 */
- (void)appListDidAppear {
    [ApplilinkCore toDelegateDidAppear:self.applilinkParams delegate:self.applilinkDelegate];
    if (self.indicator) {
        [self.indicator stopAnimating];
        [self.indicator removeFromSuperview];
    }
    self.indicator = nil;
    [RecommendFullScreenController cancelPreviousPerformRequestsWithTarget:self];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, kRecommendShowBaseViewDelayNanoseconds),
                   dispatch_get_main_queue(), ^{
                     /** @ghidraAddress 0x247d08 */
                     self.shadeView.userInteractionEnabled = YES;
                     self.shadeView.hidden = NO;
                     self.baseView.hidden = NO;
                   });
}

/** @ghidraAddress 0x247d90 */
- (void)appListDidDisappear {
    [self closeShadeView];
}

/** @ghidraAddress 0x247da0 */
- (void)appListFailLoadWithError:(NSError *)error {
    [ApplilinkCore toDelegateFailLoadWithError:error
                                      appParam:self.applilinkParams
                                      delegate:self.applilinkDelegate];
    self.applilinkDelegate = nil;
    [self releaseInterstitialView];
}

/** @ghidraAddress 0x247e50 */
- (void)appListFailLinkWithError:(NSError *)error {
    [ApplilinkCore toDelegateFailLinkWithError:error
                                      appParam:self.applilinkParams
                                      delegate:self.applilinkDelegate];
}

/** @ghidraAddress 0x247ed4 */
- (void)openedNotice {
    [self appListDidAppear];
}

/** @ghidraAddress 0x247ee4 */
- (void)closeNotice {
    [self appListDidDisappear];
}

/** @ghidraAddress 0x247ef4 */
- (void)failOpenNoticeWithError:(NSError *)error {
    [ApplilinkCore toDelegateFailLoadWithError:error
                                      appParam:self.applilinkParams
                                      delegate:self.applilinkDelegate];
    self.applilinkDelegate = nil;
}

/** @ghidraAddress 0x247f8c */
- (void)failLinkNoticeWithError:(NSError *)error {
    [ApplilinkCore toDelegateFailLinkWithError:error
                                      appParam:self.applilinkParams
                                      delegate:self.applilinkDelegate];
}

@end
