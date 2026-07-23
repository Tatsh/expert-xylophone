/** @file
 * @c UIView flash-effect machinery and frame-geometry conveniences used across the menu and
 * music-select screens. The flash machinery drives the forever-repeating, auto-reversing @c opacity
 * pulse (installed on the receiver's layer under the @c "FLUSH_ANIM" key) that advertises unseen or
 * selectable content: a plain single-pulse variant and a twelve-step multi-pulse variant that also
 * spins the layer through a full @c transform.rotation.z turn. Alongside it sit an @c "ALPHA_ANIM"
 * opacity transition, a @c "PopAnim" bounce (a keyframe path that overshoots then settles), and a
 * family of frame-derived getters (@c x, @c y, @c width, @c height, and the @c left / @c top /
 * @c right / @c bottom edges).
 *
 * Reconstructed from Ghidra project rb458, program rb458 (categories @c UIView(RB), image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 *
 * The flash overlay is managed by two @b class methods dispatched to the @c UIView class object
 * (@c setFlashEffectView:Duration:Start:End:Rotate: and @c removeFlashEffectView:); every other
 * method is recorded in the binary's instance-method list and dispatches to a @c UIView instance, so
 * those are reconstructed as instance methods. All selector spellings (including the mixed-case
 * @c SetFlashEffect… and @c SetJumpEffect… names) are preserved verbatim from the binary.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Flash-effect, alpha-transition, bounce, and frame-geometry helpers layered on @c UIView.
 */
@interface UIView (RB)

/**
 * @brief Install the @c "FLUSH_ANIM" flash animation on a view's layer.
 *
 * Removes any existing flash overlay first, then adds one of two animations under the
 * @c "FLUSH_ANIM" key. When @p rotate is @c NO it adds a single auto-reversing, forever-repeating
 * @c CABasicAnimation on @c opacity easing from @p start to @p end. When @p rotate is @c YES it
 * builds a twelve-step @c CAAnimationGroup that pulses the opacity with staggered begin times and
 * alternating timing curves while simultaneously spinning the layer through a full @c 2π
 * @c transform.rotation.z turn.
 * @param view The view whose layer receives the animation.
 * @param duration The overall pulse duration, in seconds.
 * @param start The opacity at the start of the pulse.
 * @param end The opacity at the end of the pulse.
 * @param rotate Whether to use the multi-pulse-plus-rotation group animation.
 * @ghidraAddress 0x1a376c
 */
+ (void)setFlashEffectView:(UIView *)view
                  Duration:(float)duration
                     Start:(float)start
                       End:(float)end
                    Rotate:(BOOL)rotate;

/**
 * @brief Remove the @c "FLUSH_ANIM" flash animation from a view's layer.
 * @param view The view whose layer's flash animation is removed.
 * @ghidraAddress 0x1a3ecc
 */
+ (void)removeFlashEffectView:(UIView *)view;

/**
 * @brief Start a plain (non-rotating) flash pulse on the receiver.
 *
 * Forwards to @c setFlashEffectView:Duration:Start:End:Rotate: with the receiver, @p rotate set to
 * @c NO, and the given endpoints.
 * @param duration The pulse duration, in seconds.
 * @param start The opacity at the start of the pulse.
 * @param end The opacity at the end of the pulse.
 * @ghidraAddress 0x1a36d4
 */
- (void)SetFlashEffectDuration:(float)duration Start:(float)start End:(float)end;

/**
 * @brief Stop the flash effect on the receiver by removing its flash overlay.
 *
 * Forwards to @c setFlashEffectView: with the receiver.
 * @ghidraAddress 0x1a36f4
 */
- (void)RemoveFlashEffect;

/**
 * @brief Start the default flash pulse on the receiver.
 *
 * Convenience for @c SetFlashEffectDuration:Start:End: with the default duration, a start opacity of
 * @c 1.0, and the dimmed end opacity.
 * @ghidraAddress 0x1a3710
 */
- (void)SetFlashEffectFast;

/**
 * @brief Start the rotating (multi-pulse plus full-turn) flash effect on the receiver.
 *
 * Convenience for @c setFlashEffectView:Duration:Start:End:Rotate: with the receiver, a four-second
 * duration, a start opacity of @c 1.0, the dimmed end opacity, and @p rotate set to @c YES.
 * @ghidraAddress 0x1a3730
 */
- (void)SetFlashEffectFastWithRotate;

/**
 * @brief Stop the flash effect on the receiver.
 *
 * Forwards to @c RemoveFlashEffect on the receiver.
 * @ghidraAddress 0x1a3760
 */
- (void)SetFlashEffectSlow;

/**
 * @brief Add an @c "ALPHA_ANIM" opacity transition to the receiver's layer and set the final
 * opacity.
 *
 * Captures the layer's current opacity, sets the layer opacity to @p end, then installs a
 * @c CABasicAnimation on @c opacity easing from the captured value to @p end that holds its final
 * value.
 * @param duration The transition duration, in seconds.
 * @param end The target layer opacity.
 * @ghidraAddress 0x1a3f34
 */
- (void)SetAlphaAnimationDuration:(float)duration End:(float)end;

/**
 * @brief Remove the @c "ALPHA_ANIM" animation from the receiver's layer.
 * @ghidraAddress 0x1a40d8
 */
- (void)RemoveAlphaAnimation;

/**
 * @brief Add a @c "PopAnim" bounce keyframe animation to the receiver's layer.
 *
 * Builds a @c position keyframe path anchored at (@p baseX, @p baseY) that overshoots upward then
 * settles back to the anchor, and installs it under the @c "PopAnim" key as a forever-repeating
 * animation that holds its final value.
 * @param baseX The anchor x-coordinate, in points.
 * @param baseY The anchor y-coordinate, in points.
 * @ghidraAddress 0x1a4134
 */
- (void)SetJumpEffectBaseX:(float)baseX BaseY:(float)baseY;

/**
 * @brief Remove the @c "PopAnim" animation from the receiver's layer.
 * @ghidraAddress 0x1a4414
 */
- (void)RemoveJumpEffect;

/**
 * @brief The receiver's frame origin x-coordinate.
 * @ghidraAddress 0x1a3668
 */
- (CGFloat)x;

/**
 * @brief The receiver's frame origin y-coordinate.
 * @ghidraAddress 0x1a3674
 */
- (CGFloat)y;

/**
 * @brief The receiver's frame width.
 * @ghidraAddress 0x1a3694
 */
- (CGFloat)width;

/**
 * @brief The receiver's frame height.
 * @ghidraAddress 0x1a36b4
 */
- (CGFloat)height;

/**
 * @brief The receiver's frame minimum x-coordinate (the left edge, @c frame.origin.x).
 * @ghidraAddress 0x1a35ac
 */
- (CGFloat)left;

/**
 * @brief The receiver's frame minimum y-coordinate (the top edge, @c frame.origin.y).
 * @ghidraAddress 0x1a35b8
 */
- (CGFloat)top;

/**
 * @brief The receiver's frame maximum x-coordinate (the right edge,
 * @c frame.origin.x + frame.size.width).
 * @ghidraAddress 0x1a35d8
 */
- (CGFloat)right;

/**
 * @brief The receiver's frame maximum y-coordinate (the bottom edge,
 * @c frame.origin.y + frame.size.height).
 * @ghidraAddress 0x1a3620
 */
- (CGFloat)bottom;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
