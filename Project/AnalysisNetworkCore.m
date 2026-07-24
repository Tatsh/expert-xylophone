#import "AnalysisNetworkCore.h"

#import <Foundation/Foundation.h>

#import "ApplilinkConsts.h"
#import "ApplilinkNetworkError.h"
#import "ApplilinkUdid.h"
#import "ApplilinkUtilities.h"
#import "ApplilinkWebAPI.h"
#import "NSStringURLEncoding.h"

// Analytics action-type codes posted in the request's action_type parameter.
enum {
    kAnalysisActionTypeNone = 0,
    kAnalysisActionTypeInitalize = 1,
    kAnalysisActionTypeDau = 2,
    kAnalysisActionTypeResult = 3,
    kAnalysisActionTypeSetUserID = 14,
};

// Applilink error codes forwarded to the caller's completion callback.
enum {
    kApplilinkErrorGeneric = 1000,          // Non-success server response.
    kApplilinkErrorMissingParameter = 1001, // A required parameter was nil.
    kApplilinkErrorUdidParameters = 1026,   // ApplilinkUdid could not supply UDID parameters.
    kApplilinkErrorTrackingDisabled = 1028, // Advertising tracking is disabled.
};

// The server response is a success when its status is truthy and its error_code equals this value.
static const int kApplilinkResponseSuccessCode = 100000000;

// Request timeout, in seconds, for every analytics POST.
static const float kAnalysisRequestTimeout = 10.0f;

// Request parameter and NSUserDefaults key strings.
static NSString *const kAnalysisParamActionType = @"action_type";
static NSString *const kAnalysisParamResultId = @"result_id";
static NSString *const kAnalysisParamUserId = @"user_id";
static NSString *const kAnalysisParamUdidSrc = @"udid_src";
static NSString *const kAnalysisParamAdLocation = @"ad_location";
static NSString *const kAnalysisParamImpressionId = @"impression_id";
static NSString *const kAnalysisParamSystem = @"system";
static NSString *const kAnalysisParamAdType = @"ad_type";
static NSString *const kAnalysisParamAdModel = @"ad_model";
static NSString *const kAnalysisParamAppliIdToList = @"appli_id_to_list";
static NSString *const kAnalysisParamCreativeIdList = @"creative_id_list";
static NSString *const kAnalysisParamIncentiveTypeList = @"incentive_type_list";
static NSString *const kAnalysisParamInstallFlgList = @"install_flg_list";
static NSString *const kAnalysisParamAppliIdTo = @"appli_id_to";
static NSString *const kAnalysisParamCreativeId = @"creative_id";
static NSString *const kAnalysisParamDisplayNumber = @"display_number";
static NSString *const kAnalysisParamIncentiveType = @"incentive_type";
static NSString *const kAnalysisParamInstallFlg = @"install_flg";
static NSString *const kAnalysisSystemValueAd = @"ad";

static NSString *const kAnalysisPathData = @"/analysis/regist.php";
static NSString *const kAnalysisPathListRegist = @"/analysis/list/regist.php";
static NSString *const kAnalysisPathClickRegist = @"/analysis/click/regist.php";

static NSString *const kAnalysisDefaultsInitalizeKey = @"ApplilinkAnalysis.initialize";
static NSString *const kAnalysisDefaultsDauDateKey = @"ApplilinkAnalysis.dauMeasurementDate";

@implementation AnalysisNetworkCore

#pragma mark - Persistence flags

+ (BOOL)getInitalizeFlg {
    return
        [[NSUserDefaults standardUserDefaults] objectForKey:kAnalysisDefaultsInitalizeKey] != nil;
}

+ (BOOL)getSendDauFlg {
    NSDate *persisted =
        [[NSUserDefaults standardUserDefaults] objectForKey:kAnalysisDefaultsDauDateKey];
    NSDate *now = [NSDate date];
    if (persisted) {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateStyle = NSDateFormatterMediumStyle;
        formatter.timeStyle = NSDateFormatterNoStyle;
        NSString *persistedDay = [formatter stringFromDate:persisted];
        NSString *nowDay = [formatter stringFromDate:now];
        // The persisted value is the previously formatted day string; comparing the two formatted
        // day strings collapses any difference within the same day.
        if ([persistedDay compare:nowDay] != NSOrderedAscending) {
            return YES;
        }
    }
    return NO;
}

#pragma mark - Core poster

+ (void)postAnalysisDataWithActionType:(int)actionType
                              resultId:(NSString *)resultId
                                uesrId:(NSString *)uesrId
                         finishedBlock:(void (^)(id request, id result))finishedBlock
                           failedBlock:(void (^)(id request, NSError *error))failedBlock
                              callback:(void (^)(NSError *error))callback {
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithCapacity:4];
    if (actionType == kAnalysisActionTypeNone) {
        callback([ApplilinkNetworkError
            localizedApplilinkErrorWithCode:kApplilinkErrorMissingParameter]);
        return;
    }

    parameters[kAnalysisParamActionType] = [NSString stringWithFormat:@"%d", actionType];
    if (![ApplilinkUdid setUdidParameters:parameters]) {
        callback(
            [ApplilinkNetworkError localizedApplilinkErrorWithCode:kApplilinkErrorUdidParameters]);
        return;
    }
    if (![ApplilinkUdid isAdvertisingTrackingEnabled]) {
        callback([ApplilinkNetworkError
            localizedApplilinkErrorWithCode:kApplilinkErrorTrackingDisabled]);
        return;
    }

    if (resultId && resultId.length != 0) {
        parameters[kAnalysisParamResultId] = resultId;
    }
    if (uesrId && uesrId.length != 0) {
        parameters[kAnalysisParamUserId] = [NSStringURLEncoding URLEncodedString:uesrId];
    }

    NSString *udidSource = [ApplilinkUdid isAdvertisingTrackingOSVersion] ?
                               [ApplilinkUdid getAdUdid] :
                               [ApplilinkUdid getCFUUID];
    if (udidSource) {
        parameters[kAnalysisParamUdidSrc] = udidSource;
    }

    NSDictionary *merged = [ApplilinkUtilities userAgentParametersJoinDictionary:parameters];
    NSString *url = [[ApplilinkConsts baseUrlSsl] stringByAppendingString:kAnalysisPathData];
    [ApplilinkWebAPI requestAsynchronousWithURL:url
                                         method:@"POST"
                                     parameters:merged
                                       userInfo:nil
                                            tag:0
                                    cachePolicy:nil
                                        timeout:kAnalysisRequestTimeout
                                          retry:NO
                                  finishedBlock:finishedBlock
                                    failedBlock:failedBlock];
}

#pragma mark - Initalize and DAU

+ (void)postInitalizeWithCallback:(void (^)(NSError *error))callback {
    if ([self getInitalizeFlg]) {
        callback(nil);
        return;
    }

    NSDate *now = [NSDate date];
    [self postAnalysisDataWithActionType:kAnalysisActionTypeInitalize
        resultId:nil
        uesrId:nil
        finishedBlock:^(id request, id result) {
          /** @ghidraAddress 0x20d7d4 */
          (void)request;
          NSDictionary *response = (NSDictionary *)result;
          if ([response[@"status"] boolValue] &&
              [response[@"error_code"] intValue] == kApplilinkResponseSuccessCode) {
              [[NSUserDefaults standardUserDefaults] setObject:now
                                                        forKey:kAnalysisDefaultsInitalizeKey];
              [[NSUserDefaults standardUserDefaults] synchronize];
              callback(nil);
              return;
          }
          callback([ApplilinkNetworkError localizedApplilinkErrorWithCode:kApplilinkErrorGeneric
                                                                 userInfo:response]);
        }
        failedBlock:^(id request, NSError *error) {
          /** @ghidraAddress 0x20d9dc */
          (void)request;
          (void)error;
          callback([ApplilinkNetworkError localizedApplilinkErrorWithCode:kApplilinkErrorGeneric]);
        }
        callback:callback];
}

+ (void)postDAUWithCallback:(void (^)(NSError *error))callback {
    if ([self getSendDauFlg]) {
        callback(nil);
        return;
    }

    NSString *userId = [ApplilinkConsts userId];
    NSDate *now = [NSDate date];
    [self postAnalysisDataWithActionType:kAnalysisActionTypeDau
        resultId:nil
        uesrId:userId
        finishedBlock:^(id request, id result) {
          /** @ghidraAddress 0x20dbfc */
          (void)request;
          NSDictionary *response = (NSDictionary *)result;
          if ([response[@"status"] boolValue] &&
              [response[@"error_code"] intValue] == kApplilinkResponseSuccessCode) {
              [[NSUserDefaults standardUserDefaults] setObject:now
                                                        forKey:kAnalysisDefaultsDauDateKey];
              [[NSUserDefaults standardUserDefaults] synchronize];
              callback(nil);
              return;
          }
          callback([ApplilinkNetworkError localizedApplilinkErrorWithCode:kApplilinkErrorGeneric
                                                                 userInfo:response]);
        }
        failedBlock:^(id request, NSError *error) {
          /** @ghidraAddress 0x20de04 */
          (void)request;
          (void)error;
          callback([ApplilinkNetworkError localizedApplilinkErrorWithCode:kApplilinkErrorGeneric]);
        }
        callback:callback];
}

#pragma mark - Result and user-ID registration

+ (void)postAnalysisDataWithResultId:(NSString *)resultId
                            callback:(void (^)(NSError *error))callback {
    if (resultId == nil) {
        callback([ApplilinkNetworkError
            localizedApplilinkErrorWithCode:kApplilinkErrorMissingParameter]);
        return;
    }

    NSString *userId = [ApplilinkConsts userId];
    [self postAnalysisDataWithActionType:kAnalysisActionTypeResult
        resultId:resultId
        uesrId:userId
        finishedBlock:^(id request, id result) {
          /** @ghidraAddress 0x20e018 */
          (void)request;
          NSDictionary *response = (NSDictionary *)result;
          if ([response[@"status"] boolValue] &&
              [response[@"error_code"] intValue] == kApplilinkResponseSuccessCode) {
              callback(nil);
              return;
          }
          callback([ApplilinkNetworkError localizedApplilinkErrorWithCode:kApplilinkErrorGeneric
                                                                 userInfo:response]);
        }
        failedBlock:^(id request, NSError *error) {
          /** @ghidraAddress 0x20e160 */
          (void)request;
          (void)error;
          callback([ApplilinkNetworkError localizedApplilinkErrorWithCode:kApplilinkErrorGeneric]);
        }
        callback:callback];
}

+ (void)postSetUserIDWithCallback:(void (^)(NSError *error))callback {
    NSString *userId = [ApplilinkConsts userId];
    if (userId == nil) {
        callback([ApplilinkNetworkError
            localizedApplilinkErrorWithCode:kApplilinkErrorMissingParameter]);
        return;
    }

    [self postAnalysisDataWithActionType:kAnalysisActionTypeSetUserID
        resultId:nil
        uesrId:userId
        finishedBlock:^(id request, id result) {
          /** @ghidraAddress 0x20e358 */
          (void)request;
          NSDictionary *response = (NSDictionary *)result;
          if ([response[@"status"] boolValue] &&
              [response[@"error_code"] intValue] == kApplilinkResponseSuccessCode) {
              callback(nil);
              return;
          }
          callback([ApplilinkNetworkError localizedApplilinkErrorWithCode:kApplilinkErrorGeneric
                                                                 userInfo:response]);
        }
        failedBlock:^(id request, NSError *error) {
          /** @ghidraAddress 0x20e4a0 */
          (void)request;
          (void)error;
          callback([ApplilinkNetworkError localizedApplilinkErrorWithCode:kApplilinkErrorGeneric]);
        }
        callback:callback];
}

#pragma mark - Impression and click registration

+ (void)postAnalysisListRegistWithAdType:(NSString *)adType
                                 adModel:(NSString *)adModel
                              adLocation:(NSString *)adLocation
                            impressionId:(NSString *)impressionId
                             appliIdList:(NSArray *)appliIdList
                          creativeIdList:(NSArray *)creativeIdList
                       incentiveTypeList:(NSArray *)incentiveTypeList
                          installFlgList:(NSArray *)installFlgList
                                callback:(void (^)(NSError *error))callback {
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithCapacity:9];
    if (adLocation == nil) {
        callback([ApplilinkNetworkError
            localizedApplilinkErrorWithCode:kApplilinkErrorMissingParameter]);
        return;
    }
    parameters[kAnalysisParamAdLocation] = adLocation;

    if (impressionId == nil) {
        callback([ApplilinkNetworkError
            localizedApplilinkErrorWithCode:kApplilinkErrorMissingParameter]);
        return;
    }
    parameters[kAnalysisParamImpressionId] = impressionId;
    parameters[kAnalysisParamSystem] = kAnalysisSystemValueAd;
    if (adType) {
        parameters[kAnalysisParamAdType] = adType;
    }
    if (adModel) {
        parameters[kAnalysisParamAdModel] = adModel;
    }

    if (appliIdList.count != 0 && creativeIdList.count != 0 && incentiveTypeList.count != 0 &&
        installFlgList.count != 0) {
        parameters[kAnalysisParamAppliIdToList] = appliIdList;
        parameters[kAnalysisParamCreativeIdList] = creativeIdList;
        parameters[kAnalysisParamIncentiveTypeList] = incentiveTypeList;
        parameters[kAnalysisParamInstallFlgList] = installFlgList;
    }

    NSString *url = [[ApplilinkConsts baseUrlSsl] stringByAppendingString:kAnalysisPathListRegist];
    [ApplilinkWebAPI requestAsynchronousWithURL:url
        method:@"POST"
        parameters:parameters
        userInfo:nil
        tag:0
        cachePolicy:nil
        timeout:kAnalysisRequestTimeout
        retry:NO
        finishedBlock:^(id request, id result) {
          /** @ghidraAddress 0x20ed64 */
          (void)request;
          NSDictionary *response = (NSDictionary *)result;
          if ([response[@"status"] boolValue] &&
              [response[@"error_code"] intValue] == kApplilinkResponseSuccessCode) {
              callback(nil);
              return;
          }
          callback([ApplilinkNetworkError localizedApplilinkErrorWithCode:kApplilinkErrorGeneric
                                                                 userInfo:response]);
        }
        failedBlock:^(id request, NSError *error) {
          /** @ghidraAddress 0x20eeac */
          (void)request;
          (void)error;
          callback([ApplilinkNetworkError localizedApplilinkErrorWithCode:kApplilinkErrorGeneric]);
        }];
}

+ (void)postAnalysisClickRegistWithAdType:(NSString *)adType
                                  adModel:(NSString *)adModel
                               adLocation:(NSString *)adLocation
                             impressionId:(NSString *)impressionId
                                appliIdTo:(NSString *)appliIdTo
                               creativeId:(NSString *)creativeId
                            displayNumber:(NSString *)displayNumber
                            incentiveType:(NSString *)incentiveType
                               installFlg:(NSString *)installFlg
                                 callback:(void (^)(NSError *error))callback {
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithCapacity:9];
    if (adLocation == nil) {
        callback([ApplilinkNetworkError
            localizedApplilinkErrorWithCode:kApplilinkErrorMissingParameter]);
        return;
    }
    parameters[kAnalysisParamAdLocation] = adLocation;

    if (impressionId == nil) {
        callback([ApplilinkNetworkError
            localizedApplilinkErrorWithCode:kApplilinkErrorMissingParameter]);
        return;
    }
    parameters[kAnalysisParamImpressionId] = impressionId;

    if (appliIdTo == nil) {
        callback([ApplilinkNetworkError
            localizedApplilinkErrorWithCode:kApplilinkErrorMissingParameter]);
        return;
    }
    parameters[kAnalysisParamAppliIdTo] = appliIdTo;

    if (creativeId == nil) {
        callback([ApplilinkNetworkError
            localizedApplilinkErrorWithCode:kApplilinkErrorMissingParameter]);
        return;
    }
    parameters[kAnalysisParamCreativeId] = creativeId;

    if (displayNumber == nil) {
        callback([ApplilinkNetworkError
            localizedApplilinkErrorWithCode:kApplilinkErrorMissingParameter]);
        return;
    }
    parameters[kAnalysisParamDisplayNumber] = displayNumber;

    if (incentiveType == nil) {
        callback([ApplilinkNetworkError
            localizedApplilinkErrorWithCode:kApplilinkErrorMissingParameter]);
        return;
    }
    parameters[kAnalysisParamIncentiveType] = incentiveType;

    if (installFlg == nil) {
        callback([ApplilinkNetworkError
            localizedApplilinkErrorWithCode:kApplilinkErrorMissingParameter]);
        return;
    }
    parameters[kAnalysisParamInstallFlg] = installFlg;

    parameters[kAnalysisParamSystem] = kAnalysisSystemValueAd;
    if (adType) {
        parameters[kAnalysisParamAdType] = adType;
    }
    if (adModel) {
        parameters[kAnalysisParamAdModel] = adModel;
    }

    NSString *url = [[ApplilinkConsts baseUrlSsl] stringByAppendingString:kAnalysisPathClickRegist];
    [ApplilinkWebAPI requestAsynchronousWithURL:url
        method:@"POST"
        parameters:parameters
        userInfo:nil
        tag:0
        cachePolicy:nil
        timeout:kAnalysisRequestTimeout
        retry:NO
        finishedBlock:^(id request, id result) {
          /** @ghidraAddress 0x20f40c */
          (void)request;
          NSDictionary *response = (NSDictionary *)result;
          if ([response[@"status"] boolValue] &&
              [response[@"error_code"] intValue] == kApplilinkResponseSuccessCode) {
              callback(nil);
              return;
          }
          callback([ApplilinkNetworkError localizedApplilinkErrorWithCode:kApplilinkErrorGeneric
                                                                 userInfo:response]);
        }
        failedBlock:^(id request, NSError *error) {
          /** @ghidraAddress 0x20f554 */
          (void)request;
          (void)error;
          callback([ApplilinkNetworkError localizedApplilinkErrorWithCode:kApplilinkErrorGeneric]);
        }];
}

#pragma mark - Convenience

+ (void)postAnalysisDataWithCallback:(void (^)(NSError *error))callback {
    [self postInitalizeWithCallback:^(NSError *initError) {
      /** @ghidraAddress 0x20f870 */
      [self postDAUWithCallback:^(NSError *dauError) {
        /** @ghidraAddress 0x20f920 */
        // Forward the initialisation error when it occurred, otherwise the DAU error.
        callback(initError ? initError : dauError);
      }];
    }];
}

#pragma mark - Marker clearing

+ (void)clearInitalize {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kAnalysisDefaultsInitalizeKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (void)clearDAU {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kAnalysisDefaultsDauDateKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end
