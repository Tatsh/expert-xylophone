//
//  RBNotificationPageView.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RBNotificationPageView). Verified
//  against the arm64 disassembly: -setupView's theme- and idiom-dependent web-view inset
//  was recovered from the soft-float register moves the decompiler folds into pseudo-variables,
//  and -webView:shouldStartLoadWithRequest:navigationType:'s deep-link routing was read from raw
//  branch structure. This class reaches only Objective-C collaborators (no C++ engine), so it is a
//  plain Objective-C (.m) file.
//

#import "RBNotificationPageView.h"

#import "AppDelegate.h"
#import "RBUserSettingData.h"
#import "RBWebView.h"
#import "UIAlertView+RB.h"
#import "neEngineBridge.h"

// The information variant of the music-menu popup passed to -setMusicMenuPopupViewType:.
static const NSInteger kMusicMenuPopupViewTypeInformation = 7;

// The web view is inset below the title bar by one title-bar height per satisfied condition: once
// for any non-Classic theme, and once again for the iPad (wide) layout.
static const CGFloat kWebViewTitleBarInset = 32.0;

// The centre is the midpoint of the inset content region.
static const CGFloat kHalf = 0.5;

// The tag stamped on the network-error alert.
static const NSInteger kNetworkErrorAlertTag = 1000;

// The reflecbeat deep-link scheme keywords intercepted by the web view, and the store path segment
// count and marker that identify a pack link.
static NSString *const kDeepLinkTwitter = @"twitter://";
static NSString *const kDeepLinkOpenURL = @"openurl://";
static NSString *const kDeepLinkStoreScheme = @"rbplus://store/";
static NSString *const kHTTPScheme = @"http://";
static NSString *const kStorePackMarker = @"pack";
static const NSUInteger kStorePackPathComponentCount = 3;
static const NSUInteger kStorePackMarkerIndex = 1;
static const NSUInteger kStorePackValueIndex = 2;

// The JavaScript injected on load to suppress the iOS long-press touch callout.
static NSString *const kDisableTouchCalloutScript =
    @"document.documentElement.style.webkitTouchCallout='none';";

@implementation RBNotificationPageView

#pragma mark Lifecycle

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setMusicMenuPopupViewType:kMusicMenuPopupViewTypeInformation];
        [self setupView];
    }
    // The binary sends this unconditionally after the init branch, so a nil self is a no-op send.
    self.isFirstRequest = YES;
    return self;
}

#pragma mark Layout

- (void)setupView {
    [super setupView];

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

    // Prefer the just-consumed URL; fall back to the pre-release endpoint when there was none.
    NSURL *url = self.requestURL;
    self.requestURL = nil;
    if (url == nil) {
        url = appDelegate.urlPreWebInfo;
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
    // The binary permits the two portrait orientations here (raw test orientation - 1 < 2), even
    // though -supportedInterfaceOrientations reports landscape; kept faithful to each.
    return interfaceOrientation == UIInterfaceOrientationPortrait ||
           interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskLandscape;
}

- (BOOL)shouldAutorotate {
    return YES;
}

@end
