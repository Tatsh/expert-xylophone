/** @file
 * Minimal reconstructed interface for the Applilink recommend SDK's @c RecommendAdAreaView.
 *
 * The Applilink SDK ships as a closed third-party library. @c RecommendNetwork needs the class for
 * @c isKindOfClass: subview matching and the @c closeAdArea teardown message. Reconstructed from
 * Ghidra project rb458, program rb458.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The Applilink recommend advert area view.
 */
@interface RecommendAdAreaView : UIView

/**
 * @brief Configure the advert area with its advert model, location, type, request code, and
 * delegate.
 * @param adModel The advert-model identifier.
 * @param adLocation The ad-location identifier.
 * @param adType The advert-type identifier.
 * @param requestCode The caller's request code.
 * @param delegate The advert delegate.
 */
- (void)setAdModel:(int)adModel
        adLocation:(nullable NSString *)adLocation
            adType:(int)adType
       requestCode:(nullable id)requestCode
          delegate:(nullable id)delegate;

/**
 * @brief Load the advert-area contents from a filesystem path.
 * @param path The advert-content path.
 */
- (void)startPath:(nullable NSString *)path;

/**
 * @brief Tear down the advert area before the view is removed from its superview.
 */
- (void)closeAdArea;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
