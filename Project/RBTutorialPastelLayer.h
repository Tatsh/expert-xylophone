/** @file
 * The pastel speech-bubble layer drawn beside the tutorial spotlight by @c RBMenuTutorialView.
 *
 * Speculative interface: only the members @c RBMenuTutorialView uses are declared here. The full
 * layer is reconstructed separately. Reconstructed from Ghidra project rb458, program rb458 (class
 * @c RBTutorialPastelLayer, image base 0x100000000).
 */

#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The tutorial pastel speech-bubble layer.
 */
@interface RBTutorialPastelLayer : CALayer

/**
 * @brief Configure the pastel bubble from the tutorial message artwork.
 * @param image The tutorial message artwork atlas.
 */
- (void)setupView:(nullable UIImage *)image;

/**
 * @brief Stop the pastel bubble's running animation.
 */
- (void)stopAnimation;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
