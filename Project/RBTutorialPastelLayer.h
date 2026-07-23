/** @file
 * The animated pastel speech-bubble layer drawn beside the tutorial spotlight by
 * @c RBMenuTutorialView. It is a @c CALayer that builds four weak child layers (head, body, and the
 * left and right tails) from clipped regions of the tutorial message artwork atlas, laid out around
 * a resolution-dependent display rate, and offers a wave and a jump keyframe animation over those
 * child layers. @c RBMenuTutorialView only ever drives @c setupView: and @c stopAnimation; the two
 * animation entry points are part of the class interface but are not invoked by the shipped app.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class RBTutorialPastelLayer, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <CoreGraphics/CoreGraphics.h>
#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The tutorial pastel speech-bubble layer.
 *
 * @c init sizes the layer and picks its display rate from the current font variant, @c setupView:
 * cuts the four child layers from the message artwork and positions them, and @c stopAnimation
 * clears every running animation from the layer and its children.
 */
@interface RBTutorialPastelLayer : CALayer

/**
 * @brief Create the layer, choosing the display rate from the current font variant and sizing the
 *        layer's frame from that rate.
 * @return The initialised layer, or @c nil.
 * @ghidraAddress 0x1b35fc
 */
- (nullable instancetype)init;

/**
 * @brief Build the pastel bubble's four child layers from the tutorial message artwork.
 *
 * Cuts the right, left, body, and head regions out of @p image, wraps each in a weak child layer,
 * anchors and positions them around the display rate, and adds them as sublayers.
 * @param image The tutorial message artwork atlas the child layers are clipped from.
 * @ghidraAddress 0x1b36fc
 */
- (void)setupView:(nullable UIImage *)image;

/**
 * @brief Return the artwork clip rectangle for the child layer at @p index.
 *
 * The rectangle is halved when the current font variant is the compact (non-retina) layout.
 * @param index The child-layer index (0 head, 1 body, 2 left tail, 3 right tail).
 * @return The clip rectangle in the artwork atlas.
 * @ghidraAddress 0x1b356c
 */
- (CGRect)getClipList:(int)index;

/**
 * @brief Return the layout point for the child layer at @p index.
 * @param index The child-layer index (0 head, 1 body, 2 left tail, 3 right tail).
 * @return The layout point.
 * @ghidraAddress 0x1b35cc
 */
- (CGPoint)getPosition:(int)index;

/**
 * @brief Run the wave animation over the base, right, and head layers for @p duration.
 * @param duration The animation's duration, in seconds.
 * @ghidraAddress 0x1b3cf4
 */
- (void)startWaveAnimationWithDuration:(float)duration;

/**
 * @brief Run the jump animation over the right, left, head, and base layers for @p duration.
 *
 * When @p delay is effectively zero the animations are added immediately; otherwise they are added
 * inside a delayed @c UIView animation block.
 * @param duration The animation's duration, in seconds.
 * @param delay The delay before the animation begins, in seconds.
 * @ghidraAddress 0x1b58b0
 */
- (void)startJumpAnimationWithDuration:(float)duration delay:(float)delay;

/**
 * @brief Remove every running animation from the layer, its four child layers, and their sublayers.
 * @ghidraAddress 0x1b7848
 */
- (void)stopAnimation;

#pragma mark Properties

/**
 * @brief The resolution-dependent layout scale: half on the compact font variant, unity otherwise.
 * @ghidraAddress 0x1b8170 (getter)
 * @ghidraAddress 0x1b8160 (setter)
 */
@property(nonatomic, assign) float displayRate;

/**
 * @brief The head child layer, held weakly (retained by its superlayer).
 * @ghidraAddress 0x1b80c4 (getter)
 * @ghidraAddress 0x1b80e4 (setter)
 */
@property(nonatomic, weak, nullable) CALayer *headLayer;

/**
 * @brief The body child layer, held weakly (retained by its superlayer).
 * @ghidraAddress 0x1b812c (getter)
 * @ghidraAddress 0x1b814c (setter)
 */
@property(nonatomic, weak, nullable) CALayer *bodyLayer;

/**
 * @brief The right-tail child layer, held weakly (retained by its superlayer).
 * @ghidraAddress 0x1b8090 (getter)
 * @ghidraAddress 0x1b80b0 (setter)
 */
@property(nonatomic, weak, nullable) CALayer *rightLayer;

/**
 * @brief The left-tail child layer, held weakly (retained by its superlayer).
 * @ghidraAddress 0x1b80f8 (getter)
 * @ghidraAddress 0x1b8118 (setter)
 */
@property(nonatomic, weak, nullable) CALayer *leftLayer;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
