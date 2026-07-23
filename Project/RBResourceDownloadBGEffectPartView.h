/** @file
 * A single particle layer of the resource-download background effect. Its @c init seeds the three
 * artwork paths that its @c RBMenuBGEffectPartView base animates.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class
 * @c RBResourceDownloadBGEffectPartView, image base 0x100000000). The subclass adds no ivars or
 * properties and overrides only @c init.
 */

#import "RBMenuBGEffectPartView.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A particle layer for the resource-download background effect.
 */
@interface RBResourceDownloadBGEffectPartView : RBMenuBGEffectPartView

/**
 * @brief Initialise the layer and seed its three background artwork paths on the base class.
 * @return The initialised instance, or @c nil if the superclass initialiser failed.
 * @ghidraAddress 0x19aa0
 */
- (instancetype)init;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
