/** @file
 * Reconstructed interface for the Applilink recommend advert SDK's
 * @c RecommendFullScreenController.
 *
 * @c RecommendFullScreenController is the full-screen (interstitial) advert view controller the
 * @c RecommendCore singleton presents. It lays a transparent shade view over the whole screen,
 * hosts an advert base view sized for the current interface orientation, and — once the advert
 * area's HTML body has been cached by @c RecommendAdCache — spawns a @c RecommendAdAreaView on the
 * main queue to render and drive the advert. It reports the advert lifecycle (did start, did
 * appear, did disappear, and the load and link failures) back to its advert delegate through
 * @c ApplilinkCore, and asks its full-view delegate (the presenting @c RecommendCore) to release
 * it when the advert closes. The Applilink SDK ships as a closed third-party library; this
 * interface is recovered in full from the class metadata. Reconstructed from Ghidra project rb458,
 * program rb458.
 */

#import <UIKit/UIKit.h>

@class ApplilinkParameters;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The Applilink recommend full-screen (interstitial) advert view controller.
 * @ghidraAddress 0x3bdef8
 */
@interface RecommendFullScreenController : UIViewController

/**
 * @brief Whether the interstitial advert is currently on screen.
 */
@property(nonatomic, assign) BOOL isVisible;

/**
 * @brief Open the full-screen advert view.
 * @param adModel The advert-model identifier.
 * @param adLocation The advert-location identifier.
 * @param verticalAlign The vertical-alignment identifier.
 * @param applilinkParams The advert request parameters, echoed back on failure.
 * @param delegate The advert delegate to notify of the advert lifecycle.
 * @param closeDelegate The full-view delegate asked to release this controller on close.
 * @ghidraAddress 0x246970
 */
- (void)openAdViewWithAdModel:(int)adModel
                   adLocation:(nullable NSString *)adLocation
                verticalAlign:(int)verticalAlign
              applilinkParams:(nullable ApplilinkParameters *)applilinkParams
                     delegate:(nullable id)delegate
                closeDelegate:(nullable id)closeDelegate;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
