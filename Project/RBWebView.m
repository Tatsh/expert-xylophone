#import "RBWebView.h"

#import "RBMacros.h"
#import "deviceenvironment.h"

static const CGFloat kGrayViewWhite = 0.9;
static const CGFloat kGrayViewAlpha = 0.5;

static const CGFloat kIndicatorScale = 1.5;

static NSString *const kReflecBeatScheme = @"reflecbeat";

static NSString *const kUrlListHosts[] = {@"link", @"store", @"openurl", @"twitter"};

enum {
    kUrlListHostLink = 0,
    kUrlListHostStore = 1,
    kUrlListHostOpenUrl = 2,
    kUrlListHostTwitter = 3,
};

static NSString *const kInAppLoadHosts[] = {
    @"stg.akx21.s.konaminet.jp",
    @"akx-new.s.konaminet.jp",
    @"akx.s.konaminet.jp",
#ifdef ENABLE_PATCHES
    // The configured API host, so a redirected build keeps its own links in-app.
    @RB_API_HOST,
#endif
};

static NSString *const kOpenUrlQuerySeparator = @"_";
static NSString *const kOpenUrlQueryPackToken = @"pack";

static const NSUInteger kOpenUrlQueryPartCount = 2;

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
#ifdef ENABLE_PATCHES
            // Walk the whole table so the configured API host in the last slot is tested too.
            BOOL loadInApp = NO;
            for (size_t index = 0; index < ARRAY_SIZE(kInAppLoadHosts); ++index) {
                if ([target.host isEqualToString:kInAppLoadHosts[index]]) {
                    loadInApp = YES;
                    break;
                }
            }
#else
            const BOOL loadInApp = [target.host isEqualToString:kInAppLoadHosts[0]] ||
                                   [target.host isEqualToString:kInAppLoadHosts[1]] ||
                                   [target.host isEqualToString:kInAppLoadHosts[2]];
#endif
            if (loadInApp) {
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
              /** @ghidraAddress 0x173cb0 */
              [self.parentView performSelector:@selector(webView:didFailLoadWithError:)
                                    withObject:webView
                                    withObject:error];
            });
        }
    }
}

@end
