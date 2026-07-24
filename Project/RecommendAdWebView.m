#import "RecommendAdWebView.h"

#import "ApplilinkConsts.h"
#import "ApplilinkCore.h"
#import "ApplilinkNetworkError.h"
#import "ApplilinkParameters.h"
#import "ApplilinkUdid.h"
#import "ApplilinkUtilities.h"
#import "RecommendCore.h"
#import "RecommendWebAPI.h"

// Applilink error codes reported through appListFailLoadWithError:.
enum {
    RecommendAdWebViewErrorCodeSdkUnavailable = 0x401,     // SDK not usable on this environment.
    RecommendAdWebViewErrorCodeAdTrackingDisabled = 0x404, // Advertising tracking is disabled.
    RecommendAdWebViewErrorCodeNoAd = 0x40a,               // No recommend advert is available.
    RecommendAdWebViewErrorCodeLoadCancelled = 0x40b,      // The advert load was cancelled.
};

// Banner-detail status returned by RecommendWebAPI getBannerDetailWithAdModel:callback:.
enum {
    RecommendAdWebViewBannerStatusHasAd = 1,
};

// Web-view load status stored in webViewStatus.
enum {
    RecommendAdWebViewStatusIdle = 0,
    RecommendAdWebViewStatusStarted = 1,
    RecommendAdWebViewStatusFinished = 2,
};

// Advert models whose banner enables free scrolling rather than a fixed advert area.
enum {
    RecommendAdWebViewAdModelScrollableBanner = 1,
    RecommendAdWebViewAdModelScrollableInterstitial = 4,
};

// UIWebView cancellation and policy-change error codes ignored during the advert load.
enum {
    RecommendAdWebViewWebKitFrameLoadInterrupted = 102,     // 0x66
    RecommendAdWebViewWebKitPlugInWillHandleLoad = 204,     // 0xcc
    RecommendAdWebViewURLErrorCancelled = -999,             // NSURLErrorCancelled
    RecommendAdWebViewURLErrorFrameLoadInterrupted = -1009, // NSURLErrorNotConnectedToInternet
};

// Web-view request timeout, in seconds, for advert loads.
static const NSTimeInterval kRecommendAdWebViewTimeout = 30.0;

@implementation RecommendAdWebView

#pragma mark - Initialisation

/** @ghidraAddress 0x21691c */
- (instancetype)init {
    self = [super init];
    if (self) {
        [self setInitParam];
    }
    return self;
}

/** @ghidraAddress 0x216980 */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setInitParam];
    }
    return self;
}

/** @ghidraAddress 0x2169e4 */
- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self setInitParam];
    }
    return self;
}

/** @ghidraAddress 0x216a48 */
- (void)setInitParam {
    self.backgroundColor = UIColor.clearColor;
    self.opaque = NO;
    self.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth |
                            UIViewAutoresizingFlexibleRightMargin |
                            UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleHeight |
                            UIViewAutoresizingFlexibleBottomMargin;
    self.contentMode = UIViewContentModeScaleAspectFit;
    _loadComplete = YES;
    _reloadFlg = NO;
    _cancelFlg = NO;
    _scrollFlg = NO;
}

#pragma mark - Teardown

/** @ghidraAddress 0x216b24 */
- (void)removeFromSuperview {
    _cancelFlg = YES;
    [self unloadRecommendView];
    if (_applilinkDelegate) {
        _applilinkDelegate = nil;
    }
    if (self.delegate) {
        self.delegate = nil;
    }
    [super removeFromSuperview];
}

/** @ghidraAddress 0x218f0c */
- (void)dealloc {
    if (_applilinkDelegate) {
        _applilinkDelegate = nil;
    }
    if (self.delegate) {
        self.delegate = nil;
    }
}

#pragma mark - Loading

/** @ghidraAddress 0x216c00 */
- (void)loadRequestWithAdModel:(int)adModel
                    adLocation:(NSString *)adLocation
                 verticalAlign:(int)verticalAlign
                   requestCode:(id)requestCode
                      delegate:(id<ApplilinkViewDelegate>)delegate {
    _adModel = adModel;
    if (adLocation == nil) {
        _adLocation = nil;
    } else {
        _adLocation = [NSString stringWithFormat:@"%@", adLocation];
    }
    _verticalAlign = verticalAlign;
    _requestCode = requestCode;
    _applilinkDelegate = delegate;
    if (adModel == RecommendAdWebViewAdModelScrollableBanner ||
        adModel == RecommendAdWebViewAdModelScrollableInterstitial) {
        [self setScrollBarEnabled:YES];
    } else {
        if (!_scrollFlg) {
            [self setScrollBoundsEnabled:NO];
        }
        [self setScrollBarEnabled:NO];
    }
    [self loadRequest];
}

/** @ghidraAddress 0x216d88 */
- (void)loadRequest {
    _webViewStatus = RecommendAdWebViewStatusIdle;
    if (![ApplilinkConsts canUseApplilinkSdk]) {
        [self appListFailLoadWithError:
                  [ApplilinkNetworkError
                      localizedApplilinkErrorWithCode:RecommendAdWebViewErrorCodeSdkUnavailable]];
        return;
    }
    if (![ApplilinkUdid isAdvertisingTrackingEnabled]) {
        [self appListFailLoadWithError:[ApplilinkNetworkError
                                           localizedApplilinkErrorWithCode:
                                               RecommendAdWebViewErrorCodeAdTrackingDisabled]];
        return;
    }
    self.delegate = self;
    _loadComplete = NO;
    RecommendAdWebView *blockSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
      /** @ghidraAddress 0x216fdc */
      if (!blockSelf.reloadFlg) {
          blockSelf.backgroundColor = UIColor.clearColor;
          blockSelf.opaque = NO;
      }
      [[RecommendCore sharedInstance] startSessionWithCallback:^(NSError *sessionError) {
        /** @ghidraAddress 0x2170d0 */
        if (sessionError == nil) {
            if (!blockSelf.cancelFlg) {
                [RecommendWebAPI
                    getBannerDetailWithAdModel:blockSelf.adModel
                                      callback:^(NSInteger status, NSError *detailError) {
                                        /** @ghidraAddress 0x2171c8 */
                                        if (detailError != nil) {
                                            blockSelf.loadComplete = YES;
                                            [blockSelf appListFailLoadWithError:detailError];
                                            return;
                                        }
                                        if (blockSelf.cancelFlg) {
                                            blockSelf.loadComplete = YES;
                                            [blockSelf
                                                appListFailLoadWithError:
                                                    [ApplilinkNetworkError
                                                        localizedApplilinkErrorWithCode:
                                                            RecommendAdWebViewErrorCodeLoadCancelled]];
                                            return;
                                        }
                                        if (status != RecommendAdWebViewBannerStatusHasAd) {
                                            blockSelf.loadComplete = YES;
                                            [blockSelf
                                                appListFailLoadWithError:
                                                    [ApplilinkNetworkError
                                                        localizedApplilinkErrorWithCode:
                                                            RecommendAdWebViewErrorCodeNoAd]];
                                            return;
                                        }
                                        // Continues into the RecommendCore advert-list cache
                                        // step, which builds and loads the advert web request.
                                        [[RecommendCore sharedInstance]
                                            appliListCacheWithCallBack:^(id list,
                                                                         NSError *cacheError) {
                                              /** @ghidraAddress 0x217378 */
                                              (void)list;
                                              (void)cacheError;
                                            }];
                                      }];
            } else {
                blockSelf.loadComplete = YES;
                [blockSelf
                    appListFailLoadWithError:[ApplilinkNetworkError
                                                 localizedApplilinkErrorWithCode:
                                                     RecommendAdWebViewErrorCodeLoadCancelled]];
            }
        } else {
            blockSelf.loadComplete = YES;
            [blockSelf appListFailLoadWithError:sessionError];
        }
      }];
    });
}

/** @ghidraAddress 0x217b7c */
- (void)loadRequestWithURL:(NSString *)URL parameters:(NSDictionary *)parameters {
    NSString *urlString = [ApplilinkUtilities appendParametersToURL:URL parameters:parameters];
    NSMutableURLRequest *request =
        [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    request.timeoutInterval = kRecommendAdWebViewTimeout;
    request.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
    [self loadRequest:request];
}

#pragma mark - Closing

/** @ghidraAddress 0x217c90 */
- (void)closeAdArea {
    if (self.isLoading) {
        [self stopLoading];
    }
    [self appliListClosed];
}

/** @ghidraAddress 0x2184a0 */
- (void)unloadRecommendView {
    [self stopLoading];
}

/** @ghidraAddress 0x2184b4 */
- (void)appliListClosed {
    [self unloadRecommendView];
    if (_adLocation != nil) {
        _adLocation = nil;
    }
    [self appListDidDisappear];
}

/** @ghidraAddress 0x2184b0 */
- (void)viewDidDisappear:(BOOL)viewDidDisappear {
}

#pragma mark - Scrolling

/** @ghidraAddress 0x217ce4 */
- (void)setScrollEnabled:(BOOL)scrollEnabled {
    _scrollFlg = scrollEnabled;
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UIScrollView class]]) {
            UIScrollView *scrollView = (UIScrollView *)subview;
            scrollView.scrollEnabled = scrollEnabled;
            scrollView.bounces = scrollEnabled;
            for (UIView *inner in scrollView.subviews) {
                if ([inner isKindOfClass:[UIImageView class]]) {
                    inner.hidden = !scrollEnabled;
                }
            }
        }
    }
}

/** @ghidraAddress 0x217fec */
- (void)setScrollBoundsEnabled:(BOOL)scrollBoundsEnabled {
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UIScrollView class]]) {
            UIScrollView *scrollView = (UIScrollView *)subview;
            scrollView.bounces = scrollBoundsEnabled;
            for (UIView *inner in scrollView.subviews) {
                if ([inner isKindOfClass:[UIImageView class]]) {
                    inner.hidden = !scrollBoundsEnabled;
                }
            }
        }
    }
}

/** @ghidraAddress 0x2182c4 */
- (void)setScrollBarEnabled:(BOOL)scrollBarEnabled {
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UIScrollView class]]) {
            UIScrollView *scrollView = (UIScrollView *)subview;
            scrollView.showsVerticalScrollIndicator = scrollBarEnabled;
            scrollView.showsHorizontalScrollIndicator = scrollBarEnabled;
        }
    }
}

#pragma mark - UIWebViewDelegate

/** @ghidraAddress 0x218508 */
- (void)webViewDidStartLoad:(UIWebView *)webView {
    if (_webViewStatus == RecommendAdWebViewStatusIdle) {
        _webViewStatus = RecommendAdWebViewStatusStarted;
    }
    [self appListDidStart];
}

/** @ghidraAddress 0x218530 */
- (void)webViewDidFinishLoad:(UIWebView *)webView {
    _webViewStatus = RecommendAdWebViewStatusFinished;
    NSString *query = webView.request.URL.query;
    if (query == nil || [query rangeOfString:@"command=close"].location == NSNotFound) {
        _reloadFlg = YES;
        RecommendAdWebView *blockSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
          /** @ghidraAddress 0x218a70 */
          [blockSelf appListDidAppear];
        });
    } else {
        [self appliListClosed];
    }
}

/** @ghidraAddress 0x2186a4 */
- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    if (error.code == RecommendAdWebViewURLErrorCancelled) {
        return;
    }
    if (error.code == RecommendAdWebViewWebKitFrameLoadInterrupted &&
        [error.domain isEqual:@"WebKitErrorDomain"]) {
        return;
    }
    if (error.code == RecommendAdWebViewWebKitPlugInWillHandleLoad &&
        [error.domain isEqual:@"WebKitErrorDomain"]) {
        return;
    }
    NSError *reportError = [NSError errorWithDomain:error.domain code:error.code userInfo:nil];
    if (_webViewStatus == RecommendAdWebViewStatusFinished) {
        if (error.code == RecommendAdWebViewURLErrorFrameLoadInterrupted) {
            [self appListFailLinkWithError:reportError];
            return;
        }
    } else {
        [self appListFailLoadWithError:reportError];
    }
    [self appliListClosed];
}

/** @ghidraAddress 0x218894 */
- (BOOL)webView:(UIWebView *)webView
    shouldStartLoadWithRequest:(NSURLRequest *)request
                navigationType:(UIWebViewNavigationType)navigationType {
    if (request.timeoutInterval != kRecommendAdWebViewTimeout) {
        NSMutableURLRequest *mutableRequest = (NSMutableURLRequest *)request;
        mutableRequest.timeoutInterval = kRecommendAdWebViewTimeout;
        [webView loadRequest:mutableRequest];
        return NO;
    }
    int redirect = [[RecommendCore sharedInstance] redirectWithRequest:request];
    BOOL shouldLoad = redirect == 1;
    if (redirect != 1) {
        _webViewStatus = RecommendAdWebViewStatusFinished;
    }
    if (request == nil) {
        return shouldLoad;
    }
    if (![request.URL.absoluteString isEqualToString:@"close"] &&
        ![request.URL.absoluteString hasPrefix:@"close/"]) {
        return shouldLoad;
    }
    [self appListDidDisappear];
    [self appliListClosed];
    [self removeFromSuperview];
    return NO;
}

#pragma mark - Delegate notifications

/** @ghidraAddress 0x218ae0 */
- (void)appListDidStart {
    id<ApplilinkViewDelegate> delegate = _applilinkDelegate;
    if (delegate && [delegate respondsToSelector:@selector(appListDidStart)]) {
        [delegate appListDidStart];
    }
}

/** @ghidraAddress 0x218b84 */
- (void)appListDidAppear {
    ApplilinkParameters *appParam = [[ApplilinkParameters alloc] init];
    [appParam setRequestWithAdModel:_adModel adLocation:_adLocation requestCode:_requestCode];
    [ApplilinkCore toDelegateDidAppear:appParam delegate:_applilinkDelegate];
}

/** @ghidraAddress 0x218c4c */
- (void)appListDidDisappear {
    ApplilinkParameters *appParam = [[ApplilinkParameters alloc] init];
    [appParam setRequestWithAdModel:_adModel adLocation:_adLocation requestCode:_requestCode];
    [ApplilinkCore toDelegateDidDisappear:appParam delegate:_applilinkDelegate];
    _applilinkDelegate = nil;
}

/** @ghidraAddress 0x218d24 */
- (void)appListFailLoadWithError:(NSError *)error {
    ApplilinkParameters *appParam = [[ApplilinkParameters alloc] init];
    [appParam setRequestWithAdModel:_adModel adLocation:_adLocation requestCode:_requestCode];
    [ApplilinkCore toDelegateFailLoadWithError:error appParam:appParam delegate:_applilinkDelegate];
    _applilinkDelegate = nil;
}

/** @ghidraAddress 0x218e24 */
- (void)appListFailLinkWithError:(NSError *)error {
    ApplilinkParameters *appParam = [[ApplilinkParameters alloc] init];
    [appParam setRequestWithAdModel:_adModel adLocation:_adLocation requestCode:_requestCode];
    [ApplilinkCore toDelegateFailLinkWithError:error appParam:appParam delegate:_applilinkDelegate];
}

@end
