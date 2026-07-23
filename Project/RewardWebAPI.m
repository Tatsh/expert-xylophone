//
//  RewardWebAPI.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458.
//  See RewardWebAPI.h for the class overview.
//

#import "RewardWebAPI.h"

#import "ApplilinkConsts.h"
#import "ApplilinkCore.h"
#import "ApplilinkNetworkError.h"
#import "ApplilinkUdid.h"
#import "ApplilinkUtilities.h"
#import "ApplilinkWebAPI.h"
#import "Crypto.h"
#import "NSStringURLEncoding.h"

// The request timeout, in seconds, applied to every reward request.
static const float kRewardRequestTimeout = 10.0f;

// The maximum number of installed application identifiers posted in a single install report; any
// overflow is posted recursively.
static const NSUInteger kRewardInstallReportPageSize = 10;

// Applilink error codes reported by the reward web API.
enum {
    kRewardErrorUserIdMissing = 0x3e9,   // No user identifier was supplied, or a login parameter
                                         // error was returned.
    kRewardErrorAuthorization = 0x3ea,   // The reward server rejected the request's authorization.
    kRewardErrorUdidSetupFailed = 0x402, // The UDID parameters could not be assembled.
    kRewardErrorAppIdMissing = 0x405,    // No Applilink application identifier is set.
    kRewardErrorInstallRejected = 0x3ef, // The install-report request was rejected.
    kRewardErrorInstallConflict = 0x3f1, // The install-report request conflicted with server state.
    kRewardErrorGeneric = 1000,          // A generic or unexpected server response.
};

// The reward server's success sentinel returned in the response's error_code field.
static const int kRewardResponseSuccess = 100000000;

// Login-server error codes mapped to the authorization error.
enum {
    kRewardLoginErrorAuthA = 0xc106cbb,
    kRewardLoginErrorAuthB = 0xc106cba,
    kRewardLoginErrorAuthC = 0xc106cb9,
};

// Install-server error codes.
enum {
    kRewardInstallErrorRejected = 999999999,
    kRewardInstallErrorConflict = 0xc106101,
};

// Reward request priorities.
enum {
    kRewardPriorityNormal = 0,      // Normal install / initial login.
    kRewardPriorityThreeKind = 1,   // Retry once three-kind UDIDs are present.
    kRewardPriorityPasteBoard = 2,  // Pasteboard-sourced path.
};

// Reward SSL request paths appended to ApplilinkConsts.baseUrlSsl.
static NSString *const kPathAppInstallRegist = @"/reward/app/install/regist.php";
static NSString *const kPathCheckLoginStatus = @"/reward/auth/checkLoginStatus.php";
static NSString *const kPathAuthLogin = @"/reward/auth/login.php";
static NSString *const kPathAppIndex = @"/reward/app/index.php";
static NSString *const kPathAppliIdIndex = @"/reward/app/install/appliid/index.php";
static NSString *const kPathCheckAllInstall = @"/reward/app/checkAllInstall.php";
static NSString *const kPathPreInfoForDisplay = @"/reward/app/preInfoForDisplay.php";
static NSString *const kPathInstallReportRegist = @"/reward/app/install/report/regist.php";
static NSString *const kPathBannerDetail = @"/reward/banner/detail.php";

// HTTP methods.
static NSString *const kHTTPMethodGet = @"GET";
static NSString *const kHTTPMethodPost = @"POST";

// Request parameter keys.
static NSString *const kParamUserId = @"user_id";
static NSString *const kParamAppliId = @"appli_id";
static NSString *const kParamAppliIdList = @"appli_id_list";
static NSString *const kParamType = @"type";
static NSString *const kParamFormat = @"format";
static NSString *const kParamFormatJson = @"json";
static NSString *const kParamCfr = @"cfr";
static NSString *const kParamCfrValue = @"1";
static NSString *const kParamSignature = @"signature";

// Response dictionary keys.
static NSString *const kResponseStatus = @"status";
static NSString *const kResponseErrorCode = @"error_code";
static NSString *const kResponseLoginStatus = @"login_status";
static NSString *const kResponseAllInstallFlg = @"all_install_flg";
static NSString *const kResponseKind = @"kind";
static NSString *const kResponseCampaignFlg = @"campaign_flg";

// Response "kind" discriminators for login and install errors.
static NSString *const kResponseKindAuthorization = @"authorization";
static NSString *const kResponseKindParameterError = @"parameter_error";

// The temporary-cache key and NSUserDefaults key for the persisted install flag / campaign flag.
static NSString *const kCacheKeyAppInstallFlg = @"appInstallFlg";
static NSString *const kDefaultsCampaignFlg = @"ApplilinkReward.campaignFlg";

// The keys of the archived temporary-cache entry dictionary.
static NSString *const kCacheKeyValue = @"Value";
static NSString *const kCacheKeyExpire = @"Expire";

// Whether a JSON response is a well-formed reward success: an NSDictionary whose status is true and
// whose error_code is the success sentinel.
static BOOL RewardResponseIsSuccess(id response) {
    if (![response isKindOfClass:[NSDictionary class]]) {
        return NO;
    }
    if (![response[kResponseStatus] boolValue]) {
        return NO;
    }
    return [response[kResponseErrorCode] intValue] == kRewardResponseSuccess;
}

@implementation RewardWebAPI

#pragma mark Install

// @ghidraAddress 0x223990.
+ (void)postApplicationInstallWithPriority:(int)priority
                                  callback:(void (^)(NSError *error))callback {
    NSString *appliId = [ApplilinkConsts appliId];
    if (appliId == nil) {
        callback([ApplilinkNetworkError localizedApplilinkErrorWithCode:kRewardErrorAppIdMissing]);
        return;
    }
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithCapacity:2];
    [parameters setValue:appliId forKey:kParamAppliId];
    if (![ApplilinkUdid setUdidParameters:parameters isUDIDPriorityType:priority]) {
        callback(
            [ApplilinkNetworkError localizedApplilinkErrorWithCode:kRewardErrorUdidSetupFailed]);
        return;
    }
    NSDictionary *signedParameters =
        [ApplilinkUtilities userAgentParametersJoinDictionary:parameters];
    NSString *url = [[ApplilinkConsts baseUrlSsl] stringByAppendingString:kPathAppInstallRegist];
    [ApplilinkWebAPI
        requestAsynchronousWithURL:url
                            method:kHTTPMethodPost
                        parameters:signedParameters
                          userInfo:nil
                               tag:0
                       cachePolicy:nil
                           timeout:kRewardRequestTimeout
                             retry:NO
                     finishedBlock:^(id request, id response) {
                       /** @ghidraAddress 0x223c78 (ApplilinkInstallResponseHandlerBlock) */
                       if (![response isKindOfClass:[NSDictionary class]]) {
                           callback([ApplilinkNetworkError
                               localizedApplilinkErrorWithCode:kRewardErrorGeneric
                                                      userInfo:response]);
                           return;
                       }
                       BOOL statusOk = [response[kResponseStatus] boolValue];
                       int errorCode = [response[kResponseErrorCode] intValue];
                       NSString *kind = response[kResponseKind];
                       if (![kind isKindOfClass:[NSString class]]) {
                           kind = nil;
                       }
                       if (statusOk && errorCode == kRewardResponseSuccess) {
                           if (priority == kRewardPriorityNormal &&
                               [ApplilinkUdid isUdidThreeKinds]) {
                               [RewardWebAPI
                                   postApplicationInstallWithPriority:kRewardPriorityThreeKind
                                                             callback:callback];
                               return;
                           }
                           if (priority != kRewardPriorityPasteBoard) {
                               NSString *campaignFlg = response[kResponseCampaignFlg];
                               if ([campaignFlg isKindOfClass:[NSString class]]) {
                                   [[NSUserDefaults standardUserDefaults] setObject:campaignFlg
                                                                             forKey:
                                                                                 kDefaultsCampaignFlg];
                                   [ApplilinkUdid setUdidKeychainFromPasteBoard];
                                   [[NSUserDefaults standardUserDefaults] synchronize];
                               }
                               NSString *currentUdid = [ApplilinkCore currentUdid];
                               if (currentUdid != nil) {
                                   [ApplilinkUdid setOldUdid:currentUdid error:nil];
                               }
                               [ApplilinkCore updatePasteBoard];
                           }
                           callback(nil);
                           return;
                       }
                       if (errorCode == kRewardInstallErrorRejected) {
                           callback([ApplilinkNetworkError
                               localizedApplilinkErrorWithCode:kRewardErrorInstallRejected
                                                      userInfo:response]);
                       } else if (errorCode == kRewardInstallErrorConflict) {
                           callback([ApplilinkNetworkError
                               localizedApplilinkErrorWithCode:kRewardErrorInstallConflict
                                                      userInfo:response]);
                       } else if ([kind isEqualToString:kResponseKindAuthorization]) {
                           callback([ApplilinkNetworkError
                               localizedApplilinkErrorWithCode:kRewardErrorAuthorization
                                                      userInfo:response]);
                       } else if ([kind isEqualToString:kResponseKindParameterError]) {
                           callback([ApplilinkNetworkError
                               localizedApplilinkErrorWithCode:kRewardErrorUserIdMissing
                                                      userInfo:response]);
                       } else {
                           callback([ApplilinkNetworkError
                               localizedApplilinkErrorWithCode:kRewardErrorGeneric
                                                      userInfo:response]);
                       }
                     }
                       failedBlock:^(id request, NSError *error) {
                         /** @ghidraAddress 0x224160 (ApplilinkInvokeCompletionBlock) */
                         callback(error);
                       }];
}

#pragma mark Login

// @ghidraAddress 0x224188.
+ (void)checkLoginWithBlock:(void (^)(BOOL valid, NSError *error))block {
    if ([ApplilinkCore udid] != nil && [ApplilinkCore old_udid] == nil) {
        [ApplilinkUdid setUdidKeychainFromPasteBoard];
    }
    if ([ApplilinkConsts isNeedRewardLogin]) {
        block(NO, nil);
        return;
    }
    NSString *url = [[ApplilinkConsts baseUrlSsl] stringByAppendingString:kPathCheckLoginStatus];
    [ApplilinkWebAPI
        requestAsynchronousWithURL:url
                            method:kHTTPMethodGet
                        parameters:nil
                          userInfo:nil
                               tag:0
                       cachePolicy:nil
                           timeout:kRewardRequestTimeout
                             retry:NO
                     finishedBlock:^(id request, id response) {
                       /** @ghidraAddress 0x2243b8 (ApplilinkLoginStatusResponseBlock) */
                       if (![response isKindOfClass:[NSDictionary class]]) {
                           block(NO,
                                 [ApplilinkNetworkError
                                     localizedApplilinkErrorWithCode:kRewardErrorGeneric
                                                            userInfo:response]);
                           return;
                       }
                       if ([response[kResponseStatus] boolValue]) {
                           block([response[kResponseLoginStatus] boolValue], nil);
                           return;
                       }
                       block(NO,
                             [ApplilinkNetworkError
                                 localizedApplilinkErrorWithCode:kRewardErrorGeneric
                                                        userInfo:response]);
                     }
                       failedBlock:^(id request, NSError *error) {
                         /** @ghidraAddress 0x224544 (ApplilinkCallbackNilForwardBlock) */
                         block(NO, error);
                       }];
}

// @ghidraAddress 0x22456c.
+ (void)startLoginWithUserId:(NSString *)userId
                withPriority:(int)priority
                    callback:(void (^)(NSError *error))callback {
    NSMutableDictionary *parameters = [[NSMutableDictionary alloc] init];
    if (userId == nil) {
        callback([ApplilinkNetworkError localizedApplilinkErrorWithCode:kRewardErrorUserIdMissing]);
        return;
    }
    [parameters setValue:[NSStringURLEncoding URLEncodedString:userId] forKey:kParamUserId];
    if (![ApplilinkUdid setUdidParameters:parameters isUDIDPriorityType:priority]) {
        callback(
            [ApplilinkNetworkError localizedApplilinkErrorWithCode:kRewardErrorUdidSetupFailed]);
        return;
    }
    NSMutableDictionary *signedParameters =
        [ApplilinkUtilities userAgentParametersJoinDictionary:parameters];
    [parameters removeAllObjects];
    [RewardWebAPI setSignatureWithParameters:signedParameters];
    [signedParameters setValue:kParamCfrValue forKey:kParamCfr];
    NSString *url = [[ApplilinkConsts baseUrlSsl] stringByAppendingString:kPathAuthLogin];
    [ApplilinkWebAPI
        requestAsynchronousWithURL:url
                            method:kHTTPMethodPost
                        parameters:signedParameters
                          userInfo:nil
                               tag:0
                       cachePolicy:nil
                           timeout:kRewardRequestTimeout
                             retry:NO
                     finishedBlock:^(id request, id response) {
                       /** @ghidraAddress 0x2248c4 (ApplilinkLoginResponseHandlerBlock) */
                       if (![response isKindOfClass:[NSDictionary class]]) {
                           callback([ApplilinkNetworkError
                               localizedApplilinkErrorWithCode:kRewardErrorGeneric
                                                      userInfo:response]);
                           return;
                       }
                       if ([response[kResponseStatus] boolValue] &&
                           [response[kResponseErrorCode] intValue] == kRewardResponseSuccess) {
                           if (priority == kRewardPriorityNormal &&
                               [ApplilinkUdid isUdidThreeKinds]) {
                               [RewardWebAPI startLoginWithUserId:userId
                                                     withPriority:kRewardPriorityThreeKind
                                                         callback:callback];
                               return;
                           }
                           if (priority == kRewardPriorityPasteBoard) {
                               [RewardWebAPI startLoginWithUserId:userId
                                                     withPriority:kRewardPriorityPasteBoard
                                                         callback:callback];
                               return;
                           }
                           callback(nil);
                           return;
                       }
                       int errorCode = [response[kResponseErrorCode] intValue];
                       if (errorCode == kRewardLoginErrorAuthA ||
                           errorCode == kRewardLoginErrorAuthB ||
                           errorCode == kRewardLoginErrorAuthC) {
                           callback([ApplilinkNetworkError
                               localizedApplilinkErrorWithCode:kRewardErrorAuthorization
                                                      userInfo:response]);
                           return;
                       }
                       if ([response[kResponseKind] isEqualToString:kResponseKindParameterError]) {
                           callback([ApplilinkNetworkError
                               localizedApplilinkErrorWithCode:kRewardErrorUserIdMissing
                                                      userInfo:response]);
                       } else {
                           callback([ApplilinkNetworkError
                               localizedApplilinkErrorWithCode:kRewardErrorGeneric
                                                      userInfo:response]);
                       }
                     }
                       failedBlock:^(id request, NSError *error) {
                         /** @ghidraAddress 0x224cd8 (ApplilinkCallbackForwardBlock) */
                         callback(error);
                       }];
}

#pragma mark Application lists

// @ghidraAddress 0x224d00.
+ (void)appListWithCampaignId:(NSString *)campaignId
                    inCompany:(NSString *)company
                       offset:(NSString *)offset
                        limit:(NSString *)limit
                     callback:(void (^)(NSDictionary *result, NSError *error))callback {
    NSMutableDictionary *parameters = [[NSMutableDictionary alloc] init];
    [parameters setValue:kParamFormatJson forKey:kParamFormat];
    NSString *url = [[ApplilinkConsts baseUrlSsl] stringByAppendingString:kPathAppIndex];
    [ApplilinkWebAPI
        requestAsynchronousWithURL:url
                            method:kHTTPMethodGet
                        parameters:parameters
                          userInfo:nil
                               tag:0
                       cachePolicy:nil
                           timeout:kRewardRequestTimeout
                             retry:NO
                     finishedBlock:^(id request, id response) {
                       /** @ghidraAddress 0x224ee8 (ApplilinkDataResponseHandlerBlock) */
                       if (RewardResponseIsSuccess(response)) {
                           callback(response, nil);
                           return;
                       }
                       callback(nil,
                                [ApplilinkNetworkError
                                    localizedApplilinkErrorWithCode:kRewardErrorGeneric
                                                           userInfo:response]);
                     }
                       failedBlock:^(id request, NSError *error) {
                         /** @ghidraAddress 0x22509c (ApplilinkCallbackNilForwardBlock) */
                         callback(nil, error);
                       }];
    [parameters removeAllObjects]; // Yes, the binary clears the dictionary after dispatching.
}

// @ghidraAddress 0x2250c4.
+ (void)appliIdListWithType:(int)type
                   callback:(void (^)(NSDictionary *result, NSError *error))callback {
    NSDictionary *parameters =
        [NSDictionary dictionaryWithObject:@(type) forKey:kParamType];
    NSString *url = [[ApplilinkConsts baseUrlSsl] stringByAppendingString:kPathAppliIdIndex];
    [ApplilinkWebAPI
        requestAsynchronousWithURL:url
                            method:kHTTPMethodGet
                        parameters:parameters
                          userInfo:nil
                               tag:0
                       cachePolicy:nil
                           timeout:kRewardRequestTimeout
                             retry:NO
                     finishedBlock:^(id request, id response) {
                       /** @ghidraAddress 0x2252b4 (ApplilinkDataResponseHandlerBlock) */
                       if (RewardResponseIsSuccess(response)) {
                           callback(response, nil);
                           return;
                       }
                       callback(nil,
                                [ApplilinkNetworkError
                                    localizedApplilinkErrorWithCode:kRewardErrorGeneric
                                                           userInfo:response]);
                     }
                       failedBlock:^(id request, NSError *error) {
                         /** @ghidraAddress 0x225468 (InvokeCallbackNilBlockInvoke) */
                         callback(nil, error);
                       }];
}

#pragma mark Status flags

// @ghidraAddress 0x225490.
+ (void)allInstallFlgWithCallback:(void (^)(NSInteger flg, NSError *error))callback {
    NSMutableDictionary *parameters = [[NSMutableDictionary alloc] init];
    [parameters setValue:kParamFormatJson forKey:kParamFormat];
    NSString *url = [[ApplilinkConsts baseUrlSsl] stringByAppendingString:kPathCheckAllInstall];
    [ApplilinkWebAPI
        requestAsynchronousWithURL:url
                            method:kHTTPMethodGet
                        parameters:parameters
                          userInfo:nil
                               tag:0
                       cachePolicy:nil
                           timeout:kRewardRequestTimeout
                             retry:NO
                     finishedBlock:^(id request, id response) {
                       /** @ghidraAddress 0x225738 (HandleAllInstallFlagResponseBlockInvoke) */
                       if (![response isKindOfClass:[NSDictionary class]]) {
                           callback(0,
                                    [ApplilinkNetworkError
                                        localizedApplilinkErrorWithCode:kRewardErrorGeneric
                                                               userInfo:response]);
                           return;
                       }
                       if ([response[kResponseStatus] boolValue] &&
                           [response[kResponseErrorCode] intValue] == kRewardResponseSuccess) {
                           id flg = response[kResponseAllInstallFlg];
                           if (flg != nil) {
                               [RewardWebAPI
                                   setTemporaryCacheWithKey:kCacheKeyAppInstallFlg
                                                      value:[NSString stringWithFormat:@"%@", flg]
                                                 expiration:0];
                               callback([flg intValue], nil);
                               return;
                           }
                           callback(-1,
                                    [ApplilinkNetworkError
                                        localizedApplilinkErrorWithCode:kRewardErrorGeneric
                                                               userInfo:response]);
                           return;
                       }
                       callback(0,
                                [ApplilinkNetworkError
                                    localizedApplilinkErrorWithCode:kRewardErrorGeneric
                                                           userInfo:response]);
                     }
                       failedBlock:^(id request, NSError *error) {
                         /** @ghidraAddress 0x2259e4 (InvokeCallbackNil2BlockInvoke) */
                         callback(0, error);
                       }];
}

// @ghidraAddress 0x225a0c.
+ (void)getPreInfoWithCallback:(void (^)(NSInteger flg, NSError *error))callback {
    NSMutableDictionary *parameters = [[NSMutableDictionary alloc] init];
    [parameters setValue:kParamFormatJson forKey:kParamFormat];
    NSString *url = [[ApplilinkConsts baseUrlSsl] stringByAppendingString:kPathPreInfoForDisplay];
    [ApplilinkWebAPI
        requestAsynchronousWithURL:url
                            method:kHTTPMethodGet
                        parameters:parameters
                          userInfo:nil
                               tag:0
                       cachePolicy:nil
                           timeout:kRewardRequestTimeout
                             retry:NO
                     finishedBlock:^(id request, id response) {
                       /** @ghidraAddress 0x225c84 (HandleAllInstallFlagResponse2BlockInvoke) */
                       if (![response isKindOfClass:[NSDictionary class]]) {
                           callback(0,
                                    [ApplilinkNetworkError
                                        localizedApplilinkErrorWithCode:kRewardErrorGeneric
                                                               userInfo:response]);
                           return;
                       }
                       if ([response[kResponseStatus] boolValue] &&
                           [response[kResponseErrorCode] intValue] == kRewardResponseSuccess) {
                           id flg = response[kResponseAllInstallFlg];
                           if (flg != nil) {
                               [RewardWebAPI
                                   setTemporaryCacheWithKey:kCacheKeyAppInstallFlg
                                                      value:[NSString stringWithFormat:@"%@", flg]
                                                 expiration:0];
                               callback([flg intValue], nil);
                               return;
                           }
                           callback(-1,
                                    [ApplilinkNetworkError
                                        localizedApplilinkErrorWithCode:kRewardErrorGeneric
                                                               userInfo:response]);
                           return;
                       }
                       callback(0,
                                [ApplilinkNetworkError
                                    localizedApplilinkErrorWithCode:kRewardErrorGeneric
                                                           userInfo:response]);
                     }
                       failedBlock:^(id request, NSError *error) {
                         /** @ghidraAddress 0x225f30 (InvokeCallbackNil3BlockInvoke) */
                         callback(0, error);
                       }];
}

#pragma mark Install report

// @ghidraAddress 0x225f58.
+ (void)postAppliInstallReportWithAppliList:(NSArray *)appliList
                                   callback:(void (^)(NSError *error))callback {
    NSArray *page;
    NSArray *remaining;
    if (appliList.count < kRewardInstallReportPageSize + 1) {
        page = [appliList copy];
        remaining = nil;
    } else {
        NSIndexSet *pageRange = [NSIndexSet
            indexSetWithIndexesInRange:NSMakeRange(0, kRewardInstallReportPageSize)];
        page = [appliList objectsAtIndexes:pageRange];
        NSIndexSet *remainingRange = [NSIndexSet
            indexSetWithIndexesInRange:NSMakeRange(kRewardInstallReportPageSize,
                                                   appliList.count -
                                                       kRewardInstallReportPageSize)];
        remaining = [appliList objectsAtIndexes:remainingRange];
    }
    NSDictionary *parameters =
        [NSDictionary dictionaryWithObject:page forKey:kParamAppliIdList];
    NSString *url = [[ApplilinkConsts baseUrlSsl] stringByAppendingString:kPathInstallReportRegist];
    [ApplilinkWebAPI
        requestAsynchronousWithURL:url
                            method:kHTTPMethodPost
                        parameters:parameters
                          userInfo:nil
                               tag:0
                       cachePolicy:nil
                           timeout:kRewardRequestTimeout
                             retry:NO
                     finishedBlock:^(id request, id response) {
                       /** @ghidraAddress 0x226260 (HandleInstallReportResponseBlockInvoke) */
                       if (![response isKindOfClass:[NSDictionary class]]) {
                           callback([ApplilinkNetworkError
                               localizedApplilinkErrorWithCode:kRewardErrorGeneric
                                                      userInfo:response]);
                           return;
                       }
                       if ([response[kResponseStatus] boolValue] &&
                           [response[kResponseErrorCode] intValue] == kRewardResponseSuccess) {
                           if (remaining != nil && remaining.count != 0) {
                               [RewardWebAPI postAppliInstallReportWithAppliList:remaining
                                                                       callback:callback];
                               return;
                           }
                           callback(nil);
                           return;
                       }
                       callback([ApplilinkNetworkError
                           localizedApplilinkErrorWithCode:kRewardErrorGeneric
                                                  userInfo:response]);
                     }
                       failedBlock:^(id request, id result) {
                         /** @ghidraAddress 0x226484 (ForwardResultToCallbackBlockInvoke) */
                         callback(result);
                       }];
}

#pragma mark Banner

// @ghidraAddress 0x2264ac.
+ (void)bannerInfoWithBlock:(void (^)(NSDictionary *result, NSError *error))block {
    NSDictionary *parameters = [ApplilinkUtilities userAgentParameters];
    NSString *url = [[ApplilinkConsts baseUrlSsl] stringByAppendingString:kPathBannerDetail];
    [ApplilinkWebAPI
        requestAsynchronousWithURL:url
                            method:kHTTPMethodGet
                        parameters:parameters
                          userInfo:nil
                               tag:0
                       cachePolicy:nil
                           timeout:kRewardRequestTimeout
                             retry:NO
                     finishedBlock:^(id request, id response) {
                       /** @ghidraAddress 0x226658 (HandleApiSuccessResponseBlockInvoke) */
                       if (RewardResponseIsSuccess(response)) {
                           block(response, nil);
                           return;
                       }
                       block(nil,
                             [ApplilinkNetworkError
                                 localizedApplilinkErrorWithCode:kRewardErrorGeneric
                                                        userInfo:response]);
                     }
                       failedBlock:^(id request, NSError *error) {
                         /** @ghidraAddress 0x22680c (InvokeCallbackNil4BlockInvoke) */
                         block(nil, error);
                       }];
}

#pragma mark Signing and cache

// @ghidraAddress 0x226834.
+ (void)setSignatureWithParameters:(NSMutableDictionary *)parameters {
    NSArray *sortedKeys = [[parameters allKeys]
        sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    NSMutableArray *pairs = [NSMutableArray array];
    for (NSString *key in sortedKeys) {
        id value = parameters[key];
        if ([value isKindOfClass:[NSArray class]]) {
            for (NSUInteger i = 0; i < [value count]; ++i) {
                [pairs addObject:[NSString stringWithFormat:@"%@[]=%@", key, value[i]]];
            }
        } else {
            [pairs addObject:[NSString stringWithFormat:@"%@=%@", key, value]];
        }
    }
    NSString *joined = [pairs componentsJoinedByString:@"&"];
    NSString *signatureSource =
        [NSString stringWithFormat:@"%@&%@", joined, [ApplilinkCore signatureKey]];
    NSString *signature =
        [Crypto sha256:[NSStringURLEncoding URLDecodedString:signatureSource]];
    parameters[kParamSignature] = signature;
}

// @ghidraAddress 0x226cdc.
+ (void)setTemporaryCacheWithKey:(NSString *)key value:(id)value expiration:(NSInteger)expiration {
    NSDate *expiry = [[NSDate alloc]
        initWithTimeIntervalSinceNow:(expiration == 0 ? 1.0 : (double)expiration)];
    NSDictionary *cacheEntry =
        [NSDictionary dictionaryWithObjectsAndKeys:value, kCacheKeyValue, expiry, kCacheKeyExpire,
                                                   nil];
    [[NSUserDefaults standardUserDefaults]
        setObject:[NSKeyedArchiver archivedDataWithRootObject:cacheEntry]
           forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end
