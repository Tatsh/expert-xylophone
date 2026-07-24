#import "RecommendAdAreaView.h"

#import "AnalysisNetworkCore.h"
#import "ApplilinkConsts.h"
#import "ApplilinkCore.h"
#import "ApplilinkParameters.h"
#import "ApplilinkUtilities.h"
#import "NSStringURLEncoding.h"
#import "RecommendAdCache.h"
#import "RecommendAdId.h"
#import "RecommendCore.h"
#import "RecommendWebAPI.h"

@protocol ApplilinkViewDelegate;

// Web-view load status stored in webViewStatus.
enum {
    RecommendAdAreaViewStatusIdle = 0,
    RecommendAdAreaViewStatusStarted = 1,
    RecommendAdAreaViewStatusFinished = 2,
};

// Advert models whose advert area scrolls freely rather than being pinned.
enum {
    RecommendAdAreaViewAdModelScrollableBanner = 1,
    RecommendAdAreaViewAdModelScrollableInterstitial = 4,
    RecommendAdAreaViewAdModelFixedInterstitial = 5,
};

// UIWebView cancellation and policy-change error codes ignored during the advert load.
enum {
    RecommendAdAreaViewWebKitFrameLoadInterrupted = 102,      // 0x66
    RecommendAdAreaViewWebKitPlugInWillHandleLoad = 204,      // 0xcc
    RecommendAdAreaViewURLErrorCancelled = -999,              // NSURLErrorCancelled
    RecommendAdAreaViewURLErrorNotConnectedToInternet = -1009,
};

// The port the applilink external-application scheme listens on.
enum {
    RecommendAdAreaViewExtAppPort = 80,
};

// Result of redirectWithRequest: whether the web view should proceed with the request.
enum {
    RecommendAdAreaViewRedirectConsumed = 0,
    RecommendAdAreaViewRedirectLoad = 1,
};

static NSString *const kRecommendAdAreaViewFormatObject = @"%@";
static NSString *const kRecommendAdAreaViewFormatScheme = @"%@://";
static NSString *const kRecommendAdAreaViewFormatQuerySuffix = @"?%@";
static NSString *const kRecommendAdAreaViewWebKitErrorDomain = @"WebKitErrorDomain";

// The applilink external-application redirect scheme, host, and path commands.
static NSString *const kRecommendAdAreaViewApplilinkScheme = @"applilink";
static NSString *const kRecommendAdAreaViewExtAppHost = @"ext-app";
static NSString *const kRecommendAdAreaViewExtAppUrl = @"applilink://ext-app:80";
static NSString *const kRecommendAdAreaViewCloseCommand = @"close";
static NSString *const kRecommendAdAreaViewCloseCommandPrefix = @"/close";
static NSString *const kRecommendAdAreaViewSendCommand = @"send";
static NSString *const kRecommendAdAreaViewSendCommandPrefix = @"/send";
static NSString *const kRecommendAdAreaViewQuerySeparator = @"&";
static NSString *const kRecommendAdAreaViewPathSeparator = @"/";

// The advert-record key holding the advertising identifier registered on load.
static NSString *const kRecommendAdAreaViewAdIdKey = @"ad_id";

// The redirect query-parameter keys, each including its trailing equals sign.
static NSString *const kRecommendAdAreaViewQueryDefaultScheme = @"default_scheme=";
static NSString *const kRecommendAdAreaViewQueryAdType = @"ad_type=";
static NSString *const kRecommendAdAreaViewQueryAdModel = @"ad_model=";
static NSString *const kRecommendAdAreaViewQueryAdLocation = @"ad_location=";
static NSString *const kRecommendAdAreaViewQueryAdIdFrom = @"ad_id_from=";
static NSString *const kRecommendAdAreaViewQueryAdIdTo = @"ad_id_to=";
static NSString *const kRecommendAdAreaViewQueryCountryCode = @"country_code=";
static NSString *const kRecommendAdAreaViewQueryCategoryId = @"category_id=";
static NSString *const kRecommendAdAreaViewQueryCreativeId = @"creative_id=";
static NSString *const kRecommendAdAreaViewQueryIncentiveType = @"incentive_type=";
static NSString *const kRecommendAdAreaViewQueryInstallFlg = @"install_flg=";
static NSString *const kRecommendAdAreaViewQueryDisplayNumber = @"display_number=";
static NSString *const kRecommendAdAreaViewQueryStoreId = @"store_id=";
static NSString *const kRecommendAdAreaViewQueryAppliIdTo = @"appli_id_to=";

@interface RecommendAdAreaView ()

// URL-decode the tail of a query component after stripping its leading key prefix.
- (NSString *)decodedValueFrom:(NSString *)component afterPrefix:(NSString *)prefix;

@end

@implementation RecommendAdAreaView

#pragma mark - Initialisation

/** @ghidraAddress 0x23e968 */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = UIColor.clearColor;
        self.opaque = NO;
        self.autoresizingMask =
            UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth |
            UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin |
            UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;
        self.contentMode = UIViewContentModeScaleAspectFit;
    }
    return self;
}

/** @ghidraAddress 0x2413e0 */
- (void)dealloc {
    _applilinkDelegate = nil;
    _sdkDelegate = nil;
    if (self.delegate != nil) {
        self.delegate = nil;
    }
    _adLocation = nil;
    _impressionId = nil;
    _requestCode = nil;
}

#pragma mark - Configuration

/** @ghidraAddress 0x23ea44 */
- (void)startPath:(NSString *)path {
    self.delegate = self;
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL fileURLWithPath:path]];
    [self loadRequest:request];
    self.backgroundColor = UIColor.clearColor;
    self.opaque = NO;
}

/** @ghidraAddress 0x23eb70 */
- (void)setAdModel:(int)adModel
        adLocation:(NSString *)adLocation
            adType:(int)adType
       requestCode:(id)requestCode
          delegate:(id<ApplilinkViewDelegate>)delegate {
    _webViewStatus = RecommendAdAreaViewStatusIdle;
    _adType = adType;
    _adModel = adModel;
    if (adLocation == nil) {
        _adLocation = nil;
    } else {
        _adLocation = [NSString stringWithFormat:kRecommendAdAreaViewFormatObject, adLocation];
    }
    _requestCode = requestCode;
    _applilinkDelegate = delegate;
    if (adModel == RecommendAdAreaViewAdModelScrollableBanner ||
        adModel == RecommendAdAreaViewAdModelFixedInterstitial ||
        adModel == RecommendAdAreaViewAdModelScrollableInterstitial) {
        // A fixed interstitial disables scrolling; the scrollable models enable it.
        [self setScrollEnabled:adModel != RecommendAdAreaViewAdModelFixedInterstitial];
    } else {
        self.scrollView.bounces = NO;
        [self setScrollBoundsEnabled:NO];
        [self setScrollBarEnabled:NO];
    }
}

/** @ghidraAddress 0x23ed30 */
- (void)removeFromSuperview {
    [super removeFromSuperview];
}

/** @ghidraAddress 0x23ed6c */
- (void)closeAdArea {
    [self appListDidDisappear];
}

#pragma mark - Scrolling

/** @ghidraAddress 0x23ed7c */
- (void)setScrollEnabled:(BOOL)scrollEnabled {
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

/** @ghidraAddress 0x23f078 */
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

/** @ghidraAddress 0x23f350 */
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

/** @ghidraAddress 0x23f52c */
- (void)webViewDidStartLoad:(UIWebView *)webView {
    if (_webViewStatus == RecommendAdAreaViewStatusIdle) {
        _webViewStatus = RecommendAdAreaViewStatusStarted;
    }
}

/** @ghidraAddress 0x23f548 */
- (void)webViewDidFinishLoad:(UIWebView *)webView {
    _webViewStatus = RecommendAdAreaViewStatusFinished;
    NSMutableArray *adIdList = [NSMutableArray array];
    NSArray *records = [RecommendAdCache getHtmlAdDataWithAdModel:_adModel adLocation:_adLocation];
    for (NSDictionary *record in records) {
        NSString *adId = record[kRecommendAdAreaViewAdIdKey];
        if (adId != nil) {
            [adIdList addObject:adId];
        }
    }
    [RecommendWebAPI readRegistWithAdType:_adType
                                 adIdList:adIdList
                                 callback:^(NSError *_Nullable error){
                                     /** @ghidraAddress 0x23f804 */
                                 }];
    _impressionId = [ApplilinkUtilities getImpressionId];
    [[RecommendCore sharedInstance] postAnalysisListRegistWithAdType:_adType
                                                            AdModel:_adModel
                                                         adLocation:_adLocation
                                                       impressionId:_impressionId];
    [self appListDidAppear];
}

/** @ghidraAddress 0x23f808 */
- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    if (error.code == RecommendAdAreaViewURLErrorCancelled) {
        return;
    }
    if (error.code == RecommendAdAreaViewWebKitFrameLoadInterrupted &&
        [error.domain isEqual:kRecommendAdAreaViewWebKitErrorDomain]) {
        return;
    }
    if (error.code == RecommendAdAreaViewWebKitPlugInWillHandleLoad &&
        [error.domain isEqual:kRecommendAdAreaViewWebKitErrorDomain]) {
        return;
    }
    NSError *reportError = [NSError errorWithDomain:error.domain code:error.code userInfo:nil];
    if (_webViewStatus == RecommendAdAreaViewStatusFinished) {
        if (error.code != RecommendAdAreaViewURLErrorNotConnectedToInternet) {
            return;
        }
        [self appListFailLinkWithError:reportError];
    } else {
        [self appListFailLoadWithError:reportError];
    }
}

/** @ghidraAddress 0x23f9d4 */
- (BOOL)webView:(UIWebView *)webView
    shouldStartLoadWithRequest:(NSURLRequest *)request
                navigationType:(UIWebViewNavigationType)navigationType {
    int redirect = [self redirectWithRequest:request];
    if (redirect != RecommendAdAreaViewRedirectLoad) {
        _webViewStatus = RecommendAdAreaViewStatusFinished;
    }
    return redirect == RecommendAdAreaViewRedirectLoad;
}

#pragma mark - Advert-tap redirect

- (NSString *)decodedValueFrom:(NSString *)component afterPrefix:(NSString *)prefix {
    return [NSStringURLEncoding URLDecodedString:[component substringFromIndex:prefix.length]];
}

/** @ghidraAddress 0x23ffa8 */
- (int)redirectWithRequest:(NSURLRequest *)request {
    NSURL *url = request.URL;
    NSString *scheme = url.scheme;
    NSString *host = url.host;
    NSInteger port = url.port.intValue;
    NSString *path = url.path;
    NSString *query = url.query;
    if (scheme == nil || ![scheme hasPrefix:kRecommendAdAreaViewApplilinkScheme] || host == nil ||
        ![host isEqualToString:kRecommendAdAreaViewExtAppHost] ||
        port != RecommendAdAreaViewExtAppPort) {
        return RecommendAdAreaViewRedirectLoad;
    }

    if (path != nil && ([path isEqualToString:kRecommendAdAreaViewCloseCommand] ||
                        [path hasPrefix:kRecommendAdAreaViewCloseCommandPrefix])) {
        [self appListDidDisappear];
        [self removeFromSuperview];
        return RecommendAdAreaViewRedirectConsumed;
    }

    if (query == nil) {
        return RecommendAdAreaViewRedirectLoad;
    }

    NSString *defaultScheme = nil;
    NSString *adType = nil;
    NSString *adModel = nil;
    NSString *adLocation = nil;
    NSString *adIdFrom = nil;
    NSString *adIdTo = nil;
    NSString *countryCode = nil;
    NSString *categoryId = nil;
    NSString *creativeId = nil;
    NSString *incentiveType = nil;
    NSString *installFlg = nil;
    NSString *displayNumber = nil;
    NSString *storeId = nil;
    NSString *appliIdTo = nil;
    NSArray *components =
        [query componentsSeparatedByString:kRecommendAdAreaViewQuerySeparator];
    for (NSString *component in components) {
        NSString *k = kRecommendAdAreaViewQueryDefaultScheme;
        if ([component rangeOfString:k].location != NSNotFound) {
            defaultScheme = [self decodedValueFrom:component afterPrefix:k];
        } else if ([component rangeOfString:(k = kRecommendAdAreaViewQueryAdType)].location !=
                   NSNotFound) {
            adType = [self decodedValueFrom:component afterPrefix:k];
        } else if ([component rangeOfString:(k = kRecommendAdAreaViewQueryAdModel)].location !=
                   NSNotFound) {
            adModel = [self decodedValueFrom:component afterPrefix:k];
        } else if ([component rangeOfString:(k = kRecommendAdAreaViewQueryAdLocation)].location !=
                   NSNotFound) {
            adLocation = [self decodedValueFrom:component afterPrefix:k];
        } else if ([component rangeOfString:(k = kRecommendAdAreaViewQueryAdIdFrom)].location !=
                   NSNotFound) {
            adIdFrom = [self decodedValueFrom:component afterPrefix:k];
        } else if ([component rangeOfString:(k = kRecommendAdAreaViewQueryAdIdTo)].location !=
                   NSNotFound) {
            adIdTo = [self decodedValueFrom:component afterPrefix:k];
        } else if ([component rangeOfString:(k = kRecommendAdAreaViewQueryCountryCode)].location !=
                   NSNotFound) {
            countryCode = [self decodedValueFrom:component afterPrefix:k];
        } else if ([component rangeOfString:(k = kRecommendAdAreaViewQueryCategoryId)].location !=
                   NSNotFound) {
            categoryId = [self decodedValueFrom:component afterPrefix:k];
        } else if ([component rangeOfString:(k = kRecommendAdAreaViewQueryCreativeId)].location !=
                   NSNotFound) {
            creativeId = [self decodedValueFrom:component afterPrefix:k];
        } else if ([component rangeOfString:(k = kRecommendAdAreaViewQueryIncentiveType)]
                       .location != NSNotFound) {
            incentiveType = [self decodedValueFrom:component afterPrefix:k];
        } else if ([component rangeOfString:(k = kRecommendAdAreaViewQueryInstallFlg)].location !=
                   NSNotFound) {
            installFlg = [self decodedValueFrom:component afterPrefix:k];
        } else if ([component rangeOfString:(k = kRecommendAdAreaViewQueryDisplayNumber)]
                       .location != NSNotFound) {
            displayNumber = [self decodedValueFrom:component afterPrefix:k];
        } else if ([component rangeOfString:(k = kRecommendAdAreaViewQueryStoreId)].location !=
                   NSNotFound) {
            storeId = [self decodedValueFrom:component afterPrefix:k];
        } else if ([component rangeOfString:(k = kRecommendAdAreaViewQueryAppliIdTo)].location !=
                   NSNotFound) {
            appliIdTo = [self decodedValueFrom:component afterPrefix:k];
        }
    }

    if (path == nil || (![path isEqualToString:kRecommendAdAreaViewSendCommand] &&
                        ![path hasPrefix:kRecommendAdAreaViewSendCommandPrefix])) {
        // Non-send taps drive an external App Store or scheme transition.
        NSString *extAppPrefix =
            [NSString stringWithFormat:kRecommendAdAreaViewFormatObject,
                                       kRecommendAdAreaViewExtAppUrl];
        NSString *destination = path;
        if ([url.absoluteString hasPrefix:extAppPrefix]) {
            destination = [url.absoluteString substringFromIndex:extAppPrefix.length];
            if (query.length != 0) {
                NSString *querySuffix =
                    [NSString stringWithFormat:kRecommendAdAreaViewFormatQuerySuffix, query];
                if ([destination hasSuffix:querySuffix]) {
                    destination =
                        [destination substringToIndex:destination.length - querySuffix.length];
                }
            }
        }

        if (destination.length == 0) {
            return RecommendAdAreaViewRedirectLoad;
        }

        NSURL *schemeUrl =
            [NSURL URLWithString:[NSString stringWithFormat:kRecommendAdAreaViewFormatScheme,
                                                            defaultScheme]];
        if (schemeUrl != nil && [[UIApplication sharedApplication] canOpenURL:schemeUrl]) {
            [[UIApplication sharedApplication] openURL:schemeUrl];
            [self appListDidDisappear];
            [self removeFromSuperview];
            return RecommendAdAreaViewRedirectConsumed;
        }

        NSArray *segments = [[destination substringFromIndex:1]
            componentsSeparatedByString:kRecommendAdAreaViewPathSeparator];
        if (segments.count != 0) {
            // The first path segment is decoded but the store id parsed from the query drives the
            // presentation.
            (void)[NSStringURLEncoding URLDecodedString:segments[0]];
            ApplilinkParameters *appParam = [[ApplilinkParameters alloc] init];
            [appParam setRequestWithAdModel:_adModel
                                 adLocation:_adLocation
                                requestCode:_requestCode];
            if (![ApplilinkCore showAppStoreId:storeId appParam:appParam delegate:self]) {
                NSURL *destinationUrl = [NSURL URLWithString:destination];
                ((NSMutableURLRequest *)request).URL = destinationUrl;
                if (destinationUrl != nil &&
                    [[UIApplication sharedApplication] canOpenURL:destinationUrl]) {
                    [[UIApplication sharedApplication] openURL:destinationUrl];
                    [self appListDidDisappear];
                    [self removeFromSuperview];
                }
            }
        }
        return RecommendAdAreaViewRedirectConsumed;
    }

    // A send tap registers the click analytics and reloads the target advert.
    if (adIdFrom != nil && countryCode != nil && categoryId != nil) {
        RecommendAdId *adId = [[RecommendAdId alloc] initWithCountryCode:countryCode
                                                             categoryId:categoryId];
        [adId setWithAdIdFrom:adIdFrom
                  countryCode:countryCode
                   categoryId:categoryId
                       adType:adType
                        error:nil];
    }
    [AnalysisNetworkCore postAnalysisClickRegistWithAdType:adType
                                                   adModel:adModel
                                                adLocation:_adLocation
                                              impressionId:_impressionId
                                                 appliIdTo:appliIdTo
                                                creativeId:creativeId
                                             displayNumber:displayNumber
                                             incentiveType:incentiveType
                                                installFlg:installFlg
                                                  callback:^(NSError *_Nullable error){
                                                      /** @ghidraAddress 0x241360 */
                                                  }];
    NSURL *schemeUrl =
        [NSURL URLWithString:[NSString stringWithFormat:kRecommendAdAreaViewFormatScheme,
                                                        defaultScheme]];
    if (schemeUrl != nil && [[UIApplication sharedApplication] canOpenURL:schemeUrl]) {
        NSString *appliIdFrom = [ApplilinkConsts adId];
        NSURLRequest *appStartRequest = [RecommendWebAPI appStartWithAdIdFrom:appliIdFrom
                                                                      adIdTo:adIdTo
                                                                      adType:_adType];
        [self loadRequest:appStartRequest];
    } else {
        NSURLRequest *clickRequest = [RecommendWebAPI clickRegistWithAdIdFrom:adIdFrom
                                                                      adIdTo:adIdTo
                                                                     adModel:_adModel];
        [self loadRequest:clickRequest];
    }
    return RecommendAdAreaViewRedirectConsumed;
}

#pragma mark - Advert-list delegate notifications

/** @ghidraAddress 0x23fa28 */
- (void)appListDidAppear {
    id<SdkViewDelegate> sdkDelegate = _sdkDelegate;
    if (sdkDelegate != nil && [sdkDelegate respondsToSelector:@selector(openedNotice)]) {
        [sdkDelegate openedNotice];
    }
    ApplilinkParameters *appParam = [[ApplilinkParameters alloc] init];
    [appParam setRequestWithAdModel:_adModel adLocation:_adLocation requestCode:_requestCode];
    [ApplilinkCore toDelegateDidAppear:appParam delegate:_applilinkDelegate];
}

/** @ghidraAddress 0x23fb70 */
- (void)appListDidDisappear {
    id<SdkViewDelegate> sdkDelegate = _sdkDelegate;
    if (sdkDelegate != nil) {
        if ([sdkDelegate respondsToSelector:@selector(closeNotice)]) {
            [sdkDelegate closeNotice];
        }
        _sdkDelegate = nil;
    }
    ApplilinkParameters *appParam = [[ApplilinkParameters alloc] init];
    [appParam setRequestWithAdModel:_adModel adLocation:_adLocation requestCode:_requestCode];
    [ApplilinkCore toDelegateDidDisappear:appParam delegate:_applilinkDelegate];
    _applilinkDelegate = nil;
}

/** @ghidraAddress 0x23fcd4 */
- (void)appListFailLoadWithError:(NSError *)error {
    id<SdkViewDelegate> sdkDelegate = _sdkDelegate;
    if (sdkDelegate != nil) {
        if ([sdkDelegate respondsToSelector:@selector(failOpenNoticeWithError:)]) {
            [sdkDelegate failOpenNoticeWithError:error];
        }
        _sdkDelegate = nil;
    }
    ApplilinkParameters *appParam = [[ApplilinkParameters alloc] init];
    [appParam setRequestWithAdModel:_adModel adLocation:_adLocation requestCode:_requestCode];
    [ApplilinkCore toDelegateFailLoadWithError:error
                                      appParam:appParam
                                      delegate:_applilinkDelegate];
}

/** @ghidraAddress 0x23fe44 */
- (void)appListFailLinkWithError:(NSError *)error {
    id<SdkViewDelegate> sdkDelegate = _sdkDelegate;
    if (sdkDelegate != nil &&
        [sdkDelegate respondsToSelector:@selector(failLinkNoticeWithError:)]) {
        [sdkDelegate failLinkNoticeWithError:error];
    }
    ApplilinkParameters *appParam = [[ApplilinkParameters alloc] init];
    [appParam setRequestWithAdModel:_adModel adLocation:_adLocation requestCode:_requestCode];
    [ApplilinkCore toDelegateFailLinkWithError:error
                                      appParam:appParam
                                      delegate:_applilinkDelegate];
}

#pragma mark - App Store notices

/** @ghidraAddress 0x241364 */
- (void)openedNotice {
}

/** @ghidraAddress 0x241368 */
- (void)closeNotice {
    [self appListDidDisappear];
    [self removeFromSuperview];
}

/** @ghidraAddress 0x2413a4 */
- (void)openErrorNotice {
}

/** @ghidraAddress 0x2413a8 */
- (void)appStoreOpenedNotice {
}

/** @ghidraAddress 0x2413ac */
- (void)appStoreCloseNotice {
    if (_adModel == RecommendAdAreaViewAdModelFixedInterstitial) {
        [self closeNotice];
    }
}

/** @ghidraAddress 0x2413d4 */
- (void)appStoreClosedNotice {
}

/** @ghidraAddress 0x2413d8 */
- (void)appStoreFailLoadNoticeWithError:(NSError *)error {
}

/** @ghidraAddress 0x2413dc */
- (void)appStoreTransitionNotice {
}

@end
