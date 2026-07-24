//
//  RewardWebViewController.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458.
//  See RewardWebViewController.h for the class overview.
//

#import "RewardWebViewController.h"

#import <UIKit/UIKit.h>

#import "ApplilinkCore.h"
#import "ApplilinkIndicator.h"
#import "ApplilinkMessage.h"
#import "ApplilinkUtilities.h"
#import "RewardCore.h"

// The status-bar-relative vertical inset applied to the base view: 44 points when the navigation
// bar is shown, 0 when it is hidden.
static const CGFloat kNavigationBarInsetShown = 44.0;
static const CGFloat kNavigationBarInsetHidden = 0.0;

// The delay, in seconds, before the loading overlay switches to its touch-active state.
static const NSTimeInterval kIndicatorActivationDelay = 45.0;

// The mutable request's timeout, in seconds.
static const NSTimeInterval kRequestTimeout = 30.0;

// The message-table keys for the navigation-bar title and close button.
static NSString *const kAppListTitleKey = @"RewardNetworkAppListTitle";
static NSString *const kAppListCloseButtonKey = @"RewardNetworkAppListCloseButton";

// The advert page signals a close either through a "close" navigation or a "command=close" query.
static NSString *const kCloseNavigation = @"close";
static NSString *const kCloseNavigationPrefix = @"close:";
static NSString *const kCloseCommandQuery = @"command=close";

// The system version at and above which the navigation bar is tinted and the modern rotation path
// is used.
static const float kSystemVersionIOS7 = 7.0f;
static const float kSystemVersionIOS8 = 8.0f;

// The redirect dispositions returned by RewardCore -redirectWithRequest:.
enum {
    kRedirectAllow = 0,    // Continue loading the request.
    kRedirectHandled = 1,  // The redirect was handled internally; still load the request.
    kRedirectExternal = 3, // The redirect opened elsewhere; cancel the request.
};

// The web-view load states stored in webViewStatus.
enum {
    kWebViewStatusIdle = 0,     // No load has started.
    kWebViewStatusLoading = 1,  // A load is in progress.
    kWebViewStatusFinished = 2, // The load has finished.
};

// Web-view/URL error codes handled specially in -webView:didFailLoadWithError:.
enum {
    kWebErrorCancelled = -999,       // NSURLErrorCancelled; always ignored.
    kWebErrorNotConnected = -1009,   // NSURLErrorNotConnectedToInternet; a post-load link failure.
    kWebErrorPlugInLoadFailed = 204, // WebKit plug-in load failure; ignored on the WebKit domain.
    kWebErrorFrameLoadFailed = 102,  // WebKit frame-load failure; ignored on the WebKit domain.
};

@interface RewardWebViewController () <UIWebViewDelegate>

// Set once the view has disappeared or been closed, so a subsequent -loadView just detaches the
// stale view instead of rebuilding it.
@property(nonatomic) BOOL viewCloseFlg;

// Whether the web view's scroll view is allowed to bounce. The stored value is inverted: it is
// cleared after -loadView applies it to the scroll view.
@property(nonatomic) BOOL webViewBounces;

// The reference bounds the layout is derived from, captured in -loadView.
@property(nonatomic) CGRect baseFrame;

- (void)updateIndicator:(BOOL)show;
- (void)activeWebView;
- (int)redirectWithRequest:(NSURLRequest *)request;
- (void)appListDidStart;
- (void)appListDidAppear;
- (void)appListDidDisappear;
- (void)appListFailLoadWithError:(NSError *)error;
- (void)appListFailLinkWithError:(NSError *)error;
- (void)btnCloseClicked:(id)sender;
- (void)viewDealloc;
- (BOOL)hasParentViewController:(UIResponder *)responder;
- (void)rotateWebViewWithInterfaceOrientation:(UIInterfaceOrientation)orientation
                                     duration:(NSTimeInterval)duration;

@end

@implementation RewardWebViewController

#pragma mark - Lifecycle

// @ 0x21c910
- (instancetype)init {
    return [super init];
}

// @ 0x21d0f0
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

// @ 0x21d12c
- (void)viewDidLoad {
    [super viewDidLoad];
    if ([self respondsToSelector:@selector(setNeedsStatusBarAppearanceUpdate)]) {
        [self setNeedsStatusBarAppearanceUpdate];
    }
}

// @ 0x21c94c
- (void)loadView {
    [super loadView];
    // When the view was closed, this reload just detaches the stale view and returns.
    if (_viewCloseFlg) {
        _viewCloseFlg = NO;
        [self.view removeFromSuperview];
        return;
    }
    _baseFrame = self.view.bounds;
    self.view.userInteractionEnabled = YES;
    self.view.backgroundColor = UIColor.whiteColor;

    BOOL navigationBarHidden = self.isNavigationBarHidden;
    (void)[UIScreen mainScreen].bounds; // Yes, the binary evaluates and discards this.
    if (_parentView) {
        _baseFrame = _parentView.frame;
    }

    self.baseView = [[UIView alloc] init];
    self.baseView.backgroundColor = UIColor.whiteColor;
    self.baseView.autoresizingMask =
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight |
        UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin |
        UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    CGFloat inset = navigationBarHidden ? kNavigationBarInsetHidden : kNavigationBarInsetShown;
    self.baseView.frame =
        CGRectMake(0, inset, _baseFrame.size.width, _baseFrame.size.height - inset);

    self.webView = [[UIWebView alloc]
        initWithFrame:CGRectMake(0, 0, _baseFrame.size.width, _baseFrame.size.height - inset)];
    self.webView.delegate = self;
    self.webView.backgroundColor = UIColor.whiteColor;
    if (self.webView) {
        self.webView.scrollView.bounces = !_webViewBounces;
    }
    _webViewBounces = NO;

    [self.view addSubview:self.baseView];
    [self.baseView addSubview:self.webView];

    if (!navigationBarHidden) {
        self.navigationBar = [[UINavigationBar alloc] initWithFrame:CGRectZero];
        UINavigationItem *item = [[UINavigationItem alloc]
            initWithTitle:[ApplilinkMessage localizedMessage:kAppListTitleKey]];
        item.leftBarButtonItem = [[UIBarButtonItem alloc]
            initWithTitle:[ApplilinkMessage localizedMessage:kAppListCloseButtonKey]
                    style:UIBarButtonItemStyleDone
                   target:self
                   action:@selector(btnCloseClicked:)];
        if (![ApplilinkCore isNavigationBarCommonAppearance]) {
            if ([[UIDevice currentDevice].systemVersion floatValue] >= kSystemVersionIOS7) {
                self.navigationBar.barTintColor = UIColor.whiteColor;
            }
        }
        [self.navigationBar pushNavigationItem:item animated:NO];
        [self.view addSubview:self.navigationBar];

        self.indicator = [[ApplilinkIndicator alloc] initWithFrame:self.view.bounds];
        [self.view addSubview:self.indicator];
    }

    [self
        rotateWebViewWithInterfaceOrientation:[UIApplication sharedApplication].statusBarOrientation
                                     duration:0.0];
    [self appListDidStart];
}

// @ 0x21f1f8
- (void)dealloc {
    [self clearDelegate];
    _viewCloseFlg = NO;
    // The binary's -[super dealloc] is elided: ARC synthesises the superclass teardown and the
    // strong-ivar release (the binary's .cxx_destruct at 0x21f498).
}

// @ 0x21d1a8
- (void)viewDidDisappear:(BOOL)animated {
    _viewCloseFlg = YES;
}

#pragma mark - Status bar and rotation

// @ 0x21d2dc
- (BOOL)prefersStatusBarHidden {
    return YES;
}

// @ 0x21e0d0
- (BOOL)shouldAutorotate {
    return YES;
}

// @ 0x21e0d8
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

// @ 0x21e028
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orientation {
    if (![self shouldAutorotate]) {
        return NO;
    }
    // The binary tests the raw (1 << orientation) bit against the supported mask rather than the
    // semantic UIInterfaceOrientationMask* constant, so the landscape bits do not line up with the
    // named masks; reproduce the shift faithfully.
    NSUInteger bit;
    switch (orientation) {
    case UIInterfaceOrientationPortrait:
    case UIInterfaceOrientationPortraitUpsideDown:
    case UIInterfaceOrientationLandscapeLeft:
    case UIInterfaceOrientationLandscapeRight:
        bit = (NSUInteger)1 << orientation;
        break;
    default:
        return NO;
    }
    return ([self supportedInterfaceOrientations] & bit) != 0;
}

// @ 0x21efec
- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)orientation
                                         duration:(NSTimeInterval)duration {
    [self
        rotateWebViewWithInterfaceOrientation:[UIApplication sharedApplication].statusBarOrientation
                                     duration:duration];
}

// Lays the base view, navigation bar, web view, and indicator out to follow the interface
// orientation, compensating for the status-bar inset and, on the pre-iOS 8 path, applying a manual
// rotation transform to a free-standing (window or detached) presentation. The original is a long
// branch-heavy frame-arithmetic routine keyed on system version, Xcode-6 build, and hosting mode;
// this reconstruction preserves that structure and the observable frames rather than every
// intermediate register.
// @ 0x21e0e0
- (void)rotateWebViewWithInterfaceOrientation:(UIInterfaceOrientation)orientation
                                     duration:(NSTimeInterval)duration {
    CGRect screenBounds = [UIScreen mainScreen].bounds;
    if ([[UIDevice currentDevice].systemVersion floatValue] < kSystemVersionIOS7) {
        screenBounds = [UIScreen mainScreen].applicationFrame;
    }
    CGFloat width = screenBounds.size.width;
    CGFloat height = screenBounds.size.height;

    // Determine the status-bar inset. It is dropped for a hidden navigation bar on iOS 7+ and for a
    // hosted (non-window, parented) presentation.
    CGFloat statusInset;
    BOOL hosted = _parentView && ![_parentView isKindOfClass:[UIWindow class]] &&
                  [ApplilinkUtilities hasParentViewController:_parentView];
    if (self.isNavigationBarHidden &&
        [[UIDevice currentDevice].systemVersion floatValue] >= kSystemVersionIOS7) {
        statusInset = 0.0;
    } else if (hosted) {
        statusInset = 0.0;
    } else {
        CGRect statusBarFrame = [UIApplication sharedApplication].statusBarFrame;
        statusInset = statusBarFrame.size.height;
        if (width < statusInset) {
            statusInset = width;
        }
    }

    // The manual rotation transform is only applied on the pre-iOS 8 (or non-Xcode 6 build) path,
    // where UIKit does not rotate the window's content for us.
    BOOL legacyRotation =
        [[UIDevice currentDevice].systemVersion floatValue] < kSystemVersionIOS8 ||
        ![ApplilinkCore isBuildXcode6];
    CGFloat portraitWidth = MIN(width, height);
    CGFloat portraitHeight = MAX(width, height);
    if (legacyRotation) {
        CGAffineTransform transform;
        CGFloat viewWidth = portraitWidth;
        CGFloat viewHeight = portraitHeight;
        switch (orientation) {
        case UIInterfaceOrientationPortraitUpsideDown:
            transform = CGAffineTransformMakeRotation((CGFloat)M_PI);
            break;
        case UIInterfaceOrientationLandscapeLeft:
            transform = CGAffineTransformMakeRotation((CGFloat)(-M_PI_2));
            viewWidth = portraitHeight;
            viewHeight = portraitWidth;
            break;
        case UIInterfaceOrientationLandscapeRight:
            transform = CGAffineTransformMakeRotation((CGFloat)M_PI_2);
            viewWidth = portraitHeight;
            viewHeight = portraitWidth;
            break;
        default:
            transform = CGAffineTransformMakeRotation(0);
            break;
        }
        if (hosted) {
            self.view.bounds = CGRectMake(0, statusInset, viewWidth, viewHeight);
        } else {
            CGRect boundsRect = CGRectMake(0, statusInset, viewWidth, viewHeight);
            [UIView animateWithDuration:duration
                             animations:^{
                               /** @ghidraAddress 0x20a768 */
                               self.view.transform = transform;
                               self.view.bounds = boundsRect;
                             }];
        }
    }

    // Re-align the view frame for the current orientation and status inset.
    CGFloat originX = 0.0;
    CGFloat originY = 0.0;
    CGFloat viewWidth = _baseFrame.size.width;
    CGFloat viewHeight = _baseFrame.size.height;
    if (_parentView) {
        viewWidth = _parentView.frame.size.width;
        viewHeight = _parentView.frame.size.height;
    }
    if (statusInset > 0.0) {
        float version = [[UIDevice currentDevice].systemVersion floatValue];
        if (version >= kSystemVersionIOS7) {
            if (version >= kSystemVersionIOS8 && [ApplilinkCore isBuildXcode6]) {
                UIInterfaceOrientation now = [UIApplication sharedApplication].statusBarOrientation;
                if (now == UIInterfaceOrientationLandscapeRight) {
                    originX = statusInset;
                    originY = 0.0;
                } else if (now == UIInterfaceOrientationPortrait) {
                    originX = 0.0;
                    originY = statusInset;
                    viewHeight -= statusInset;
                }
            }
        } else {
            UIInterfaceOrientation now = [UIApplication sharedApplication].statusBarOrientation;
            if (now == UIInterfaceOrientationLandscapeRight) {
                originX = statusInset;
            } else if (now == UIInterfaceOrientationPortrait) {
                originY = statusInset;
            }
        }
    }
    self.view.frame = CGRectMake(originX, originY, viewWidth, viewHeight);

    CGFloat baseInset = statusInset;
    CGRect baseFrame = self.baseView.frame;
    if (self.isNavigationBarHidden) {
        [self.navigationBar removeFromSuperview];
        baseFrame = self.baseView.frame;
        baseFrame.origin.y = statusInset;
        baseFrame.size.height -= statusInset;
    } else {
        [self.navigationBar sizeToFit];
        baseFrame = self.baseView.frame;
        CGRect navFrame = self.navigationBar.frame;
        baseInset = statusInset + navFrame.size.height;
        baseFrame.origin.y = baseInset;
        baseFrame.size.height -= baseInset;
        self.navigationBar.frame =
            CGRectMake(navFrame.origin.x, statusInset, navFrame.size.width, navFrame.size.height);
    }
    self.baseView.frame = baseFrame;

    self.indicator.frame = self.view.bounds;
    // The web view fills the base view starting from its origin.
    self.webView.frame =
        CGRectMake(0, 0, self.baseView.frame.size.width, self.baseView.frame.size.height);
}

#pragma mark - Loading

// @ 0x21d2e4
- (void)loadRequestWithURL:(NSString *)url parameters:(NSDictionary *)parameters {
    self.webViewStatus = kWebViewStatusIdle;
    _viewCloseFlg = NO;
    if (_parentView) {
        [_parentView addSubview:self.view];
    } else {
        UIWindow *mainWindow = [ApplilinkCore mainWindow];
        if (mainWindow) {
            [mainWindow addSubview:self.view];
        }
    }

    NSString *full = [ApplilinkUtilities appendParametersToURL:url parameters:parameters];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:full]];
    request.timeoutInterval = kRequestTimeout;
    request.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;

    if (!self.webView) {
        [self loadView];
    }
    [self
        rotateWebViewWithInterfaceOrientation:[UIApplication sharedApplication].statusBarOrientation
                                     duration:0.0];
    [self.webView loadRequest:request];
}

#pragma mark - Indicator

// @ 0x21d620
- (void)updateIndicator:(BOOL)show {
    if (!self.indicator) {
        return;
    }
    if (show) {
        [self.indicator show];
        [RewardWebViewController cancelPreviousPerformRequestsWithTarget:self];
        [self performSelector:@selector(activeWebView)
                   withObject:nil
                   afterDelay:kIndicatorActivationDelay];
        return;
    }
    [self.indicator close];
    [RewardWebViewController cancelPreviousPerformRequestsWithTarget:self];
}

// @ 0x21d6e4
- (void)activeWebView {
    if (self.indicator) {
        [self.indicator touchEventActived];
    }
}

#pragma mark - UIWebViewDelegate

// @ 0x21da8c
- (BOOL)webView:(UIWebView *)webView
    shouldStartLoadWithRequest:(NSURLRequest *)request
                navigationType:(UIWebViewNavigationType)navigationType {
    int redirect = [self redirectWithRequest:request];
    if (!self.isNavigationBarHidden) {
        if (redirect == kRedirectExternal) {
            return NO;
        }
        if (redirect == kRedirectAllow) {
            [self btnCloseClicked:nil];
            return NO;
        }
    }
    if (request) {
        NSString *absolute = request.URL.absoluteString;
        if ([absolute isEqualToString:kCloseNavigation] ||
            [request.URL.absoluteString hasPrefix:kCloseNavigationPrefix]) {
            [self btnCloseClicked:nil];
            return NO;
        }
    }
    return redirect == kRedirectHandled;
}

// @ 0x21d71c
- (void)webViewDidStartLoad:(UIWebView *)webView {
    if (self.webViewStatus == kWebViewStatusIdle) {
        self.webViewStatus = kWebViewStatusLoading;
    }
    [self updateIndicator:YES];
}

// @ 0x21d748
- (void)webViewDidFinishLoad:(UIWebView *)webView {
    self.webViewStatus = kWebViewStatusFinished;
    [self updateIndicator:NO];
    NSString *query = webView.request.URL.query;
    if (query && [query rangeOfString:kCloseCommandQuery].location != NSNotFound) {
        [self btnCloseClicked:nil];
    } else {
        [self appListDidAppear];
    }
}

// @ 0x21d87c
- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    [self updateIndicator:NO];
    if (error.code == kWebErrorCancelled) {
        return;
    }
    if (error.code == kWebErrorPlugInLoadFailed && [error.domain isEqual:@"WebKitErrorDomain"]) {
        return;
    }
    if (error.code == kWebErrorFrameLoadFailed && [error.domain isEqual:@"WebKitErrorDomain"]) {
        return;
    }
    if (self.webViewStatus == kWebViewStatusFinished && error.code == kWebErrorNotConnected) {
        NSError *linkError = [NSError errorWithDomain:error.domain code:error.code userInfo:nil];
        [self appListFailLinkWithError:linkError];
    } else {
        [self appListFailLoadWithError:error];
        [self btnCloseClicked:nil];
    }
}

// @ 0x21dc30
- (int)redirectWithRequest:(NSURLRequest *)request {
    return [[RewardCore sharedInstance] redirectWithRequest:request];
}

#pragma mark - Close and teardown

// @ 0x21d570
- (void)btnCloseClicked:(id)sender {
    [self appListDidDisappear];
}

// @ 0x21d580
- (void)appliListClosed {
    [RewardWebViewController cancelPreviousPerformRequestsWithTarget:self];
    if (_viewCloseFlg) {
        return;
    }
    _viewCloseFlg = YES;
    if (self.webView.isLoading) {
        [self.webView stopLoading];
    }
    [self viewDealloc];
}

// @ 0x21d1bc
- (void)viewDealloc {
    [self.indicator removeFromSuperview];
    if (self.webView) {
        self.webView.delegate = nil;
        [self.webView removeFromSuperview];
    }
    [self.navigationBar removeFromSuperview];
    self.indicator = nil;
    self.navigationBar = nil;
    self.webView = nil;
    self.parentView = nil;
    [self.view removeFromSuperview];
}

// @ 0x21f19c
- (void)clearDelegate {
    self.sdkDelegate = nil;
    if (self.webView) {
        self.webView.delegate = nil;
    }
}

// This SDK-facing alias forwards to the isNavigationBarHidden property setter.
// @ 0x21d2cc
- (void)setNavigationBarHidden:(BOOL)navigationBarHidden {
    _isNavigationBarHidden = navigationBarHidden;
}

// The backing store is inverted: the getter returns the raw flag but the setter stores its
// complement, so a caller asking to enable bounces clears the stored value that -loadView negates.
// @ 0x21d708
- (void)setWebViewBounces:(BOOL)webViewBounces {
    _webViewBounces = !webViewBounces;
}

#pragma mark - Delegate notices

// @ 0x21dcb4
- (void)appListDidStart {
    if (self.sdkDelegate && [self.sdkDelegate respondsToSelector:@selector(startedNotice)]) {
        [self.sdkDelegate startedNotice];
    }
}

// @ 0x21dd58
- (void)appListDidAppear {
    if (self.sdkDelegate && [self.sdkDelegate respondsToSelector:@selector(openedNotice)]) {
        [self.sdkDelegate openedNotice];
    }
}

// @ 0x21ddfc
- (void)appListDidDisappear {
    if (self.sdkDelegate) {
        if ([self.sdkDelegate respondsToSelector:@selector(closeNotice)]) {
            [self.sdkDelegate closeNotice];
        }
        self.sdkDelegate = nil;
    }
}

// @ 0x21deac
- (void)appListFailLoadWithError:(NSError *)error {
    if (self.sdkDelegate) {
        if ([self.sdkDelegate respondsToSelector:@selector(failOpenNoticeWithError:)]) {
            [self.sdkDelegate failOpenNoticeWithError:error];
        }
        self.sdkDelegate = nil;
    }
}

// @ 0x21df70
- (void)appListFailLinkWithError:(NSError *)error {
    if (self.sdkDelegate &&
        [self.sdkDelegate respondsToSelector:@selector(failLinkNoticeWithError:)]) {
        [self.sdkDelegate failLinkNoticeWithError:error];
    }
}

#pragma mark - Responder chain

// Walks a responder up its chain to decide whether it resolves to a presentable host: a window,
// application, or view controller counts directly; a plain view recurses to its next responder.
// @ 0x21f068
- (BOOL)hasParentViewController:(UIResponder *)responder {
    if ([responder isKindOfClass:[UIWindow class]] ||
        [responder isKindOfClass:[UIApplication class]]) {
        return NO;
    }
    if ([responder isKindOfClass:[UIView class]]) {
        return [self hasParentViewController:[responder nextResponder]];
    }
    return [responder isKindOfClass:[UIViewController class]];
}

@end
