/** @file
 * Minimal reconstructed interface for the Applilink recommend SDK's @c ApplilinkConsts helper.
 *
 * The Applilink SDK ships as a closed third-party library, so only the class methods that
 * @c RecommendNetwork messages are declared here. Reconstructed from Ghidra project rb458, program
 * rb458.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Applilink SDK availability and request-gating helper.
 */
@interface ApplilinkConsts : NSObject

/**
 * @brief Whether the Applilink SDK may be used at all on this build and device.
 * @return @c YES when the SDK is usable.
 */
+ (BOOL)canUseApplilinkSdk;

/**
 * @brief Whether a specific advert request may proceed, given the SDK state and the caller's
 * parameters.
 * @param adModel The advert-model identifier.
 * @param adLocation The ad-location identifier.
 * @param verticalAlign The vertical-alignment identifier.
 * @param requestCode The caller's request code.
 * @param delegate The advert delegate.
 * @return @c YES when the request may proceed.
 */
+ (BOOL)checkUseSDKWithAdModel:(int)adModel
                    adLocation:(nullable NSString *)adLocation
                 verticalAlign:(int)verticalAlign
                   requestCode:(NSInteger)requestCode
                      delegate:(nullable id)delegate;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
