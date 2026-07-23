/** @file
 * Reconstructed interface for the Applilink advert SDK's @c ApplilinkViewController.
 *
 * @c ApplilinkViewController is the SDK's @c UIViewController that owns and presents the native App
 * Store product page through a @c RotateStoreProductViewController (a rotation-forcing
 * @c SKStoreProductViewController subclass) and reports the store lifecycle back to its
 * @c sdkDelegate. It shows an @c ApplilinkIndicator overlay while the product page loads, is itself
 * the product view controller's @c SKStoreProductViewControllerDelegate, and fires the App Store
 * opened, close, closed, and load-failure notices to the delegate. Reconstructed from Ghidra
 * project rb458, program rb458.
 */

#import <StoreKit/StoreKit.h>
#import <UIKit/UIKit.h>

#import "ApplilinkIndicator.h"
#import "ApplilinkParameters.h"
#import "ApplilinkStore.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The SDK view controller that presents the App Store product page.
 */
@interface ApplilinkViewController : UIViewController <SKStoreProductViewControllerDelegate>

/**
 * @brief The delegate notified of the store lifecycle notices.
 *
 * Held weakly: the view controller forwards each notice to it but does not own it.
 */
@property(weak, nonatomic, nullable) id<SdkViewDelegate> sdkDelegate;

/**
 * @brief The advert request parameters of the in-flight store request.
 */
@property(copy, atomic, nullable) ApplilinkParameters *applilinkParams;

/**
 * @brief The loading overlay shown over the product page while it loads.
 */
@property(strong, nonatomic, nullable) ApplilinkIndicator *indicator;

/**
 * @brief Present the App Store product page for an application.
 *
 * Sizes the view to the main screen, adds a loading @c ApplilinkIndicator overlay, hosts the view
 * in the SDK main window, and asks a @c RotateStoreProductViewController to load the product
 * identified by @p appStoreId. On a successful load the product page is presented and the opened
 * notice fires; on a failed load the overlay is torn down and the load-failure notice fires.
 * @param appStoreId The App Store application identifier.
 * @param appParam The request parameters.
 * @param delegate The store lifecycle delegate.
 * @ghidraAddress 0x213810
 */
- (void)showSKStore:(nullable NSString *)appStoreId
           appParam:(nullable ApplilinkParameters *)appParam
           delegate:(nullable id<SdkViewDelegate>)delegate;

/**
 * @brief Dismiss the presented App Store product page with animation and post the close notices.
 *
 * The @c SKStoreProductViewControllerDelegate finish callback: fires the close notice, dismisses
 * the product page with animation, and on completion fires the closed notice.
 * @param viewController The product view controller that finished.
 * @ghidraAddress 0x213f3c
 */
- (void)productViewControllerDidFinish:(nullable SKStoreProductViewController *)viewController;

/**
 * @brief Dismiss the presented App Store product page without animation and post the close notices.
 *
 * Fires the close notice, dismisses the product page without animation, and on completion fires the
 * closed notice.
 * @ghidraAddress 0x214160
 */
- (void)productViewControllerDidFinish;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
