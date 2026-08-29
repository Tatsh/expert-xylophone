#import "RBNotificationPagePhoneViewController.h"

#import "AppDelegate.h"
#import "RBUserSettingData.h"
#import "RBWebView.h"
#import "UIAlertView+RB.h"
#import "UIImage+RB.h"
#import "soundeffectmanager.h"

constexpr int kSoundEffectCancel = 4;

constexpr NSInteger kWebViewTag = 0x2ac;

constexpr NSInteger kNetworkErrorAlertTag = 1000;

constexpr CGFloat kHalf = 0.5;

constexpr NSUInteger kStorePackPathComponentCount = 3;
constexpr NSUInteger kStorePackMarkerIndex = 1;
constexpr NSUInteger kStorePackValueIndex = 2;

static NSString *const kTitleBarImageName = @"21_information/information_bar";
static NSString *const kClassicNavBarImageName = @"06_search/sear_bar_2";

static NSString *const kDeepLinkTwitter = @"twitter://";
static NSString *const kDeepLinkOpenURL = @"openurl://";
static NSString *const kDeepLinkStoreScheme = @"rbplus://store/";
static NSString *const kHTTPScheme = @"http://";
static NSString *const kStorePackMarker = @"pack";

static NSString *const kDisableTouchCalloutScript =
    @"document.documentElement.style.webkitTouchCallout='none';";

// @ghidraAddress 0x310460 (g_dwRBWebViewIndicatorAutoresizingMask)
static const UIViewAutoresizing kIndicatorAutoresizingMask = (UIViewAutoresizing)0x2d;

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

- (void)viewDidLoad {
    [super viewDidLoad];

    // Both are cleared so the page is only shown once per update.
    if ([[AppDelegate appDelegate] getWebInfoURL] != nil) {
        self.requestURL = [[AppDelegate appDelegate] getWebInfoURL];
    }
    if ([[AppDelegate appDelegate] getInfoLastUpdateTimeString] != nil) {
        [RBUserSettingData sharedInstance].infoLastReadTimeString =
            [[AppDelegate appDelegate] getInfoLastUpdateTimeString];
    }
    [[RBUserSettingData sharedInstance] save];
    [[AppDelegate appDelegate] setWebInfoURL:nil];
    [AppDelegate appDelegate].infoLastUpdateTimeString = nil;

    self.view.backgroundColor = UIColor.whiteColor;

    UIActivityIndicatorView *indicator = [[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    [indicator startAnimating];
    indicator.center =
        CGPointMake(self.view.bounds.size.width * kHalf, self.view.bounds.size.height * kHalf);
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

    NSURL *url = self.requestURL;
    self.requestURL = nil;
    if (url == nil) {
        url = [[AppDelegate appDelegate] getPreWebInfoURL];
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
    // The scheme alone never equals the full store link string, so this branch is inert.
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
