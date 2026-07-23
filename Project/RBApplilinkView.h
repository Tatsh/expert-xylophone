/** @file
 * The Applilink campaign overlay presented over the music menu. It is an @c RBMusicMenuPopupView
 * subclass (popup type @c RBMusicMenuPopupViewTypeApplilink) that @c RBMenuView presents; it hosts
 * the @c RecommendNetwork companion-application advert area inside its own rounded web target
 * view, showing a large spinner until the advert area has loaded. As the advert area's delegate it
 * drives the spinner, fades the web target view in, and tears the overlay down.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c RBApplilinkView, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

#import "RBMusicMenuPopupView.h"

@class RBSettingView;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Popup view that hosts the @c RecommendNetwork Applilink advert area over the music menu.
 *
 * The receiver builds a rounded, clipped web target view for the advert area and a large activity
 * indicator spun while the area loads. @c showAnimation opens the advert area with the receiver as
 * its delegate; the delegate callbacks (@c appListDidAppear, @c appListDidDisappear, and
 * @c appListFailLoadWithError:) drive the spinner and the fade of the web target view. The class
 * adopts the @c ApplilinkViewDelegate protocol in the binary; those callbacks are declared here as
 * an informal delegate.
 */
@interface RBApplilinkView : RBMusicMenuPopupView

/**
 * @brief Create the Applilink popup with the given frame.
 *
 * Calls through to @c super, selects the Applilink popup type, builds the view, and clears the
 * hide-animating flag.
 * @param frame The view's frame rectangle.
 * @return The initialised view, or @c nil.
 * @ghidraAddress 0x1bd624
 */
- (nullable instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief Build the Applilink content: hide the base gradation and title, then add the rounded web
 * target view and the centred, magnified loading spinner inside the base popup's content view.
 * @ghidraAddress 0x1bd6c8
 */
- (void)setupView;

/**
 * @brief Fade the popup in, then open the @c RecommendNetwork advert area inside the web target
 * view with the receiver as its delegate.
 * @ghidraAddress 0x1bde84
 */
- (void)showAnimation;

/**
 * @brief Close the advert area, remove the spinner and web target view, and fade the popup out.
 *
 * Ignored while a transition is already running.
 * @ghidraAddress 0x1bdd50
 */
- (void)hideAnimation;

/**
 * @brief @c RecommendNetwork delegate callback: the advert area has appeared. Stops the spinner
 * and, on the first appearance, fades the web target view in.
 * @ghidraAddress 0x1bdf74
 */
- (void)appListDidAppear;

/**
 * @brief @c RecommendNetwork delegate callback: the advert area has disappeared. Closes the advert
 * area, marks the hide as under way, and fades the popup out.
 * @ghidraAddress 0x1be1a0
 */
- (void)appListDidDisappear;

/**
 * @brief @c RecommendNetwork delegate callback: the advert area failed to load. Stops the spinner
 * and shows a network-error alert.
 * @param error The load error.
 * @ghidraAddress 0x1be258
 */
- (void)appListFailLoadWithError:(nullable NSError *)error;

/**
 * @brief The rounded, clipped view that hosts the @c RecommendNetwork advert area.
 * @ghidraAddress 0x1be37c (getter)
 * @ghidraAddress 0x1be38c (setter)
 */
@property(strong, nonatomic, nullable) UIView *webTargetView;

/**
 * @brief The large spinner shown while the advert area loads.
 * @ghidraAddress 0x1be3c4 (getter)
 * @ghidraAddress 0x1be3d4 (setter)
 */
@property(assign, nonatomic, nullable) UIActivityIndicatorView *indicatorView;

/**
 * @brief The settings view that owns and presents this popup, if any.
 * @ghidraAddress 0x1be348 (getter)
 * @ghidraAddress 0x1be368 (setter)
 */
@property(weak, nonatomic, nullable) RBSettingView *settingView;

/**
 * @brief Whether the web target view fade-in is running.
 * @ghidraAddress 0x1be40c (getter)
 * @ghidraAddress 0x1be41c (setter)
 */
@property(assign, nonatomic) BOOL webTargetAnimating;

/**
 * @brief Whether a hide transition is under way.
 * @ghidraAddress 0x1be42c (getter)
 * @ghidraAddress 0x1be43c (setter)
 */
@property(assign, nonatomic) BOOL hideAnimating;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
