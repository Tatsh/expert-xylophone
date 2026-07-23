/** @file
 * Minimal reconstructed interface for the Applilink reward SDK's @c RewardWebViewController.
 *
 * @c RewardWebViewController hosts the reward advert web page inside the application. It is created
 * and driven by @c RewardCore, which is the only reconstructed caller, so only the members
 * @c RewardCore messages are declared here. Reconstructed from Ghidra project rb458, program rb458.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The in-application host controller for the reward advert web page.
 */
@interface RewardWebViewController : UIViewController

/**
 * @brief Set the parent view that hosts the advert web view.
 * @param parentView The hosting view.
 */
- (void)setParentView:(nullable UIView *)parentView;

/**
 * @brief Set whether the advert screen hides its navigation bar.
 * @param navigationBarHidden @c YES to hide the navigation bar.
 */
- (void)setNavigationBarHidden:(BOOL)navigationBarHidden;

/**
 * @brief Set the SDK delegate that receives web-view lifecycle notices.
 * @param sdkDelegate The SDK delegate.
 */
- (void)setSdkDelegate:(nullable id)sdkDelegate;

/**
 * @brief Load the reward advert page from a URL with request parameters.
 * @param url The reward advert page URL string.
 * @param parameters The request parameters.
 */
- (void)loadRequestWithURL:(nullable NSString *)url parameters:(nullable NSDictionary *)parameters;

/**
 * @brief Notify the controller that the advert list has been closed.
 */
- (void)appliListClosed;

/**
 * @brief Tear down the advert web view and release its resources.
 */
- (void)viewDealloc;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
