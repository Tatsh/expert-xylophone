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

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
