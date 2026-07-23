/** @file
 * Minimal reconstructed interface for the Applilink recommend SDK's @c RecommendWebAPI.
 *
 * @c RecommendWebAPI is the recommend network's high-level web-API facade: it wraps the recommend
 * server endpoints (login, session, banner detail, unread count, pre-info, ad detail, application
 * install, and installed-application list) behind callback-based class methods. The Applilink SDK
 * ships as a closed third-party library, so only the class methods that @c RecommendCore messages
 * are declared here. Reconstructed from Ghidra project rb458, program rb458.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The recommend network's web-API facade.
 */
@interface RecommendWebAPI : NSObject

/**
 * @brief Fetch the installed-application list.
 * @param callback The completion callback invoked with the list and an error.
 */
+ (void)installAppliListWithCallBack:(nullable void (^)(id _Nullable list,
                                                        NSError *_Nullable error))callback;

/**
 * @brief Fetch the advert-detail table.
 * @param callback The completion callback invoked with an error.
 */
+ (void)getAdDetailWithCallback:(nullable void (^)(NSError *_Nullable error))callback;

/**
 * @brief Post the application-install record for the current advertising identifier.
 * @param adIdFrom The source advertising identifier.
 * @param categoryId The advert category identifier.
 * @param adType The advert-type string.
 * @param priority The install priority.
 * @param callback The completion callback invoked with an error.
 */
+ (void)postApplicationInstallWithAdIdFrom:(nullable NSString *)adIdFrom
                                categoryId:(nullable NSString *)categoryId
                                    adType:(nullable NSString *)adType
                                  priority:(int)priority
                                  callback:(nullable void (^)(NSError *_Nullable error))callback;

/**
 * @brief Check whether the recommend session is still logged in.
 * @param callback The completion callback invoked with the login state and an error.
 */
+ (void)checkLoginWithCallback:(nullable void (^)(BOOL loggedIn, NSError *_Nullable error))callback;

/**
 * @brief Start a recommend login.
 * @param callback The completion callback invoked with an error.
 */
+ (void)startLoginWithCallback:(nullable void (^)(NSError *_Nullable error))callback;

/**
 * @brief Fetch the banner detail for an advert model.
 * @param adModel The advert-model identifier.
 * @param callback The status callback invoked with the status and an error.
 */
+ (void)getBannerDetailWithAdModel:(int)adModel
                          callback:(nullable void (^)(NSInteger status,
                                                      NSError *_Nullable error))callback;

/**
 * @brief Fetch the unread advert count for an advert model at an ad location.
 * @param adModel The advert-model identifier.
 * @param adLocation The ad-location identifier.
 * @param callback The status callback invoked with the count and an error.
 */
+ (void)getUnreadCountWithAdModel:(int)adModel
                       adLocation:(nullable NSString *)adLocation
                         callback:(nullable void (^)(NSInteger status,
                                                     NSError *_Nullable error))callback;

/**
 * @brief Fetch the pre-info display status for an advert model at an ad location.
 * @param adModel The advert-model identifier.
 * @param adLocation The ad-location identifier.
 * @param callback The status callback invoked with the status dictionary and an error.
 */
+ (void)getPreInfoWithAdModel:(int)adModel
                   adLocation:(nullable NSString *)adLocation
                     callback:(nullable void (^)(NSDictionary *_Nullable status,
                                                 NSError *_Nullable error))callback;

/**
 * @brief Build the click-registration request for a first-party advert.
 * @param adIdFrom The source advertising identifier.
 * @param adIdTo The destination advertising identifier.
 * @param adModel The advert-model identifier.
 * @return The click-registration request.
 */
+ (nullable NSURLRequest *)clickRegistWithAdIdFrom:(nullable NSString *)adIdFrom
                                            adIdTo:(nullable NSString *)adIdTo
                                           adModel:(int)adModel;

/**
 * @brief Build the application-start request for a first-party advert.
 * @param adIdFrom The source advertising identifier.
 * @param adIdTo The destination advertising identifier.
 * @param adType The advert-type identifier.
 * @return The application-start request.
 */
+ (nullable NSURLRequest *)appStartWithAdIdFrom:(nullable NSString *)adIdFrom
                                         adIdTo:(nullable NSString *)adIdTo
                                         adType:(int)adType;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
