/** @file
 * @c UIImageView flash-effect helpers used by the menu and music-select buttons. A flash effect
 * adds a forever-repeating, auto-reversing opacity pulse to the receiver's layer (under the
 * @c "FLUSH_ANIM" animation key) to advertise unseen or selectable content; removing it strips that
 * animation. A "fast" convenience starts the pulse with a shorter period, and a default convenience
 * starts it with the standard period.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (category @c UIImageView(RB), image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 *
 * The category's methods are recorded in the binary's instance-method list and every caller
 * dispatches them to a @c UIImageView instance, so they are reconstructed as instance methods. The
 * selector spellings (@c SetFlashEffectFast, @c SetFlashEffectDuration:Start:End:, and
 * @c RemoveFlashEffect, all with a capital initial) are preserved verbatim from the binary.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Flash-effect helpers layered on @c UIImageView.
 */
@interface UIImageView (RB)

/**
 * @brief Start the fast repeating flash pulse on the receiver.
 *
 * Convenience that starts the opacity pulse with the shorter "fast" period; equivalent to
 * @c SetFlashEffectDuration:Start:End: with the fast duration and the standard full-to-dim opacity
 * endpoints.
 * @ghidraAddress 0x41830a
 */
- (void)SetFlashEffectFast;

/**
 * @brief Start the default repeating flash pulse on the receiver.
 *
 * Convenience that starts the opacity pulse with the standard period; equivalent to
 * @c SetFlashEffectDuration:Start:End: with the default duration, a start opacity of @c 1.0, and a
 * dimmed end opacity.
 * @ghidraAddress 0x1a3710
 */
- (void)StartDefaultFlashEffect;

/**
 * @brief Add a forever-repeating, auto-reversing opacity pulse to the receiver's layer.
 *
 * Installs a @c CABasicAnimation on the @c opacity key path under the @c "FLUSH_ANIM" key that
 * eases between @p start and @p end and holds its final value. The pulse auto-reverses and repeats
 * forever.
 * @param duration The one-way pulse duration, in seconds.
 * @param start The opacity at the start of each pulse.
 * @param end The opacity at the end of each pulse.
 * @ghidraAddress 0x41831d
 */
- (void)SetFlashEffectDuration:(CGFloat)duration Start:(CGFloat)start End:(CGFloat)end;

/**
 * @brief Stop the flash pulse on the receiver.
 *
 * Removes the @c "FLUSH_ANIM" animation from the receiver's layer.
 * @ghidraAddress 0x1a3760
 */
- (void)RemoveFlashEffect;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
