/** @file
 * The reward list hosted by @c RBCustomView. It slides in over the customize picker and, on demand,
 * opens the @c RewardNetwork companion-application advert screen inside its own rounded web target
 * view, showing a spinner until the list has loaded.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c RBRewardListView, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

@class RBCustomView;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A view that hosts the @c RewardNetwork advert screen over the customize picker.
 *
 * The view builds a rounded, clipped web target view for the advert screen, a large activity
 * indicator spun while the list loads, and a close button that is revealed once the advert screen
 * has appeared. @c RBCustomView reveals the list, then calls @c loadStart to request the advert
 * screen; the @c RewardNetwork delegate callbacks (@c appListDidAppear, @c appListDidDisappear, and
 * @c appListFailLoadWithError:) drive the spinner, the close button, and the fade of the web target
 * view.
 */
@interface RBRewardListView : UIView

/**
 * @brief Create the reward list with the given frame and build its subviews.
 * @param frame The view's frame rectangle.
 * @return The initialised view, or @c nil.
 * @ghidraAddress 0x10cfa4
 */
- (nullable instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief Build the web target view, the loading spinner, and the hidden close button.
 * @ghidraAddress 0x10d034
 */
- (void)setupView;

/**
 * @brief Close the advert screen, then remove the spinner and the web target view from their
 * superview.
 *
 * Ignored while a transition is already running.
 * @ghidraAddress 0x10d758
 */
- (void)hideAnimation;

/**
 * @brief Reveal the close button and open the @c RewardNetwork advert screen inside the web target
 * view, with the receiver as its delegate.
 * @ghidraAddress 0x10d824
 */
- (void)loadStart;

/**
 * @brief @c RewardNetwork delegate callback: the advert list has appeared. Stops the spinner and,
 * on the first appearance, fades the web target view in and reveals the loaded list.
 * @ghidraAddress 0x10d924
 */
- (void)appListDidAppear;

/**
 * @brief @c RewardNetwork delegate callback: the advert list has disappeared. Closes the advert
 * screen, hides the web target view, asks the owning customize popup to hide the reward list, hides
 * the close button, and restarts the spinner for the next presentation.
 * @ghidraAddress 0x10db9c
 */
- (void)appListDidDisappear;

/**
 * @brief @c RewardNetwork delegate callback: the advert list failed to load. Stops the spinner,
 * shows a network-error alert, and dismisses the list when the spinner was still animating.
 * @param error The load error.
 * @ghidraAddress 0x10dcb0
 */
- (void)appListFailLoadWithError:(nullable NSError *)error;

/**
 * @brief The rounded, clipped view that hosts the @c RewardNetwork advert screen.
 * @ghidraAddress 0x10de40 (getter)
 * @ghidraAddress 0x10de50 (setter)
 */
@property(strong, nonatomic, nullable) UIView *webTargetView;

/**
 * @brief The large spinner shown while the advert list loads.
 * @ghidraAddress 0x10ddf8 (getter)
 * @ghidraAddress 0x10de08 (setter)
 */
@property(strong, nonatomic, nullable) UIActivityIndicatorView *indicatorView;

/**
 * @brief The close button that dismisses the advert list, hidden until the list has appeared.
 * @ghidraAddress 0x10de88 (getter)
 * @ghidraAddress 0x10de98 (setter)
 */
@property(strong, nonatomic, nullable) UIButton *backButton;

/**
 * @brief The customize popup that owns and presents this reward list.
 * @ghidraAddress 0x10ddc4 (getter)
 * @ghidraAddress 0x10dde4 (setter)
 */
@property(weak, nonatomic, nullable) RBCustomView *parentCustomView;

/**
 * @brief Whether a hide transition is running.
 * @ghidraAddress 0x10ded0 (getter)
 * @ghidraAddress 0x10dee0 (setter)
 */
@property(assign, nonatomic) BOOL animating;

/**
 * @brief Whether the web target view fade-in is running.
 * @ghidraAddress 0x10def0 (getter)
 * @ghidraAddress 0x10df00 (setter)
 */
@property(assign, nonatomic) BOOL webTargetAnimating;

/**
 * @brief A convenience alias for @c parentCustomView that only forwards to its setter; the binary
 * declares no matching getter.
 * @param parentView The owning customize popup.
 * @ghidraAddress 0x10d018
 */
- (void)setParentView:(nullable RBCustomView *)parentView;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
