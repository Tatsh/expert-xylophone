/** @file
 * Reconstructed interface for the Applilink advert SDK's @c ApplilinkStore.
 *
 * @c ApplilinkStore is the SDK's App Store product-page facade: a @c dispatch_once singleton that
 * drives an @c ApplilinkViewController, which in turn presents and dismisses the native App Store
 * product page through @c SKStoreProductViewController. The store instance is itself the
 * @c SdkViewDelegate of that view controller; it forwards the open, close, closed, and load-failure
 * notices on to the caller's own advert delegate. Reconstructed from Ghidra project rb458, program
 * rb458.
 */

#import <UIKit/UIKit.h>

#import "ApplilinkParameters.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The advert lifecycle callbacks the Applilink SDK reports to a caller's delegate.
 *
 * Every method is optional; the SDK guards each dispatch with @c -respondsToSelector:.
 */
@protocol SdkViewDelegate <NSObject>

@optional

/**
 * @brief Notify the delegate that the advert started.
 */
- (void)startedNotice;

/**
 * @brief Notify the delegate that the advert opened.
 */
- (void)openedNotice;

/**
 * @brief Notify the delegate that the advert closed.
 */
- (void)closeNotice;

/**
 * @brief Report an advert open failure to the delegate.
 * @param error The open error.
 */
- (void)failOpenNoticeWithError:(nullable NSError *)error;

/**
 * @brief Report an advert link failure to the delegate.
 * @param error The link error.
 */
- (void)failLinkNoticeWithError:(nullable NSError *)error;

/**
 * @brief Report that the delegate cancelled an advert open.
 * @param error The cancellation error.
 */
- (void)openCancelWithError:(nullable NSError *)error;

/**
 * @brief Notify the delegate that the App Store product page opened.
 * @param appParam The advert request parameters.
 */
- (void)appStoreOpenedNoticeWithAppParam:(nullable ApplilinkParameters *)appParam;

/**
 * @brief Notify the delegate that the App Store product page is about to close.
 * @param appParam The advert request parameters.
 */
- (void)appStoreCloseNoticeWithAppParam:(nullable ApplilinkParameters *)appParam;

/**
 * @brief Notify the delegate that the App Store product page closed.
 * @param appParam The advert request parameters.
 */
- (void)appStoreClosedNoticeWithAppParam:(nullable ApplilinkParameters *)appParam;

/**
 * @brief Report an App Store product-page load failure to the delegate.
 * @param error The load error.
 * @param appParam The advert request parameters.
 */
- (void)appStoreFailLoadNoticeWithError:(nullable NSError *)error
                               appParam:(nullable ApplilinkParameters *)appParam;

/**
 * @brief Notify the delegate that the App Store product page transitioned.
 * @param appParam The advert request parameters.
 */
- (void)appStoreTransitionNoticeWithAppParam:(nullable ApplilinkParameters *)appParam;

@end

/**
 * @brief The SDK's App Store product-page facade singleton.
 *
 * The singleton is the @c SdkViewDelegate of the @c ApplilinkViewController it creates, so it
 * receives the store notices and re-dispatches them to @c sdkDelegate.
 */
@interface ApplilinkStore : NSObject <SdkViewDelegate>

/**
 * @brief The caller's advert delegate, notified of the store lifecycle notices.
 *
 * Held weakly: the store forwards each notice to it but does not own it.
 */
@property(weak, nonatomic, nullable) id<SdkViewDelegate> sdkDelegate;

/**
 * @brief The advert request parameters of the in-flight store request.
 */
@property(copy, nonatomic, nullable) ApplilinkParameters *applilinkParams;

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
 * @return @c YES when the running system is iOS 6 or later (the only versions that can present the
 * store), @c NO otherwise.
 * @ghidraAddress 0x220650
 */
- (BOOL)showSKStore:(nullable NSString *)appStoreId
           appParam:(nullable ApplilinkParameters *)appParam
           delegate:(nullable id<SdkViewDelegate>)delegate;

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
