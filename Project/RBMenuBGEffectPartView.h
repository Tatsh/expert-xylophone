/** @file
 * A single animated particle layer of an @c RBMenuBGEffectView background. Concrete subclasses (for
 * example @c RBResourceDownloadBGEffectPartView) seed the three artwork paths in their @c init; the
 * base class builds a sprite @c UIImageView from those paths and drives its per-cycle spawn
 * position, alpha, size, and image with a looping @c UIView animation.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c RBMenuBGEffectPartView, image
 * base 0x100000000). The superclass is @c UIView; every ivar is property-backed, so each keeps its
 * leading underscore.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A single animated particle layer of a background effect.
 */
@interface RBMenuBGEffectPartView : UIView

/** @brief Image name for the first (rearmost) artwork layer. */
@property(strong, nonatomic, nullable) NSString *image1Path; // +0x10
/** @brief Image name for the second artwork layer. */
@property(strong, nonatomic, nullable) NSString *image2Path; // +0x18
/** @brief Image name for the third (frontmost) artwork layer. */
@property(strong, nonatomic, nullable) NSString *image3Path; // +0x20
/** @brief The image view that renders the current particle sprite. */
@property(strong, nonatomic, nullable) UIImageView *effect; // +0x28
/** @brief The first sprite frame, loaded from @c image1Path. */
@property(strong, nonatomic, nullable) UIImage *image1; // +0x30
/** @brief The second sprite frame, loaded from @c image2Path. */
@property(strong, nonatomic, nullable) UIImage *image2; // +0x38
/** @brief The third sprite frame, loaded from @c image3Path. */
@property(strong, nonatomic, nullable) UIImage *image3; // +0x40
/** @brief Whether an animation cycle is currently running. */
@property(assign, nonatomic) BOOL isAnimation; // +0x08
/** @brief Whether a completed cycle should immediately spawn again and loop. */
@property(assign, nonatomic) BOOL isAnimationEnableLoop; // +0x09

/** @brief Build the particle's frames and effect view for the current bounds. */
- (void)setupView;
/**
 * @brief Spawn the particle at a random position, alpha, and size, then run one looping cycle.
 */
- (void)startAnimation;
/** @brief Stop the running cycle and clear the particle sprite. */
- (void)stopAnimation;
/**
 * @brief Set whether a completed cycle should loop.
 * @param animationLoopFlag @c YES to keep spawning again after each cycle.
 */
- (void)setAnimationLoopFlag:(BOOL)animationLoopFlag;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
