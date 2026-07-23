/** @file
 * Reconstructed interface for the Applilink reward SDK's @c RewardWebAPI transport.
 *
 * @c RewardWebAPI is the reward network's high-level web API. Every method builds a parameter
 * dictionary and dispatches a single asynchronous request through
 * @c ApplilinkWebAPI @c +requestAsynchronousWithURL:method:parameters:userInfo:tag:cachePolicy:
 * timeout:retry:finishedBlock:failedBlock:, against a @c "/reward/..." path appended to
 * @c ApplilinkConsts.baseUrlSsl, with a ten-second timeout and no retry. Each request pairs a
 * finished handler that validates the JSON response (an @c NSDictionary with @c status true and
 * @c error_code equal to the success sentinel) and forwards the outcome to the caller's callback,
 * with a failed handler that forwards the transport error. The class is stateless: it has no
 * instance state and exposes only class methods. Reconstructed from Ghidra project rb458, program
 * rb458.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Reward network high-level web API.
 */
@interface RewardWebAPI : NSObject

/**
 * @brief Post the application-install event at a priority.
 *
 * Builds the @c appli_id and UDID parameters, signs them, and posts to
 * @c /reward/app/install/regist.php. On a successful response the priority-@c 0 path retries at
 * priority @c 1 when three-kind UDIDs are present, persists the campaign flag, promotes the current
 * UDID to the old UDID, and updates the pasteboard.
 * @param priority The request priority; @c 0 is a normal install, @c 1 the three-kind retry, and
 * @c 2 the pasteboard path.
 * @param callback Invoked with an error, or @c nil on success.
 * @ghidraAddress 0x223990
 */
+ (void)postApplicationInstallWithPriority:(int)priority
                                  callback:(nullable void (^)(NSError *_Nullable error))callback;

/**
 * @brief Check whether the reward login session is still valid.
 *
 * When a reward login is not needed the callback is invoked immediately with @c NO and no error;
 * otherwise it queries @c /reward/auth/checkLoginStatus.php and reports the @c login_status flag.
 * @param block Invoked with whether the session is valid and an optional error.
 * @ghidraAddress 0x224188
 */
+ (void)checkLoginWithBlock:(nullable void (^)(BOOL valid, NSError *_Nullable error))block;

/**
 * @brief Start a reward login for a user identifier at a priority.
 *
 * Builds the @c user_id and UDID parameters, signs them, and posts to @c /reward/auth/login.php. On
 * a successful response the priority-@c 0 path retries at priority @c 1 when three-kind UDIDs are
 * present, and the priority-@c 2 path retries at priority @c 2.
 * @param userId The Applilink user identifier.
 * @param priority The request priority; @c 1 is an interactive login.
 * @param callback Invoked with an error, or @c nil on success.
 * @ghidraAddress 0x22456c
 */
+ (void)startLoginWithUserId:(nullable NSString *)userId
                withPriority:(int)priority
                    callback:(nullable void (^)(NSError *_Nullable error))callback;

/**
 * @brief Fetch the advertisable application list for a campaign at an offset.
 *
 * Requests the JSON-format @c /reward/app/index.php list. The shipped build sends only the
 * @c format parameter and ignores @p campaignId, @p company, @p offset, and @p limit.
 * @param campaignId The campaign identifier.
 * @param company The company identifier.
 * @param offset The paging offset.
 * @param limit The paging limit.
 * @param callback Invoked with the response dictionary and an optional error.
 * @ghidraAddress 0x224d00
 */
+ (void)appListWithCampaignId:(nullable NSString *)campaignId
                    inCompany:(nullable NSString *)company
                       offset:(nullable NSString *)offset
                        limit:(nullable NSString *)limit
                     callback:(nullable void (^)(NSDictionary *_Nullable result,
                                                 NSError *_Nullable error))callback;

/**
 * @brief Fetch the advertisable application-identifier list for a list type.
 *
 * Queries @c /reward/app/install/appliid/index.php with the @c type parameter.
 * @param type The list type; @c 1 requests every identifier, @c 2 the install-post list.
 * @param callback Invoked with the response dictionary and an optional error.
 * @ghidraAddress 0x2250c4
 */
+ (void)appliIdListWithType:(int)type
                   callback:(nullable void (^)(NSDictionary *_Nullable result,
                                               NSError *_Nullable error))callback;

/**
 * @brief Fetch the all-install flag.
 *
 * Queries the JSON-format @c /reward/app/checkAllInstall.php; on success caches the flag under
 * @c appInstallFlg and reports it, or @c -1 when the flag is absent.
 * @param callback Invoked with the flag and an optional error.
 * @ghidraAddress 0x225490
 */
+ (void)allInstallFlgWithCallback:(nullable void (^)(NSInteger flg,
                                                     NSError *_Nullable error))callback;

/**
 * @brief Fetch the pre-info display flag.
 *
 * Queries the JSON-format @c /reward/app/preInfoForDisplay.php; on success caches the flag under
 * @c appInstallFlg and reports it, or @c -1 when the flag is absent.
 * @param callback Invoked with the flag and an optional error.
 * @ghidraAddress 0x225a0c
 */
+ (void)getPreInfoWithCallback:(nullable void (^)(NSInteger flg, NSError *_Nullable error))callback;

/**
 * @brief Post the list of installed companion applications to the reward network.
 *
 * Posts up to the first ten identifiers to @c /reward/app/install/report/regist.php; on success any
 * remaining identifiers are posted recursively.
 * @param appliList The installed application identifiers.
 * @param callback Invoked with an error, or @c nil on success.
 * @ghidraAddress 0x225f58
 */
+ (void)postAppliInstallReportWithAppliList:(nullable NSArray *)appliList
                                   callback:(nullable void (^)(NSError *_Nullable error))callback;

/**
 * @brief Fetch the reward banner info.
 *
 * Queries @c /reward/banner/detail.php with the user-agent parameters.
 * @param block Invoked with the banner info dictionary and an optional error.
 * @ghidraAddress 0x2264ac
 */
+ (void)bannerInfoWithBlock:(nullable void (^)(NSDictionary *_Nullable result,
                                               NSError *_Nullable error))block;

/**
 * @brief Sign a parameter dictionary in place.
 *
 * Sorts the keys case-insensitively, joins each @c key=value pair (expanding array values into
 * repeated pairs), appends the @c ApplilinkCore.signatureKey, takes the SHA-256 of the
 * URL-decoded joined string, and stores it under the @c signature key.
 * @param parameters The mutable parameter dictionary to sign.
 * @ghidraAddress 0x226834
 */
+ (void)setSignatureWithParameters:(nullable NSMutableDictionary *)parameters;

/**
 * @brief Store a keyed-archived value in @c NSUserDefaults with an expiry.
 * @param key The user-defaults key.
 * @param value The value to archive.
 * @param expiration The lifetime, in seconds, from now; @c 0 stores a one-second lifetime.
 * @ghidraAddress 0x226cdc
 */
+ (void)setTemporaryCacheWithKey:(nullable NSString *)key
                           value:(nullable id)value
                      expiration:(NSInteger)expiration;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
