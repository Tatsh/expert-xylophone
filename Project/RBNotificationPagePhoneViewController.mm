//
//  RBNotificationPagePhoneViewController.mm
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class
//  RBNotificationPagePhoneViewController). This is the phone-side news / information page controller,
//  the counterpart of the RBNotificationPageView popup used on the pad build. Its -pushBarBtnBack:
//  plays a themed sound effect through the C++ SoundEffectManager engine singleton, so this is an
//  Objective-C++ (.mm) file. Verified against the arm64 disassembly: -viewDidLoad's spinner centre
//  is the view-bounds midpoint (the decompiler folds the soft-float register moves into pseudo
//  doubles), and -webView:shouldStartLoadWithRequest:navigationType:'s deep-link routing was read
//  from the raw branch structure.
//

#import "RBNotificationPagePhoneViewController.h"

#import "AppDelegate.h"
#import "RBUserSettingData.h"
#import "RBWebView.h"
#import "UIAlertView+RB.h"
#import "UIImage+RB.h"
#import "soundeffectmanager.h"

// The themed sound-effect slot played on cancel / back navigation.
constexpr int kSoundEffectCancel = 4;

// The tag identifying the hosted web view within the controller's view hierarchy.
constexpr NSInteger kWebViewTag = 0x2ac;

// The tag stamped on the network-error alert.
constexpr NSInteger kNetworkErrorAlertTag = 1000;

// The centre is the midpoint of the view bounds.
constexpr CGFloat kHalf = 0.5;

// The store deep link is identified by a three-component path whose first segment marks a pack and
// whose second segment carries the pack identifier.
constexpr NSUInteger kStorePackPathComponentCount = 3;
constexpr NSUInteger kStorePackMarkerIndex = 1;
constexpr NSUInteger kStorePackValueIndex = 2;

// The information-page navigation-bar title image and the Classic-theme navigation-bar background
// image.
static NSString *const kTitleBarImageName = @"21_information/information_bar";
static NSString *const kClassicNavBarImageName = @"06_search/sear_bar_2";

// The reflecbeat deep-link scheme keywords intercepted by the web view, the store path marker, and
// the scheme rewrite used to open external links.
static NSString *const kDeepLinkTwitter = @"twitter://";
static NSString *const kDeepLinkOpenURL = @"openurl://";
static NSString *const kDeepLinkStoreScheme = @"rbplus://store/";
static NSString *const kHTTPScheme = @"http://";
static NSString *const kStorePackMarker = @"pack";

// The JavaScript injected on load to suppress the iOS long-press touch callout.
static NSString *const kDisableTouchCalloutScript =
    @"document.documentElement.style.webkitTouchCallout='none';";

// The spinner autoresizing mask (flexible margins around a fixed-size view), transcribed verbatim
// from the binary's raw flag value.
// @ghidraAddress 0x310460 (g_dwRBWebViewIndicatorAutoresizingMask)
static const UIViewAutoresizing kIndicatorAutoresizingMask = (UIViewAutoresizing)0x2d;

// The web view autoresizing mask (flexible width and height), transcribed verbatim from the
// binary's raw flag value.
// @ghidraAddress 0x310450 (g_dwAutoresizingMaskFlexibleAll)
static const UIViewAutoresizing kAutoresizingMaskFlexibleAll = (UIViewAutoresizing)0x3f;

@implementation RBNotificationPagePhoneViewController

#pragma mark Lifecycle

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        UIImageView *titleView =
            [[UIImageView alloc] initWithImage:[UIImage imageWithName:kTitleBarImageName]];
        self.navigationItem.titleView = titleView;

        UIButton *backButton = [UIButton buttonWithType:UIButtonTypeSystem];
        // The binary's title is a two-byte private-use glyph; it renders as no visible text.
        [backButton setTitle:@"" forState:UIControlStateNormal];
        [backButton addTarget:self
                       action:@selector(pushBarBtnBack:)
             forControlEvents:UIControlEventTouchUpInside];
        [backButton sizeToFit];
        self.navigationItem.leftBarButtonItem =
            [[UIBarButtonItem alloc] initWithCustomView:backButton];
    }
    return self;
}

// The binary's -dealloc only chains to super; under ARC that teardown is automatic, so no explicit
// -dealloc is needed.

- (void)viewDidLoad {
    [super viewDidLoad];

    AppDelegate *appDelegate = [AppDelegate appDelegate];

    // Consume the pending news web-info URL and remember the last-update time as the read time,
    // then clear both so the page is only shown once per update.
    if (appDelegate.urlWebInfo != nil) {
        self.requestURL = appDelegate.urlWebInfo;
    }
    if (appDelegate.infoLastUpdateTimeString != nil) {
        [RBUserSettingData sharedInstance].infoLastReadTimeString =
            appDelegate.infoLastUpdateTimeString;
    }
    [[RBUserSettingData sharedInstance] save];
    appDelegate.urlWebInfo = nil;
    appDelegate.infoLastUpdateTimeString = nil;

    self.view.backgroundColor = UIColor.whiteColor;

    // The loading spinner, centred on the view bounds.
    UIActivityIndicatorView *indicator = [[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    [indicator startAnimating];
    CGRect bounds = self.view.bounds;
    indicator.center = CGPointMake(bounds.size.width * kHalf, bounds.size.height * kHalf);
    indicator.autoresizingMask = kIndicatorAutoresizingMask;
    [self.view addSubview:indicator];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [self.navigationController setNavigationBarHidden:NO animated:YES];
    UINavigationBar *navigationBar = self.navigationController.navigationBar;
    if ([RBUserSettingData sharedInstance].thema == RBUserSettingDataThemeClassic) {
        navigationBar.tintColor = UIColor.whiteColor;
        navigationBar.barTintColor = UIColor.blackColor;
        if ([navigationBar respondsToSelector:@selector(setBackgroundImage:forBarMetrics:)]) {
            [navigationBar setBackgroundImage:[UIImage imageWithName:kClassicNavBarImageName]
                                forBarMetrics:UIBarMetricsDefault];
        }
    } else {
        navigationBar.tintColor = nil;
        navigationBar.barTintColor = UIColor.whiteColor;
        if ([navigationBar respondsToSelector:@selector(setBackgroundImage:forBarMetrics:)]) {
            [navigationBar setBackgroundImage:nil forBarMetrics:UIBarMetricsDefault];
        }
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    RBWebView *webView = (RBWebView *)[self.view viewWithTag:kWebViewTag];
    if (webView == nil) {
        webView = [[RBWebView alloc] initWithFrame:self.view.bounds superView:self.view];
        webView.tag = kWebViewTag;
        [self.view addSubview:webView];
    }
    webView.autoresizingMask = kAutoresizingMaskFlexibleAll;

    // Prefer the just-consumed URL; fall back to the pre-release endpoint when there was none.
    NSURL *url = self.requestURL;
    self.requestURL = nil;
    if (url == nil) {
        url = [AppDelegate appDelegate].urlPreWebInfo;
    }
    [webView loadRequest:[NSURLRequest requestWithURL:url]];
}

- (void)viewDidDisappear:(BOOL)animated {
    UIView *webView = [self.view viewWithTag:kWebViewTag];
    if (webView != nil) {
        [[self.view viewWithTag:kWebViewTag] removeFromSuperview];
    }
    [super viewDidDisappear:animated];
}

#pragma mark Navigation

- (void)pushBarBtnBack:(id)sender {
    [self.navigationController setNavigationBarHidden:YES animated:YES];
    SoundEffectManager::GetInstance()->PlayThemedSoundEffect(kSoundEffectCancel);
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)forceClose {
    [self.navigationController setNavigationBarHidden:YES animated:NO];
    [self.navigationController popViewControllerAnimated:NO];
}

#pragma mark UIWebViewDelegate

- (BOOL)webView:(UIWebView *)webView
    shouldStartLoadWithRequest:(NSURLRequest *)request
                navigationType:(UIWebViewNavigationType)navigationType {
    if (navigationType != UIWebViewNavigationTypeLinkClicked || request.URL == nil) {
        return YES;
    }
    NSString *absoluteString = request.URL.absoluteString;
    NSURL *url = request.URL;
    if ([absoluteString rangeOfString:kDeepLinkTwitter].location != NSNotFound) {
        return YES;
    }
    if ([absoluteString rangeOfString:kDeepLinkOpenURL].location != NSNotFound) {
        NSString *httpString = [absoluteString stringByReplacingOccurrencesOfString:kDeepLinkOpenURL
                                                                         withString:kHTTPScheme];
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:httpString]];
        return NO;
    }
    // The binary compares the URL scheme against the full store link string; kept faithfully even
    // though the scheme alone never equals it, so this branch is effectively inert.
    if (![url.scheme isEqualToString:kDeepLinkStoreScheme]) {
        return YES;
    }
    NSDictionary *packInfo = nil;
    if (url.pathComponents.count == kStorePackPathComponentCount &&
        [url.pathComponents[kStorePackMarkerIndex] isEqualToString:kStorePackMarker]) {
        packInfo = @{kStorePackMarker : url.pathComponents[kStorePackValueIndex]};
    }
    if ([self respondsToSelector:@selector(clickPackInfomation:)]) {
        [self performSelector:@selector(clickPackInfomation:) withObject:packInfo];
    }
    return NO;
}

- (void)webViewDidStartLoad:(UIWebView *)webView {
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    self.isFirstRequest = NO;
    [webView stringByEvaluatingJavaScriptFromString:kDisableTouchCalloutScript];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    UIAlertView *alert = [UIAlertView showNetworkErrorWithDelegate:self];
    alert.tag = kNetworkErrorAlertTag;
    [alert show];
}

#pragma mark UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (self.isFirstRequest) {
        [self pushBarBtnBack:nil];
    }
}

@end
