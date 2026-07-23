/** @file
 * Minimal reconstructed interface for the Applilink SDK's @c ApplilinkStore.
 *
 * @c ApplilinkStore is the SDK's @c SKStoreProductViewController facade: a @c dispatch_once
 * singleton that presents and dismisses the native App Store product page through an
 * @c ApplilinkViewController. Only the members that @c ApplilinkCore messages are declared here.
 * Reconstructed from Ghidra project rb458, program rb458.
 */

#import <UIKit/UIKit.h>

#import "ApplilinkParameters.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The SDK's App Store product-page facade singleton.
 */
@interface ApplilinkStore : NSObject

/**
 * @brief The shared store singleton, created once via @c dispatch_once.
 * @return The shared @c ApplilinkStore instance.
 * @ghidraAddress 0x2205c0
 */
+ (instancetype)sharedInstance;

/**
 * @brief Present the App Store product page for an application on iOS 6 and later.
 * @param appStoreId The App Store application identifier.
 * @param appParam The request parameters.
 * @param delegate The advert delegate to notify.
 * @return @c YES when the store product page was presented.
 * @ghidraAddress 0x220650
 */
- (BOOL)showSKStore:(nullable NSString *)appStoreId
           appParam:(nullable ApplilinkParameters *)appParam
           delegate:(nullable id)delegate;

/**
 * @brief Dismiss any open App Store product page.
 * @ghidraAddress 0x2207e4
 */
- (void)closeSKStore;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
