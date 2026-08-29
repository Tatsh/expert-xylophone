#import "RBNotificationPageView.h"

#import "AppDelegate.h"
#import "RBUserSettingData.h"
#import "RBWebView.h"
#import "UIAlertView+RB.h"
#import "deviceenvironment.h"

// One title-bar height per satisfied condition: any non-Classic theme, and the iPad layout.
// @ghidraAddress 0x302d40, 0x2ee9b0
static const CGFloat kWebViewTitleBarInset = 32.0;

static const CGFloat kHalf = 0.5;

static const NSInteger kNetworkErrorAlertTag = 1000;

static NSString *const kDeepLinkTwitter = @"twitter://";
static NSString *const kDeepLinkOpenURL = @"openurl://";
static NSString *const kDeepLinkStoreScheme = @"rbplus://store/";
static NSString *const kHTTPScheme = @"http://";
static NSString *const kStorePackMarker = @"pack";
static const NSUInteger kStorePackPathComponentCount = 3;
static const NSUInteger kStorePackMarkerIndex = 1;
static const NSUInteger kStorePackValueIndex = 2;

static NSString *const kDisableTouchCalloutScript =
    @"document.documentElement.style.webkitTouchCallout='none';";

@implementation RBNotificationPageView

#pragma mark Lifecycle

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setMusicMenuPopupViewType:RBMusicMenuPopupViewTypeInformation];
        [self setupView];
    }
    // The binary sends this unconditionally after the init branch, so a nil self is a no-op send.
    self.isFirstRequest = YES;
    return self;
}

#pragma mark Layout

- (void)setupView {
    [super setupView];

    // Consuming the URL and the update time clears both, so the page is shown once per update.
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

    RBUserSettingDataTheme thema = [RBUserSettingData sharedInstance].thema;
    BOOL isPad = IsPad();
    CGFloat inset = (thema != RBUserSettingDataThemeClassic ? kWebViewTitleBarInset : 0.0) +
                    (isPad ? kWebViewTitleBarInset : 0.0);

    CGRect contentBounds = self.contentView.bounds;
    RBWebView *webView = [[RBWebView alloc]
        initWithFrame:CGRectMake(0, 0, contentBounds.size.width, contentBounds.size.height - inset)
            superView:self];
    webView.center = CGPointMake(contentBounds.size.width * kHalf,
                                 inset + (contentBounds.size.height - inset) * kHalf);
    webView.backgroundColor = UIColor.clearColor;
    [webView setUseGrayView:NO];

    NSURL *url = self.requestURL;
    self.requestURL = nil;
    if (url == nil) {
        url = [[AppDelegate appDelegate] getPreWebInfoURL];
    }
    [webView loadRequest:[NSURLRequest requestWithURL:url]];
    [self.contentView addSubview:webView];
    self.contentView.backgroundColor = UIColor.clearColor;
}

- (void)hideAnimation {
    if (!self.animating) {
        [super hideAnimation];
    }
}

#pragma mark Store navigation

- (void)moveStore:(id)packID {
    if (packID == nil || [packID intValue] <= 0) {
        return;
    }
    if (![self.superview respondsToSelector:@selector(SelectStoreButton)]) {
        return;
    }
    [AppDelegate appDelegate].packIDForOpenStore = packID;
    [self.superview performSelector:@selector(SelectStoreButton)];
    [self hideAnimation];
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
    // The binary compares the scheme against the full store link string, so this branch is inert.
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
        self.animating = NO;
        [self hideAnimation];
    }
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
}

- (void)alertView:(UIAlertView *)alertView willDismissWithButtonIndex:(NSInteger)buttonIndex {
}

- (void)alertViewCancel:(UIAlertView *)alertView {
}

- (void)didPresentAlertView:(UIAlertView *)alertView {
}

#pragma mark Orientation

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // The binary permits the two portrait orientations here (raw test orientation - 1 < 2).
    return interfaceOrientation == UIInterfaceOrientationPortrait ||
           interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    // The binary returns 6 (orr w0,wzr,#0x6 at 0x194148), which is the two portrait bits.
    return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
}

- (BOOL)shouldAutorotate {
    return YES;
}

@end
