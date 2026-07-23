/** @file
 * Minimal reconstructed interface for the Applilink recommend SDK's @c RecommendWebView.
 *
 * The Applilink SDK ships as a closed third-party library. @c RecommendNetwork only needs the
 * class itself, for @c isKindOfClass: subview matching. Reconstructed from Ghidra project rb458,
 * program rb458.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The Applilink recommend advert web view.
 */
@interface RecommendWebView : UIView

/**
 * @brief Load the advert web content for an advert model at an ad location.
 * @param adModel The advert-model identifier.
 * @param adLocation The ad-location identifier.
 * @param verticalAlign The vertical-alignment identifier.
 * @param requestCode The caller's request code.
 * @param delegate The advert delegate.
 */
- (void)loadRequestWithAdModel:(int)adModel
                    adLocation:(nullable NSString *)adLocation
                 verticalAlign:(int)verticalAlign
                   requestCode:(nullable id)requestCode
                      delegate:(nullable id)delegate;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
