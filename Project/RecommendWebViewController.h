/** @file
 * Minimal reconstructed interface for the Applilink recommend SDK's @c RecommendWebViewController.
 *
 * @c RecommendWebViewController is the advert-screen web view controller that @c RecommendCore
 * presents: it hosts the advert web content, forwards SDK callbacks, and loads the external advert
 * index request. The Applilink SDK ships as a closed third-party library, so only the members that
 * @c RecommendCore messages are declared here. Reconstructed from Ghidra project rb458, program
 * rb458.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The Applilink recommend advert-screen web view controller.
 */
@interface RecommendWebViewController : UIViewController

/**
 * @brief The advert base view whose frame bounds the advert content.
 * @return The base view.
 */
- (nullable UIView *)baseView;

/**
 * @brief Set the SDK callback delegate to the shared recommend core.
 */
- (void)setSdkDelegate;

/**
 * @brief Set whether the advert-screen navigation bar is hidden.
 * @param navigationBarHidden @c YES to hide the navigation bar.
 */
- (void)setNavigationBarHidden:(BOOL)navigationBarHidden;

/**
 * @brief Set the parent view that hosts the advert screen.
 */
- (void)setParentView;

/**
 * @brief Set whether the advert web view bounces when scrolled past its edges.
 * @param webViewBounces @c YES to allow bouncing.
 */
- (void)setWebViewBounces:(BOOL)webViewBounces;

/**
 * @brief Show or hide the loading indicator.
 * @param updateIndicator @c YES to show the indicator.
 */
- (void)updateIndicator:(BOOL)updateIndicator;

/**
 * @brief Load an advert request into the advert web view.
 * @param URL The advert request URL string.
 * @param parameters The request parameters.
 */
- (void)loadRequestWithURL:(nullable NSString *)URL parameters:(nullable NSDictionary *)parameters;

/**
 * @brief Notify the controller that the installed-application list closed.
 */
- (void)appliListClosed;

/**
 * @brief Clear the controller's SDK callback delegate.
 */
- (void)clearDelegate;

/**
 * @brief Tear down the advert-screen view.
 */
- (void)viewDealloc;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
