/** @file
 * The first-run tutorial overlay shown over the menu. It dims the whole screen with four grey
 * quadrant layers plus four grey centre layers that together punch a rectangular "spotlight" hole
 * around the control the current tutorial step points at, draws the tutorial message artwork and a
 * pastel speech bubble beside the hole, and animates a bouncing cursor or a pulsing touch marker on
 * top of the highlighted control. Each tap advances the step: @c hitTest:withEvent: swallows touches
 * outside the spotlight, drives the step cursor forward, and re-lays-out the overlay for the next
 * step. The step sequence is owned by @c RBTutorialManager; this view mirrors the live step into its
 * own @c tutorialStatus and reports completion back through the manager.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class RBMenuTutorialView, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

@class RBMenuView;
@class RBTutorialPastelLayer;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The first-run tutorial overlay view.
 *
 * The overlay is a full-screen @c UIControl. @c initWithFrame: sizes the message content view from
 * the font variant, @c setupView builds the dimming layers, message artwork, pastel bubble, cursor,
 * and touch marker, and the tutorial is driven forward by taps through @c hitTest:withEvent:.
 */
@interface RBMenuTutorialView : UIControl

#pragma mark Lifecycle

/**
 * @brief Create the overlay with the given frame and size its message content view from the current
 *        font variant.
 * @param frame The view's frame rectangle.
 * @return The initialised overlay, or @c nil.
 * @ghidraAddress 0x37b0c
 */
- (nullable instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief Build the overlay content: the dimming base view and its eight grey spotlight layers, the
 *        message artwork window and message layer, the pastel speech-bubble layer, the bouncing
 *        cursor image, the pulsing touch-marker image, and the full-cover tap target.
 * @ghidraAddress 0x37bfc
 */
- (void)setupView;

#pragma mark Presentation

/**
 * @brief Fade the overlay in for the given tutorial type, then start that tutorial step on
 *        completion (unless @p tutorialType is the "no tutorial" sentinel).
 * @param tutorialType The tutorial step identifier to run once the fade-in completes.
 * @param rootView The clip-root view whose child controls the steps point at.
 * @ghidraAddress 0x139af8
 */
- (void)showAnimationWithTutorialType:(NSUInteger)tutorialType
                         withRootView:(nullable UIView *)rootView;

/**
 * @brief Fade the overlay out, then tear it down and detach it from @c RBMenuView on completion.
 * @ghidraAddress 0x139e04
 */
- (void)hideAnimation;

/**
 * @brief Prepare the overlay for a device rotation.
 */
- (void)willRotate;

/**
 * @brief Re-lay the overlay after a device rotation.
 */
- (void)didRotate;

#pragma mark Tutorial steps

/**
 * @brief Run the tutorial step of the given type against @p rootView, animating its appearance.
 *
 * Records @p rootView as the clip root, then calls @c startTutorialWithType:withAnimation:.
 * @param tutorialType The tutorial step identifier.
 * @param rootView The view whose child control the step points at.
 * @ghidraAddress 0x13b8fc
 */
- (void)startTutorialWithType:(NSUInteger)tutorialType withRootView:(nullable UIView *)rootView;

/**
 * @brief Run the tutorial step of the given type: pick the control it points at, lay out the
 *        spotlight around it, and start the cursor and touch animations for that step.
 *
 * On the customize-item step it also grants the one-off experience-point reward and plays the
 * decide sound the first time it is reached.
 * @param tutorialType The tutorial step identifier.
 * @param animation Whether to animate the layout in.
 * @ghidraAddress 0x13ab34
 */
- (void)startTutorialWithType:(NSUInteger)tutorialType withAnimation:(BOOL)animation;

#pragma mark Properties

/**
 * @brief The menu hub that presents this overlay, held weakly.
 * @ghidraAddress 0x140d04 (getter)
 * @ghidraAddress 0x140d24 (setter)
 */
@property(nonatomic, weak, nullable) RBMenuView *musicMenuView;

/**
 * @brief The dimming base image view that hosts the eight grey spotlight layers.
 * @ghidraAddress 0x140d38 (getter)
 * @ghidraAddress 0x140d48 (setter)
 */
@property(nonatomic, strong, nullable) UIImageView *baseView;

/**
 * @brief Whether an overlay transition is currently running; taps and rotation are ignored while
 *        set.
 * @ghidraAddress 0x140d80 (getter)
 * @ghidraAddress 0x140d90 (setter)
 */
@property(nonatomic, assign) BOOL animating;

/**
 * @brief The opaque black view laid over everything during a rotation.
 * @ghidraAddress 0x140da0 (getter)
 * @ghidraAddress 0x140db0 (setter)
 */
@property(nonatomic, strong, nullable) UIView *fullCoverView;

/**
 * @brief The root view supplied by the current step, whose child control the step highlights, held
 *        weakly.
 * @ghidraAddress 0x140de8 (getter)
 * @ghidraAddress 0x140e08 (setter)
 */
@property(nonatomic, weak, nullable) UIView *clipRootView;

/**
 * @brief The specific control the current step points at, held weakly.
 * @ghidraAddress 0x140e1c (getter)
 * @ghidraAddress 0x140e3c (setter)
 */
@property(nonatomic, weak, nullable) UIView *clipTargetView;

/**
 * @brief Whether the current step's spotlight lets touches through to the highlighted control.
 * @ghidraAddress 0x140e50 (getter)
 * @ghidraAddress 0x140e60 (setter)
 */
@property(nonatomic, assign) BOOL clipTargetForTouch;

/**
 * @brief The spotlight rectangle, in this view's coordinates, of the currently highlighted control.
 * @ghidraAddress 0x140e70 (getter)
 * @ghidraAddress 0x140e88 (setter)
 */
@property(nonatomic, assign) CGRect clipRect;

/**
 * @brief The bouncing cursor image drawn over the highlighted control.
 * @ghidraAddress 0x140ea0 (getter)
 * @ghidraAddress 0x140eb0 (setter)
 */
@property(nonatomic, strong, nullable) UIImageView *cursorView;

/**
 * @brief The pulsing touch-marker image drawn over the highlighted control.
 * @ghidraAddress 0x140ee8 (getter)
 * @ghidraAddress 0x140ef8 (setter)
 */
@property(nonatomic, strong, nullable) UIImageView *touchView;

/**
 * @brief The top-left grey dimming layer.
 * @ghidraAddress 0x140f30 (getter)
 * @ghidraAddress 0x140f50 (setter)
 */
@property(nonatomic, weak, nullable) CALayer *grayTL;
/**
 * @brief The top-right grey dimming layer.
 * @ghidraAddress 0x140f64 (getter)
 * @ghidraAddress 0x140f84 (setter)
 */
@property(nonatomic, weak, nullable) CALayer *grayTR;
/**
 * @brief The bottom-left grey dimming layer.
 * @ghidraAddress 0x140f98 (getter)
 * @ghidraAddress 0x140fb8 (setter)
 */
@property(nonatomic, weak, nullable) CALayer *grayBL;
/**
 * @brief The bottom-right grey dimming layer.
 * @ghidraAddress 0x140fcc (getter)
 * @ghidraAddress 0x140fec (setter)
 */
@property(nonatomic, weak, nullable) CALayer *grayBR;
/**
 * @brief The top-left rounded-corner grey layer that trims the spotlight hole.
 * @ghidraAddress 0x141000 (getter)
 * @ghidraAddress 0x141020 (setter)
 */
@property(nonatomic, weak, nullable) CALayer *grayCTL;
/**
 * @brief The top-right rounded-corner grey layer that trims the spotlight hole.
 * @ghidraAddress 0x141034 (getter)
 * @ghidraAddress 0x141054 (setter)
 */
@property(nonatomic, weak, nullable) CALayer *grayCTR;
/**
 * @brief The bottom-left rounded-corner grey layer that trims the spotlight hole.
 * @ghidraAddress 0x141068 (getter)
 * @ghidraAddress 0x141088 (setter)
 */
@property(nonatomic, weak, nullable) CALayer *grayCBL;
/**
 * @brief The bottom-right rounded-corner grey layer that trims the spotlight hole.
 * @ghidraAddress 0x14109c (getter)
 * @ghidraAddress 0x1410bc (setter)
 */
@property(nonatomic, weak, nullable) CALayer *grayCBR;

/**
 * @brief The message content view that holds the message layer, pastel bubble, and window layer.
 * @ghidraAddress 0x1410d0 (getter)
 * @ghidraAddress 0x1410e0 (setter)
 */
@property(nonatomic, strong, nullable) UIView *contentView;

/**
 * @brief The layer name tag whose sublayers keep their animations across a re-layout.
 * @ghidraAddress 0x141118 (getter)
 * @ghidraAddress 0x141128 (setter)
 */
@property(nonatomic, strong, nullable) NSString *showLayerTag;

/**
 * @brief The layer name tag whose sublayers are removed on a re-layout.
 * @ghidraAddress 0x141160 (getter)
 * @ghidraAddress 0x141170 (setter)
 */
@property(nonatomic, strong, nullable) NSString *deleteLayerTag;

/**
 * @brief The framed message-window layer that holds the message artwork.
 * @ghidraAddress 0x1411a8 (getter)
 * @ghidraAddress 0x1411c8 (setter)
 */
@property(nonatomic, weak, nullable) CALayer *messageWindowLayer;

/**
 * @brief The message-text layer whose contents rectangle is swapped per step.
 * @ghidraAddress 0x1411dc (getter)
 * @ghidraAddress 0x1411fc (setter)
 */
@property(nonatomic, weak, nullable) CALayer *messageLayer;

/**
 * @brief The pastel speech-bubble layer drawn beside the spotlight.
 * @ghidraAddress 0x141210 (getter)
 * @ghidraAddress 0x141230 (setter)
 */
@property(nonatomic, weak, nullable) RBTutorialPastelLayer *pastelLayer;

/**
 * @brief The full message artwork atlas the per-step clips are cut from.
 * @ghidraAddress 0x141244 (getter)
 * @ghidraAddress 0x141254 (setter)
 */
@property(nonatomic, strong, nullable) UIImage *messageImage;

/**
 * @brief The clip rectangle of the message text within the artwork atlas. Declared by the binary
 *        but not populated by @c setupView.
 * @ghidraAddress 0x14128c (getter)
 * @ghidraAddress 0x14129c (setter)
 */
@property(nonatomic, strong, nullable) NSValue *messageClipRect;

/**
 * @brief The live tutorial step identifier this overlay is showing, mirrored from
 *        @c RBTutorialManager.
 * @ghidraAddress 0x1412d4 (getter)
 * @ghidraAddress 0x1412e4 (setter)
 */
@property(nonatomic, assign) NSUInteger tutorialStatus;

/**
 * @brief The message content view's width, derived from the font variant.
 * @ghidraAddress 0x1412f4 (getter)
 * @ghidraAddress 0x141304 (setter)
 */
@property(nonatomic, assign) CGFloat contentViewWidth;

/**
 * @brief The message content view's height, derived from the font variant.
 * @ghidraAddress 0x141314 (getter)
 * @ghidraAddress 0x141324 (setter)
 */
@property(nonatomic, assign) CGFloat contentViewHeight;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
