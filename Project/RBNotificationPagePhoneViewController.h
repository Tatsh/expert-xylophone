/** @file
 * The phone build's full-screen news / information page view controller. It is the phone-side
 * counterpart of the @c RBNotificationPageView popup: instead of a popup over the music menu, the
 * phone build pushes this @c RBBaseViewController onto its navigation stack. It builds a themed
 * navigation bar with a custom back button, hosts an @c RBWebView loading the news web-info URL
 * (falling back to the pre-release endpoint), and — as the web view's delegate — intercepts the
 * @c reflecbeat deep links (@c twitter, @c openurl, and the @c rbplus://store pack routes), drives
 * a loading spinner, and presents a network-error alert.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class
 * @c RBNotificationPagePhoneViewController, image base 0x100000000). @ghidraAddress values are
 * offsets relative to the image base. The class adopts @c UIWebViewDelegate (its @c class_ro_t
 * protocol list).
 */

#import <UIKit/UIKit.h>

#import "RBBaseViewController.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The phone news / information page controller that hosts an @c RBWebView on the navigation
 * stack.
 */
@interface RBNotificationPagePhoneViewController : RBBaseViewController <UIWebViewDelegate>

#pragma mark Lifecycle

/**
 * @brief Build the controller: install the information-bar title view and a custom back button in
 * the navigation item.
 * @return The initialised controller, or @c nil.
 * @ghidraAddress 0x191c3c
 */
- (nullable instancetype)init;

#pragma mark Navigation

/**
 * @brief Handle the back button: hide the navigation bar, play the themed cancel sound effect, and
 * pop the controller animated.
 * @param sender The bar button that triggered the action.
 * @ghidraAddress 0x192a60
 */
- (void)pushBarBtnBack:(nullable id)sender;

/**
 * @brief Dismiss the controller without animation: hide the navigation bar and pop it.
 * @ghidraAddress 0x192b28
 */
- (void)forceClose;

#pragma mark Properties

/** @brief Whether this is the first request, gating the alert-driven dismiss. */
@property(nonatomic, assign) BOOL isFirstRequest;
/** @brief The pending news web-info URL consumed when the web view is built. */
@property(nonatomic, strong, nullable) NSURL *requestURL;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
