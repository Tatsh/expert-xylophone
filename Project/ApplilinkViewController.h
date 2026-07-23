/** @file
 * Minimal reconstructed interface for the Applilink advert SDK's @c ApplilinkViewController.
 *
 * @c ApplilinkViewController is the SDK's @c UIViewController that owns and presents the native
 * App Store product page through @c SKStoreProductViewController and reports the store lifecycle
 * back to its @c sdkDelegate. Only the members that @c ApplilinkStore messages are declared here.
 * Reconstructed from Ghidra project rb458, program rb458.
 */

#import <UIKit/UIKit.h>

#import "ApplilinkParameters.h"
#import "ApplilinkStore.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The SDK view controller that presents the App Store product page.
 */
@interface ApplilinkViewController : UIViewController

/**
 * @brief The delegate notified of the store lifecycle notices.
 */
@property(weak, nonatomic, nullable) id<SdkViewDelegate> sdkDelegate;

/**
 * @brief Present the App Store product page for an application.
 * @param appStoreId The App Store application identifier.
 * @param appParam The request parameters.
 * @param delegate The store lifecycle delegate.
 * @ghidraAddress 0x213810
 */
- (void)showSKStore:(nullable NSString *)appStoreId
           appParam:(nullable ApplilinkParameters *)appParam
           delegate:(nullable id<SdkViewDelegate>)delegate;

/**
 * @brief Dismiss the presented App Store product page and post the close notices.
 * @ghidraAddress 0x213f3c
 */
- (void)productViewControllerDidFinish;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
