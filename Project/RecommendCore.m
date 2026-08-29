#import "RecommendCore.h"

#import "AnalysisNetworkCore.h"
#import "ApplilinkConsts.h"
#import "ApplilinkCore.h"
#import "ApplilinkNetworkError.h"
#import "ApplilinkParameters.h"
#import "ApplilinkStore.h"
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

typedef enum {
    RecommendCoreErrorCodeParameter = 1001,
    RecommendCoreErrorCodeNotInitialized = 1010,
    RecommendCoreErrorCodeNoAdData = 1034,
    RecommendCoreErrorCodeCacheCreate = 1035,
    RecommendCoreErrorCodeAlreadyOpen = 1036,
    RecommendCoreErrorCodeNoBannerData = 1037,
    RecommendCoreErrorCodeAdTrackingDisabled = 1028,
    RecommendCoreErrorCodeNoAppliId = 1029,
} RecommendCoreErrorCode;

typedef enum {
    RecommendCoreAdModelInterstitial = 5,
    RecommendCoreAdModelOwnAdBase = 100,
    RecommendCoreAdModelDirectRangeLength = 2,
} RecommendCoreAdModel;

typedef enum {
    RecommendCoreAdTypeBanner = 2,
    RecommendCoreAdTypeIcon = 3,
    RecommendCoreAdTypeInterstitial = 5,
} RecommendCoreAdType;

static const int kRecommendCoreBannerAvailable = 1;

static const int kRecommendCoreAdStatusAvailable = 1;

static const NSTimeInterval kRecommendCoreLoginValiditySeconds = 60.0;

static const int kRecommendCoreInstallPriority = 1;

static NSString *const kRecommendCoreApplilinkScheme = @"applilink";
static NSString *const kRecommendCoreExtAppHost = @"ext-app";
static const int kRecommendCoreExtAppPort = 80;
static NSString *const kRecommendCoreApplilinkExtAppUrl = @"applilink://ext-app:80";
static NSString *const kRecommendCoreChangeDestSuffix = @"#changeDest";
static NSString *const kRecommendCoreCloseHost = @"close";

static NSString *const kRecommendCoreQueryDefaultScheme = @"default_scheme=";
static NSString *const kRecommendCoreQueryAdIdFrom = @"ad_id_from=";
static NSString *const kRecommendCoreQueryCountryCode = @"country_code=";
static NSString *const kRecommendCoreQueryCategoryId = @"category_id=";
static NSString *const kRecommendCoreQueryAdType = @"ad_type=";
static NSString *const kRecommendCoreQueryStoreId = @"store_id=";

// The binary searches for the bare key, then skips past the key with the trailing "=" above.
static NSString *const kRecommendCoreQueryKeyDefaultScheme = @"default_scheme";
static NSString *const kRecommendCoreQueryKeyAdIdFrom = @"ad_id_from";
static NSString *const kRecommendCoreQueryKeyCountryCode = @"country_code";
static NSString *const kRecommendCoreQueryKeyCategoryId = @"category_id";
static NSString *const kRecommendCoreQueryKeyAdType = @"ad_type";
static NSString *const kRecommendCoreQueryKeyStoreId = @"store_id";

static NSString *const kRecommendCoreAdExternalIndexPath = @"/ad/external/index.php";

static NSString *const kRecommendCorePostInstalledKey = @"ApplilinkRecommend.postInstalled";
static NSString *const kRecommendCoreBannerInfoKey = @"ApplilinkRecommend.bannerInfo";
static NSString *const kRecommendCoreUniqueAdDataKey = @"UniqueAdData";
static NSString *const kRecommendCoreAppliIdKey = @"ApplilinkNetwork.appliId";

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

// The disabled server environment is "0", not the empty string.
static NSString *const kRecommendCoreInstallFlgNone = @"0";
static NSString *const kRecommendCoreEnvServerDisabled = @"0";
static NSString *const kRecommendCoreDisplayNumberDefault = @"1";

static NSString *const kRecommendCoreParamIsSdk = @"is_sdk";
static NSString *const kRecommendCoreParamAdLocation = @"ad_location";
static NSString *const kRecommendCoreParamAdModel = @"ad_model";
static NSString *const kRecommendCoreParamVerticalAlign = @"vertical_align";
static NSString *const kRecommendCoreParamInstallAdIdList = @"install_ad_id_list";
static NSString *const kRecommendCoreParamValueOne = @"1";

static NSString *const kRecommendCoreFormatInteger = @"%d";
static NSString *const kRecommendCoreFormatSchemeOnly = @"%@://";
static NSString *const kRecommendCoreFormatQuery = @"?%@";
static NSString *const kRecommendCoreFormatHtmlName = @"%d_%@.html";
static NSString *const kRecommendCoreFormatBannerDisplayStatus =
    @"banner_display_status_list ad_model:%d";
static NSString *const kRecommendCoreFormatAllAdDataMissing =
    @"allAdDataForDisplay fall in line with list by no appliId %@";

static NSString *const kErrorUserInfoKey = @"Error";

static const NSInteger kRecommendCoreWebKitCancelledCode = -999;
static const NSInteger kRecommendCoreWebKitFrameLoadInterruptedCode = 102;
static const NSInteger kRecommendCoreWebKitPlugInCancelledCode = 204;
static NSString *const kRecommendCoreWebKitErrorDomain = @"WebKitErrorDomain";

static NSString *const kRecommendCoreQuerySeparator = @"&";
static NSString *const kRecommendCorePathSeparator = @"/";

static BOOL g_recommendCoreScreenOpen = NO;

static NSDate *g_recommendCoreLoginValidUntil = nil;

static RecommendCore *g_recommendCoreInstance = nil;
static dispatch_queue_t g_recommendCoreQueue = nil;

@interface RecommendCore () <SdkViewDelegate>
@end

static void RecommendCoreOpenAdScreenAppliList(RecommendCore *core,
                                               id appliList,
                                               NSError *error,
                                               NSString *adLocation,
                                               int adModel,
                                               int verticalAlign,
                                               id delegate);

static void RecommendCorePostAnalysisClickRegist(RecommendCore *core,
                                                 NSError *error,
                                                 NSString *adLocation,
                                                 NSString *appliId,
                                                 NSString *creativeId,
                                                 id requestCode,
                                                 id delegate);

@implementation RecommendCore

#pragma mark - Singleton

+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      /** @ghidraAddress 0x236ca8 */
      g_recommendCoreInstance = [[RecommendCore alloc] init];
      g_recommendCoreInstance.initializeFlg = NO;
    });
    return g_recommendCoreInstance;
}

/**
 * @ghidraAddress 0x236b4c (dispatch_once body BlockInvokeAllocRecommendCore at 0x236bc4). Routes
 * every allocation through a single super-allocation so the class is a true singleton, and creates
 * the serial queue used to serialise its work.
 */
+ (instancetype)allocWithZone:(NSZone *)zone {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      g_recommendCoreQueue = dispatch_queue_create("RecommendCore", nil);
      if (g_recommendCoreInstance == nil) {
          g_recommendCoreInstance = [super allocWithZone:zone];
          g_recommendCoreInstance.initializeFlg = NO;
      }
    });
    return g_recommendCoreInstance;
}

- (instancetype)init {
    // @ghidraAddress 0x236978
    __block RecommendCore *result = nil;
    dispatch_sync(g_recommendCoreQueue, ^{
      /** @ghidraAddress 0x236a88 */
      result = [super init];
    });
    return result;
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
        // Unguarded in the binary: this exit calls the block without a nil test.
        callback([ApplilinkNetworkError
            localizedApplilinkErrorWithCode:RecommendCoreErrorCodeNoAppliId]);
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
      // The first two block arguments are unnamed: the binary re-reads them from ApplilinkConsts.
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
    // Unlike -startWithCallback:, nothing on this path nil-tests the block before invoking it.
    if (![ApplilinkUdid isAdvertisingTrackingEnabled]) {
        callback([ApplilinkNetworkError
            localizedApplilinkErrorWithCode:RecommendCoreErrorCodeAdTrackingDisabled]);
        return;
    }
    [ApplilinkCore appAuthSessionRegenerateWithBlock:^(NSError *_Nullable error) {
      /** @ghidraAddress 0x237868 */
      if (error != nil) {
          callback(error);
          return;
      }
      if (g_recommendCoreLoginValidUntil == nil || [ApplilinkConsts isNeedRecommendLogin] ||
          [g_recommendCoreLoginValidUntil timeIntervalSinceNow] < 0.0) {
          // The binary reads only the login status and the error, ignoring userIdPresent.
          [RecommendWebAPI
              checkLoginWithCallback:^(BOOL loggedIn, BOOL userIdPresent, NSError *checkError) {
                /** @ghidraAddress 0x237960 */
                if (checkError != nil) {
                    callback(checkError);
                    return;
                }
                if (!loggedIn) {
                    [RecommendWebAPI startLoginWithCallback:^(NSError *_Nullable loginError) {
                      /** @ghidraAddress 0x237a94 */
                      if (loginError != nil) {
                          callback(loginError);
                          return;
                      }
                      [ApplilinkUdid setUdidKeychainFromPasteBoard];
                      [ApplilinkConsts loggedInRecommend];
                      g_recommendCoreLoginValidUntil = [[NSDate date]
                          dateByAddingTimeInterval:kRecommendCoreLoginValiditySeconds];
                      callback(nil);
                    }];
                    return;
                }
                g_recommendCoreLoginValidUntil =
                    [[NSDate date] dateByAddingTimeInterval:kRecommendCoreLoginValiditySeconds];
                callback(nil);
              }];
          return;
      }
      callback(nil);
    }];
}

#pragma mark - Installed-application list

- (void)appliListWithCallBack:(void (^)(id _Nullable list, NSError *_Nullable error))callback {
    [self startSessionWithCallback:^(NSError *_Nullable error) {
      /** @ghidraAddress 0x237c48 */
      if (error != nil) {
          callback(nil, error);
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
    callback(list, nil);
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
            callback([cached intValue], nil); // Yes, the binary sends -intValue a second time.
            return;
        }
        [self startSessionWithCallback:^(NSError *_Nullable sessionError) {
          /** @ghidraAddress 0x237f8c */
          if (sessionError != nil) {
              callback(0, sessionError);
              return;
          }
          [RecommendWebAPI getBannerDetailWithAdModel:adModel callback:callback];
        }];
        return;
    }
    callback(0, error);
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
              callback(0, sessionError);
              return;
          }
          [RecommendWebAPI getUnreadCountWithAdModel:adModel
                                          adLocation:adLocation
                                            callback:callback];
        }];
        return;
    }
    callback(0, error);
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
              callback(status, sessionError);
              return;
          }
          [RecommendWebAPI getPreInfoWithAdModel:adModel adLocation:adLocation callback:callback];
        }];
        return;
    }
    callback(status, error);
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
          callback(sessionError);
        }];
        return;
    }
    callback(error);
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
      [self.adScreenViewController setSdkDelegate:self];
      [self.adScreenViewController setNavigationBarHidden:self.navigationBarHidden];
      if (parentView == nil) {
          UIWindow *window = [ApplilinkCore mainWindow];
          if (window != nil) {
              [window addSubview:self.adScreenViewController.view];
          }
      } else {
          [self.adScreenViewController setParentView:parentView];
          [parentView addSubview:self.adScreenViewController.view];
      }
      [self.adScreenViewController updateIndicator:YES];
      if (adModel == RecommendCoreAdModelInterstitial) {
          [self.adScreenViewController setWebViewBounces:NO];
      }
      if ((unsigned int)(adModel - RecommendCoreAdModelOwnAdBase) <
              RecommendCoreAdModelDirectRangeLength ||
          adModel == RecommendCoreAdModelInterstitial) {
          UIView *baseView = self.adScreenViewController.baseView;
          CGRect baseFrame = baseView.frame;
          // The binary hands itself in as the delegate rather than the caller's.
          [self openAdAreaWithParentView:baseView
                                    rect:CGRectMake(
                                             0.0, 0.0, baseFrame.size.width, baseFrame.size.height)
                                 adModel:adModel
                              adLocation:adLocation
                           verticalAlign:verticalAlign
                             requestCode:requestCode
                                delegate:self];
          g_recommendCoreScreenOpen = NO;
      } else {
          [self appliListWithCallBack:^(id _Nullable list, NSError *_Nullable error) {
            /** @ghidraAddress 0x238e84 */
            RecommendCoreOpenAdScreenAppliList(
                self, list, error, adLocation, adModel, verticalAlign, delegate);
          }];
      }
    });
}

/** @ghidraAddress 0x238e84 */
static void RecommendCoreOpenAdScreenAppliList(RecommendCore *core,
                                               id appliList,
                                               NSError *error,
                                               NSString *adLocation,
                                               int adModel,
                                               int verticalAlign,
                                               id delegate) {
    if (error != nil || core.adScreenviewCloseFlg) {
        [core releaseAdScreenViewController];
        [ApplilinkCore toDelegateFailOpenWithError:error
                                          appParam:core.applilinkParams
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
        if ([scheme isKindOfClass:[NSString class]] && [core isInstalledAppliWithScheme:scheme] &&
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
    [core.adScreenViewController loadRequestWithURL:url parameters:parameters];
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
        if ((unsigned int)(adModel - RecommendCoreAdModelOwnAdBase) >=
                RecommendCoreAdModelDirectRangeLength &&
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
                                                                      adModel,
                                                                      adLocation]];
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
                                                   verticalAlign:verticalAlign
                                                 applilinkParams:self.applilinkParams
                                                        delegate:delegate
                                                   closeDelegate:self];
        });
        return;
    }
    NSDictionary *userInfo = [NSDictionary
        dictionaryWithObjectsAndKeys:[NSString
                                         stringWithFormat:kRecommendCoreFormatBannerDisplayStatus,
                                                          adModel],
                                     kErrorUserInfoKey,
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
        BOOL openedExternalApp = NO;
        if (query != nil) {
            NSArray *components = [query componentsSeparatedByString:kRecommendCoreQuerySeparator];
            for (NSString *component in components) {
                if ([component rangeOfString:kRecommendCoreQueryKeyDefaultScheme].location !=
                    NSNotFound) {
                    NSString *value =
                        [component substringFromIndex:kRecommendCoreQueryDefaultScheme.length];
                    defaultScheme = [NSStringURLEncoding URLDecodedString:value];
                    NSURL *appUrl = [NSURL
                        URLWithString:[NSString stringWithFormat:kRecommendCoreFormatSchemeOnly,
                                                                 defaultScheme]];
                    if (appUrl != nil && [[UIApplication sharedApplication] canOpenURL:appUrl]) {
                        [[UIApplication sharedApplication] openURL:appUrl];
                        openedExternalApp = YES;
                    }
                    break;
                } else if ([component rangeOfString:kRecommendCoreQueryKeyAdIdFrom].location !=
                           NSNotFound) {
                    adIdTo = [NSStringURLEncoding
                        URLDecodedString:[component substringFromIndex:kRecommendCoreQueryAdIdFrom
                                                                           .length]];
                } else if ([component rangeOfString:kRecommendCoreQueryKeyCountryCode].location !=
                           NSNotFound) {
                    countryCode = [NSStringURLEncoding
                        URLDecodedString:[component
                                             substringFromIndex:kRecommendCoreQueryCountryCode
                                                                    .length]];
                } else if ([component rangeOfString:kRecommendCoreQueryKeyCategoryId].location !=
                           NSNotFound) {
                    categoryId = [NSStringURLEncoding
                        URLDecodedString:[component substringFromIndex:kRecommendCoreQueryCategoryId
                                                                           .length]];
                } else if ([component rangeOfString:kRecommendCoreQueryKeyAdType].location !=
                           NSNotFound) {
                    adType = [NSStringURLEncoding
                        URLDecodedString:[component
                                             substringFromIndex:kRecommendCoreQueryAdType.length]];
                } else if ([component rangeOfString:kRecommendCoreQueryKeyStoreId].location !=
                           NSNotFound) {
                    storeId = [NSStringURLEncoding
                        URLDecodedString:[component
                                             substringFromIndex:kRecommendCoreQueryStoreId.length]];
                }
            }
        }
        if (openedExternalApp) {
            return 0;
        }
        if (adIdTo != nil && countryCode != nil && categoryId != nil) {
            RecommendAdId *adId = [[RecommendAdId alloc] initWithCountryCode:countryCode
                                                                  categoryId:categoryId];
            [adId setWithAdIdFrom:adIdTo
                      countryCode:countryCode
                       categoryId:categoryId
                           adType:adType
                            error:nil];
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
        // A destination that is not the close host reports 1, not 0.
        if ([destination isEqualToString:kRecommendCoreCloseHost]) {
            return 0;
        }
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
    // The binary boxes the model with -numberWithUnsignedInt:, not -numberWithInt:.
    NSString *modelKey = [@((unsigned int)adModel) stringValue];
    NSDictionary *entry = table[modelKey];
    if (entry == nil) {
        return nil;
    }
    if ([entry[kRecommendCoreKeyExpire] compare:[NSDate date]] != NSOrderedAscending) {
        return entry[kRecommendCoreKeyStatus];
    }
    NSMutableDictionary *mutableTable = [table mutableCopy];
    [mutableTable removeObjectForKey:[@((unsigned int)adModel) stringValue]];
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

/** @ghidraAddress 0x23ba24 */
+ (void)clearData {
    NSString *env = [ApplilinkConsts envServer];
    if (env != nil && ![env isEqualToString:kRecommendCoreEnvServerDisabled]) {
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
    // The binary builds a fifth array of ad_id values and never passes it to the post.
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
          NSString *installFlg = kRecommendCoreInstallFlgNone;
          if (record != nil) {
              installFlg = [RecommendAdData getInstallFlgWithAdData:record];
          }
          [appliIdList addObject:appliId];
          [creativeIdList addObject:creativeId];
          [incentiveTypeList addObject:kRecommendCoreKeyRewardNone];
          [installFlgList addObject:installFlg];
      }
      NSString *adType =
          [NSString stringWithFormat:kRecommendCoreFormatInteger, RecommendCoreAdTypeBanner];
      NSString *adModel =
          [NSString stringWithFormat:kRecommendCoreFormatInteger, RecommendCoreAdModelOwnAdBase];
      [AnalysisNetworkCore
          postAnalysisListRegistWithAdType:adType
                                   adModel:adModel
                                adLocation:adLocation
                              impressionId:impressionId
                               appliIdList:appliIdList
                            creativeIdList:creativeIdList
                         incentiveTypeList:incentiveTypeList
                            installFlgList:installFlgList
                                  callback:^(NSError *_Nullable registerError){
                                      // The binary passes a global no-op block here.
                                  }];
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
          RecommendCorePostAnalysisClickRegist(
              self, sessionError, adLocation, appliId, creativeId, requestCode, delegate);
        }];
        return;
    }
    ApplilinkParameters *appParam = [[ApplilinkParameters alloc] init];
    [appParam setRequestWithAdModel:RecommendCoreAdModelOwnAdBase
                         adLocation:adLocation
                        requestCode:requestCode];
    [ApplilinkCore toDelegateFailOpenWithError:error appParam:appParam delegate:delegate];
}

/** @ghidraAddress 0x23c934 */
static void RecommendCorePostAnalysisClickRegist(RecommendCore *core,
                                                 NSError *error,
                                                 NSString *adLocation,
                                                 NSString *appliId,
                                                 NSString *creativeId,
                                                 id requestCode,
                                                 id delegate) {
    if (error != nil) {
        ApplilinkParameters *appParam = [[ApplilinkParameters alloc] init];
        [appParam setRequestWithAdModel:RecommendCoreAdModelOwnAdBase
                             adLocation:adLocation
                            requestCode:requestCode];
        [ApplilinkCore toDelegateFailOpenWithError:error appParam:appParam delegate:delegate];
        return;
    }
    NSString *impressionId = [core getUniqueAdWithAdLocation:adLocation];
    if ([impressionId length] == 0) {
        impressionId = [ApplilinkUtilities getImpressionId];
    }
    NSDictionary *record = [RecommendAdData getAdDataWithAppliId:appliId];
    if (record == nil) {
        NSDictionary *userInfo = [NSDictionary
            dictionaryWithObjectsAndKeys:[NSString
                                             stringWithFormat:kRecommendCoreFormatAllAdDataMissing,
                                                              appliId],
                                         kErrorUserInfoKey,
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
        postAnalysisClickRegistWithAdType:[NSString stringWithFormat:kRecommendCoreFormatInteger,
                                                                     RecommendCoreAdTypeBanner]
                                  adModel:[NSString stringWithFormat:kRecommendCoreFormatInteger,
                                                                     RecommendCoreAdModelOwnAdBase]
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
                                   if (core.uniqueApplilinkParams == nil) {
                                       core.uniqueApplilinkParams =
                                           [[ApplilinkParameters alloc] init];
                                   }
                                   [core.uniqueApplilinkParams
                                       setRequestWithAdModel:RecommendCoreAdModelOwnAdBase
                                                  adLocation:adLocation
                                                 requestCode:requestCode];
                                   NSString *adType =
                                       [NSString stringWithFormat:kRecommendCoreFormatInteger,
                                                                  RecommendCoreAdTypeBanner];
                                   NSString *adModel =
                                       [NSString stringWithFormat:kRecommendCoreFormatInteger,
                                                                  RecommendCoreAdModelOwnAdBase];
                                   [core linkActionWithDefaultScheme:defaultScheme
                                                              adIdTo:adId
                                                              adType:adType
                                                             adModel:adModel
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
    // The appParam argument is unused.
    if (self.adScreenViewController == nil) {
        [ApplilinkCore toDelegateFailOpenWithError:error
                                          appParam:self.uniqueApplilinkParams
                                          delegate:self.uniqueAdDelegate];
    } else {
        [ApplilinkCore toDelegateFailLinkWithError:error
                                          appParam:self.applilinkParams
                                          delegate:self.applilinkDelegate];
    }
}

- (void)appStoreTransitionNoticeWithAppParam:(ApplilinkParameters *)appParam {
    // The binary's implementation is intentionally empty.
}

@end
