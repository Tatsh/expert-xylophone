//
//  RBWebView.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RBWebView). Verified against the
//  arm64 disassembly: -initWithFrame:superView:'s soft-float colour, indicator transform, and
//  autoresizing-mask constants, and the navigation allow-list in
//  -webView:shouldStartLoadWithRequest:navigationType:, were recovered from the register moves the
//  decompiler folds into pseudo-variables.
//

#import "RBWebView.h"

#import "neEngineBridge.h"

// The white component and alpha of the translucent loading cover shown over the content.
static const CGFloat kGrayViewWhite = 0.9;
static const CGFloat kGrayViewAlpha = 0.5;

// The scale applied to the activity indicator through its layer's transform.scale key path.
static const CGFloat kIndicatorScale = 1.5;

// The custom URL scheme whose hosts this view interprets rather than loading directly.
static NSString *const kReflecBeatScheme = @"reflecbeat";

// The recognised reflecbeat scheme hosts, seeded into urlList in priority order.
static NSString *const kUrlListHosts[] = {@"link", @"store", @"openurl", @"twitter"};

// urlList index of each recognised reflecbeat scheme host.
enum {
    kUrlListHostLink = 0,
    kUrlListHostStore = 1,
    kUrlListHostOpenUrl = 2,
    kUrlListHostTwitter = 3,
};

// The konaminet hosts whose links are loaded inside this web view rather than opened externally.
static NSString *const kInAppLoadHosts[] = {
    @"stg.akx21.s.konaminet.jp",
    @"akx-new.s.konaminet.jp",
    @"akx.s.konaminet.jp",
};

// The separator between the parts of a reflecbeat://openurl query, and the leading part that
// selects the move-to-store action.
static NSString *const kOpenUrlQuerySeparator = @"_";
static NSString *const kOpenUrlQueryPackToken = @"pack";

// The number of parts a well-formed reflecbeat://openurl query splits into.
static const NSUInteger kOpenUrlQueryPartCount = 2;

// JavaScript run on every finished page to suppress the iOS long-press callout menu.
static NSString *const kDisableTouchCalloutScript =
    @"document.documentElement.style.webkitTouchCallout='none';";

@implementation RBWebView

- (instancetype)initWithFrame:(CGRect)frame superView:(id)superView {
    self = [super initWithFrame:frame];
    if (self) {
        self.grayView = [[UIView alloc] initWithFrame:frame];
        self.grayView.backgroundColor = [UIColor colorWithWhite:kGrayViewWhite
                                                          alpha:kGrayViewAlpha];
        self.grayView.hidden = YES;
        [self addSubview:self.grayView];

        self.indicatorView = [[UIActivityIndicatorView alloc] init];
        [self.indicatorView.layer setValue:@(kIndicatorScale) forKeyPath:@"transform.scale"];
        self.indicatorView.center = self.center;
        self.indicatorView.autoresizingMask =
            UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
            UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
        [self addSubview:self.indicatorView];

        self.delegate = self;
        self.dataDetectorTypes = UIDataDetectorTypeNone;
        [self stringByEvaluatingJavaScriptFromString:kDisableTouchCalloutScript];
        self.parentView = superView;
        self.urlList = [[NSMutableArray alloc] initWithObjects:kUrlListHosts[kUrlListHostLink],
                                                               kUrlListHosts[kUrlListHostStore],
                                                               kUrlListHosts[kUrlListHostOpenUrl],
                                                               kUrlListHosts[kUrlListHostTwitter],
                                                               nil];
    }
    return self;
}

- (void)setUseGrayView:(BOOL)useGrayView {
    self.isUseGrayView = useGrayView;
}

#pragma mark - WebResourceLoadDelegate

- (id)uiWebView:(id)uiWebView
            resource:(id)resource
     willSendRequest:(id)willSendRequest
    redirectResponse:(id)redirectResponse
      fromDataSource:(id)fromDataSource {
    [willSendRequest setValue:GetDeviceDescriptionString() forHTTPHeaderField:@"User-Agent"];
    return willSendRequest;
}

#pragma mark - UIWebViewDelegate

- (BOOL)webView:(UIWebView *)webView
    shouldStartLoadWithRequest:(NSURLRequest *)request
                navigationType:(UIWebViewNavigationType)navigationType {
    if (navigationType != UIWebViewNavigationTypeLinkClicked) {
        return YES;
    }

    NSURL *url = request.URL;
    if (!url || !url.query || url.query.length == 0) {
        return NO;
    }

    if (![url.scheme isEqualToString:kReflecBeatScheme]) {
        return YES;
    }

    if ([url.host isEqualToString:self.urlList[kUrlListHostLink]]) {
        NSURL *target = [NSURL URLWithString:url.query];
        if (target) {
            if ([target.host isEqualToString:kInAppLoadHosts[0]] ||
                [target.host isEqualToString:kInAppLoadHosts[1]] ||
                [target.host isEqualToString:kInAppLoadHosts[2]]) {
                [self loadRequest:[NSURLRequest requestWithURL:target]];
            } else {
                [[UIApplication sharedApplication] openURL:target];
            }
        }
        return NO;
    }

    if ([url.host isEqualToString:self.urlList[kUrlListHostStore]]) {
        NSURL *target = [NSURL URLWithString:url.query];
        if (target) {
            [[UIApplication sharedApplication] openURL:target];
        }
        return NO;
    }

    if ([url.host isEqualToString:self.urlList[kUrlListHostOpenUrl]]) {
        NSArray *parts = [url.query componentsSeparatedByString:kOpenUrlQuerySeparator];
        if (!parts) {
            return NO;
        }
        if (parts.count != kOpenUrlQueryPartCount) {
            return NO;
        }
        if ([parts[0] isEqualToString:kOpenUrlQueryPackToken]) {
            if ([self.parentView respondsToSelector:@selector(moveStore:)]) {
                [self.parentView performSelector:@selector(moveStore:) withObject:parts[1]];
                return NO;
            }
        }
        return YES;
    }

    [url.host isEqualToString:self.urlList[kUrlListHostTwitter]];
    return YES;
}

- (void)webViewDidStartLoad:(UIWebView *)webView {
    if (self.isUseGrayView) {
        self.grayView.hidden = NO;
    }
    [self.indicatorView startAnimating];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    if (self.isUseGrayView) {
        self.grayView.hidden = YES;
    }
    [self.indicatorView stopAnimating];
    if (self.parentView) {
        if ([self.parentView respondsToSelector:@selector(webViewDidFinishLoad:)]) {
            [self.parentView performSelectorOnMainThread:@selector(webViewDidFinishLoad:)
                                              withObject:webView
                                           waitUntilDone:NO];
        }
    }
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    if (self.isUseGrayView) {
        self.grayView.hidden = YES;
    }
    [self.indicatorView stopAnimating];
    if (self.parentView) {
        if ([self.parentView respondsToSelector:@selector(webView:didFailLoadWithError:)]) {
            dispatch_async(dispatch_get_main_queue(), ^{
              /** @ghidraAddress 0x73cb0 */
              [self.parentView performSelector:@selector(webView:didFailLoadWithError:)
                                    withObject:webView
                                    withObject:error];
            });
        }
    }
}

@end
