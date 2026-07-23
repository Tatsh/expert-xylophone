/** @file
 * Minimal reconstructed interface for the Applilink reward SDK's @c RewardWebAPI transport.
 *
 * @c RewardWebAPI is the reward network's high-level web API: it wraps the login, install-report,
 * app-list, all-install-flag, and banner-info endpoints. @c RewardCore is the only reconstructed
 * caller, so only the class methods it messages are declared here. Reconstructed from Ghidra
 * project rb458, program rb458.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Reward network high-level web API.
 */
@interface RewardWebAPI : NSObject

/**
 * @brief Check whether the reward login session is still valid.
 * @param block Invoked with whether the session is valid and an optional error.
 */
+ (void)checkLoginWithBlock:(nullable void (^)(BOOL valid, NSError *_Nullable error))block;

/**
 * @brief Start a reward login for a user identifier at a priority.
 * @param userId The Applilink user identifier.
 * @param priority The request priority; @c 1 is an interactive login.
 * @param callback Invoked with an error, or @c nil on success.
 */
+ (void)startLoginWithUserId:(nullable NSString *)userId
                withPriority:(int)priority
                    callback:(nullable void (^)(NSError *_Nullable error))callback;

/**
 * @brief Post the application-install event at a priority.
 * @param priority The request priority; @c 0 is a normal install, @c 2 is the pasteboard path.
 * @param callback Invoked with an error, or @c nil on success.
 */
+ (void)postApplicationInstallWithPriority:(int)priority
                                  callback:(nullable void (^)(NSError *_Nullable error))callback;

/**
 * @brief Post the list of installed companion applications to the reward network.
 * @param appliList The installed application identifiers.
 * @param callback Invoked with an error, or @c nil on success.
 */
+ (void)postAppliInstallReportWithAppliList:(nullable NSArray *)appliList
                                   callback:(nullable void (^)(NSError *_Nullable error))callback;

/**
 * @brief Fetch the advertisable application list for a list type.
 * @param type The list type; @c 1 requests every identifier, @c 2 the install-post list.
 * @param callback Invoked with the response dictionary and an optional error.
 */
+ (void)appliIdListWithType:(int)type
                   callback:(nullable void (^)(NSDictionary *_Nullable result,
                                               NSError *_Nullable error))callback;

/**
 * @brief Fetch the all-install flag.
 * @param callback Invoked with the flag and an optional error.
 */
+ (void)allInstallFlgWithCallback:(nullable void (^)(NSInteger flg,
                                                     NSError *_Nullable error))callback;

/**
 * @brief Fetch the reward banner info.
 * @param block Invoked with the banner info dictionary and an optional error.
 */
+ (void)bannerInfoWithBlock:(nullable void (^)(NSDictionary *_Nullable result,
                                               NSError *_Nullable error))block;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
