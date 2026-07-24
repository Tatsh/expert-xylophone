#import "RecommendCore.h"

#import "AnalysisNetworkCore.h"
#import "ApplilinkConsts.h"
#import "ApplilinkCore.h"
#import "ApplilinkNetworkError.h"
#import "ApplilinkParameters.h"
#import "ApplilinkURLConnection.h"
#import "ApplilinkUdid.h"
#import "ApplilinkUtilities.h"
#import "NSStringURLEncoding.h"
#import "RecommendAdAreaView.h"
#import "RecommendAdCache.h"
#import "RecommendAdData.h"
#import "RecommendAdId.h"
#import "RecommendFullScreenController.h"
#import "RecommendWebAPI.h"
#import "RecommendWebView.h"
#import "RecommendWebViewController.h"
#import "RewardCore.h"

// Applilink error codes reported to callers and delegates.
typedef enum {
    RecommendCoreErrorCodeParameter = 1001,          // 0x3e9
    RecommendCoreErrorCodeNotInitialized = 1010,     // 0x3f2
    RecommendCoreErrorCodeNoAdData = 1034,           // 0x40a
    RecommendCoreErrorCodeCacheCreate = 1035,        // 0x40b
    RecommendCoreErrorCodeAlreadyOpen = 1036,        // 0x40c
    RecommendCoreErrorCodeNoBannerData = 1037,       // 0x40d
    RecommendCoreErrorCodeAdTrackingDisabled = 1028, // 0x404
    RecommendCoreErrorCodeNoAppliId = 1029,          // 0x405
} RecommendCoreErrorCode;

// Advert-model identifiers whose banner opens the advert area directly (100, 101) or the interstitial
// (5) rather than gating on the installed-application list.
typedef enum {
    RecommendCoreAdModelInterstitial = 5,
    RecommendCoreAdModelOwnAdBase = 100,
    RecommendCoreAdModelDirectRangeLength = 2,
} RecommendCoreAdModel;

// Advert types passed to the analytics registration.
typedef enum {
    RecommendCoreAdTypeBanner = 2,
    RecommendCoreAdTypeIcon = 3,
    RecommendCoreAdTypeInterstitial = 5,
} RecommendCoreAdType;

// The cached-banner-status value that marks an advert as available.
static const int kRecommendCoreBannerAvailable = 1;

// The advert-status value that marks an advert model as available.
static const int kRecommendCoreAdStatusAvailable = 1;

// The recommend-login validity window, in seconds.
static const NSTimeInterval kRecommendCoreLoginValiditySeconds = 60.0;

// The install-post priority for the application-install registration.
static const int kRecommendCoreInstallPriority = 1;

// The Applilink deep-link scheme, host, and port that a redirect must match.
static NSString *const kRecommendCoreApplilinkScheme = @"applilink";
static NSString *const kRecommendCoreExtAppHost = @"ext-app";
static const int kRecommendCoreExtAppPort = 80;
static NSString *const kRecommendCoreApplilinkExtAppUrl = @"applilink://ext-app:80";
static NSString *const kRecommendCoreChangeDestSuffix = @"#changeDest";
static NSString *const kRecommendCoreCloseHost = @"close";

// The redirect query keys, each parsed from a `key=value` component.
static NSString *const kRecommendCoreQueryDefaultScheme = @"default_scheme=";
static NSString *const kRecommendCoreQueryAdIdFrom = @"ad_id_from=";
static NSString *const kRecommendCoreQueryCountryCode = @"country_code=";
static NSString *const kRecommendCoreQueryCategoryId = @"category_id=";
static NSString *const kRecommendCoreQueryAdType = @"ad_type=";
static NSString *const kRecommendCoreQueryStoreId = @"store_id=";

// The external advert index endpoint appended to the SSL base URL.
static NSString *const kRecommendCoreAdExternalIndexPath = @"/ad/external/index.php";

// NSUserDefaults keys owned by the recommend network.
static NSString *const kRecommendCorePostInstalledKey = @"ApplilinkRecommend.postInstalled";
static NSString *const kRecommendCoreBannerInfoKey = @"ApplilinkRecommend.bannerInfo";
static NSString *const kRecommendCoreUniqueAdDataKey = @"UniqueAdData";
static NSString *const kRecommendCoreAppliIdKey = @"ApplilinkNetwork.appliId";

// Advert-record and cache dictionary keys.
static NSString *const kRecommendCoreKeyAdId = @"ad_id";
static NSString *const kRecommendCoreKeyAppliId = @"appli_id";
static NSString *const kRecommendCoreKeyDefaultScheme = @"default_scheme";
static NSString *const kRecommendCoreKeyIncentiveType = @"incentive_type";
static NSString *const kRecommendCoreKeyBannerUrl = @"banner_url";
static NSString *const kRecommendCoreKeyBannerIconUrl = @"banner_icon_url";
static NSString *const kRecommendCoreKeyInterstitialBannerUrl = @"interstitial_banner_url";
static NSString *const kRecommendCoreKeyExpire = @"expire";
static NSString *const kRecommendCoreKeyStatus = @"status";
static NSString *const kRecommendCoreKeyUnreadCount = @"unreadCount";
static NSString *const kRecommendCoreKeyBannerDisplayStatus = @"bannerDisplayStatus";
static NSString *const kRecommendCoreKeyAdIdFrom = @"AdIdFrom";
static NSString *const kRecommendCoreKeyAdType = @"AdType";
static NSString *const kRecommendCoreKeyRewardNone = @"REWARD_NONE";
static NSString *const kRecommendCoreDisplayNumberDefault = @"1";

// The request-parameter keys for the external advert index request.
static NSString *const kRecommendCoreParamIsSdk = @"is_sdk";
static NSString *const kRecommendCoreParamAdLocation = @"ad_location";
static NSString *const kRecommendCoreParamAdModel = @"ad_model";
static NSString *const kRecommendCoreParamVerticalAlign = @"vertical_align";
static NSString *const kRecommendCoreParamInstallAdIdList = @"install_ad_id_list";
static NSString *const kRecommendCoreParamValueOne = @"1";

// Format strings.
static NSString *const kRecommendCoreFormatInteger = @"%d";
static NSString *const kRecommendCoreFormatSchemeOnly = @"%@://";
static NSString *const kRecommendCoreFormatQuery = @"?%@";
static NSString *const kRecommendCoreFormatHtmlName = @"ad_type%d.html";
static NSString *const kRecommendCoreFormatBannerDisplayStatus =
    @"banner_display_status_list ad_model:%d";
static NSString *const kRecommendCoreFormatAllAdDataMissing =
    @"allAdDataForDisplay fall in line with list by no appliId.";

// The web-load error codes that are silently ignored when they come from WebKit.
static const NSInteger kRecommendCoreWebKitCancelledCode = -999;
static const NSInteger kRecommendCoreWebKitFrameLoadInterruptedCode = 102; // 0x66
static const NSInteger kRecommendCoreWebKitPlugInCancelledCode = 204;      // 0xcc
static NSString *const kRecommendCoreWebKitErrorDomain = @"WebKitErrorDomain";

// The query-component separator and the deep-link path separator.
static NSString *const kRecommendCoreQuerySeparator = @"&";
static NSString *const kRecommendCorePathSeparator = @"/";

// Whether an advert screen or advert view is currently open, guarding re-entry.
static BOOL g_recommendCoreScreenOpen = NO;

// The absolute time until which the recommend login remains valid; nil forces a re-login.
static NSDate *g_recommendCoreLoginValidUntil = nil;

@interface RecommendCore ()

// The installed-application-list callback body for the advert-screen presentation.
- (void)openAdScreenAppliList:(nullable id)appliList
                        error:(nullable NSError *)error
                   adLocation:(nullable NSString *)adLocation
                      adModel:(int)adModel
                verticalAlign:(int)verticalAlign
                     delegate:(nullable id)delegate;

// The session-gated click-registration callback body for a first-party advert touch.
- (void)postAnalysisClickRegistWithError:(nullable NSError *)error
                              adLocation:(nullable NSString *)adLocation
                                 appliId:(nullable NSString *)appliId
                              creativeId:(nullable NSString *)creativeId
                             requestCode:(nullable id)requestCode
                                delegate:(nullable id)delegate;

@end

@implementation RecommendCore

#pragma mark - Singleton

+ (instancetype)sharedInstance {
    static RecommendCore *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      /** @ghidraAddress 0x236ca8 */
      instance = [[RecommendCore alloc] init];
      instance.initializeFlg = NO;
    });
    return instance;
}

#pragma mark - Initialisation state

- (BOOL)isInitialized {
    return self.initializeFlg == kRecommendCoreAdStatusAvailable;
}

- (void)clearInitialize {
    self.initializeFlg = 0;
}

- (BOOL)isInstalledAppliWithScheme:(NSString *)scheme {
    NSURL *url =
        [NSURL URLWithString:[NSString stringWithFormat:kRecommendCoreFormatSchemeOnly, scheme]];
    return [[UIApplication sharedApplication] canOpenURL:url];
}

#pragma mark - Start and session

- (void)startWithCallback:(void (^)(NSError *_Nullable error))callback {
    if ([ApplilinkConsts appliId] == nil) {
        if (callback) {
            callback([ApplilinkNetworkError
                localizedApplilinkErrorWithCode:RecommendCoreErrorCodeNoAppliId]);
        }
        return;
    }
    if (![ApplilinkCore checkUdid]) {
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kRecommendCorePostInstalledKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    if ([RecommendCore sharedInstance].initializeFlg == 0) {
        if (![[RewardCore sharedInstance] createUdidWithBlock:callback]) {
            [[NSUserDefaults standardUserDefaults] setBool:NO
                                                    forKey:kRecommendCorePostInstalledKey];
            [[NSUserDefaults standardUserDefaults] synchronize];
            if (callback) {
                callback(nil);
            }
            return;
        }
    }
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
      /** @ghidraAddress 0x237124 */
      // The recommend API invokes this block with (categoryId, countryCode, error); the binary
      // ignores the first two arguments here and re-reads them from ApplilinkConsts below, so they
      // are left unnamed.
      [RecommendWebAPI getAdDetailWithCallback:^(id, id, NSError *error) {
        /** @ghidraAddress 0x2371bc */
        if (error != nil) {
            if (callback) {
                callback(error);
            }
            return;
        }
        self.initializeFlg = YES;
        if ([[NSUserDefaults standardUserDefaults] boolForKey:kRecommendCorePostInstalledKey]) {
            if (callback) {
                callback(nil);
            }
            return;
        }
        NSString *countryCode = [ApplilinkConsts countryCode];
        NSString *categoryId = [ApplilinkConsts categoryId];
        RecommendAdId *adId = [[RecommendAdId alloc] initWithCountryCode:countryCode
                                                              categoryId:categoryId];
        NSError *lookupError = nil;
        NSDictionary *record = [adId getWithCountryCode:countryCode
                                             categoryId:categoryId
                                                  error:&lookupError];
        NSString *adIdFrom = nil;
        NSString *adType = nil;
        if (lookupError == nil && record != nil) {
            adIdFrom = record[kRecommendCoreKeyAdIdFrom];
            if (![adIdFrom isKindOfClass:[NSString class]]) {
                adIdFrom = nil;
            }
            adType = record[kRecommendCoreKeyAdType];
            if (![adType isKindOfClass:[NSString class]]) {
                adType = nil;
            }
        }
        [RecommendWebAPI
            postApplicationInstallWithAdIdFrom:adIdFrom
                                    categoryId:categoryId
                                        adType:adType
                                      priority:kRecommendCoreInstallPriority
                                      callback:^(NSError *_Nullable postError) {
                                        /** @ghidraAddress 0x237550 */
                                        if (postError != nil) {
                                            if (callback) {
                                                callback(postError);
                                            }
                                            return;
                                        }
                                        [adId deleteWithCountryCode:countryCode
                                                         categoryId:categoryId
                                                              error:nil];
                                        [[NSUserDefaults standardUserDefaults]
                                            setBool:YES
                                             forKey:kRecommendCorePostInstalledKey];
                                        [[NSUserDefaults standardUserDefaults] synchronize];
                                        if (callback) {
                                            callback(nil);
                                        }
                                      }];
      }];
    });
}

- (void)startSessionWithCallback:(void (^)(NSError *_Nullable error))callback {
    if (![ApplilinkUdid isAdvertisingTrackingEnabled]) {
        if (callback) {
            callback([ApplilinkNetworkError
                localizedApplilinkErrorWithCode:RecommendCoreErrorCodeAdTrackingDisabled]);
        }
        return;
    }
    [ApplilinkCore appAuthSessionRegenerateWithBlock:^(NSError *_Nullable error) {
      /** @ghidraAddress 0x237868 */
      if (error != nil) {
          if (callback) {
              callback(error);
          }
          return;
      }
      if (g_recommendCoreLoginValidUntil == nil || [ApplilinkConsts isNeedRecommendLogin] ||
          [g_recommendCoreLoginValidUntil timeIntervalSinceNow] < 0.0) {
          // The recommend API invokes this block with (loginStatus, userIdPresent, error); the
          // binary reads only the login status and the error, ignoring userIdPresent.
          [RecommendWebAPI
              checkLoginWithCallback:^(BOOL loggedIn, BOOL userIdPresent, NSError *checkError) {
                /** @ghidraAddress 0x237960 */
                if (checkError != nil) {
                    if (callback) {
                        callback(checkError);
                    }
                    return;
                }
                if (!loggedIn) {
                    [RecommendWebAPI startLoginWithCallback:^(NSError *_Nullable loginError) {
                      /** @ghidraAddress 0x237a94 */
                      if (loginError != nil) {
                          if (callback) {
                              callback(loginError);
                          }
                          return;
                      }
                      [ApplilinkUdid setUdidKeychainFromPasteBoard];
                      [ApplilinkConsts loggedInRecommend];
                      g_recommendCoreLoginValidUntil = [[NSDate date]
                          dateByAddingTimeInterval:kRecommendCoreLoginValiditySeconds];
                      if (callback) {
                          callback(nil);
                      }
                    }];
                    return;
                }
                g_recommendCoreLoginValidUntil =
                    [[NSDate date] dateByAddingTimeInterval:kRecommendCoreLoginValiditySeconds];
                if (callback) {
                    callback(nil);
                }
              }];
          return;
      }
      if (callback) {
          callback(nil);
      }
    }];
}

#pragma mark - Installed-application list

- (void)appliListWithCallBack:(void (^)(id _Nullable list, NSError *_Nullable error))callback {
    [self startSessionWithCallback:^(NSError *_Nullable error) {
      /** @ghidraAddress 0x237c48 */
      if (error != nil) {
          if (callback) {
              callback(nil, error);
          }
          return;
      }
      [self appliListCacheWithCallBack:callback];
    }];
}

- (void)appliListCacheWithCallBack:(void (^)(id _Nullable list, NSError *_Nullable error))callback {
    id list = [ApplilinkConsts appInstallList];
    if (list == nil) {
        [RecommendWebAPI installAppliListWithCallBack:callback];
        return;
    }
    if (callback) {
        callback(list, nil);
    }
}

#pragma mark - Advert status queries

- (void)getAdStatusWithAdModel:(int)adModel
                      callback:(void (^)(NSInteger status, NSError *_Nullable error))callback {
    NSError *error;
    if (adModel == 0) {
        error =
            [ApplilinkNetworkError localizedApplilinkErrorWithCode:RecommendCoreErrorCodeParameter];
    } else if ([RecommendCore sharedInstance].initializeFlg == 0 &&
               ![ApplilinkCore isInitializeStatusFlg]) {
        error = [ApplilinkNetworkError
            localizedApplilinkErrorWithCode:RecommendCoreErrorCodeNotInitialized];
    } else if (![ApplilinkUdid isAdvertisingTrackingEnabled]) {
        error = [ApplilinkNetworkError
            localizedApplilinkErrorWithCode:RecommendCoreErrorCodeAdTrackingDisabled];
    } else {
        NSNumber *cached = [self getTemporaryCacheWithAdModel:adModel];
        if ([cached intValue] == kRecommendCoreBannerAvailable) {
            if (callback) {
                callback([cached intValue], nil);
            }
            return;
        }
        [self startSessionWithCallback:^(NSError *_Nullable sessionError) {
          /** @ghidraAddress 0x237f8c */
          if (sessionError != nil) {
              if (callback) {
                  callback(0, sessionError);
              }
              return;
          }
          [RecommendWebAPI getBannerDetailWithAdModel:adModel callback:callback];
        }];
        return;
    }
    if (callback) {
        callback(0, error);
    }
}

- (void)getUnreadCountWithAdModel:(int)adModel
                       adLocation:(NSString *)adLocation
                         callback:(void (^)(NSInteger status, NSError *_Nullable error))callback {
    NSError *error;
    if (adLocation == nil || adModel == 0) {
        error =
            [ApplilinkNetworkError localizedApplilinkErrorWithCode:RecommendCoreErrorCodeParameter];
    } else if ([RecommendCore sharedInstance].initializeFlg == 0 &&
               ![ApplilinkCore isInitializeStatusFlg]) {
        error = [ApplilinkNetworkError
            localizedApplilinkErrorWithCode:RecommendCoreErrorCodeNotInitialized];
    } else if (![ApplilinkUdid isAdvertisingTrackingEnabled]) {
        error = [ApplilinkNetworkError
            localizedApplilinkErrorWithCode:RecommendCoreErrorCodeAdTrackingDisabled];
    } else {
        [self startSessionWithCallback:^(NSError *_Nullable sessionError) {
          /** @ghidraAddress 0x2381c8 */
          if (sessionError != nil) {
              if (callback) {
                  callback(0, sessionError);
              }
              return;
          }
          [RecommendWebAPI getUnreadCountWithAdModel:adModel
                                          adLocation:adLocation
                                            callback:callback];
        }];
        return;
    }
    if (callback) {
        callback(0, error);
    }
}

- (void)getAdDisplayStatusWithAdModel:(int)adModel
                           adLocation:(NSString *)adLocation
                             callback:(void (^)(NSDictionary *_Nullable status,
                                                NSError *_Nullable error))callback {
    NSMutableDictionary *status = [NSMutableDictionary dictionaryWithCapacity:2];
    [status setValue:@(0) forKey:kRecommendCoreKeyUnreadCount];
    [status setValue:@(0) forKey:kRecommendCoreKeyBannerDisplayStatus];
    NSError *error;
    if (adLocation == nil || adModel == 0) {
        error =
            [ApplilinkNetworkError localizedApplilinkErrorWithCode:RecommendCoreErrorCodeParameter];
    } else if ([RecommendCore sharedInstance].initializeFlg == 0 &&
               ![ApplilinkCore isInitializeStatusFlg]) {
        error = [ApplilinkNetworkError
            localizedApplilinkErrorWithCode:RecommendCoreErrorCodeNotInitialized];
    } else if (![ApplilinkUdid isAdvertisingTrackingEnabled]) {
        error = [ApplilinkNetworkError
            localizedApplilinkErrorWithCode:RecommendCoreErrorCodeAdTrackingDisabled];
    } else {
        [self startSessionWithCallback:^(NSError *_Nullable sessionError) {
          /** @ghidraAddress 0x23852c */
          if (sessionError != nil) {
              if (callback) {
                  callback(status, sessionError);
              }
              return;
          }
          [RecommendWebAPI getPreInfoWithAdModel:adModel adLocation:adLocation callback:callback];
        }];
        return;
    }
    if (callback) {
        callback(status, error);
    }
}

- (void)getAllAdStatusWithCallback:(void (^)(NSError *_Nullable error))callback {
    NSError *error;
    if ([RecommendCore sharedInstance].initializeFlg == 0 &&
        ![ApplilinkCore isInitializeStatusFlg]) {
        error = [ApplilinkNetworkError
            localizedApplilinkErrorWithCode:RecommendCoreErrorCodeNotInitialized];
    } else if (![ApplilinkUdid isAdvertisingTrackingEnabled]) {
        error = [ApplilinkNetworkError
            localizedApplilinkErrorWithCode:RecommendCoreErrorCodeAdTrackingDisabled];
    } else {
        [self startSessionWithCallback:^(NSError *_Nullable sessionError) {
          /** @ghidraAddress 0x238750 */
          if (sessionError == nil) {
              [RecommendAdCache getAllAdStatus];
          }
          if (callback) {
              callback(sessionError);
          }
        }];
        return;
    }
    if (callback) {
        callback(error);
    }
}

- (void)clearAllAdData {
    [RecommendAdCache clearAllAdData];
}

- (void)reloadAllAdData {
    [RecommendAdCache clearAllAdData];
    [RecommendAdCache delateFolder];
    [RecommendAdCache clearAllAdDataInfoExpire];
    [self getAllAdStatusWithCallback:^(NSError *_Nullable error){
        // The binary passes a global no-op block here.
    }];
}

#pragma mark - Presentation

- (void)openAdScreenWithParentView:(UIView *)parentView
                           adModel:(int)adModel
                        adLocation:(NSString *)adLocation
                     verticalAlign:(int)verticalAlign
                       requestCode:(id)requestCode
                          delegate:(id)delegate {
    if (g_recommendCoreScreenOpen) {
        ApplilinkParameters *appParam = [[ApplilinkParameters alloc] init];
        [appParam setRequestWithAdModel:adModel adLocation:adLocation requestCode:requestCode];
        [ApplilinkCore toDelegateFailOpenWithError:
                           [ApplilinkNetworkError
                               localizedApplilinkErrorWithCode:RecommendCoreErrorCodeCacheCreate]
                                          appParam:appParam
                                          delegate:delegate];
        return;
    }
    g_recommendCoreScreenOpen = YES;
    self.adScreenviewCloseFlg = NO;
    if (self.applilinkParams == nil) {
        self.applilinkParams = [[ApplilinkParameters alloc] init];
    }
    [self.applilinkParams setRequestWithAdModel:adModel
                                     adLocation:adLocation
                                    requestCode:requestCode];
    self.applilinkDelegate = delegate;
    self.navigationBarHidden = (parentView != nil && adModel == RecommendCoreAdModelInterstitial);
    dispatch_async(dispatch_get_main_queue(), ^{
      /** @ghidraAddress 0x238b14 */
      if (self.adScreenViewController == nil) {
          self.adScreenViewController = [[RecommendWebViewController alloc] init];
      }
      [self.adScreenViewController setSdkDelegate];
      [self.adScreenViewController setNavigationBarHidden:self.navigationBarHidden];
      if (parentView == nil) {
          UIWindow *window = [ApplilinkCore mainWindow];
          if (window != nil) {
              [window addSubview:self.adScreenViewController.view];
          }
      } else {
          [self.adScreenViewController setParentView];
          [parentView addSubview:self.adScreenViewController.view];
      }
      [self.adScreenViewController updateIndicator:YES];
      if (adModel == RecommendCoreAdModelInterstitial) {
          [self.adScreenViewController setWebViewBounces:NO];
      }
      if ((adModel - RecommendCoreAdModelOwnAdBase < RecommendCoreAdModelDirectRangeLength) ||
          adModel == RecommendCoreAdModelInterstitial) {
          [self openAdAreaWithParentView:self.adScreenViewController.baseView
                                    rect:self.adScreenViewController.baseView.frame
                                 adModel:adModel
                              adLocation:adLocation
                           verticalAlign:verticalAlign
                             requestCode:requestCode
                                delegate:delegate];
          g_recommendCoreScreenOpen = NO;
      } else {
          [self appliListWithCallBack:^(id _Nullable list, NSError *_Nullable error) {
            /** @ghidraAddress 0x238e84 */
            [self openAdScreenAppliList:list
                                  error:error
                             adLocation:adLocation
                                adModel:adModel
                          verticalAlign:verticalAlign
                               delegate:delegate];
          }];
      }
    });
}

// The installed-application-list callback for the advert-screen presentation.
/** @ghidraAddress 0x238e84 */
- (void)openAdScreenAppliList:(nullable id)appliList
                        error:(nullable NSError *)error
                   adLocation:(nullable NSString *)adLocation
                      adModel:(int)adModel
                verticalAlign:(int)verticalAlign
                     delegate:(nullable id)delegate {
    if (error != nil || self.adScreenviewCloseFlg) {
        [self releaseAdScreenViewController];
        [ApplilinkCore toDelegateFailOpenWithError:error
                                          appParam:self.applilinkParams
                                          delegate:delegate];
        return;
    }
    NSMutableArray *installedAdIds = [[NSMutableArray alloc] init];
    for (id entry in appliList) {
        if (![entry isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        NSString *scheme = entry[kRecommendCoreKeyDefaultScheme];
        NSString *adId = entry[kRecommendCoreKeyAdId];
        if ([scheme isKindOfClass:[NSString class]] && [self isInstalledAppliWithScheme:scheme] &&
            adId != nil) {
            [installedAdIds addObject:adId];
        }
    }
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithCapacity:5];
    [parameters setValue:kRecommendCoreParamValueOne forKey:kRecommendCoreParamIsSdk];
    if (adLocation != nil) {
        [parameters setValue:adLocation forKey:kRecommendCoreParamAdLocation];
    }
    if (adModel != 0) {
        [parameters setValue:[NSString stringWithFormat:kRecommendCoreFormatInteger, adModel]
                      forKey:kRecommendCoreParamAdModel];
    }
    if (verticalAlign != 0) {
        [parameters setValue:[NSString stringWithFormat:kRecommendCoreFormatInteger, verticalAlign]
                      forKey:kRecommendCoreParamVerticalAlign];
    }
    if (installedAdIds.count != 0) {
        parameters[kRecommendCoreParamInstallAdIdList] = installedAdIds;
    }
    NSString *url =
        [[ApplilinkConsts baseUrlSsl] stringByAppendingString:kRecommendCoreAdExternalIndexPath];
    [self.adScreenViewController loadRequestWithURL:url parameters:parameters];
    g_recommendCoreScreenOpen = NO;
}

- (void)openAdAreaWithParentView:(UIView *)parentView
                            rect:(CGRect)rect
                         adModel:(int)adModel
                      adLocation:(NSString *)adLocation
                   verticalAlign:(int)verticalAlign
                     requestCode:(id)requestCode
                        delegate:(id)delegate {
    ApplilinkParameters *appParam;
    NSError *error;
    if (rect.size.width <= 0.0 || rect.size.height <= 0.0) {
        appParam = [[ApplilinkParameters alloc] init];
        [appParam setRequestWithAdModel:adModel adLocation:adLocation requestCode:requestCode];
        error =
            [ApplilinkNetworkError localizedApplilinkErrorWithCode:RecommendCoreErrorCodeParameter];
    } else if ([RecommendAdData getAdStatusByAdModel:adModel] != kRecommendCoreAdStatusAvailable) {
        appParam = [[ApplilinkParameters alloc] init];
        [appParam setRequestWithAdModel:adModel adLocation:adLocation requestCode:requestCode];
        error = [ApplilinkNetworkError
            localizedApplilinkErrorWithCode:RecommendCoreErrorCodeNoBannerData];
    } else {
        self.adAreaDelegate = delegate;
        if ((adModel - RecommendCoreAdModelOwnAdBase >= RecommendCoreAdModelDirectRangeLength) &&
            adModel != RecommendCoreAdModelInterstitial) {
            BOOL bringToFront = parentView == nil;
            UIView *hostView = parentView;
            if (bringToFront) {
                hostView = [ApplilinkCore mainWindow];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
              /** @ghidraAddress 0x239d14 */
              RecommendWebView *webView = [[RecommendWebView alloc] initWithFrame:rect];
              [hostView addSubview:webView];
              if (bringToFront) {
                  if (self.interstitialViewController != nil) {
                      [hostView bringSubviewToFront:self.interstitialViewController.view];
                  }
                  if (self.adScreenViewController != nil) {
                      [hostView bringSubviewToFront:self.adScreenViewController.view];
                  }
              }
              [webView loadRequestWithAdModel:adModel
                                   adLocation:adLocation
                                verticalAlign:verticalAlign
                                  requestCode:requestCode
                                     delegate:delegate];
            });
            return;
        }
        NSError *createError = [RecommendAdCache createHtmlWithAdModel:adModel
                                                            adLocation:adLocation
                                                         verticalAlign:verticalAlign];
        appParam = [[ApplilinkParameters alloc] init];
        [appParam setRequestWithAdModel:adModel adLocation:adLocation requestCode:requestCode];
        if (createError != nil) {
            [ApplilinkCore toDelegateFailOpenWithError:createError
                                              appParam:appParam
                                              delegate:delegate];
            return;
        }
        NSString *contentPath = [[RecommendAdCache getContentsPath]
            stringByAppendingPathComponent:[NSString stringWithFormat:kRecommendCoreFormatHtmlName,
                                                                      adModel]];
        BOOL isDirectory = NO;
        if (![[NSFileManager defaultManager] fileExistsAtPath:contentPath
                                                  isDirectory:&isDirectory]) {
            [ApplilinkCore toDelegateFailOpenWithError:[ApplilinkNetworkError
                                                           localizedApplilinkErrorWithCode:
                                                               RecommendCoreErrorCodeCacheCreate]
                                              appParam:appParam
                                              delegate:delegate];
            return;
        }
        int adType = [RecommendAdData getAdTypeWithAdModel:adModel adLocation:adLocation];
        BOOL bringToFront = parentView == nil;
        UIView *hostView = parentView;
        if (bringToFront) {
            hostView = [ApplilinkCore mainWindow];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
          /** @ghidraAddress 0x239afc */
          RecommendAdAreaView *areaView = [[RecommendAdAreaView alloc] initWithFrame:rect];
          [areaView setAdModel:adModel
                    adLocation:adLocation
                        adType:adType
                   requestCode:requestCode
                      delegate:delegate];
          [areaView startPath:contentPath];
          [hostView addSubview:areaView];
          [ApplilinkCore toDelegateDidStart:appParam delegate:delegate];
          if (bringToFront) {
              if (self.interstitialViewController != nil) {
                  [hostView bringSubviewToFront:self.interstitialViewController.view];
              }
              if (self.adScreenViewController != nil) {
                  [hostView bringSubviewToFront:self.adScreenViewController.view];
              }
          }
        });
        return;
    }
    [ApplilinkCore toDelegateFailOpenWithError:error appParam:appParam delegate:delegate];
}

- (void)openFullViewControllerWithAdModel:(int)adModel
                               adLocation:(NSString *)adLocation
                            verticalAlign:(int)verticalAlign
                              requestCode:(id)requestCode
                                 delegate:(id)delegate {
    if (g_recommendCoreScreenOpen) {
        ApplilinkParameters *appParam = [[ApplilinkParameters alloc] init];
        [appParam setRequestWithAdModel:adModel adLocation:adLocation requestCode:requestCode];
        [ApplilinkCore toDelegateFailOpenWithError:
                           [ApplilinkNetworkError
                               localizedApplilinkErrorWithCode:RecommendCoreErrorCodeCacheCreate]
                                          appParam:appParam
                                          delegate:delegate];
        return;
    }
    if ([RecommendAdData getAdStatusByAdModel:adModel] == kRecommendCoreAdStatusAvailable) {
        g_recommendCoreScreenOpen = YES;
        self.adScreenviewCloseFlg = NO;
        if (self.applilinkParams == nil) {
            self.applilinkParams = [[ApplilinkParameters alloc] init];
        }
        [self.applilinkParams setRequestWithAdModel:adModel
                                         adLocation:adLocation
                                        requestCode:requestCode];
        self.applilinkDelegate = delegate;
        dispatch_async(dispatch_get_main_queue(), ^{
          /** @ghidraAddress 0x23a268 */
          if (self.interstitialViewController == nil) {
              self.interstitialViewController = [[RecommendFullScreenController alloc] init];
          }
          self.interstitialViewController.view.frame = [UIScreen mainScreen].bounds;
          [self.interstitialViewController openAdViewWithAdModel:adModel
                                                      adLocation:adLocation
                                                          adType:verticalAlign
                                                        appParam:self.applilinkParams
                                                        delegate:delegate];
        });
        return;
    }
    NSDictionary *userInfo = [NSDictionary
        dictionaryWithObjectsAndKeys:[NSString
                                         stringWithFormat:kRecommendCoreFormatBannerDisplayStatus,
                                                          adModel],
                                     nil];
    NSError *error =
        [ApplilinkNetworkError localizedApplilinkErrorWithCode:RecommendCoreErrorCodeNoBannerData
                                                      userInfo:userInfo];
    ApplilinkParameters *appParam = [[ApplilinkParameters alloc] init];
    [appParam setRequestWithAdModel:adModel adLocation:adLocation requestCode:requestCode];
    [ApplilinkCore toDelegateFailOpenWithError:error appParam:appParam delegate:delegate];
}

- (void)closeAdScreen {
    if (!self.adScreenviewCloseFlg) {
        [self.adScreenViewController appliListClosed];
    }
    if (self.interstitialViewController != nil) {
        if ([self.interstitialViewController isVisible]) {
            [ApplilinkCore toDelegateDidDisappear:self.applilinkParams
                                         delegate:self.applilinkDelegate];
        } else {
            [ApplilinkCore toDelegateFailOpenWithError:[ApplilinkNetworkError
                                                           localizedApplilinkErrorWithCode:
                                                               RecommendCoreErrorCodeAlreadyOpen]
                                              appParam:self.applilinkParams
                                              delegate:self.applilinkDelegate];
        }
        self.applilinkDelegate = nil;
        [self releaseInterstitialViewController];
    }
    self.adScreenviewCloseFlg = YES;
    g_recommendCoreScreenOpen = NO;
    self.adScreenViewController = nil;
}

- (void)rotateWithInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
                              duration:(NSTimeInterval)duration {
    if (self.adScreenViewController != nil) {
        [self.adScreenViewController willAnimateRotationToInterfaceOrientation:interfaceOrientation
                                                                      duration:duration];
    }
    if (self.interstitialViewController != nil) {
        [self.interstitialViewController
            willAnimateRotationToInterfaceOrientation:interfaceOrientation
                                             duration:duration];
    }
}

#pragma mark - Redirect

- (int)redirectViewContollerWithRequest:(NSURLRequest *)request {
    return [self redirectWithRequest:request appParam:self.applilinkParams];
}

- (int)redirectWithRequest:(NSURLRequest *)request {
    return [self redirectWithRequest:request appParam:nil];
}

- (int)redirectWithRequest:(NSURLRequest *)request appParam:(ApplilinkParameters *)appParam {
    // The binary rewrites the request URL in place, so it is always an NSMutableURLRequest.
    NSMutableURLRequest *mutableRequest = (NSMutableURLRequest *)request;
    NSURL *url = request.URL;
    NSString *scheme = url.scheme;
    NSString *host = url.host;
    int port = [url.port intValue];
    NSString *path = url.path;
    NSString *query = url.query;
    if ([scheme hasPrefix:kRecommendCoreApplilinkScheme] &&
        [host isEqualToString:kRecommendCoreExtAppHost] && port == kRecommendCoreExtAppPort) {
        NSString *adIdTo = nil;
        NSString *storeId = nil;
        NSString *countryCode = nil;
        NSString *categoryId = nil;
        NSString *adType = nil;
        NSString *defaultScheme = nil;
        BOOL keepParsing = YES;
        if (query != nil) {
            NSArray *components = [query componentsSeparatedByString:kRecommendCoreQuerySeparator];
            for (NSString *component in components) {
                if ([component rangeOfString:kRecommendCoreQueryDefaultScheme].location !=
                    NSNotFound) {
                    NSString *value =
                        [component substringFromIndex:kRecommendCoreQueryDefaultScheme.length];
                    defaultScheme = [NSStringURLEncoding URLDecodedString:value];
                    NSURL *appUrl = [NSURL
                        URLWithString:[NSString stringWithFormat:kRecommendCoreFormatSchemeOnly,
                                                                 defaultScheme]];
                    if (appUrl != nil && [[UIApplication sharedApplication] canOpenURL:appUrl]) {
                        [[UIApplication sharedApplication] openURL:appUrl];
                        keepParsing = NO;
                    } else {
                        keepParsing = NO;
                    }
                    break;
                } else if ([component rangeOfString:kRecommendCoreQueryAdIdFrom].location !=
                           NSNotFound) {
                    adIdTo = [NSStringURLEncoding
                        URLDecodedString:[component substringFromIndex:kRecommendCoreQueryAdIdFrom
                                                                           .length]];
                } else if ([component rangeOfString:kRecommendCoreQueryCountryCode].location !=
                           NSNotFound) {
                    countryCode = [NSStringURLEncoding
                        URLDecodedString:[component
                                             substringFromIndex:kRecommendCoreQueryCountryCode
                                                                    .length]];
                } else if ([component rangeOfString:kRecommendCoreQueryCategoryId].location !=
                           NSNotFound) {
                    categoryId = [NSStringURLEncoding
                        URLDecodedString:[component substringFromIndex:kRecommendCoreQueryCategoryId
                                                                           .length]];
                } else if ([component rangeOfString:kRecommendCoreQueryAdType].location !=
                           NSNotFound) {
                    adType = [NSStringURLEncoding
                        URLDecodedString:[component
                                             substringFromIndex:kRecommendCoreQueryAdType.length]];
                } else if ([component rangeOfString:kRecommendCoreQueryStoreId].location !=
                           NSNotFound) {
                    storeId = [NSStringURLEncoding
                        URLDecodedString:[component
                                             substringFromIndex:kRecommendCoreQueryStoreId.length]];
                }
            }
        }
        if (keepParsing) {
            if (adIdTo != nil && countryCode != nil && categoryId != nil) {
                RecommendAdId *adId = [[RecommendAdId alloc] initWithCountryCode:countryCode
                                                                      categoryId:categoryId];
                [adId setWithAdIdFrom:adIdTo
                          countryCode:countryCode
                           categoryId:categoryId
                               adType:adType
                                error:nil];
            }
        } else {
            return 0;
        }
        NSString *extAppPrefix = kRecommendCoreApplilinkExtAppUrl;
        NSString *tail = path;
        if ([url.absoluteString hasPrefix:extAppPrefix]) {
            tail = [url.absoluteString substringFromIndex:extAppPrefix.length];
            if (query.length != 0) {
                NSString *querySuffix =
                    [NSString stringWithFormat:kRecommendCoreFormatQuery, query];
                if ([tail hasSuffix:querySuffix]) {
                    tail = [tail substringToIndex:tail.length - querySuffix.length];
                }
            }
        }
        if (tail.length == 0) {
            return 1;
        }
        NSArray *segments =
            [[tail substringFromIndex:1] componentsSeparatedByString:kRecommendCorePathSeparator];
        if (segments.count == 0) {
            return 1;
        }
        NSString *destination = [NSStringURLEncoding URLDecodedString:segments[0]];
        if ([destination hasSuffix:kRecommendCoreChangeDestSuffix]) {
            [self reloadAllAdData];
            NSURL *destUrl = [NSURL
                URLWithString:[destination substringToIndex:destination.length -
                                                            kRecommendCoreChangeDestSuffix.length]];
            [mutableRequest setURL:destUrl];
            return 2;
        }
        if ([ApplilinkCore showAppStoreId:storeId appParam:appParam delegate:self]) {
            return 3;
        }
        NSURL *destUrl = [NSURL URLWithString:destination];
        [mutableRequest setURL:destUrl];
        if (destUrl != nil && [[UIApplication sharedApplication] canOpenURL:destUrl]) {
            [[UIApplication sharedApplication] openURL:destUrl];
            return 0;
        }
        if ([destination isEqualToString:kRecommendCoreCloseHost]) {
            return 0;
        }
        return 0;
    }
    return 1;
}

#pragma mark - Banner cache

- (id)getTemporaryCacheWithAdModel:(int)adModel {
    NSData *data = [[NSUserDefaults standardUserDefaults] objectForKey:kRecommendCoreBannerInfoKey];
    if (data == nil) {
        return nil;
    }
    NSDictionary *table = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    if (table == nil) {
        return nil;
    }
    NSString *modelKey = [@(adModel) stringValue];
    NSDictionary *entry = table[modelKey];
    if (entry == nil) {
        return nil;
    }
    if ([entry[kRecommendCoreKeyExpire] compare:[NSDate date]] != NSOrderedAscending) {
        return entry[kRecommendCoreKeyStatus];
    }
    NSMutableDictionary *mutableTable = [table mutableCopy];
    [mutableTable removeObjectForKey:[@(adModel) stringValue]];
    NSData *archived = [NSKeyedArchiver archivedDataWithRootObject:mutableTable];
    [[NSUserDefaults standardUserDefaults] setObject:archived forKey:kRecommendCoreBannerInfoKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    return nil;
}

- (BOOL)canUseBannerCache {
    NSString *udid = [ApplilinkCore udid];
    NSString *adUdid = [ApplilinkCore ad_udid];
    NSString *oldUdid = [ApplilinkCore old_udid];
    if (udid == nil && oldUdid == nil && adUdid == nil) {
        [self clearAdStatus];
    }
    return udid != nil || oldUdid != nil || adUdid != nil;
}

- (void)clearAdStatus {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kRecommendCoreBannerInfoKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)clearSession {
    NSHTTPCookieStorage *storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (NSHTTPCookie *cookie in storage.cookies) {
        [storage deleteCookie:cookie];
    }
}

- (void)clearData {
    NSString *env = [ApplilinkConsts envServer];
    if (env != nil && ![env isEqualToString:@""]) {
        [ApplilinkUdid deleteAllUDID];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kRecommendCorePostInstalledKey];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kRecommendCoreAppliIdKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

#pragma mark - Analytics and first-party adverts

- (void)postAnalysisListRegistWithAdType:(int)adType
                                 AdModel:(int)adModel
                              adLocation:(NSString *)adLocation
                            impressionId:(NSString *)impressionId {
    // The binary collects an ad_id array too but discards it (its slot is reused for a format
    // string), so it is not built here. The four lists actually posted are appli_id, the creative
    // URL file names, incentive types, and install flags.
    NSMutableArray *appliIdList = [NSMutableArray array];
    NSMutableArray *creativeIdList = [NSMutableArray array];
    NSMutableArray *incentiveTypeList = [NSMutableArray array];
    NSMutableArray *installFlgList = [NSMutableArray array];
    NSArray *records = [RecommendAdCache getHtmlAdDataWithAdModel:adModel adLocation:adLocation];
    for (NSDictionary *record in records) {
        NSString *appliId = record[kRecommendCoreKeyAppliId];
        if (appliId != nil) {
            [appliIdList addObject:appliId];
        }
        NSString *creativeUrl = nil;
        if (adType == RecommendCoreAdTypeInterstitial) {
            creativeUrl = record[kRecommendCoreKeyInterstitialBannerUrl];
        } else if (adType == RecommendCoreAdTypeIcon) {
            creativeUrl = record[kRecommendCoreKeyBannerIconUrl];
        } else if (adType == RecommendCoreAdTypeBanner) {
            creativeUrl = record[kRecommendCoreKeyBannerUrl];
        }
        if (creativeUrl != nil) {
            NSString *fileName = [ApplilinkUtilities geFileNameFromPath:creativeUrl];
            if (fileName != nil) {
                [creativeIdList addObject:fileName];
            }
        }
        NSString *incentiveType = record[kRecommendCoreKeyIncentiveType];
        if (incentiveType != nil) {
            [incentiveTypeList addObject:incentiveType];
        }
        NSString *installFlg = [RecommendAdData getInstallFlgWithAdData:record];
        if (installFlg != nil) {
            [installFlgList addObject:installFlg];
        }
    }
    [AnalysisNetworkCore
        postAnalysisListRegistWithAdType:[NSString
                                             stringWithFormat:kRecommendCoreFormatInteger, adType]
                                 adModel:[NSString
                                             stringWithFormat:kRecommendCoreFormatInteger, adModel]
                              adLocation:adLocation
                            impressionId:impressionId
                             appliIdList:appliIdList
                          creativeIdList:creativeIdList
                       incentiveTypeList:incentiveTypeList
                          installFlgList:installFlgList
                                callback:^(NSError *_Nullable error) {
                                  /** @ghidraAddress 0x23c098 */
                                  if (error != nil) {
                                      return;
                                  }
                                  [self setUniqueAdWithAdLocation:adLocation
                                                     impressionId:impressionId];
                                }];
}

- (void)showOwnAdWithAdLocation:(NSString *)adLocation
                      toAppliId:(NSString *)appliId
                     creativeId:(NSString *)creativeId {
    if (adLocation == nil) {
        return;
    }
    if (!([RecommendCore sharedInstance].initializeFlg != 0 ||
          [ApplilinkCore isInitializeStatusFlg]) ||
        ![ApplilinkUdid isAdvertisingTrackingEnabled]) {
        return;
    }
    [self startSessionWithCallback:^(NSError *_Nullable error) {
      /** @ghidraAddress 0x23c2ac */
      if (error != nil) {
          return;
      }
      NSMutableArray *appliIdList = [NSMutableArray array];
      NSMutableArray *creativeIdList = [NSMutableArray array];
      NSMutableArray *incentiveTypeList = [NSMutableArray array];
      NSMutableArray *installFlgList = [NSMutableArray array];
      NSString *impressionId = [ApplilinkUtilities getImpressionId];
      [self setUniqueAdWithAdLocation:adLocation impressionId:impressionId];
      if (appliId != nil && creativeId != nil) {
          NSDictionary *record = [RecommendAdData getAdDataWithAppliId:appliId];
          NSString *installFlg = @"";
          if (record != nil) {
              installFlg = [RecommendAdData getInstallFlgWithAdData:record];
          }
          [appliIdList addObject:appliId];
          [creativeIdList addObject:creativeId];
          [incentiveTypeList addObject:kRecommendCoreKeyRewardNone];
          [installFlgList addObject:installFlg];
      }
      [AnalysisNetworkCore
          postAnalysisListRegistWithAdType:[NSString
                                               stringWithFormat:kRecommendCoreFormatInteger, 0]
                                   adModel:[NSString
                                               stringWithFormat:kRecommendCoreFormatInteger, 0]
                                adLocation:adLocation
                              impressionId:impressionId
                               appliIdList:appliIdList
                            creativeIdList:creativeIdList
                         incentiveTypeList:incentiveTypeList
                            installFlgList:installFlgList
                                  callback:nil];
    }];
}

- (void)touchOwnAdWithAdLocation:(NSString *)adLocation
                       toAppliId:(NSString *)appliId
                      creativeId:(NSString *)creativeId
                     requestCode:(id)requestCode
                        delegate:(id)delegate {
    NSError *error;
    if (adLocation == nil || appliId == nil || creativeId == nil) {
        error =
            [ApplilinkNetworkError localizedApplilinkErrorWithCode:RecommendCoreErrorCodeParameter];
    } else if ([RecommendCore sharedInstance].initializeFlg == 0 &&
               ![ApplilinkCore isInitializeStatusFlg]) {
        error = [ApplilinkNetworkError
            localizedApplilinkErrorWithCode:RecommendCoreErrorCodeNotInitialized];
    } else if (![ApplilinkUdid isAdvertisingTrackingEnabled]) {
        error = [ApplilinkNetworkError
            localizedApplilinkErrorWithCode:RecommendCoreErrorCodeAdTrackingDisabled];
    } else {
        [self startSessionWithCallback:^(NSError *_Nullable sessionError) {
          /** @ghidraAddress 0x23c934 */
          [self postAnalysisClickRegistWithError:sessionError
                                      adLocation:adLocation
                                         appliId:appliId
                                      creativeId:creativeId
                                     requestCode:requestCode
                                        delegate:delegate];
        }];
        return;
    }
    ApplilinkParameters *appParam = [[ApplilinkParameters alloc] init];
    [appParam setRequestWithAdModel:RecommendCoreAdModelOwnAdBase
                         adLocation:adLocation
                        requestCode:requestCode];
    [ApplilinkCore toDelegateFailOpenWithError:error appParam:appParam delegate:delegate];
}

// The session-gated click-registration callback for a first-party advert touch.
/** @ghidraAddress 0x23c934 */
- (void)postAnalysisClickRegistWithError:(nullable NSError *)error
                              adLocation:(nullable NSString *)adLocation
                                 appliId:(nullable NSString *)appliId
                              creativeId:(nullable NSString *)creativeId
                             requestCode:(nullable id)requestCode
                                delegate:(nullable id)delegate {
    if (error != nil) {
        ApplilinkParameters *appParam = [[ApplilinkParameters alloc] init];
        [appParam setRequestWithAdModel:RecommendCoreAdModelOwnAdBase
                             adLocation:adLocation
                            requestCode:requestCode];
        [ApplilinkCore toDelegateFailOpenWithError:error appParam:appParam delegate:delegate];
        return;
    }
    NSString *impressionId = [self getUniqueAdWithAdLocation:adLocation];
    if ([impressionId length] == 0) {
        impressionId = [ApplilinkUtilities getImpressionId];
    }
    NSDictionary *record = [RecommendAdData getAdDataWithAppliId:appliId];
    if (record == nil) {
        NSDictionary *userInfo = [NSDictionary
            dictionaryWithObjectsAndKeys:[NSString
                                             stringWithFormat:kRecommendCoreFormatAllAdDataMissing],
                                         nil];
        NSError *noDataError =
            [ApplilinkNetworkError localizedApplilinkErrorWithCode:RecommendCoreErrorCodeNoAdData
                                                          userInfo:userInfo];
        ApplilinkParameters *appParam = [[ApplilinkParameters alloc] init];
        [appParam setRequestWithAdModel:RecommendCoreAdModelOwnAdBase
                             adLocation:adLocation
                            requestCode:requestCode];
        [ApplilinkCore toDelegateFailOpenWithError:noDataError appParam:appParam delegate:delegate];
        return;
    }
    NSString *adId = record[kRecommendCoreKeyAdId];
    NSString *installFlg = [RecommendAdData getInstallFlgWithAdData:record];
    NSString *defaultScheme = record[kRecommendCoreKeyDefaultScheme];
    [AnalysisNetworkCore
        postAnalysisClickRegistWithAdType:[NSString stringWithFormat:kRecommendCoreFormatInteger, 0]
                                  adModel:[NSString stringWithFormat:kRecommendCoreFormatInteger, 0]
                               adLocation:adLocation
                             impressionId:impressionId
                                appliIdTo:appliId
                               creativeId:creativeId
                            displayNumber:kRecommendCoreDisplayNumberDefault
                            incentiveType:kRecommendCoreKeyRewardNone
                               installFlg:installFlg
                                 callback:^(NSError *_Nullable clickError) {
                                   /** @ghidraAddress 0x23cde0 */
                                   if (clickError != nil) {
                                       ApplilinkParameters *appParam =
                                           [[ApplilinkParameters alloc] init];
                                       [appParam setRequestWithAdModel:RecommendCoreAdModelOwnAdBase
                                                            adLocation:adLocation
                                                           requestCode:requestCode];
                                       [ApplilinkCore toDelegateFailOpenWithError:clickError
                                                                         appParam:appParam
                                                                         delegate:delegate];
                                       return;
                                   }
                                   if (self.uniqueApplilinkParams == nil) {
                                       self.uniqueApplilinkParams =
                                           [[ApplilinkParameters alloc] init];
                                   }
                                   [self.uniqueApplilinkParams
                                       setRequestWithAdModel:RecommendCoreAdModelOwnAdBase
                                                  adLocation:adLocation
                                                 requestCode:requestCode];
                                   [self
                                       linkActionWithDefaultScheme:defaultScheme
                                                            adIdTo:adId
                                                            adType:
                                                                [NSString
                                                                    stringWithFormat:
                                                                        kRecommendCoreFormatInteger,
                                                                        0]
                                                           adModel:
                                                               [NSString
                                                                   stringWithFormat:
                                                                       kRecommendCoreFormatInteger,
                                                                       0]
                                                          delegate:delegate];
                                 }];
}

- (void)linkActionWithDefaultScheme:(NSString *)defaultScheme
                             adIdTo:(NSString *)adIdTo
                             adType:(NSString *)adType
                            adModel:(NSString *)adModel
                           delegate:(id)delegate {
    self.uniqueAdDelegate = delegate;
    self.redirectFlg = NO;
    NSURL *schemeUrl = [NSURL
        URLWithString:[NSString stringWithFormat:kRecommendCoreFormatSchemeOnly, defaultScheme]];
    BOOL canOpenScheme = NO;
    if (schemeUrl != nil) {
        canOpenScheme = [[UIApplication sharedApplication] canOpenURL:schemeUrl];
    }
    NSString *adIdFrom = [ApplilinkConsts adId];
    NSURLRequest *request;
    if (!canOpenScheme) {
        request = [RecommendWebAPI clickRegistWithAdIdFrom:adIdFrom
                                                    adIdTo:adIdTo
                                                   adModel:[adModel intValue]];
    } else {
        request = [RecommendWebAPI appStartWithAdIdFrom:adIdFrom
                                                 adIdTo:adIdTo
                                                 adType:[adType intValue]];
    }
    ApplilinkURLConnection *connection = [[ApplilinkURLConnection alloc] init];
    [connection loadRequestWithRequest:request delegate:self];
}

- (void)setUniqueAdWithAdLocation:(NSString *)adLocation impressionId:(NSString *)impressionId {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSData *data = [defaults dataForKey:kRecommendCoreUniqueAdDataKey];
    NSMutableDictionary *table;
    if (data == nil) {
        table = [NSMutableDictionary dictionary];
    } else {
        table = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    }
    if (impressionId == nil) {
        [table removeObjectForKey:adLocation];
    } else {
        [table setObject:impressionId forKey:adLocation];
    }
    NSData *archived = [NSKeyedArchiver archivedDataWithRootObject:table];
    [defaults setObject:archived forKey:kRecommendCoreUniqueAdDataKey];
    [defaults synchronize];
}

- (id)getUniqueAdWithAdLocation:(NSString *)adLocation {
    NSData *data = [[NSUserDefaults standardUserDefaults] dataForKey:kRecommendCoreUniqueAdDataKey];
    if (data == nil) {
        return nil;
    }
    NSDictionary *table = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    return table[adLocation];
}

#pragma mark - Click connection callbacks

- (void)failLoadWithError:(NSError *)error {
    if (error.code == kRecommendCoreWebKitCancelledCode) {
        return;
    }
    if (error.code == kRecommendCoreWebKitFrameLoadInterruptedCode &&
        [error.domain isEqual:kRecommendCoreWebKitErrorDomain]) {
        return;
    }
    if (error.code == kRecommendCoreWebKitPlugInCancelledCode &&
        [error.domain isEqual:kRecommendCoreWebKitErrorDomain]) {
        return;
    }
    if (!self.redirectFlg) {
        [ApplilinkCore toDelegateFailOpenWithError:error
                                          appParam:self.uniqueApplilinkParams
                                          delegate:self.uniqueAdDelegate];
        self.uniqueAdDelegate = nil;
    }
}

- (void)finishLoadWithResponse:(id)response {
    // The binary's implementation is intentionally empty.
}

- (BOOL)redirectStartLoad:(NSURLRequest *)request {
    NSMutableURLRequest *mutableRequest = [NSMutableURLRequest requestWithURL:request.URL];
    if ([self redirectWithRequest:mutableRequest] == 1) {
        self.redirectFlg = YES;
    }
    return NO;
}

#pragma mark - Controller teardown

- (void)releaseAdScreenViewController {
    if (self.adScreenViewController != nil) {
        [self.adScreenViewController viewDealloc];
        self.adScreenViewController = nil;
    }
    g_recommendCoreScreenOpen = NO;
}

- (void)releaseInterstitialViewController {
    if (self.interstitialViewController != nil) {
        [self.interstitialViewController.view removeFromSuperview];
        self.interstitialViewController = nil;
    }
    g_recommendCoreScreenOpen = NO;
}

#pragma mark - Installed-application list notices

- (void)appListDidStart {
    if (self.applilinkDelegate != nil) {
        if ([self.applilinkDelegate respondsToSelector:@selector(appListDidStart)]) {
            [self.applilinkDelegate appListDidStart];
        }
    }
    if (self.adScreenViewController != nil) {
        [ApplilinkCore toDelegateDidAppear:self.applilinkParams delegate:self.applilinkDelegate];
    }
}

- (void)appListDidAppear {
    if (self.adScreenViewController == nil) {
        ApplilinkParameters *appParam = [[ApplilinkParameters alloc] init];
        [appParam setRequestWithAdModel:0 adLocation:nil requestCode:nil];
        [ApplilinkCore toDelegateDidAppear:appParam delegate:self.adAreaDelegate];
    } else {
        [self.adScreenViewController updateIndicator:NO];
        [ApplilinkCore toDelegateDidAppear:self.applilinkParams delegate:self.applilinkDelegate];
    }
}

- (void)appListDidDisappear {
    if (self.adScreenViewController != nil) {
        [self.adScreenViewController clearDelegate];
        [self releaseAdScreenViewController];
        [ApplilinkCore toDelegateDidDisappear:self.applilinkParams delegate:self.applilinkDelegate];
        self.applilinkDelegate = nil;
        return;
    }
    ApplilinkParameters *appParam = [[ApplilinkParameters alloc] init];
    [appParam setRequestWithAdModel:0 adLocation:nil requestCode:nil];
    [ApplilinkCore toDelegateDidDisappear:appParam delegate:self.adAreaDelegate];
    self.adAreaDelegate = nil;
}

- (void)appListFailOpenWithError:(NSError *)error {
    if (self.adScreenViewController == nil) {
        if (self.adAreaDelegate != self) {
            ApplilinkParameters *appParam = [[ApplilinkParameters alloc] init];
            [appParam setRequestWithAdModel:0 adLocation:nil requestCode:nil];
            [ApplilinkCore toDelegateFailOpenWithError:error
                                              appParam:appParam
                                              delegate:self.adAreaDelegate];
            self.adAreaDelegate = nil;
        }
    } else {
        [self.adScreenViewController clearDelegate];
        [self releaseAdScreenViewController];
        if (self.applilinkDelegate != self) {
            [ApplilinkCore toDelegateFailOpenWithError:error
                                              appParam:self.applilinkParams
                                              delegate:self.applilinkDelegate];
            self.applilinkDelegate = nil;
        }
    }
}

- (void)appListFailLoadWithError:(NSError *)error {
    if (self.adScreenViewController == nil) {
        if (self.adAreaDelegate != self) {
            ApplilinkParameters *appParam = [[ApplilinkParameters alloc] init];
            [appParam setRequestWithAdModel:0 adLocation:nil requestCode:nil];
            [ApplilinkCore toDelegateFailLoadWithError:error
                                              appParam:appParam
                                              delegate:self.adAreaDelegate];
            self.adAreaDelegate = nil;
        }
    } else {
        [self.adScreenViewController clearDelegate];
        [self releaseAdScreenViewController];
        if (self.applilinkDelegate != self) {
            [ApplilinkCore toDelegateFailLoadWithError:error
                                              appParam:self.applilinkParams
                                              delegate:self.applilinkDelegate];
            self.applilinkDelegate = nil;
        }
    }
}

- (void)appListFailWithError:(NSError *)error {
    if (self.adScreenViewController == nil) {
        if (self.adAreaDelegate != self) {
            ApplilinkParameters *appParam = [[ApplilinkParameters alloc] init];
            [appParam setRequestWithAdModel:0 adLocation:nil requestCode:nil];
            [ApplilinkCore toDelegateFailLoadWithError:error
                                              appParam:appParam
                                              delegate:self.adAreaDelegate];
            self.adAreaDelegate = nil;
        }
    } else {
        [self.adScreenViewController clearDelegate];
        [self releaseAdScreenViewController];
        if (self.applilinkDelegate != self) {
            [ApplilinkCore toDelegateFailLoadWithError:error
                                              appParam:self.applilinkParams
                                              delegate:self.applilinkDelegate];
            self.applilinkDelegate = nil;
        }
    }
}

#pragma mark - Advert-lifecycle notices

- (void)startedNotice {
    [ApplilinkCore toDelegateDidStart:self.applilinkParams delegate:self.applilinkDelegate];
}

- (void)openedNotice {
    [ApplilinkCore toDelegateDidAppear:self.applilinkParams delegate:self.applilinkDelegate];
    if (self.adScreenViewController != nil) {
        [self.adScreenViewController updateIndicator:NO];
    }
}

- (void)closeNotice {
    if (self.adScreenViewController != nil) {
        [self.adScreenViewController clearDelegate];
    }
    [self releaseAdScreenViewController];
    [ApplilinkCore toDelegateDidDisappear:self.applilinkParams delegate:self.applilinkDelegate];
    self.applilinkDelegate = nil;
}

- (void)failOpenNoticeWithError:(NSError *)error {
    if (self.adScreenViewController != nil) {
        [self.adScreenViewController clearDelegate];
    }
    [self releaseAdScreenViewController];
    [ApplilinkCore toDelegateFailLoadWithError:error
                                      appParam:self.applilinkParams
                                      delegate:self.applilinkDelegate];
    self.applilinkDelegate = nil;
}

- (void)failLinkNoticeWithError:(NSError *)error {
    [ApplilinkCore toDelegateFailLinkWithError:error
                                      appParam:self.applilinkParams
                                      delegate:self.applilinkDelegate];
}

- (void)appStoreOpenedNoticeWithAppParam:(ApplilinkParameters *)appParam {
    if (self.adScreenViewController != nil) {
        return;
    }
    [ApplilinkCore toDelegateDidAppear:self.uniqueApplilinkParams delegate:self.uniqueAdDelegate];
}

- (void)appStoreCloseNoticeWithAppParam:(ApplilinkParameters *)appParam {
    // The binary's implementation is intentionally empty.
}

- (void)appStoreClosedNoticeWithAppParam:(ApplilinkParameters *)appParam {
    if (self.adScreenViewController != nil) {
        return;
    }
    id delegate;
    ApplilinkParameters *params = appParam;
    if (self.uniqueApplilinkParams != nil) {
        delegate = self.uniqueAdDelegate;
        params = self.uniqueApplilinkParams;
    } else {
        if (appParam == nil) {
            return;
        }
        delegate = self.applilinkDelegate;
    }
    [ApplilinkCore toDelegateDidDisappear:params delegate:delegate];
}

- (void)appStoreFailLoadNoticeWithError:(NSError *)error appParam:(ApplilinkParameters *)appParam {
    if (self.adScreenViewController == nil) {
        // The unique-advert path fails open; the advert-screen path fails the link. Both go
        // through toDelegateFailOpenWithError:appParam:delegate: in the binary.
        [ApplilinkCore toDelegateFailOpenWithError:error
                                          appParam:self.uniqueApplilinkParams
                                          delegate:self.uniqueAdDelegate];
    } else {
        [ApplilinkCore toDelegateFailOpenWithError:error
                                          appParam:self.applilinkParams
                                          delegate:self.applilinkDelegate];
    }
}

- (void)appStoreTransitionNoticeWithAppParam:(ApplilinkParameters *)appParam {
    // The binary's implementation is intentionally empty.
}

@end
