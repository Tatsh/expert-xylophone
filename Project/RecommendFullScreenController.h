/** @file
 * Minimal reconstructed interface for the Applilink recommend SDK's
 * @c RecommendFullScreenController.
 *
 * @c RecommendFullScreenController is the full-screen (interstitial) advert view controller that
 * @c RecommendCore presents. The Applilink SDK ships as a closed third-party library, so only the
 * members that @c RecommendCore messages are declared here. Reconstructed from Ghidra project
 * rb458, program rb458.
 */

#import <UIKit/UIKit.h>

@class ApplilinkParameters;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The Applilink recommend full-screen (interstitial) advert view controller.
 */
@interface RecommendFullScreenController : UIViewController

/**
 * @brief Whether the interstitial advert is currently visible.
 * @return @c YES when the advert is on screen.
 */
- (BOOL)isVisible;

/**
 * @brief Open the full-screen advert view.
 * @param adModel The advert-model identifier.
 * @param adLocation The ad-location identifier.
 * @param adType The advert-type identifier.
 * @param appParam The advert-request parameters.
 * @param delegate The advert delegate.
 */
- (void)openAdViewWithAdModel:(int)adModel
                   adLocation:(nullable NSString *)adLocation
                       adType:(int)adType
                     appParam:(nullable ApplilinkParameters *)appParam
                     delegate:(nullable id)delegate;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
