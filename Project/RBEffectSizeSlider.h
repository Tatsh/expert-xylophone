/** @file
 * The explosion/effect-size slider control used by @c RBCustomSelectCollectionView. It shows a
 * numeric readout of the given digit count.
 *
 * Speculative interface: only the members @c RBCustomSelectCollectionView uses are declared here.
 * Reconstructed from Ghidra project rb458, program rb458 (class @c RBEffectSizeSlider, image base
 * 0x100000000).
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief An effect-size slider with a numeric readout.
 */
@interface RBEffectSizeSlider : UISlider

/**
 * @brief Create the slider with a numeric readout of the given digit count.
 * @param digit The number of digits to show in the readout.
 * @return The initialised slider, or @c nil.
 */
- (nullable instancetype)initWithDigit:(int)digit;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
