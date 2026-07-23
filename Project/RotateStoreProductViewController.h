/** @file
 * Reconstructed interface for the Applilink advert SDK's @c RotateStoreProductViewController.
 *
 * @c RotateStoreProductViewController is a thin @c SKStoreProductViewController subclass that the
 * SDK's @c ApplilinkViewController presents to show the native App Store product page. It exists
 * only to force the store sheet to permit every interface orientation, overriding the rotation
 * callbacks to report itself as freely rotatable. It declares no ivars or properties of its own.
 * Reconstructed from Ghidra project rb458, program rb458.
 */

#import <StoreKit/StoreKit.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A rotation-forcing @c SKStoreProductViewController subclass used to host the store sheet.
 */
@interface RotateStoreProductViewController : SKStoreProductViewController

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
