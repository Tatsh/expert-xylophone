/** @file
 * A rounded store action button with a configurable fill colour and a distinct disabled colour.
 *
 * Minimal stub for the surface @c RBCampaignDetailViewController messages; the full class is
 * reconstructed separately. Reconstructed from Ghidra project rb458, program rb458 (class
 * @c StoreButtonView, image base 0x100000000).
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A rounded store action button.
 */
@interface StoreButtonView : UIButton

/**
 * @brief Sets the button's enabled fill colour.
 * @param buttonColor The fill colour.
 */
- (void)setButtonColor:(nullable UIColor *)buttonColor;
/**
 * @brief Sets the button's disabled fill colour.
 * @param disabledColor The disabled fill colour.
 */
- (void)setDisabledColor:(nullable UIColor *)disabledColor;
/**
 * @brief Sets the button's corner radius.
 * @param cornerRadius The corner radius, in points.
 */
- (void)setCornerRadius:(CGFloat)cornerRadius;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
