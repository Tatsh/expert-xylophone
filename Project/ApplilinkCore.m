#import "ApplilinkCore.h"

#import "AnalysisNetworkCore.h"
#import "ApplilinkConsts.h"
#import "ApplilinkNetworkError.h"
#import "ApplilinkStore.h"
#import "ApplilinkUdid.h"
#import "ApplilinkWebAPI.h"
#import "RecommendCore.h"
#import "RewardCore.h"

// The advert-delegate callbacks the fan-out methods dispatch through respondsToSelector:. In the
// binary the delegate is an id<ApplilinkViewDelegate>; the protocol is only forward declared in the
// shared headers, so the selectors are gathered here so the messages type-check.
@protocol ApplilinkCoreAdDelegate <NSObject>
@optional
- (void)appListDidStart;
- (void)appListDidStart:(nullable ApplilinkParameters *)appParam;
- (void)appListDidAppear;
- (void)appListDidAppear:(nullable ApplilinkParameters *)appParam;
- (void)appListDidDisappear;
- (void)appListDidDisappear:(nullable ApplilinkParameters *)appParam;
- (void)appListFailOpenWithError:(nullable NSError *)error;
- (void)appListFailOpenWithError:(nullable NSError *)error
         withApplilinkParameters:(nullable ApplilinkParameters *)appParam;
- (void)appListFailLoadWithError:(nullable NSError *)error;
- (void)appListFailLoadWithError:(nullable NSError *)error
         withApplilinkParameters:(nullable ApplilinkParameters *)appParam;
- (void)appListFailWithError:(nullable NSError *)error;
- (void)appListFailWithError:(nullable NSError *)error
     withApplilinkParameters:(nullable ApplilinkParameters *)appParam;
- (void)appListFailLinkWithError:(nullable NSError *)error;
- (void)appListFailLinkWithError:(nullable NSError *)error
         withApplilinkParameters:(nullable ApplilinkParameters *)appParam;
@end

// Localised-error codes passed to +[ApplilinkNetworkError localizedApplilinkErrorWithCode:]. These
// mirror the file-local enumeration in ApplilinkNetworkError.m.
static const NSInteger kApplilinkErrorCodeParameter = 0x3e9;
static const NSInteger kApplilinkErrorCodeSdkVersionNotSupported = 0x401;
static const NSInteger kApplilinkErrorCodeInitializingError = 0x408;
static const NSInteger kApplilinkErrorCodeResumeExecutingError = 0x409;
static const NSInteger kApplilinkErrorCodeSession = 0x40e;

// The response status flag and success sentinel returned by the session-regenerate endpoint.
static const int kApplilinkSessionSuccessCode = 100000000;

// How long, in seconds, a regenerated authentication session stays valid.
static const NSTimeInterval kApplilinkSessionValidDuration = 60.0;

// NSUserDefaults keys shared with ApplilinkConsts.
static NSString *const kApplilinkAppliIdKey = @"ApplilinkNetwork.appliId";
static NSString *const kApplilinkEnvKey = @"ApplilinkNetwork.env";
static NSString *const kApplilinkRewardReLoginFlgKey = @"ApplilinkReward.reLoginFlg";
static NSString *const kApplilinkRecommendReLoginFlgKey = @"ApplilinkRecommend.reLoginFlg";
static NSString *const kApplilinkRewardStorageIndexKey = @"ApplilinkReward.storageIndex";

// Keys read out of the SDK's UDID and session-response dictionaries.
static NSString *const kApplilinkUdidValueKey = @"Value";
static NSString *const kApplilinkResponseStatusKey = @"status";
static NSString *const kApplilinkResponseErrorCodeKey = @"error_code";

// The keychain service and storage index the advertising-UDID records are reset to on clear.
static NSString *const kApplilinkAdStorageService = @"adStorageIndex";
static NSString *const kApplilinkAdStorageIndex = @"0";

// The default environment string used when none is supplied.
static NSString *const kApplilinkDefaultEnv = @"0";

// The path appended to the SSL base URL for the session-regenerate request.
static NSString *const kApplilinkSessionRegeneratePath = @"/app/auth/sessionRegenerate.php";
static NSString *const kApplilinkHTTPMethodGet = @"GET";
static const float kApplilinkSessionRequestTimeout = 10.0f;

// The Applilink SDK development version components. versionDev renders "<version>.<build>".
static NSString *const kApplilinkVersion = @"2.2.2";
static NSString *const kApplilinkVersionBuild = @"5";

// The Applilink SDK signature key.
static NSString *const kApplilinkSignatureKey =
    @"KyqFp6lHYuAnAuVdfzhtlZ5VCMYL5aK4MpMpKjJSB5eDEyPO1vYMHRTT0sVVLQTo5R5QmMVE0wbpIwkopMERdOg5HDw24"
    @"zvAZN54sax9b3YObo07DG71L1encpL08qeV";

// The class carries no instance ivars: the whole SDK state is file scope. Each static keeps its
// original 32-bit contiguous block offset from 0x3df630 as a documentation comment.
static BOOL sInitializingFlg;               // 0x3df630
static BOOL sInitializeStatusFlg;           // 0x3df631
static BOOL sSessionValid;                  // 0x3df632
static BOOL sNavigationBarCommonAppearance; // 0x3df633
static BOOL sPriorityDeviceLanguages;       // 0x3df634
static BOOL sUsedInStore;                   // 0x3df635
static BOOL sBuiltUnderXcode6;              // 0x3df636
static BOOL sAdUdidResolved;                // 0x3df637
static BOOL sUdidChecked;                   // 0x3df638
static BOOL sReLoginPending;                // 0x3df639
static NSDate *sSessionExpiry;              // 0x3df640
static UIColor *sIndicatorColor;            // 0x3df648
static NSString *sAdUdidCache;              // 0x3df650
static NSString *sUdidCache;                // 0x3df658
static NSString *sOldUdidCache;             // 0x3df660
static NSString *sPasteBoardUdidCache;      // 0x3df668

@implementation ApplilinkCore

#pragma mark - Initialisation

+ (void)initializeWithAppliId:(NSString *)appliId
                          env:(NSString *)env
                       resume:(BOOL)resume
                     callback:(void (^)(NSError *_Nullable error))callback {
    if (![ApplilinkConsts canUseApplilinkSdk]) {
        if (callback) {
            callback([ApplilinkNetworkError
                localizedApplilinkErrorWithCode:kApplilinkErrorCodeSdkVersionNotSupported]);
        }
        return;
    }
    if (!appliId) {
        if (callback) {
            callback([ApplilinkNetworkError
                localizedApplilinkErrorWithCode:kApplilinkErrorCodeParameter]);
        }
        return;
    }
    if (sInitializingFlg) {
        if (callback) {
            NSInteger code = resume ? kApplilinkErrorCodeResumeExecutingError :
                                      kApplilinkErrorCodeInitializingError;
            callback([ApplilinkNetworkError localizedApplilinkErrorWithCode:code]);
        }
        return;
    }
    sInitializingFlg = YES;
    if (!resume) {
        [[NSUserDefaults standardUserDefaults] setObject:appliId forKey:kApplilinkAppliIdKey];
        [[NSUserDefaults standardUserDefaults] setObject:env forKey:kApplilinkEnvKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
        sInitializeStatusFlg = YES;
    }
    if (!env) {
        env = [NSString stringWithString:kApplilinkDefaultEnv];
    }
    [self appAuthSessionRegenerateWithBlock:^(NSError *_Nullable error) {
      /** @ghidraAddress 0x214754 */
      [[RewardCore sharedInstance] startWithCallback:^(NSError *_Nullable rewardError) {
        /** @ghidraAddress 0x2147fc */
        if (rewardError && callback) {
            sInitializingFlg = NO;
            callback(rewardError);
            return;
        }
        [[RecommendCore sharedInstance] startWithCallback:^(NSError *_Nullable recommendError) {
          /** @ghidraAddress 0x2148e8 */
          if (recommendError && callback) {
              sInitializingFlg = NO;
              callback(recommendError);
              return;
          }
          [AnalysisNetworkCore postAnalysisDataWithCallback:^(NSError *_Nullable analysisError) {
            /** @ghidraAddress 0x2149a8 */
            if (callback) {
                callback(analysisError);
            }
            sInitializingFlg = NO;
            [[RecommendCore sharedInstance] getAllAdStatusWithCallback:nil];
          }];
        }];
      }];
    }];
}

+ (void)resume {
    [self closeAppStore];
    NSString *appliId = [ApplilinkConsts appliId];
    NSString *env = [ApplilinkConsts envServer];
    if (!appliId) {
        return;
    }
    if (!sSessionValid || !sSessionExpiry || [sSessionExpiry timeIntervalSinceNow] < 0.0) {
        sSessionValid = NO;
        [ApplilinkWebAPI setSessionStatus:NO];
    }
    [self initializeWithAppliId:appliId env:env resume:YES callback:nil];
}

+ (void)appAuthSessionRegenerateWithBlock:(void (^)(NSError *_Nullable error))block {
    if (sSessionValid) {
        if (block) {
            block(nil);
        }
        return;
    }
    NSString *url =
        [[ApplilinkConsts baseUrlSsl] stringByAppendingString:kApplilinkSessionRegeneratePath];
    [ApplilinkWebAPI requestAsynchronousWithURL:url
        method:kApplilinkHTTPMethodGet
        parameters:nil
        userInfo:nil
        tag:0
        cachePolicy:nil
        timeout:kApplilinkSessionRequestTimeout
        retry:NO
        finishedBlock:^(id request, id response) {
          /** @ghidraAddress 0x215f24 */
          NSError *error = nil;
          if ([response isKindOfClass:[NSDictionary class]] &&
              [response[kApplilinkResponseStatusKey] boolValue] &&
              [response[kApplilinkResponseErrorCodeKey] intValue] == kApplilinkSessionSuccessCode) {
              sSessionValid = YES;
              sSessionExpiry =
                  [[NSDate date] dateByAddingTimeInterval:kApplilinkSessionValidDuration];
          } else {
              error =
                  [ApplilinkNetworkError localizedApplilinkErrorWithCode:kApplilinkErrorCodeSession
                                                                userInfo:response];
          }
          if (block) {
              block(error);
          }
          [ApplilinkWebAPI setSessionStatus:sSessionValid];
          [ApplilinkWebAPI setSessionConnectionWait:NO];
        }
        failedBlock:^(id request, NSError *error) {
          /** @ghidraAddress 0x21616c */
          [ApplilinkWebAPI setSessionConnectionWait:NO];
          if (block) {
              block(error);
          }
        }];
}

+ (void)clearInitialize {
    [[RewardCore sharedInstance] clearInitialize];
    [[RecommendCore sharedInstance] clearInitialize];
    sInitializeStatusFlg = NO;
}

#pragma mark - Appearance configuration

+ (void)setNavigationBarCommonAppearance:(BOOL)navigationBarCommonAppearance {
    sNavigationBarCommonAppearance = navigationBarCommonAppearance;
}

+ (BOOL)isNavigationBarCommonAppearance {
    return sNavigationBarCommonAppearance;
}

+ (void)setPriorityDeviceLanguages:(BOOL)priorityDeviceLanguages {
    sPriorityDeviceLanguages = priorityDeviceLanguages;
}

+ (BOOL)isPriorityDeviceLanguages {
    return sPriorityDeviceLanguages;
}

+ (void)setIndicatorColor:(UIColor *)indicatorColor {
    sIndicatorColor = indicatorColor;
}

+ (UIColor *)getIndicatorColor {
    if (!sIndicatorColor) {
        return [UIColor whiteColor];
    }
    return sIndicatorColor;
}

#pragma mark - Build and store flags

+ (void)unusedInStore {
    sUsedInStore = YES;
}

+ (BOOL)isUsedInStore {
    return sUsedInStore;
}

+ (void)buildUnderXcode6 {
    sBuiltUnderXcode6 = YES;
}

+ (BOOL)isBuildXcode6 {
    // Yes, the binary returns the inverse of the flag buildUnderXcode6 sets.
    return !sBuiltUnderXcode6;
}

#pragma mark - Windows and status

+ (UIWindow *)mainWindow {
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    if (![keyWindow isMemberOfClass:[UIWindow class]]) {
        for (UIWindow *window in [UIApplication sharedApplication].windows) {
            if (![window isKindOfClass:NSClassFromString(@"_UIModalItemHostingWindow")] &&
                [window isMemberOfClass:[UIWindow class]]) {
                return window;
            }
        }
    }
    return [UIApplication sharedApplication].keyWindow;
}

+ (BOOL)isInitializingFlg {
    return sInitializingFlg;
}

+ (BOOL)isInitializeStatusFlg {
    return sInitializeStatusFlg;
}

+ (NSString *)appliId {
    return [[NSUserDefaults standardUserDefaults] objectForKey:kApplilinkAppliIdKey];
}

#pragma mark - UDID accessors

+ (NSString *)currentUdid {
    if (!sAdUdidCache && !sUdidCache && !sOldUdidCache) {
        return nil;
    }
    if ([ApplilinkUdid isAdvertisingTrackingOSVersion]) {
        return sAdUdidCache;
    }
    if (sUdidCache) {
        return sUdidCache;
    }
    return sOldUdidCache;
}

+ (NSString *)udid_cache {
    return sUdidCache;
}

+ (NSString *)ad_udid_cache {
    return sAdUdidCache;
}

+ (NSString *)old_udid_cache {
    return sOldUdidCache;
}

+ (NSString *)udid {
    if (![ApplilinkConsts canUseApplilinkSdk]) {
        return nil;
    }
    if (sUdidCache || sAdUdidResolved) {
        return sUdidCache;
    }
    NSError *error = nil;
    NSDictionary *record = [ApplilinkUdid udidForFirstInvalidDataWithError:&error];
    if (record) {
        sUdidCache = record[kApplilinkUdidValueKey];
        return sUdidCache;
    }
    (void)[ApplilinkUdid isAdvertisingTrackingOSVersion]; // Yes, the binary discards this result.
    if ([self ad_udid]) {
        sAdUdidResolved = YES;
    }
    sUdidChecked = YES;
    return sUdidCache;
}

+ (NSString *)pasteBoard_udid {
    if (![ApplilinkConsts canUseApplilinkSdk]) {
        return nil;
    }
    if (sPasteBoardUdidCache || sUdidChecked) {
        return sPasteBoardUdidCache;
    }
    NSError *error = nil;
    NSDictionary *record = [ApplilinkUdid udidOldForFirstInvalidDataWithError:&error];
    if (record) {
        sPasteBoardUdidCache = record[kApplilinkUdidValueKey];
        return sPasteBoardUdidCache;
    }
    (void)[ApplilinkUdid isAdvertisingTrackingOSVersion]; // Yes, the binary discards this result.
    sUdidChecked = YES;
    return sPasteBoardUdidCache;
}

+ (NSString *)ad_udid {
    if (![ApplilinkConsts canUseApplilinkSdk]) {
        return nil;
    }
    if (sAdUdidCache) {
        return sAdUdidCache;
    }
    if (![ApplilinkUdid isAdvertisingTrackingOSVersion]) {
        return nil;
    }
    NSError *error = nil;
    sAdUdidCache = [ApplilinkUdid getAdvertisingRewardUdidWithError:&error];
    if ([sAdUdidCache isEqualToString:[ApplilinkUdid getAdvertisingUdid]]) {
        return sAdUdidCache;
    }
    sReLoginPending = YES;
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kApplilinkRewardReLoginFlgKey];
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kApplilinkRecommendReLoginFlgKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    return sAdUdidCache;
}

+ (NSString *)old_udid {
    if (![ApplilinkConsts canUseApplilinkSdk]) {
        return nil;
    }
    if (sOldUdidCache) {
        return sOldUdidCache;
    }
    NSError *error = nil;
    sOldUdidCache = [ApplilinkUdid getOldUdidWithError:&error];
    return sOldUdidCache;
}

+ (BOOL)checkUdid {
    NSString *udid = [self udid];
    NSString *adUdid = [self ad_udid];
    return udid != nil || adUdid != nil;
}

#pragma mark - UDID maintenance

+ (void)clearUDID {
    NSString *env = [ApplilinkConsts envServer];
    if (env && ![env isEqualToString:@""]) {
        [ApplilinkUdid deleteAllUDID];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kApplilinkRewardStorageIndexKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [self clearInitialize];
    }
    sUdidCache = nil;
    sAdUdidResolved = NO;
}

+ (void)setAdUdid:(NSString *)adUdid {
    sAdUdidCache = [NSString stringWithFormat:@"%@", adUdid];
    sOldUdidCache = nil;
}

+ (void)clearKeyChainOldUDID {
    NSString *env = [ApplilinkConsts envServer];
    if (env && ![env isEqualToString:@""]) {
        NSError *error = nil;
        [ApplilinkUdid deleteOldUdidWithError:&error];
    }
    NSString *adUdid = [ApplilinkCore ad_udid];
    NSString *udid = [ApplilinkCore udid];
    NSString *oldUdid = [ApplilinkCore old_udid];
    if (!adUdid && !udid && !oldUdid) {
        [self clearInitialize];
    }
    sOldUdidCache = nil;
}

+ (void)clearAdUDID {
    NSString *env = [ApplilinkConsts envServer];
    if (env && ![env isEqualToString:@""]) {
        [ApplilinkUdid deleteAllAdvertisingUDID];
        [ApplilinkUdid setService:kApplilinkAdStorageService
                 withStorageIndex:kApplilinkAdStorageIndex];
        [self clearInitialize];
    }
    sAdUdidCache = nil;
}

+ (void)updatePasteBoard {
    if (!sReLoginPending) {
        return;
    }
    NSString *udid = [ApplilinkCore currentUdid];
    if (udid) {
        [ApplilinkUdid writeUDIDForFirstEmptyLocationWithUdid:udid];
        sReLoginPending = NO;
    }
}

#pragma mark - Store

+ (BOOL)showAppStoreId:(NSString *)appStoreId
              appParam:(ApplilinkParameters *)appParam
              delegate:(id)delegate {
    if ([ApplilinkCore isUsedInStore] || [appStoreId length] == 0) {
        return NO;
    }
    return [[ApplilinkStore sharedInstance] showSKStore:appStoreId
                                               appParam:appParam
                                               delegate:delegate];
}

+ (void)closeAppStore {
    [[ApplilinkStore sharedInstance] closeSKStore];
}

#pragma mark - Metadata

+ (NSString *)signatureKey {
    return kApplilinkSignatureKey;
}

+ (NSString *)versionDev {
    return [NSString stringWithFormat:@"%@.%@", kApplilinkVersion, kApplilinkVersionBuild];
}

#pragma mark - Delegate fan-out

+ (void)toDelegateDidStart:(ApplilinkParameters *)appParam delegate:(id)delegate {
    id<ApplilinkCoreAdDelegate> adDelegate = delegate;
    if (!adDelegate) {
        return;
    }
    if ([adDelegate respondsToSelector:@selector(appListDidStart:)] && [appParam requestCode]) {
        [adDelegate appListDidStart:appParam];
    } else if ([adDelegate respondsToSelector:@selector(appListDidStart)]) {
        [adDelegate appListDidStart];
    }
}

+ (void)toDelegateDidAppear:(ApplilinkParameters *)appParam delegate:(id)delegate {
    id<ApplilinkCoreAdDelegate> adDelegate = delegate;
    if (!adDelegate) {
        return;
    }
    if ([adDelegate respondsToSelector:@selector(appListDidAppear:)] && [appParam requestCode]) {
        [adDelegate appListDidAppear:appParam];
    } else if ([adDelegate respondsToSelector:@selector(appListDidAppear)]) {
        [adDelegate appListDidAppear];
    }
}

+ (void)toDelegateDidDisappear:(ApplilinkParameters *)appParam delegate:(id)delegate {
    id<ApplilinkCoreAdDelegate> adDelegate = delegate;
    if (!adDelegate) {
        return;
    }
    if ([adDelegate respondsToSelector:@selector(appListDidDisappear:)] && [appParam requestCode]) {
        [adDelegate appListDidDisappear:appParam];
    } else if ([adDelegate respondsToSelector:@selector(appListDidDisappear)]) {
        [adDelegate appListDidDisappear];
    }
}

+ (void)toDelegateFailOpenWithError:(NSError *)error
                           appParam:(ApplilinkParameters *)appParam
                           delegate:(id)delegate {
    id<ApplilinkCoreAdDelegate> adDelegate = delegate;
    if (!adDelegate) {
        return;
    }
    if ([adDelegate
            respondsToSelector:@selector(appListFailOpenWithError:withApplilinkParameters:)] &&
        [appParam requestCode]) {
        [adDelegate appListFailOpenWithError:error withApplilinkParameters:appParam];
    } else if ([adDelegate respondsToSelector:@selector(appListFailOpenWithError:)]) {
        [adDelegate appListFailOpenWithError:error];
    }
    [self toDelegateFailWithError:error appParam:appParam delegate:delegate];
}

+ (void)toDelegateFailLoadWithError:(NSError *)error
                           appParam:(ApplilinkParameters *)appParam
                           delegate:(id)delegate {
    id<ApplilinkCoreAdDelegate> adDelegate = delegate;
    if (!adDelegate) {
        return;
    }
    if ([adDelegate
            respondsToSelector:@selector(appListFailLoadWithError:withApplilinkParameters:)] &&
        [appParam requestCode]) {
        [adDelegate appListFailLoadWithError:error withApplilinkParameters:appParam];
    } else if ([adDelegate respondsToSelector:@selector(appListFailLoadWithError:)]) {
        [adDelegate appListFailLoadWithError:error];
    }
    [self toDelegateFailWithError:error appParam:appParam delegate:delegate];
}

+ (void)toDelegateFailWithError:(NSError *)error
                       appParam:(ApplilinkParameters *)appParam
                       delegate:(id)delegate {
    id<ApplilinkCoreAdDelegate> adDelegate = delegate;
    if (!adDelegate) {
        return;
    }
    if ([adDelegate respondsToSelector:@selector(appListFailWithError:withApplilinkParameters:)] &&
        [appParam requestCode]) {
        [adDelegate appListFailWithError:error withApplilinkParameters:appParam];
    } else if ([adDelegate respondsToSelector:@selector(appListFailWithError:)]) {
        [adDelegate appListFailWithError:error];
    }
}

+ (void)toDelegateFailLinkWithError:(NSError *)error
                           appParam:(ApplilinkParameters *)appParam
                           delegate:(id)delegate {
    id<ApplilinkCoreAdDelegate> adDelegate = delegate;
    if (!adDelegate) {
        return;
    }
    if ([adDelegate
            respondsToSelector:@selector(appListFailLinkWithError:withApplilinkParameters:)] &&
        [appParam requestCode]) {
        [adDelegate appListFailLinkWithError:error withApplilinkParameters:appParam];
    } else if ([adDelegate respondsToSelector:@selector(appListFailLinkWithError:)]) {
        [adDelegate appListFailLinkWithError:error];
    }
}

@end
