/** @file
 * A stateless factory of Core Animation builders for the app's user-interface effects. Every entry
 * point is a class method that assembles and returns a keyframe animation (or a grouped pair of
 * them) already configured to persist after it finishes: each is built with
 * @c removedOnCompletion set to @c NO and @c fillMode set to @c kCAFillModeForwards. A companion
 * class method strips every running animation from a layer and its sublayers.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class RBAnimationFactory, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Builds the Core Animation animations that drive the interface effects.
 */
@interface RBAnimationFactory : NSObject

/**
 * @brief Build a two-keyframe animation on @p keyPath that eases from @p fromValue to @p toValue.
 *
 * The animation begins at @p delay, runs for @p duration, holds both endpoints with ease-in
 * timing, and keeps its final value on screen.
 * @param keyPath The layer key path to animate.
 * @param fromValue The starting value at key time 0.
 * @param toValue The ending value at key time 1.
 * @param delay The animation's begin time, in seconds.
 * @param duration The animation's duration, in seconds.
 * @return The configured keyframe animation.
 * @ghidraAddress 0x200f70
 */
+ (CAKeyframeAnimation *)createAnimWithKeyPath:(NSString *)keyPath
                                     fromValue:(double)fromValue
                                       toValue:(double)toValue
                                         delay:(double)delay
                                      duration:(double)duration;

/**
 * @brief Build an opacity fade from @p fromValue to @p toValue with linear timing.
 * @param fromValue The starting opacity at key time 0.
 * @param toValue The ending opacity at key time 1.
 * @param delay The animation's begin time, in seconds.
 * @param duration The animation's duration, in seconds.
 * @return The configured fade animation.
 * @ghidraAddress 0x2012e0
 */
+ (CAKeyframeAnimation *)createFadeAnimWithFromValue:(double)fromValue
                                             toValue:(double)toValue
                                               delay:(double)delay
                                            duration:(double)duration;

/**
 * @brief Build a horizontal-position animation from @p fromValue to @p toValue.
 * @param fromValue The starting @c position.x at key time 0.
 * @param toValue The ending @c position.x at key time 1.
 * @param delay The animation's begin time, in seconds.
 * @param duration The animation's duration, in seconds.
 * @return The configured @c position.x animation.
 * @ghidraAddress 0x201628
 */
+ (CAKeyframeAnimation *)createPositionXAnimWithFromValue:(double)fromValue
                                                  toValue:(double)toValue
                                                    delay:(double)delay
                                                 duration:(double)duration;

/**
 * @brief Build a vertical-position animation from @p fromValue to @p toValue.
 * @note The shipped binary animates the @c position.x key path here rather than @c position.y;
 * this is preserved faithfully.
 * @param fromValue The starting value at key time 0.
 * @param toValue The ending value at key time 1.
 * @param delay The animation's begin time, in seconds.
 * @param duration The animation's duration, in seconds.
 * @return The configured animation.
 * @ghidraAddress 0x201644
 */
+ (CAKeyframeAnimation *)createPositionYAnimWithFromValue:(double)fromValue
                                                  toValue:(double)toValue
                                                    delay:(double)delay
                                                 duration:(double)duration;

/**
 * @brief Build a grouped animation that moves a layer from @p fromValue to @p toValue.
 *
 * The result is a @c CAAnimationGroup wrapping a @c position.x and a @c position.y animation.
 * @param fromValue The starting position.
 * @param toValue The ending position.
 * @param delay The group's begin time, in seconds.
 * @param duration The group's duration, in seconds.
 * @return The configured position animation group.
 * @ghidraAddress 0x201660
 */
+ (CAAnimationGroup *)createPositionAnimWithFromValue:(CGPoint)fromValue
                                              toValue:(CGPoint)toValue
                                                delay:(double)delay
                                             duration:(double)duration;

/**
 * @brief Build a scale animation from @p fromValue to @p toValue along the selected axes.
 *
 * When both @p X and @p Y are set the animation targets @c transform.scale; when only one is set it
 * targets @c transform.scale.x or @c transform.scale.y; when neither is set it returns @c nil.
 * @param fromValue The starting scale at key time 0.
 * @param toValue The ending scale at key time 1.
 * @param X Whether to scale along the horizontal axis.
 * @param Y Whether to scale along the vertical axis.
 * @param delay The animation's begin time, in seconds.
 * @param duration The animation's duration, in seconds.
 * @return The configured scale animation, or @c nil when neither axis is selected.
 * @ghidraAddress 0x20182c
 */
+ (nullable CAKeyframeAnimation *)createScaleAnimWithFromValue:(double)fromValue
                                                       toValue:(double)toValue
                                                             X:(BOOL)X
                                                             Y:(BOOL)Y
                                                         delay:(double)delay
                                                      duration:(double)duration;

/**
 * @brief Build a stay-in-place bob on @c position.y that overshoots and settles.
 *
 * The value keyframes rise from @p Y by a fixed offset, return to @p Y, then rise again, with
 * ease-out timing throughout, repeating @p repeatCount times.
 * @param duration The animation's duration, in seconds.
 * @param Y The resting @c position.y the bob departs from and returns to.
 * @param repeatCount The number of times to repeat the bob.
 * @return The configured @c position.y animation.
 * @ghidraAddress 0x201be0
 */
+ (CAKeyframeAnimation *)createAnimHereWithDuration:(double)duration
                                                  Y:(double)Y
                                        repeatCount:(int)repeatCount;

/**
 * @brief Build a five-keyframe bounce on the selected scale axes.
 *
 * The value keyframes overshoot above and dip below unit scale before settling, giving a springy
 * "bound" effect. The axis selection matches @c createScaleAnimWithFromValue:toValue:X:Y:delay:duration:
 * and returns @c nil when neither axis is selected.
 * @param X Whether to bounce along the horizontal axis.
 * @param Y Whether to bounce along the vertical axis.
 * @param delay The animation's begin time, in seconds.
 * @param duration The animation's duration, in seconds.
 * @return The configured bounce animation, or @c nil when neither axis is selected.
 * @ghidraAddress 0x201fa8
 */
+ (nullable CAKeyframeAnimation *)createBoundAnimWithX:(BOOL)X
                                                     Y:(BOOL)Y
                                                 delay:(double)delay
                                              duration:(double)duration;

/**
 * @brief Remove every running animation from @p layer and each of its sublayers.
 *
 * Does nothing when @p layer has no animation keys.
 * @param layer The layer to clear.
 * @ghidraAddress 0x202580
 */
+ (void)animationDelete:(CALayer *)layer;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
