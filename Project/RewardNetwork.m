#import "RewardNetwork.h"

#import "ApplilinkConsts.h"
#import "ApplilinkCore.h"
#import "ApplilinkMessage.h"
#import "ApplilinkNetworkError.h"
#import "ApplilinkParameters.h"
#import "RewardCore.h"

enum {
    kRewardErrorSdkUnavailable = 0x401, // The SDK cannot run on this device.
    kRewardErrorNotInitialized = 0x3f2, // The SDK has not finished initialising.
};

static NSString *const kRewardNetworkAppListTitleKey = @"RewardNetworkAppListTitle";

@implementation RewardNetwork

// @ghidraAddress 0x21f524
+ (void)openAdScreenWithAdLocation:(NSString *)adLocation
                       requestCode:(id)requestCode
                          delegate:(id)delegate {
    [RewardNetwork openAdScreenWithParentView:nil
                                   adLocation:adLocation
                                  requestCode:requestCode
                                     delegate:delegate];
}

// @ghidraAddress 0x21f598
+ (void)openAdScreenWithParentView:(UIView *)parentView
                        adLocation:(NSString *)adLocation
                          delegate:(id)delegate {
    [RewardNetwork openAdScreenWithParentView:parentView
                                   adLocation:adLocation
                                  requestCode:nil
                                     delegate:delegate];
}

// @ghidraAddress 0x21f60c
+ (void)openAdScreenWithParentView:(UIView *)parentView
                        adLocation:(NSString *)adLocation
                       requestCode:(id)requestCode
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

// @ghidraAddress 0x21f808
+ (void)closeAdScreen {
    if ([ApplilinkConsts canUseApplilinkSdk]) {
        [[RewardCore sharedInstance] closeAdScreen];
    }
}

// @ghidraAddress 0x21f880
+ (void)allInstallFlgWithCallback:(void (^)(NSInteger flg, NSError *error))callback {
    if (![ApplilinkConsts canUseApplilinkSdk]) {
        callback(
            0, [ApplilinkNetworkError localizedApplilinkErrorWithCode:kRewardErrorSdkUnavailable]);
        return;
    }
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
      // @ghidraAddress 0x21f970
      [[RewardCore sharedInstance] allInstallFlgWithCallback:callback];
    });
}

// @ghidraAddress 0x21f9e0
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
      // @ghidraAddress 0x21fba4
      [[RewardCore sharedInstance] getAdDisplayStatusWithCallback:callback];
    });
}

// @ghidraAddress 0x21fc14
+ (void)getAdStatusWithBlock:(void (^)(NSInteger status, NSError *error))block {
    if (![ApplilinkConsts canUseApplilinkSdk]) {
        block(0,
              [ApplilinkNetworkError localizedApplilinkErrorWithCode:kRewardErrorSdkUnavailable]);
        return;
    }
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
      // @ghidraAddress 0x21fd04
      [[RewardCore sharedInstance] getAppListStatusWithBlock:block];
    });
}

// @ghidraAddress 0x21fd74
+ (void)setNavigationBarHidden:(BOOL)navigationBarHidden {
    [[RewardCore sharedInstance] setNavigationBarHidden:navigationBarHidden];
}

// @ghidraAddress 0x21fdcc
+ (NSString *)getNavigationTitle {
    return [ApplilinkMessage localizedMessage:kRewardNetworkAppListTitleKey];
}

@end
