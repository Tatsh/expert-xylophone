/** @file
 * Reconstructed interface for the Applilink SDK's @c ApplilinkIndicator.
 *
 * @c ApplilinkIndicator is the Applilink advert SDK's loading indicator: a dimming @c UIView overlay
 * that hosts a large white @c UIActivityIndicatorView and is shown while an advert screen loads. It
 * keeps the spinner centred on layout, exposes @c -show and @c -close to start and stop the
 * animation, and @c -touchEventActived to turn the overlay transparent and non-interactive.
 * Reconstructed from Ghidra project rb458, program rb458.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The Applilink SDK's advert loading overlay.
 */
@interface ApplilinkIndicator : UIView

/**
 * @brief The activity indicator spinner shown at the centre of the overlay.
 * @ghidraAddress 0x220290
 */
@property(strong, nonatomic, nullable) UIActivityIndicatorView *indicator;

/**
 * @brief Initialise the overlay and its centred activity indicator for a frame.
 *
 * Creates a large white @c UIActivityIndicatorView, sets a black background at half opacity, and
 * adds the spinner as a subview.
 * @param frame The overlay's frame.
 * @return The initialised overlay, or @c nil.
 * @ghidraAddress 0x21ff40
 */
- (nullable instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief Show the overlay and start the spinner animating.
 * @ghidraAddress 0x220124
 */
- (void)show;

/**
 * @brief Hide the overlay, stop the spinner animating, and release it.
 * @ghidraAddress 0x22017c
 */
- (void)close;

/**
 * @brief Make the overlay transparent and non-interactive after a touch event.
 * @ghidraAddress 0x2201e0
 */
- (void)touchEventActived;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
