/** @file
 * The animated particle background shown behind the resource-download flow for the wide font
 * variant. @c RBResourceDownloadViewController creates one, calls @c setupView to build its
 * particle layers, and drives it with @c startAnimation and @c stopAnimation.
 *
 * Speculative interface: only the members @c RBResourceDownloadViewController uses are declared
 * here. Reconstructed from Ghidra project rb458, program rb458 (class
 * @c RBResoureDownloadBGEffectView, image base 0x100000000; the "Resoure" misspelling is the
 * binary's own).
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Animated particle background for the resource-download screen.
 */
@interface RBResoureDownloadBGEffectView : UIView

/**
 * @brief Build the particle layers for the current bounds.
 */
- (void)setupView;
/**
 * @brief Start the particle animation.
 */
- (void)startAnimation;
/**
 * @brief Stop the particle animation.
 */
- (void)stopAnimation;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
