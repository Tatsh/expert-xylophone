/** @file
 * Minimal reconstructed interface for the Applilink recommend SDK's @c ApplilinkCore.
 *
 * The Applilink SDK ships as a closed third-party library, so only the class methods that
 * @c RecommendNetwork messages are declared here. Reconstructed from Ghidra project rb458, program
 * rb458.
 */

#import <UIKit/UIKit.h>

#import "ApplilinkParameters.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The Applilink SDK's core entry point.
 */
@interface ApplilinkCore : NSObject

/**
 * @brief The SDK's main window, used as a fallback advert host.
 * @return The SDK main window.
 */
+ (nullable UIWindow *)mainWindow;

/**
 * @brief Whether the SDK's initialisation-status flag is set.
 * @return @c YES when the SDK has finished initialising.
 */
+ (BOOL)isInitializeStatusFlg;

/**
 * @brief Report an open failure back to a delegate with the given error and request parameters.
 * @param error The localised failure error.
 * @param appParam The request parameters the open was attempted with.
 * @param delegate The advert delegate to notify.
 */
+ (void)toDelegateFailOpenWithError:(nullable NSError *)error
                           appParam:(nullable ApplilinkParameters *)appParam
                           delegate:(nullable id)delegate;

/**
 * @brief The device advertising UDID cached in the SDK core.
 * @return The advertising UDID, or @c nil.
 * @ghidraAddress 0x2153a0
 */
+ (nullable NSString *)ad_udid;

/**
 * @brief The current UDID cached in the SDK core.
 * @return The current UDID, or @c nil.
 * @ghidraAddress 0x2150ec
 */
+ (nullable NSString *)udid;

/**
 * @brief The old UDID cached in the SDK core.
 * @return The old UDID, or @c nil.
 * @ghidraAddress 0x21558c
 */
+ (nullable NSString *)old_udid;

/**
 * @brief The pasteboard UDID cached in the SDK core.
 * @return The pasteboard UDID, or @c nil.
 * @ghidraAddress 0x215260
 */
+ (nullable NSString *)pasteBoard_udid;

/**
 * @brief Store the advertising UDID in the SDK core.
 * @param adUdid The advertising UDID to store.
 * @ghidraAddress 0x2157f8
 */
+ (void)setAdUdid:(nullable NSString *)adUdid;

/**
 * @brief Reset the SDK core's cached initialisation state.
 * @ghidraAddress 0x215a90
 */
+ (void)clearInitialize;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
