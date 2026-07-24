/** @file
 * The animated pastel speech-bubble view shown beside the tutorial spotlight. It is a @c UIView
 * that builds four @c UIImageView children (head, body, and the left and right tails) from clipped
 * regions of the tutorial message artwork atlas, laid out around a resolution-dependent display
 * rate, and offers a wave and a jump keyframe animation driven through those children's layers.
 *
 * This is the @c UIView twin of @c RBTutorialPastelLayer (a @c CALayer built from the identical
 * artwork clip and position tables and the identical wave and jump keyframes); the two classes
 * share the same clip-rectangle and position backing store in the binary.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class RBTutorialPastel, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <CoreGraphics/CoreGraphics.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The tutorial pastel speech-bubble view.
 *
 * @c init sizes the view and picks its display rate from the current iPad idiom, @c setupView:
 * cuts the four child image views from the message artwork and positions them, and @c stopAnimation
 * clears every running animation from the view's layer and its children's layers.
 */
@interface RBTutorialPastel : UIView

/**
 * @brief Create the view, choosing the display rate from the current iPad idiom and sizing the
 *        view's frame from that rate.
 * @return The initialised view, or @c nil.
 * @ghidraAddress 0x1ad4b4
 */
- (nullable instancetype)init;

/**
 * @brief Build the pastel bubble's four child image views from the tutorial message artwork.
 *
 * Cuts the body, head, right, and left regions out of @p image, wraps each in a @c UIImageView,
 * anchors and positions them around the display rate through each child's layer, and adds them as
 * subviews.
 * @param image The tutorial message artwork atlas the child image views are clipped from.
 * @ghidraAddress 0x1ad588
 */
- (void)setupView:(nullable UIImage *)image;

/**
 * @brief Return the artwork clip rectangle for the child at @p index.
 *
 * The rectangle is halved when the current idiom is not the iPad (the compact layout).
 * @param index The child index (0 head, 1 body, 2 left tail, 3 right tail).
 * @return The clip rectangle in the artwork atlas.
 * @ghidraAddress 0x1ad424
 */
- (CGRect)getClipList:(int)index;

/**
 * @brief Return the layout point for the child at @p index.
 * @param index The child index (0 head, 1 body, 2 left tail, 3 right tail).
 * @return The layout point.
 * @ghidraAddress 0x1ad484
 */
- (CGPoint)getPosition:(int)index;

/**
 * @brief Run the wave animation over the base, right, and head layers for @p duration.
 * @param duration The animation's duration, in seconds.
 * @ghidraAddress 0x1adfd4
 */
- (void)startWaveAnimationWithDuration:(float)duration;

/**
 * @brief Run the jump animation over the right, left, head, and base layers for @p duration.
 *
 * When @p delay is effectively zero the animations are added immediately; otherwise they are added
 * inside a delayed @c UIView animation block.
 * @param duration The animation's duration, in seconds.
 * @param delay The delay before the animation begins, in seconds.
 * @ghidraAddress 0x1aff94
 */
- (void)startJumpAnimationWithDuration:(float)duration delay:(float)delay;

/**
 * @brief Remove every running animation from the view's layer, its four child image views' layers,
 *        and their sublayers.
 * @ghidraAddress 0x1b2784
 */
- (void)stopAnimation;

#pragma mark Properties

/**
 * @brief The resolution-dependent layout scale: half on the compact (non-iPad) idiom, unity on
 *        iPad.
 */
@property(nonatomic, assign) float displayRate;

/**
 * @brief The head child image view.
 */
@property(nonatomic, strong, nullable) UIImageView *headView;

/**
 * @brief The body child image view.
 */
@property(nonatomic, strong, nullable) UIImageView *bodyView;

/**
 * @brief The right-tail child image view.
 */
@property(nonatomic, strong, nullable) UIImageView *rightView;

/**
 * @brief The left-tail child image view.
 */
@property(nonatomic, strong, nullable) UIImageView *leftView;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
