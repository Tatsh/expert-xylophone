//
//  RBCorporateViewController.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RBCorporateViewController). This is
//  a plain Objective-C (.m) file: it presents Konami's corporate web page in an RBWebView and never
//  reaches the C++ engine. The -viewDidLoad spinner centring was read from the arm64 disassembly,
//  where the decompiler folds the soft-float register moves into pseudo doubles.
//

#import "RBCorporateViewController.h"

#import "RBWebView.h"
#import "UIAlertView+RB.h"

// The alert tag stamped on the network-error alert this controller presents.
static const NSInteger kNetworkErrorAlertTag = 1000;

// The activity-indicator style: the classic small grey spinner.
static const UIActivityIndicatorViewStyle kIndicatorStyle = UIActivityIndicatorViewStyleGray;

// The corporate page loaded into the web view.
// @ghidraAddress 0x33c03a
static NSString *const kCorporatePageURL = @"https://www.konami.com/ja/";

// The JavaScript injected once the page finishes loading to suppress the iOS touch callout.
// @ghidraAddress 0x33c055
static NSString *const kSuppressTouchCalloutScript =
    @"document.documentElement.style.webkitTouchCallout='none';";

// The loading spinner's autoresizing mask, transcribed verbatim from the binary's raw flag value.
// @ghidraAddress 0x310460 (g_dwRBWebViewIndicatorAutoresizingMask)
static const UIViewAutoresizing kIndicatorAutoresizingMask = (UIViewAutoresizing)0x2d;

// The web view's autoresizing mask (flexible in every dimension), transcribed verbatim from the
// binary's raw flag value.
// @ghidraAddress 0x310450 (g_dwAutoresizingMaskFlexibleAll)
static const UIViewAutoresizing kWebViewAutoresizingMask = (UIViewAutoresizing)0x3f;

// The spinner is centred on the view by halving each of the view's bounds dimensions.
static const CGFloat kHalf = 0.5;

@implementation RBCorporateViewController

#pragma mark Lifecycle

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        UIButton *backButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [backButton setTitle:NSLocalizedString(@"Done", @"") forState:UIControlStateNormal];
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

    self.view.backgroundColor = UIColor.whiteColor;

    // The loading spinner, centred on the view and animating from the outset.
    UIActivityIndicatorView *indicator =
        [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:kIndicatorStyle];
    [indicator startAnimating];
    indicator.center =
        CGPointMake(self.view.bounds.size.width * kHalf, self.view.bounds.size.height * kHalf);
    indicator.autoresizingMask = kIndicatorAutoresizingMask;
    [self.view addSubview:indicator];
    self.indicator = indicator;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [self.navigationController setNavigationBarHidden:NO animated:YES];
    (void)self.navigationController.navigationBar; // Yes, the binary discards this fetch's result.
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    RBWebView *webView = self.webView;
    if (webView == nil) {
        webView = [[RBWebView alloc] initWithFrame:self.view.bounds superView:self.view];
        [self.view addSubview:webView];
        self.webView = webView;
    }
    webView.autoresizingMask = kWebViewAutoresizingMask;
    [webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:kCorporatePageURL]]];
}

- (void)viewDidDisappear:(BOOL)animated {
    if (self.webView != nil) {
        [self.webView removeFromSuperview];
        self.webView = nil;
    }
    [super viewDidDisappear:animated];
}

#pragma mark Navigation

- (void)pushBarBtnBack:(id)sender {
    [self.indicator stopAnimating];
    [self.navigationController setNavigationBarHidden:YES animated:YES];
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)forceClose {
    [self.indicator stopAnimating];
    [self.navigationController setNavigationBarHidden:YES animated:NO];
    [self.navigationController popViewControllerAnimated:NO];
}

#pragma mark Web view delegate

- (BOOL)webView:(UIWebView *)webView
    shouldStartLoadWithRequest:(NSURLRequest *)request
                navigationType:(UIWebViewNavigationType)navigationType {
    [self.indicator startAnimating];
    return YES;
}

- (void)webViewDidStartLoad:(UIWebView *)webView {
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    self.isFirstRequest = NO;
    [self.indicator stopAnimating];
    [webView stringByEvaluatingJavaScriptFromString:kSuppressTouchCalloutScript];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    [self.indicator stopAnimating];
    UIAlertView *alert = [UIAlertView showNetworkErrorWithDelegate:self];
    alert.tag = kNetworkErrorAlertTag;
    [alert show];
}

#pragma mark Alert view delegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (self.isFirstRequest) {
        [self pushBarBtnBack:nil];
    }
}

@end
