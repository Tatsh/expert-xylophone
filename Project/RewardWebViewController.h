/** @file
 * Reconstructed interface for the Applilink reward SDK's @c RewardWebViewController.
 *
 * @c RewardWebViewController is the reward advert SDK's in-application web-view host: a
 * @c UIViewController that owns a base @c UIView, a @c UIWebView, an optional @c UINavigationBar
 * with a close button, and an @c ApplilinkIndicator loading overlay. It loads the reward advert
 * page, tracks the load through the @c UIWebViewDelegate callbacks, detects the advert's close
 * request (either a @c "close" navigation or a @c "command=close" query), rotates its content to
 * follow the status-bar orientation, and reports the advert lifecycle back to its @c SdkViewDelegate.
 * It is created and driven by @c RewardCore. Reconstructed from Ghidra project rb458, program rb458.
 */

#import <UIKit/UIKit.h>

#import "ApplilinkIndicator.h"
#import "ApplilinkStore.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The in-application host controller for the reward advert web page.
 */
@interface RewardWebViewController : UIViewController

/**
 * @brief The SDK delegate that receives the advert lifecycle notices.
 *
 * Held weakly: the controller forwards each notice to it but does not own it, and clears the
 * reference once the closing or open-failure notice has been sent.
 */
@property(weak, nonatomic, nullable) id<SdkViewDelegate> sdkDelegate;

/**
 * @brief The host view the advert web view is added to.
 *
 * When @c nil the advert is added to @c [ApplilinkCore mainWindow] instead.
 */
@property(strong, nonatomic, nullable) UIView *parentView;

/**
 * @brief The container view that hosts the web view and navigation bar.
 */
@property(strong, nonatomic, nullable) UIView *baseView;

/**
 * @brief The web view that renders the reward advert page.
 */
@property(strong, nonatomic, nullable) UIWebView *webView;

/**
 * @brief The navigation bar carrying the advert title and close button.
 *
 * Created only when the navigation bar is not hidden.
 */
@property(strong, nonatomic, nullable) UINavigationBar *navigationBar;

/**
 * @brief The loading overlay shown while the advert page loads.
 */
@property(strong, nonatomic, nullable) ApplilinkIndicator *indicator;

/**
 * @brief Whether the advert screen hides its navigation bar.
 */
@property(nonatomic) BOOL isNavigationBarHidden;

/**
 * @brief The current load state of the advert web view.
 *
 * @c 0 before any load starts, @c 1 while loading, and @c 2 once the load has finished.
 */
@property(nonatomic) int webViewStatus;

/**
 * @brief Set whether the advert screen hides its navigation bar.
 *
 * This is the SDK-facing alias for @c isNavigationBarHidden used by @c RewardCore.
 * @param navigationBarHidden @c YES to hide the navigation bar.
 * @ghidraAddress 0x21d2cc
 */
- (void)setNavigationBarHidden:(BOOL)navigationBarHidden;

/**
 * @brief Load the reward advert page from a URL with request parameters.
 *
 * Resets the load state, attaches the controller's view to @c parentView (or the main window),
 * builds a ten-second, no-cache mutable request with the parameters appended to the URL, lazily
 * creates the web view, aligns it to the current status-bar orientation, and starts the load.
 * @param url The reward advert page URL string.
 * @param parameters The request parameters to append as a query string.
 * @ghidraAddress 0x21d2e4
 */
- (void)loadRequestWithURL:(nullable NSString *)url parameters:(nullable NSDictionary *)parameters;

/**
 * @brief Close the advert list from an external request.
 *
 * Cancels the pending indicator activation, marks the view closed, stops any in-flight load, and
 * tears the advert web view down.
 * @ghidraAddress 0x21d580
 */
- (void)appliListClosed;

/**
 * @brief Tear down the advert web view and release its subviews.
 * @ghidraAddress 0x21d1bc
 */
- (void)viewDealloc;

/**
 * @brief Clear the SDK delegate and detach the web view's delegate.
 * @ghidraAddress 0x21f19c
 */
- (void)clearDelegate;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
