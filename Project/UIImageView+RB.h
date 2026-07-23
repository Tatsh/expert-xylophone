/** @file
 * @c UIImageView flash-effect helpers used by the menu buttons. A flash effect fades the image
 * view in and out on a repeating animation to advertise unseen content; removing it stops the
 * animation.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (category @c UIImageView(RB), image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base. This is a speculative
 * header declaring only the members its callers currently need; the full category is reconstructed
 * elsewhere.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Flash-effect helpers layered on @c UIImageView.
 */
@interface UIImageView (RB)

/**
 * @brief Start the fast repeating flash animation on the receiver.
 * @ghidraAddress 0x41830a
 */
- (void)SetFlashEffectFast;

/**
 * @brief Stop the flash animation on the receiver.
 * @ghidraAddress 0x1a3760
 */
- (void)RemoveFlashEffect;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
