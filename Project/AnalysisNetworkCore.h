/** @file
 * Reconstructed interface for the Applilink advert SDK's @c AnalysisNetworkCore.
 *
 * @c AnalysisNetworkCore is the advert-analytics core of the Applilink SDK: a stateless class
 * (no ivars, only class methods) that posts analytics events to the Applilink server. It handles
 * install/initialisation registration, daily-active-user (DAU) measurement, user-ID registration,
 * generic action-data posting, and advert impression (list) and click registrations. Success is
 * persisted to @c NSUserDefaults under the @c ApplilinkAnalysis.initialize and
 * @c ApplilinkAnalysis.dauMeasurementDate keys. Reconstructed from Ghidra project rb458, program
 * rb458.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The Applilink advert SDK's advert-analytics core.
 *
 * All members are class methods; the class holds no state of its own and persists its markers to
 * @c NSUserDefaults.
 */
@interface AnalysisNetworkCore : NSObject

/**
 * @brief Whether the analytics-initialisation marker has been persisted.
 * @return @c YES when the @c ApplilinkAnalysis.initialize key exists in @c NSUserDefaults.
 * @ghidraAddress 0x20f5c4
 */
+ (BOOL)getInitalizeFlg;

/**
 * @brief Whether daily-active-user measurement has already been sent today.
 * @return @c YES when the persisted @c ApplilinkAnalysis.dauMeasurementDate is the same calendar day
 * as now.
 * @ghidraAddress 0x20f640
 */
+ (BOOL)getSendDauFlg;

/**
 * @brief Post a generic analytics action to the server.
 *
 * Builds the request parameters (action type, optional result and user identifiers, and the UDID
 * source), merges the user-agent parameters, and posts them to @c /analysis/regist.php. The method
 * name preserves the binary's @c uesrId misspelling.
 * @param actionType The analytics action-type code (for example @c 1 for initialisation, @c 2 for
 * DAU, @c 3 for a result, or @c 14 for a user-ID registration).
 * @param resultId The optional result identifier.
 * @param uesrId The optional user identifier, URL-encoded before sending.
 * @param finishedBlock The block invoked with the server response on success.
 * @param failedBlock The block invoked with the request and error on failure.
 * @param callback The completion callback invoked with an error, or @c nil on success.
 * @ghidraAddress 0x20e510
 */
+ (void)postAnalysisDataWithActionType:(int)actionType
                              resultId:(nullable NSString *)resultId
                                uesrId:(nullable NSString *)uesrId
                         finishedBlock:(nullable void (^)(id _Nullable request,
                                                          id _Nullable result))finishedBlock
                           failedBlock:(nullable void (^)(id _Nullable request,
                                                          NSError *_Nullable error))failedBlock
                              callback:(nullable void (^)(NSError *_Nullable error))callback;

/**
 * @brief Post the install/initialisation registration if it has not yet succeeded.
 *
 * When @c getInitalizeFlg is already set, the callback is invoked immediately with @c nil.
 * Otherwise an initialisation action (type @c 1) is posted, capturing the current date; on success
 * the @c ApplilinkAnalysis.initialize marker is persisted. The method name preserves the binary's
 * misspelling.
 * @param callback The completion callback invoked with an error, or @c nil on success.
 * @ghidraAddress 0x20d650
 */
+ (void)postInitalizeWithCallback:(nullable void (^)(NSError *_Nullable error))callback;

/**
 * @brief Post the daily-active-user measurement if it has not yet been sent today.
 *
 * When @c getSendDauFlg is already set, the callback is invoked immediately with @c nil. Otherwise
 * a DAU action (type @c 2) is posted for the current @c ApplilinkConsts userId, capturing the
 * current date; on success the @c ApplilinkAnalysis.dauMeasurementDate marker is persisted.
 * @param callback The completion callback invoked with an error, or @c nil on success.
 * @ghidraAddress 0x20da4c
 */
+ (void)postDAUWithCallback:(nullable void (^)(NSError *_Nullable error))callback;

/**
 * @brief Post a result registration for the given result identifier.
 *
 * When @p resultId is @c nil, the callback is invoked with error code @c 1001. Otherwise a result
 * action (type @c 3) is posted for the current @c ApplilinkConsts userId.
 * @param resultId The result identifier.
 * @param callback The completion callback invoked with an error, or @c nil on success.
 * @ghidraAddress 0x20de74
 */
+ (void)postAnalysisDataWithResultId:(nullable NSString *)resultId
                            callback:(nullable void (^)(NSError *_Nullable error))callback;

/**
 * @brief Post the user-ID registration.
 *
 * When @c ApplilinkConsts userId is @c nil, the callback is invoked with error code @c 1001.
 * Otherwise a user-ID action (type @c 14) is posted.
 * @param callback The completion callback invoked with an error, or @c nil on success.
 * @ghidraAddress 0x20e1d0
 */
+ (void)postSetUserIDWithCallback:(nullable void (^)(NSError *_Nullable error))callback;

/**
 * @brief Register an impression list for the displayed adverts.
 *
 * Posts to @c /analysis/list/regist.php. When @p adLocation or @p impressionId is @c nil the
 * callback is invoked with error code @c 1001. The four list parameters are only sent when all of
 * them are non-empty.
 * @param adType The advert-type string.
 * @param adModel The advert-model string.
 * @param adLocation The advert-location identifier.
 * @param impressionId The impression identifier.
 * @param appliIdList The advert application identifiers.
 * @param creativeIdList The advert creative identifiers.
 * @param incentiveTypeList The incentive-type strings.
 * @param installFlgList The install-flag strings.
 * @param callback The completion callback invoked with an error, or @c nil on success.
 * @ghidraAddress 0x20e8f8
 */
+ (void)postAnalysisListRegistWithAdType:(nullable NSString *)adType
                                 adModel:(nullable NSString *)adModel
                              adLocation:(nullable NSString *)adLocation
                            impressionId:(nullable NSString *)impressionId
                             appliIdList:(nullable NSArray *)appliIdList
                          creativeIdList:(nullable NSArray *)creativeIdList
                       incentiveTypeList:(nullable NSArray *)incentiveTypeList
                          installFlgList:(nullable NSArray *)installFlgList
                                callback:(nullable void (^)(NSError *_Nullable error))callback;

/**
 * @brief Register a click for a displayed advert.
 *
 * Posts to @c /analysis/click/regist.php. When any of @p adLocation, @p impressionId, @p appliIdTo,
 * @p creativeId, @p displayNumber, @p incentiveType, or @p installFlg is @c nil the callback is
 * invoked with error code @c 1001.
 * @param adType The advert-type string.
 * @param adModel The advert-model string.
 * @param adLocation The advert-location identifier.
 * @param impressionId The impression identifier.
 * @param appliIdTo The destination advert application identifier.
 * @param creativeId The advert creative identifier.
 * @param displayNumber The advert display-number string.
 * @param incentiveType The incentive-type string.
 * @param installFlg The install-flag string.
 * @param callback The completion callback invoked with an error, or @c nil on success.
 * @ghidraAddress 0x20ef1c
 */
+ (void)postAnalysisClickRegistWithAdType:(nullable NSString *)adType
                                  adModel:(nullable NSString *)adModel
                               adLocation:(nullable NSString *)adLocation
                             impressionId:(nullable NSString *)impressionId
                                appliIdTo:(nullable NSString *)appliIdTo
                               creativeId:(nullable NSString *)creativeId
                            displayNumber:(nullable NSString *)displayNumber
                            incentiveType:(nullable NSString *)incentiveType
                               installFlg:(nullable NSString *)installFlg
                                 callback:(nullable void (^)(NSError *_Nullable error))callback;

/**
 * @brief Post the queued advert-analysis data to the analytics server.
 *
 * Runs the install/initialisation registration and then the daily-active-user measurement in
 * sequence. The callback receives the initialisation error when one occurred, otherwise the DAU
 * error (or @c nil when both succeeded).
 * @param callback The completion callback invoked with an error, or @c nil on success.
 * @ghidraAddress 0x20f7d8
 */
+ (void)postAnalysisDataWithCallback:(nullable void (^)(NSError *_Nullable error))callback;

/**
 * @brief Clear the persisted analytics-initialisation marker.
 *
 * Removes the @c ApplilinkAnalysis.initialize key from @c NSUserDefaults and synchronises. The
 * method name preserves the binary's misspelling.
 * @ghidraAddress 0x20f9f0
 */
+ (void)clearInitalize;

/**
 * @brief Clear the persisted daily-active-user measurement date.
 *
 * Removes the @c ApplilinkAnalysis.dauMeasurementDate key from @c NSUserDefaults and synchronises.
 * @ghidraAddress 0x20fa84
 */
+ (void)clearDAU;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
