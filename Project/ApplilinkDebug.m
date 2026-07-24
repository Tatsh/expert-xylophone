#import "ApplilinkDebug.h"

#import "AnalysisNetworkCore.h"
#import "ApplilinkConsts.h"
#import "ApplilinkCore.h"
#import "RecommendAdCache.h"
#import "RecommendCore.h"
#import "RecommendDebug.h"
#import "RewardCore.h"

// The Applilink SDK version this debug build reports.
static NSString *const kApplilinkSdkVersionBase = @"2.2.2";
static NSString *const kApplilinkSdkVersionBuild = @"5";

@implementation ApplilinkDebug

+ (NSString *)countryCode {
    return [ApplilinkConsts countryCode];
}

+ (NSString *)categoryId {
    return [ApplilinkConsts categoryId];
}

+ (NSString *)udid {
    return [ApplilinkCore udid_cache];
}

+ (NSString *)ad_udid {
    return [ApplilinkCore ad_udid_cache];
}

+ (NSString *)old_udid {
    return [ApplilinkCore old_udid_cache];
}

+ (void)clearUDID {
    [ApplilinkCore clearUDID];
}

+ (void)clearKeyChainOldUDID {
    [ApplilinkCore clearKeyChainOldUDID];
}

+ (void)clearAdUDID {
    [ApplilinkCore clearAdUDID];
}

+ (NSString *)versionDev {
    return
        [NSString stringWithFormat:@"%@.%@", kApplilinkSdkVersionBase, kApplilinkSdkVersionBuild];
}

+ (void)clearSession {
    [[RewardCore sharedInstance] clearSession];
    [[RecommendCore sharedInstance] clearSession];
}

+ (void)clearAdStatus {
    [[RewardCore sharedInstance] clearAdStatus];
    [[RecommendCore sharedInstance] clearAdStatus];
}

+ (void)clearInitalize {
    [AnalysisNetworkCore clearInitalize];
}

+ (void)clearDAU {
    [AnalysisNetworkCore clearDAU];
}

+ (void)debugMode:(id)debugMode {
    [RecommendDebug debugMode:debugMode];
}

+ (id)getDebugMode {
    return [RecommendDebug getDebugMode];
}

+ (void)allClearCacheBannerImage {
    [RecommendAdCache allClearCacheBannerImage];
}

+ (NSMutableDictionary *)getFrequencyStatus {
    return [RecommendDebug getFrequencyStatus];
}

+ (NSMutableDictionary *)getDisplaySpec {
    return [RecommendDebug getDisplaySpec];
}

@end
