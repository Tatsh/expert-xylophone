/** @file
 * The corporate/legal information view controller. It is an @c RBBaseViewController subclass pushed
 * onto the navigation stack that presents Konami's corporate web page (@c https://www.konami.com/ja/)
 * inside an @c RBWebView. It builds a custom "back" left bar-button item, shows a centred activity
 * indicator while the page loads, and acts as the web view's delegate: it starts the spinner on each
 * navigation, clears the URL cache when a load starts, suppresses the iOS touch callout and stops the
 * spinner when a load finishes, and presents the shared network-error alert on failure.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c RBCorporateViewController, image
 * base 0x100000000). @ghidraAddress values are offsets relative to the image base. The class adopts
 * @c UIWebViewDelegate (its @c class_ro_t protocol list).
 */

#import <UIKit/UIKit.h>

#import "RBBaseViewController.h"

@class RBWebView;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The corporate/legal information view controller, presenting Konami's corporate web page in
 * a web view on the navigation stack.
 */
@interface RBCorporateViewController : RBBaseViewController <UIWebViewDelegate>

#pragma mark Lifecycle

/**
 * @brief Create the controller and build the navigation-bar custom "back" left bar-button item
 * titled with the localised "Done" string.
 * @return The initialised controller, or @c nil.
 * @ghidraAddress 0xf033c
 */
- (nullable instancetype)init;

/**
 * @brief Set the view background to white and build the centred, animating loading spinner.
 * @ghidraAddress 0xf0554
 */
- (void)viewDidLoad;

/**
 * @brief Reveal the navigation bar for this controller.
 * @param animated Whether the appearance is animated.
 * @ghidraAddress 0xf0774
 */
- (void)viewWillAppear:(BOOL)animated;

/**
 * @brief Lazily build the corporate web view (when absent), add it to the view, and load Konami's
 * corporate page.
 * @param animated Whether the appearance is animated.
 * @ghidraAddress 0xf0858
 */
- (void)viewDidAppear:(BOOL)animated;

/**
 * @brief Tear the web view down (removing it from its superview) when leaving the screen.
 * @param animated Whether the disappearance is animated.
 * @ghidraAddress 0xf0aa4
 */
- (void)viewDidDisappear:(BOOL)animated;

#pragma mark Navigation

/**
 * @brief Handle the custom "back" bar-button tap: stop the loading spinner, hide the navigation bar,
 * and pop the controller (all animated).
 * @param sender The tapped bar-button item.
 * @ghidraAddress 0xf0b84
 */
- (void)pushBarBtnBack:(nullable id)sender;

/**
 * @brief Dismiss the controller without animation: stop the spinner, hide the navigation bar, and
 * pop the controller.
 * @ghidraAddress 0xf0c74
 */
- (void)forceClose;

#pragma mark Web view delegate

/**
 * @brief Start the loading spinner before a navigation begins.
 * @param webView The web view about to load.
 * @param request The request about to load.
 * @param navigationType The navigation type.
 * @return Always @c YES (every navigation is allowed).
 * @ghidraAddress 0xf0d5c
 */
- (BOOL)webView:(nullable UIWebView *)webView
    shouldStartLoadWithRequest:(nullable NSURLRequest *)request
                navigationType:(UIWebViewNavigationType)navigationType;

/**
 * @brief Clear the shared URL cache as a page load starts.
 * @param webView The web view that started loading.
 * @ghidraAddress 0xf0ecc
 */
- (void)webViewDidStartLoad:(nullable UIWebView *)webView;

/**
 * @brief Finish a page load: clear the first-request flag, stop the spinner, and suppress the iOS
 * touch callout on the loaded document.
 * @param webView The web view that finished loading.
 * @ghidraAddress 0xf0f30
 */
- (void)webViewDidFinishLoad:(nullable UIWebView *)webView;

/**
 * @brief Handle a page-load failure: stop the spinner and present the shared network-error alert
 * (tagged 1000) with this controller as its delegate.
 * @param webView The web view that failed to load.
 * @param error The load error.
 * @ghidraAddress 0xf0dc0
 */
- (void)webView:(nullable UIWebView *)webView didFailLoadWithError:(nullable NSError *)error;

#pragma mark Alert view delegate

/**
 * @brief Handle the network-error alert dismissal: pop the controller when this is the first request.
 * @param alertView The alert view that was dismissed.
 * @param buttonIndex The index of the button that was tapped.
 * @ghidraAddress 0xf0ff0
 */
- (void)alertView:(nullable UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex;

#pragma mark Properties

/** @brief Whether this is the first page request, gating the alert-driven dismiss. */
@property(assign, nonatomic) BOOL isFirstRequest;
/** @brief The loading spinner shown during page loads. */
@property(assign, nonatomic, nullable) UIActivityIndicatorView *indicator;
/** @brief The most recent request URL. */
@property(strong, nonatomic, nullable) NSURL *requestURL;
/** @brief The web view presenting the corporate page. */
@property(assign, nonatomic, nullable) RBWebView *webView;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
