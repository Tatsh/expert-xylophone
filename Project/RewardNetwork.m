//
//  RewardNetwork.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458.
//  See RewardNetwork.h for the class overview.
//

#import "RewardNetwork.h"

#import "ApplilinkConsts.h"
#import "ApplilinkCore.h"
#import "ApplilinkNetworkError.h"
#import "ApplilinkParameters.h"
#import "RewardCore.h"

// Applilink error codes messaged as the localised-error factory argument.
enum {
    kRewardErrorSdkUnavailable = 0x401, // The SDK cannot run on this device.
    kRewardErrorNotInitialized = 0x3f2, // The SDK has not finished initialising.
};

@implementation RewardNetwork

// @ 0x21f524
+ (void)openAdScreenWithAdLocation:(NSString *)adLocation
                       requestCode:(NSInteger)requestCode
                          delegate:(id)delegate {
    [RewardNetwork openAdScreenWithParentView:nil
                                   adLocation:adLocation
                                  requestCode:requestCode
                                     delegate:delegate];
}

// @ 0x21f598
+ (void)openAdScreenWithParentView:(UIView *)parentView
                        adLocation:(NSString *)adLocation
                          delegate:(id)delegate {
    [RewardNetwork openAdScreenWithParentView:parentView
                                   adLocation:adLocation
                                  requestCode:0
                                     delegate:delegate];
}

// @ 0x21f60c
+ (void)openAdScreenWithParentView:(UIView *)parentView
                        adLocation:(NSString *)adLocation
                       requestCode:(NSInteger)requestCode
                          delegate:(id)delegate {
    if (![ApplilinkConsts checkUseSDKWithAdModel:0
                                      adLocation:adLocation
                                   verticalAlign:0
                                     requestCode:requestCode
                                        delegate:delegate]) {
        return;
    }
    if ([RewardCore sharedInstance].initializeFlg == 0 && ![ApplilinkCore isInitializeStatusFlg]) {
        ApplilinkParameters *params = [[ApplilinkParameters alloc] init];
        [params setRequestWithAdModel:0 adLocation:adLocation requestCode:requestCode];
        [ApplilinkCore
            toDelegateFailOpenWithError:
                [ApplilinkNetworkError localizedApplilinkErrorWithCode:kRewardErrorNotInitialized]
                               appParam:params
                               delegate:delegate];
        return;
    }
    [[RewardCore sharedInstance] openAdScreenWithParentView:parentView
                                                 adLocation:adLocation
                                                requestCode:requestCode
                                                   delegate:delegate];
}

// @ 0x21f808
+ (void)closeAdScreen {
    if ([ApplilinkConsts canUseApplilinkSdk]) {
        [[RewardCore sharedInstance] closeAdScreen];
    }
}

// @ 0x21f880
+ (void)allInstallFlgWithCallback:(void (^)(NSInteger flg, NSError *error))callback {
    if (![ApplilinkConsts canUseApplilinkSdk]) {
        callback(
            0, [ApplilinkNetworkError localizedApplilinkErrorWithCode:kRewardErrorSdkUnavailable]);
        return;
    }
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
      // @ 0x21f970 — forward to the RewardCore all-install query on a background queue.
      [[RewardCore sharedInstance] allInstallFlgWithCallback:callback];
    });
}

// @ 0x21f9e0
+ (void)getAdDisplayStatusWithCallback:(void (^)(NSDictionary *status, NSError *error))callback {
    NSMutableDictionary *defaultStatus = [NSMutableDictionary dictionaryWithCapacity:2];
    [defaultStatus setValue:@(0) forKey:@"allInstallFlg"];
    [defaultStatus setValue:@(0) forKey:@"bannerDisplayStatus"];
    if (![ApplilinkConsts canUseApplilinkSdk]) {
        callback(
            defaultStatus,
            [ApplilinkNetworkError localizedApplilinkErrorWithCode:kRewardErrorSdkUnavailable]);
        return;
    }
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
      // @ 0x21fba4 — forward to the RewardCore ad-display query on a background queue.
      [[RewardCore sharedInstance] getAdDisplayStatusWithCallback:callback];
    });
}

// @ 0x21fc14
+ (void)getAdStatusWithBlock:(void (^)(NSInteger status, NSError *error))block {
    if (![ApplilinkConsts canUseApplilinkSdk]) {
        block(0,
              [ApplilinkNetworkError localizedApplilinkErrorWithCode:kRewardErrorSdkUnavailable]);
        return;
    }
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
      // @ 0x21fd04 — forward to the RewardCore app-list status query on a background queue.
      [[RewardCore sharedInstance] getAppListStatusWithBlock:block];
    });
}

@end
