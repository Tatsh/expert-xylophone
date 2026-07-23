/** @file
 * The base popup view. It is a @c UIControl subclass that fills its host view with a dimmed
 * backdrop and fades itself in and out. A concrete popup subclass builds its own chrome inside the
 * @c baseView and @c contentView the base panel provides, and dismisses the popup by tapping the
 * dimmed backdrop.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class RBPopupView, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Base popup view presented over another view, dimming it and fading itself in and out.
 *
 * The control fills its superview and is dismissed by a touch anywhere on the dimmed backdrop.
 * Subclasses lay their own content out inside @c baseView and @c contentView, then present the
 * popup with @c showAnimation and dismiss it with @c hideAnimation.
 */
@interface RBPopupView : UIControl

/**
 * @brief Create the popup with the given frame.
 *
 * Calls through to @c super, clears the backdrop colour, makes the control fill and follow its
 * superview, and registers the dismiss handler for a touch-up on the backdrop.
 * @param frame The view's frame rectangle.
 * @return The initialised view, or @c nil.
 * @ghidraAddress 0x19b840
 */
- (nullable instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief Fade the popup in, marking it animating for the duration of the transition.
 *
 * Does nothing while a show or hide animation is already running.
 * @ghidraAddress 0x19b8fc
 */
- (void)showAnimation;

/**
 * @brief Fade the popup out with the cancel sound effect, then remove it from its superview.
 *
 * Does nothing while a show or hide animation is already running.
 * @ghidraAddress 0x19ba70
 */
- (void)hideAnimation;

/**
 * @brief Touch-up handler that dismisses the popup.
 * @param sender The control that sent the action.
 * @ghidraAddress 0x19bc00
 */
- (void)tap:(nullable id)sender;

/**
 * @brief The base panel that hosts the popup chrome a subclass builds.
 */
@property(strong, nonatomic, nullable) UIView *baseView;

/**
 * @brief The content view into which a subclass lays its own content.
 */
@property(strong, nonatomic, nullable) UIView *contentView;

/**
 * @brief Whether a show or hide animation is currently running.
 */
@property(assign, nonatomic) BOOL animating;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
