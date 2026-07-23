//
//  RewardCore.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458.
//  See RewardCore.h for the class overview.
//

#import "RewardCore.h"

#import "ApplilinkConsts.h"
#import "ApplilinkCore.h"
#import "ApplilinkNetworkError.h"
#import "ApplilinkParameters.h"
#import "ApplilinkUdid.h"
#import "ApplilinkUtilities.h"
#import "NSStringURLEncoding.h"
#import "RewardWebAPI.h"
#import "RewardWebViewController.h"

// Applilink error codes used by the reward core.
enum {
    kRewardErrorApplicationIdMissing = 0x3e9,   // No Applilink application identifier is set.
    kRewardErrorNotInitialized = 0x3f2,         // The reward session has not initialised.
    kRewardErrorBannerCacheUnavailable = 0x402, // No cached banner status is available.
    kRewardErrorTrackingDisabled = 0x404,       // Advertising tracking is disabled.
    kRewardErrorNotAuthenticated = 0x406,       // The reward session is not authenticated.
    kRewardErrorAlreadyOpen = 0x40f,            // An advert screen is already open.
};

// Reward app-list request/list priorities passed to RewardWebAPI.
enum {
    kRewardListTypeAllAppIds = 1,     // Request every advertisable application identifier.
    kRewardListTypeInstalledPost = 2, // Request the install-post application list.
};

enum {
    kRewardInstallPriorityNormal = 0,     // Normal application-install post.
    kRewardLoginPriorityInteractive = 1,  // Interactive reward login.
    kRewardInstallPriorityPasteBoard = 2, // Pasteboard-sourced UDID install post.
};

// The campaignFlg sentinel returned when no valid flag is available.
static const int kRewardCampaignFlgNone = -2;

// The reward authentication session lifetime, in seconds.
static const NSTimeInterval kRewardAuthSessionLifetime = 60.0;

// The reward advert index page appended to the SSL base URL.
static NSString *const kRewardIndexPath = @"/reward/app/index.php";

// The Applilink external-app redirect scheme prefix, host, and port.
static NSString *const kApplilinkSchemePrefix = @"applilink";
static NSString *const kApplilinkExtAppHost = @"ext-app";
static NSString *const kApplilinkExtAppPrefix = @"applilink://ext-app:80";
static const int kApplilinkExtAppPort = 80;

// Query-parameter keys parsed out of the redirect URL.
static NSString *const kRedirectQueryDefaultScheme = @"default_scheme";
static NSString *const kRedirectQueryStoreId = @"store_id";
static NSString *const kRedirectQueryClose = @"close";

// NSUserDefaults keys owned by the reward session.
static NSString *const kDefaultsCampaignFlg = @"ApplilinkReward.campaignFlg";
static NSString *const kDefaultsStorageIndex = @"ApplilinkReward.storageIndex";
static NSString *const kDefaultsAppliURL = @"ApplilinkReward.appliURL";
static NSString *const kDefaultsParameters = @"ApplilinkReward.parameters";
static NSString *const kDefaultsMethod = @"ApplilinkReward.method";

// Temporary-cache archive keys and response dictionary keys.
static NSString *const kCacheKeyValue = @"Value";
static NSString *const kCacheKeyExpire = @"Expire";
static NSString *const kResponseKeyStorageIndex = @"StorageIndex";
static NSString *const kStatusKeyAllInstallFlg = @"allInstallFlg";
static NSString *const kCacheKeyAppInstallFlg = @"appInstallFlg";
static NSString *const kStatusKeyBannerDisplayStatus = @"bannerDisplayStatus";
static NSString *const kResponseKeyList = @"list";
static NSString *const kResponseKeyInfo = @"info";
static NSString *const kResponseKeyStatus = @"status";
static NSString *const kResponseKeyExpire = @"expire";
static NSString *const kResponseKeyAppliInfo = @"appli_info";
static NSString *const kResponseKeyAppliId = @"appli_id";
static NSString *const kResponseKeyDefaultScheme = @"default_scheme";
static NSString *const kRequestKeyAdLocation = @"ad_location";
static NSString *const kRequestKeyAppliIdList = @"appli_id_list";

// URL-building fragments used by the redirect handler.
static NSString *const kSchemeSeparator = @"://";
static NSString *const kQuerySuffixFormat = @"?%@";

// Reward-session shared state (Ghidra: DAT_1003df5d0..DAT_1003df608). The singleton owns no
// per-request state for these; they are file-scope in the binary, so they stay file-scope here.
static BOOL gRewardAdScreenOpen;        // Ghidra: DAT_1003df5d0 — a request is in flight.
static BOOL gRewardAdScreenCancelled;   // Ghidra: DAT_1003df5d1 — the user cancelled the open.
static NSDate *gRewardAuthExpiry;       // Ghidra: DAT_1003df5f8 — reward auth session expiry.
static NSDictionary *gRewardBannerInfo; // Ghidra: DAT_1003df600 — cached banner info dictionary.
static NSDate *gRewardBannerExpiry;     // Ghidra: DAT_1003df608 — cached banner info expiry.

@implementation RewardCore

#pragma mark Singleton

// @ghidraAddress 0x2079d0 (dispatch_once body at 0x207a14, AllocRewardCoreSingleton at 0x207930).
+ (instancetype)sharedInstance {
    static RewardCore *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      instance = [[RewardCore alloc] init];
      instance.initializeFlg = 0;
    });
    return instance;
}

// @ghidraAddress 0x2076e4 (init body dispatched onto a serial queue; InitRewardCoreBlockInvoke at
// 0x2077f4 calls [super init]).
- (instancetype)init {
    return [super init];
}

#pragma mark Properties

// @ghidraAddress 0x207a80. Advertising-tracking-gated override of the synthesised getter.
- (int)initializeFlg {
    if (![ApplilinkUdid isAdvertisingTrackingEnabled]) {
        return 0;
    }
    return _initializeFlg;
}

// The @c isNavigationBarHidden property setter shares its ivar with @c setNavigationBarHidden:.
// @ghidraAddress 0x20b62c.
- (void)setNavigationBarHidden:(BOOL)navigationBarHidden {
    _isNavigationBarHidden = navigationBarHidden;
}

#pragma mark Session lifecycle

// @ghidraAddress 0x207acc.
- (void)clearInitialize {
    _initializeFlg = 0;
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kDefaultsCampaignFlg];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

// @ghidraAddress 0x207b6c.
- (int)campaignFlg {
    if ([ApplilinkUdid isAdvertisingTrackingEnabled] &&
        [RewardCore sharedInstance].initializeFlg == 1) {
        NSString *stored =
            [[NSUserDefaults standardUserDefaults] stringForKey:kDefaultsCampaignFlg];
        if (stored) {
            return stored.intValue;
        }
    }
    return kRewardCampaignFlgNone;
}

// @ghidraAddress 0x207c70.
- (void)startWithCallback:(void (^)(NSError *error))callback {
    if (![ApplilinkUdid isAdvertisingTrackingEnabled]) {
        callback(
            [ApplilinkNetworkError localizedApplilinkErrorWithCode:kRewardErrorTrackingDisabled]);
        return;
    }
    if (![ApplilinkConsts appliId]) {
        callback([ApplilinkNetworkError
            localizedApplilinkErrorWithCode:kRewardErrorApplicationIdMissing]);
        return;
    }
    if (![ApplilinkCore checkUdid]) {
        [RewardCore sharedInstance].initializeFlg = 0;
    }
    if ([RewardCore sharedInstance].initializeFlg == 1) {
        callback(nil);
        return;
    }
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
      /** @ghidraAddress 0x207e84 (CreateUdidThenInstallBlockInvoke) */
      if ([self createUdidWithBlock:callback]) {
          [RewardWebAPI
              postApplicationInstallWithPriority:kRewardInstallPriorityNormal
                                        callback:^(NSError *error) {
                                          /** @ghidraAddress 0x207f7c
                                                     * (HandleInstallPostCompletionBlockInvoke) */
                                          if (error) {
                                              [RewardCore sharedInstance].initializeFlg = 0;
                                              callback(error);
                                              return;
                                          }
                                          if ([ApplilinkUdid isUdidSDKPasteBoard]) {
                                              [RewardWebAPI postApplicationInstallWithPriority:
                                                                kRewardInstallPriorityPasteBoard
                                                                                      callback:nil];
                                          }
                                          [RewardCore sharedInstance].initializeFlg = 1;
                                          callback(nil);
                                        }];
      } else {
          [RewardCore sharedInstance].initializeFlg = 0;
          if (callback) {
              callback(nil);
          }
      }
    });
}

// @ghidraAddress 0x20810c.
- (void)startSessionWithBlock:(void (^)(NSError *error))block {
    if (![ApplilinkUdid isAdvertisingTrackingEnabled]) {
        block([ApplilinkNetworkError localizedApplilinkErrorWithCode:kRewardErrorTrackingDisabled]);
        return;
    }
    if (gRewardAuthExpiry != nil && ![ApplilinkConsts isNeedRewardLogin] &&
        gRewardAuthExpiry.timeIntervalSinceNow >= 0.0) {
        block(nil);
        return;
    }
    [RewardWebAPI checkLoginWithBlock:^(BOOL valid, NSError *error) {
      /** @ghidraAddress 0x20825c (HandleApplilinkAuthCheckBlockInvoke) */
      if (valid) {
          gRewardAuthExpiry = [[NSDate date] dateByAddingTimeInterval:kRewardAuthSessionLifetime];
          block(nil);
          return;
      }
      if (![ApplilinkConsts userId]) {
          if (block) {
              block([ApplilinkNetworkError
                  localizedApplilinkErrorWithCode:kRewardErrorNotAuthenticated]);
          }
          return;
      }
      [ApplilinkCore appAuthSessionRegenerateWithBlock:^(NSError *regenError) {
        /** @ghidraAddress 0x208404 (StartRewardLoginBlockInvoke) */
        (void)regenError; // The regenerate error is not consumed here; login reports its own.
        [RewardWebAPI startLoginWithUserId:[ApplilinkConsts userId]
                              withPriority:kRewardLoginPriorityInteractive
                                  callback:^(NSError *loginError) {
                                    /** @ghidraAddress 0x208490
                                     * (HandleRewardLoginCompletionBlockInvoke) */
                                    if (loginError) {
                                        [ApplilinkUtilities debugLog];
                                        block(loginError);
                                        return;
                                    }
                                    [ApplilinkUdid setUdidKeychainFromPasteBoard];
                                    [ApplilinkConsts loggedInReward];
                                    gRewardAuthExpiry = [[NSDate date]
                                        dateByAddingTimeInterval:kRewardAuthSessionLifetime];
                                    block(nil);
                                  }];
      }];
    }];
}

// @ghidraAddress 0x208624.
- (void)startWithBlock:(void (^)(NSError *error))block {
    [self startWithCallback:^(NSError *error) {
      /** @ghidraAddress 0x2086bc (RetrySessionStartBlockInvoke) */
      if (error) {
          block(error);
          return;
      }
      [self startSessionWithBlock:block];
    }];
}

// @ghidraAddress 0x208738.
- (BOOL)createUdidWithBlock:(void (^)(NSError *error))block {
    NSError *error = nil;
    if (![self createCFUdidWithError:&error] || error != nil) {
        block(error);
        return NO;
    }
    (void)[ApplilinkCore udid]; // Read for effect, matching the binary.
    NSError *rewardError = nil;
    [ApplilinkUdid createAdvertisingRewardUdidWithError:&rewardError];
    if (rewardError != nil) {
        block(rewardError);
        return NO;
    }
    (void)[ApplilinkCore ad_udid]; // Read for effect, matching the binary.
    if ([ApplilinkUdid isPasteBoardStatus]) {
        NSString *currentUdid = [ApplilinkCore currentUdid];
        if (currentUdid) {
            [ApplilinkUdid writeUDIDForFirstEmptyLocationWithUdid:currentUdid];
        }
    }
    return YES;
}

// @ghidraAddress 0x2088e0.
- (BOOL)createCFUdidWithError:(NSError *_Nullable *_Nullable)error {
    if ([ApplilinkCore udid] != nil && [ApplilinkCore old_udid] == nil) {
        [ApplilinkUdid setUdidKeychainFromPasteBoard];
    }
    if ([ApplilinkUdid isAdvertisingTrackingOSVersion]) {
        return YES;
    }
    NSString *storedIndex =
        [[NSUserDefaults standardUserDefaults] stringForKey:kDefaultsStorageIndex];
    NSString *serviceName = [[[ApplilinkPasteBoard alloc] init] getServiceName];
    if (storedIndex != nil) {
        if ([ApplilinkUdid udidWithServiceName:serviceName
                                  storageIndex:storedIndex.intValue
                                         error:nil] != nil) {
            return YES;
        }
    }
    NSDictionary *written = [ApplilinkUdid writeUDIDForFirstEmptyLocationWithError:error];
    if (written == nil) {
        return NO;
    }
    NSString *index = [written[kResponseKeyStorageIndex] stringValue];
    [[NSUserDefaults standardUserDefaults] setValue:index forKey:kDefaultsStorageIndex];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kDefaultsCampaignFlg];
    [[NSUserDefaults standardUserDefaults] synchronize];
    return YES;
}

#pragma mark Status queries

// @ghidraAddress 0x208bf0.
- (void)allInstallFlgWithCallback:(void (^)(NSInteger flg, NSError *error))callback {
    id cached = [[RewardCore sharedInstance] getTemporaryCacheWithKey:kCacheKeyAppInstallFlg];
    if (cached != nil) {
        callback([cached intValue], nil);
        return;
    }
    if (![ApplilinkUdid isAdvertisingTrackingEnabled]) {
        callback(
            0,
            [ApplilinkNetworkError localizedApplilinkErrorWithCode:kRewardErrorTrackingDisabled]);
        return;
    }
    if ([RewardCore sharedInstance].initializeFlg == 0 && ![ApplilinkCore isInitializeStatusFlg]) {
        callback(
            0, [ApplilinkNetworkError localizedApplilinkErrorWithCode:kRewardErrorNotInitialized]);
        return;
    }
    [self startWithBlock:^(NSError *error) {
      /** @ghidraAddress 0x208df4 (FetchAllInstallFlagBlockInvoke) */
      if (error) {
          callback(-1, error);
          return;
      }
      [RewardWebAPI allInstallFlgWithCallback:callback];
    }];
}

// @ghidraAddress 0x208e48.
- (void)getAdDisplayStatusWithCallback:(void (^)(NSDictionary *status, NSError *error))callback {
    NSMutableDictionary *status = [NSMutableDictionary dictionaryWithCapacity:2];
    [status setValue:@(0) forKey:kStatusKeyAllInstallFlg];
    [status setValue:@(0) forKey:kStatusKeyBannerDisplayStatus];
    [self allInstallFlgWithCallback:^(NSInteger allInstallFlg, NSError *error) {
      /** @ghidraAddress 0x208fdc (FetchAppListStatusBlockInvoke) */
      if (error) {
          callback(status, error);
          return;
      }
      [self getAppListStatusWithBlock:^(NSInteger bannerStatus, NSError *statusError) {
        /** @ghidraAddress 0x209094 (HandleAppListStatusCompletionBlockInvoke) */
        if (statusError) {
            callback(status, statusError);
            return;
        }
        [status setValue:@((int)allInstallFlg) forKey:kStatusKeyAllInstallFlg];
        [status setValue:@((int)bannerStatus) forKey:kStatusKeyBannerDisplayStatus];
        callback(status, nil);
      }];
    }];
}

// @ghidraAddress 0x209244.
- (void)postInstalledAppWithCallback:(void (^)(NSError *error))callback {
    [RewardWebAPI
        appliIdListWithType:kRewardListTypeInstalledPost
                   callback:^(NSDictionary *result, NSError *error) {
                     /** @ghidraAddress 0x2092e0
                                * (HandleInstalledAppReportBlockInvoke) */
                     if (error) {
                         callback(error);
                         return;
                     }
                     if (![result isKindOfClass:[NSDictionary class]]) {
                         callback(nil);
                         return;
                     }
                     NSMutableArray *installed = [[NSMutableArray alloc] init];
                     for (NSDictionary *entry in result[kResponseKeyList]) {
                         NSDictionary *info = entry[kResponseKeyAppliInfo];
                         NSString *appliId = info[kResponseKeyAppliId];
                         NSString *scheme = info[kResponseKeyDefaultScheme];
                         if (scheme == nil || [scheme isKindOfClass:[NSNull class]]) {
                             continue;
                         }
                         if ([scheme rangeOfString:kSchemeSeparator].location == NSNotFound) {
                             scheme = [scheme stringByAppendingString:kSchemeSeparator];
                         }
                         NSURL *url = [NSURL URLWithString:scheme];
                         if ([[UIApplication sharedApplication] canOpenURL:url]) {
                             [installed addObject:appliId];
                         }
                     }
                     if (installed.count == 0) {
                         callback(nil);
                         return;
                     }
                     [RewardWebAPI postAppliInstallReportWithAppliList:installed callback:callback];
                   }];
}

// @ghidraAddress 0x209724.
- (void)getInstalledAppWithCallback:(void (^)(NSArray *appIdList, NSError *error))callback {
    [RewardWebAPI appliIdListWithType:kRewardListTypeAllAppIds
                             callback:^(NSDictionary *result, NSError *error) {
                               /** @ghidraAddress 0x2097c0 (HandleAppIdListBlockInvoke) */
                               if (error) {
                                   callback(nil, error);
                                   return;
                               }
                               if (![result isKindOfClass:[NSDictionary class]]) {
                                   callback(nil, nil);
                                   return;
                               }
                               NSMutableArray *ids = [[NSMutableArray alloc] init];
                               for (NSDictionary *entry in result[kResponseKeyList]) {
                                   NSString *appliId =
                                       entry[kResponseKeyAppliInfo][kResponseKeyAppliId];
                                   if (appliId) {
                                       [ids addObject:appliId];
                                   }
                               }
                               callback(ids.count == 0 ? nil : ids, nil);
                             }];
}

// @ghidraAddress 0x209a90.
- (void)getAppListStatusWithBlock:(void (^)(NSInteger status, NSError *error))block {
    if (![ApplilinkUdid isAdvertisingTrackingEnabled]) {
        block(0,
              [ApplilinkNetworkError localizedApplilinkErrorWithCode:kRewardErrorTrackingDisabled]);
        return;
    }
    NSError *error = nil;
    if (![ApplilinkConsts appliId]) {
        error = [ApplilinkNetworkError localizedApplilinkErrorWithCode:kRewardErrorNotInitialized];
    } else if ([RewardCore sharedInstance].initializeFlg == 0 &&
               ![ApplilinkCore isInitializeStatusFlg]) {
        error = [ApplilinkNetworkError localizedApplilinkErrorWithCode:kRewardErrorNotInitialized];
    } else if (![self canUseBannerCache]) {
        error = [ApplilinkNetworkError
            localizedApplilinkErrorWithCode:kRewardErrorBannerCacheUnavailable];
    } else if (gRewardBannerInfo == nil || gRewardBannerExpiry == nil ||
               gRewardBannerExpiry.timeIntervalSinceNow < 0.0) {
        [self startWithBlock:^(NSError *sessionError) {
          /** @ghidraAddress 0x209d7c (FetchBannerInfoBlockInvoke) */
          if (sessionError) {
              block(0, sessionError);
              return;
          }
          [RewardWebAPI bannerInfoWithBlock:^(NSDictionary *result, NSError *bannerError) {
            /** @ghidraAddress 0x209e1c (HandleBannerInfoCompletionBlockInvoke) */
            if (bannerError || ![result isKindOfClass:[NSDictionary class]]) {
                block(0, bannerError);
                return;
            }
            gRewardBannerInfo = result[kResponseKeyInfo];
            NSInteger status = 0;
            if (gRewardBannerInfo != nil) {
                id expire = gRewardBannerInfo[kResponseKeyExpire];
                int expireSeconds = 0;
                if ([expire isKindOfClass:[NSString class]] ||
                    [expire isKindOfClass:[NSNumber class]]) {
                    expireSeconds = [expire intValue];
                }
                gRewardBannerExpiry = [[NSDate date] dateByAddingTimeInterval:expireSeconds];
                id statusValue = gRewardBannerInfo[kResponseKeyStatus];
                if ([statusValue isKindOfClass:[NSString class]] ||
                    [statusValue isKindOfClass:[NSNumber class]]) {
                    status = [statusValue intValue];
                }
            }
            block(status, nil);
          }];
        }];
        return;
    } else {
        id statusValue = gRewardBannerInfo[kResponseKeyStatus];
        NSInteger status =
            [statusValue isKindOfClass:[NSString class]] ? [statusValue intValue] : 0;
        block(status, nil);
        return;
    }
    block(0, error);
}

#pragma mark Advert screen

// @ghidraAddress 0x20a0dc.
- (void)openAdScreenWithParentView:(UIView *)parentView
                        adLocation:(NSString *)adLocation
                       requestCode:(id)requestCode
                          delegate:(id<ApplilinkViewDelegate>)delegate {
    if (gRewardAdScreenOpen) {
        ApplilinkParameters *params = [[ApplilinkParameters alloc] init];
        [params setRequestWithAdModel:0 adLocation:adLocation requestCode:requestCode];
        [ApplilinkCore
            toDelegateFailOpenWithError:[ApplilinkNetworkError
                                            localizedApplilinkErrorWithCode:kRewardErrorAlreadyOpen]
                               appParam:params
                               delegate:delegate];
        return;
    }
    gRewardAdScreenOpen = YES;
    if (self.applilinkParams == nil) {
        self.applilinkParams = [[ApplilinkParameters alloc] init];
    }
    [self.applilinkParams setRequestWithAdModel:0 adLocation:adLocation requestCode:requestCode];
    gRewardAdScreenCancelled = NO;
    __weak id<ApplilinkViewDelegate> weakDelegate = delegate;
    [self startWithBlock:^(NSError *error) {
      /** @ghidraAddress 0x20a3ac (PostInstalledAppStepBlockInvoke) */
      if (error) {
          [self appListFailLoadWithError:error delegate:weakDelegate];
          gRewardAdScreenOpen = NO;
          return;
      }
      if (gRewardAdScreenCancelled) {
          gRewardAdScreenCancelled = NO;
          gRewardAdScreenOpen = NO;
          return;
      }
      [self postInstalledAppWithCallback:^(NSError *postError) {
        /** @ghidraAddress 0x20a538 (GetInstalledAppStepBlockInvoke) */
        if (postError) {
            [self appListFailLoadWithError:postError delegate:weakDelegate];
            gRewardAdScreenOpen = NO;
            return;
        }
        if (gRewardAdScreenCancelled) {
            gRewardAdScreenCancelled = NO;
            gRewardAdScreenOpen = NO;
            return;
        }
        [self getInstalledAppWithCallback:^(NSArray *appIdList, NSError *getError) {
          /** @ghidraAddress 0x20a6c4 (BuildRewardParamsStepBlockInvoke) */
          if (getError) {
              [self appListFailLoadWithError:getError delegate:weakDelegate];
              gRewardAdScreenOpen = NO;
              return;
          }
          if (gRewardAdScreenCancelled) {
              gRewardAdScreenCancelled = NO;
              gRewardAdScreenOpen = NO;
              return;
          }
          NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
          if (adLocation) {
              [params setValue:adLocation forKey:kRequestKeyAdLocation];
          }
          if (appIdList) {
              [params setValue:appIdList forKey:kRequestKeyAppliIdList];
          }
          dispatch_async(dispatch_get_main_queue(), ^{
            /** @ghidraAddress 0x20a88c (PresentRewardWebViewBlockInvoke) */
            if (self.rewardViewController == nil) {
                self.rewardViewController = [[RewardWebViewController alloc] init];
            }
            if (parentView) {
                [self.rewardViewController setParentView:parentView];
                [self.rewardViewController setNavigationBarHidden:self.isNavigationBarHidden];
            } else {
                [self.rewardViewController setNavigationBarHidden:NO];
            }
            [self.rewardViewController setSdkDelegate:self];
            self.applilinkDelegate = weakDelegate;
            NSString *url = [[ApplilinkConsts baseUrlSsl] stringByAppendingString:kRewardIndexPath];
            [self.rewardViewController loadRequestWithURL:url parameters:params];
            gRewardAdScreenOpen = NO;
          });
        }];
      }];
    }];
}

// @ghidraAddress 0x20ac1c.
- (void)closeAdScreen {
    gRewardAdScreenCancelled = YES;
    if (self.rewardViewController != nil) {
        [self.rewardViewController appliListClosed];
        [self.rewardViewController viewDealloc];
        [self appListDidDisappear:self.applilinkDelegate];
    }
    self.rewardViewController = nil;
    gRewardAdScreenOpen = NO;
}

// @ghidraAddress 0x20accc.
- (void)rotateAdScreenWithInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
                                      duration:(NSTimeInterval)duration {
    if (self.rewardViewController != nil) {
        [self.rewardViewController willAnimateRotationToInterfaceOrientation:interfaceOrientation
                                                                    duration:duration];
    }
}

// @ghidraAddress 0x20acf0.
- (int)redirectWithRequest:(NSURLRequest *)request {
    NSURL *url = request.URL;
    NSString *scheme = url.scheme;
    NSString *host = url.host;
    int port = url.port.intValue;
    NSString *path = url.path;
    NSString *query = url.query;
    if (scheme == nil || ![scheme hasPrefix:kApplilinkSchemePrefix] || host == nil ||
        ![host isEqualToString:kApplilinkExtAppHost] || port != kApplilinkExtAppPort) {
        return 1;
    }
    NSString *storeId = nil;
    if (query != nil) {
        for (NSString *component in [query componentsSeparatedByString:@"&"]) {
            if ([component rangeOfString:kRedirectQueryDefaultScheme].location != NSNotFound) {
                NSString *value = [NSStringURLEncoding
                    URLDecodedString:[component
                                         substringFromIndex:(kRedirectQueryDefaultScheme.length +
                                                             1)]];
                NSURL *schemeURL = [NSURL URLWithString:value];
                if (schemeURL != nil && [[UIApplication sharedApplication] canOpenURL:schemeURL]) {
                    [[UIApplication sharedApplication] openURL:schemeURL];
                    return 0;
                }
                return 2;
            }
            if ([component rangeOfString:kRedirectQueryStoreId].location != NSNotFound) {
                storeId = [NSStringURLEncoding
                    URLDecodedString:[component
                                         substringFromIndex:(kRedirectQueryStoreId.length + 1)]];
            }
        }
    }
    NSString *prefix = kApplilinkExtAppPrefix;
    if ([url.absoluteString hasPrefix:prefix]) {
        path = [url.absoluteString substringFromIndex:prefix.length];
        if (query.length) {
            NSString *suffix = [NSString stringWithFormat:kQuerySuffixFormat, query];
            if ([path hasSuffix:suffix]) {
                path = [path substringToIndex:(path.length - suffix.length)];
            }
        }
    }
    if (path.length == 0) {
        return 1;
    }
    NSArray *segments = [[path substringFromIndex:1] componentsSeparatedByString:@"/"];
    if (segments.count == 0) {
        return 1;
    }
    if ([ApplilinkCore showAppStoreId:storeId appParam:nil delegate:self]) {
        return 3;
    }
    NSString *first = [NSStringURLEncoding URLDecodedString:segments[0]];
    NSURL *firstURL = [NSURL URLWithString:first];
    if (firstURL != nil && [[UIApplication sharedApplication] canOpenURL:firstURL]) {
        [[UIApplication sharedApplication] openURL:firstURL];
        return 0;
    }
    if ([first isEqualToString:kRedirectQueryClose]) {
        return 1;
    }
    return 0;
}

#pragma mark Temporary cache

// @ghidraAddress 0x20b63c.
- (void)setTemporaryCacheWithKey:(NSString *)key value:(id)value expiration:(NSInteger)expiration {
    NSDate *expiry =
        [[NSDate alloc] initWithTimeIntervalSinceNow:(expiration == 0 ? 1.0 : (double)expiration)];
    NSDictionary *entry = [NSDictionary
        dictionaryWithObjectsAndKeys:value, kCacheKeyValue, expiry, kCacheKeyExpire, nil];
    [[NSUserDefaults standardUserDefaults]
        setObject:[NSKeyedArchiver archivedDataWithRootObject:entry]
           forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

// @ghidraAddress 0x20b7f0.
- (id)getTemporaryCacheWithKey:(NSString *)key {
    NSData *data = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    if (data == nil) {
        return nil;
    }
    NSDictionary *entry = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    if (entry == nil) {
        return nil;
    }
    NSDate *expiry = entry[kCacheKeyExpire];
    if (expiry != nil && [expiry compare:[NSDate date]] == NSOrderedAscending) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:key];
        [[NSUserDefaults standardUserDefaults] synchronize];
        return nil;
    }
    return entry[kCacheKeyValue];
}

#pragma mark Delegate notifications

// @ghidraAddress 0x20b9e4.
- (void)appListDidStart:(id<ApplilinkViewDelegate>)delegate {
    [ApplilinkCore toDelegateDidStart:self.applilinkParams delegate:delegate];
}

// @ghidraAddress 0x20ba10.
- (void)appListDidAppear:(id<ApplilinkViewDelegate>)delegate {
    [ApplilinkCore toDelegateDidAppear:self.applilinkParams delegate:delegate];
}

// @ghidraAddress 0x20ba3c.
- (void)appListDidDisappear:(id<ApplilinkViewDelegate>)delegate {
    [ApplilinkCore toDelegateDidDisappear:self.applilinkParams delegate:delegate];
}

// @ghidraAddress 0x20ba68.
- (void)appListFailLoadWithError:(NSError *)error delegate:(id<ApplilinkViewDelegate>)delegate {
    [ApplilinkCore toDelegateFailLoadWithError:error
                                      appParam:self.applilinkParams
                                      delegate:delegate];
}

// @ghidraAddress 0x20bacc.
- (void)appListFailLinkWithError:(NSError *)error delegate:(id<ApplilinkViewDelegate>)delegate {
    [ApplilinkCore toDelegateFailLinkWithError:error
                                      appParam:self.applilinkParams
                                      delegate:delegate];
}

#pragma mark Web-view notices

// @ghidraAddress 0x20bb30.
- (void)startedNotice {
    [self appListDidStart:self.applilinkDelegate];
}

// @ghidraAddress 0x20bb7c.
- (void)openedNotice {
    [self appListDidAppear:self.applilinkDelegate];
}

// @ghidraAddress 0x20bbc8.
- (void)closeNotice {
    if (self.rewardViewController != nil) {
        gRewardAdScreenCancelled = YES;
        [self.rewardViewController viewDealloc];
        self.rewardViewController = nil;
    }
    gRewardAdScreenOpen = NO;
    [self appListDidDisappear:self.applilinkDelegate];
}

// @ghidraAddress 0x20bc5c.
- (void)failOpenNoticeWithError:(NSError *)error {
    [self appListFailLoadWithError:error delegate:self.applilinkDelegate];
}

// @ghidraAddress 0x20bccc.
- (void)failLinkNoticeWithError:(NSError *)error {
    [self appListFailLinkWithError:error delegate:self.applilinkDelegate];
}

// @ghidraAddress 0x20bd3c. The shipped build ignores the cancellation error.
- (void)openCancelWithError:(NSError *)error {
    (void)error; // Yes, the binary discards this argument.
}

#pragma mark Cache and session teardown

// @ghidraAddress 0x20bd40.
- (BOOL)canUseBannerCache {
    NSString *udid = [ApplilinkCore udid];
    NSString *adUdid = [ApplilinkCore ad_udid];
    NSString *oldUdid = [ApplilinkCore old_udid];
    if (udid == nil && oldUdid == nil && adUdid == nil) {
        gRewardBannerInfo = nil;
        gRewardBannerExpiry = nil;
    }
    return udid != nil || oldUdid != nil || adUdid != nil;
}

// @ghidraAddress 0x20be1c.
- (void)clearAdStatus {
    gRewardBannerInfo = nil;
    gRewardBannerExpiry = nil;
}

// @ghidraAddress 0x20be50.
- (void)clearSession {
    NSHTTPCookieStorage *storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (NSHTTPCookie *cookie in storage.cookies) {
        [storage deleteCookie:cookie];
    }
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kDefaultsAppliURL];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kDefaultsParameters];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kDefaultsMethod];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end
