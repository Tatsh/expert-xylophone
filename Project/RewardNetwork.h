/** @file
 * The Applilink reward-network advert facade. A thin public wrapper over the private
 * @c RewardCore singleton and the @c ApplilinkConsts / @c ApplilinkNetworkError helpers: it opens
 * and closes the advert screen and forwards the ad-status, all-install-flag, and ad-display-status
 * queries.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c RewardNetwork, image base
 * @c 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The companion-application reward-advert facade over the Applilink SDK.
 *
 * The advert screen reports back through an informal delegate: the delegate implements
 * @c appListDidAppear, @c appListDidDisappear, and @c appListFailLoadWithError: as it needs them.
 * Every method forwards to @c [RewardCore sharedInstance] once @c ApplilinkConsts reports the SDK is
 * usable on this device.
 */
@interface RewardNetwork : NSObject

/**
 * @brief Open the reward-advert screen at the given ad location without a parent view, reporting to
 * @p delegate.
 * @param adLocation The ad-location identifier, such as @c "ADL_TOP".
 * @param requestCode The request code forwarded to the SDK.
 * @param delegate The advert-screen delegate.
 * @ghidraAddress 0x21f524
 */
+ (void)openAdScreenWithAdLocation:(nullable NSString *)adLocation
                       requestCode:(NSInteger)requestCode
                          delegate:(nullable id)delegate;

/**
 * @brief Open the reward-advert screen inside @p parentView at the given ad location, reporting to
 * @p delegate.
 * @param parentView The view that hosts the advert screen.
 * @param adLocation The ad-location identifier, such as @c "ADL_TOP".
 * @param delegate The advert-screen delegate.
 * @ghidraAddress 0x21f598
 */
+ (void)openAdScreenWithParentView:(nullable UIView *)parentView
                        adLocation:(nullable NSString *)adLocation
                          delegate:(nullable id)delegate;

/**
 * @brief Open the reward-advert screen inside @p parentView at the given ad location with a request
 * code, reporting to @p delegate.
 * @param parentView The view that hosts the advert screen.
 * @param adLocation The ad-location identifier, such as @c "ADL_TOP".
 * @param requestCode The request code forwarded to the SDK.
 * @param delegate The advert-screen delegate.
 * @ghidraAddress 0x21f60c
 */
+ (void)openAdScreenWithParentView:(nullable UIView *)parentView
                        adLocation:(nullable NSString *)adLocation
                       requestCode:(NSInteger)requestCode
                          delegate:(nullable id)delegate;

/**
 * @brief Close the reward-advert screen.
 * @ghidraAddress 0x21f808
 */
+ (void)closeAdScreen;

/**
 * @brief Query the all-install flag asynchronously, invoking @p callback with the flag and an error
 * when the SDK is unavailable.
 * @param callback The completion block, called with the all-install flag and an optional error.
 * @ghidraAddress 0x21f880
 */
+ (void)allInstallFlgWithCallback:(nullable void (^)(NSInteger flg,
                                                     NSError *_Nullable error))callback;

/**
 * @brief Query the ad-display status asynchronously, invoking @p callback with a status dictionary
 * (keyed @c "allInstallFlg" and @c "bannerDisplayStatus") and an error.
 * @param callback The completion block, called with the status dictionary and an optional error.
 * @ghidraAddress 0x21f9e0
 */
+ (void)getAdDisplayStatusWithCallback:(nullable void (^)(NSDictionary *_Nullable status,
                                                          NSError *_Nullable error))callback;

/**
 * @brief Query the reward-advert status asynchronously, invoking @p block with the status code and
 * an error when the SDK is unavailable.
 * @param block The completion block, called with the ad-status code and an optional error.
 * @ghidraAddress 0x21fc14
 */
+ (void)getAdStatusWithBlock:(nullable void (^)(NSInteger status, NSError *_Nullable error))block;

/**
 * @brief Hide or show the reward-advert navigation bar by forwarding to the reward core.
 * @param navigationBarHidden Whether the navigation bar should be hidden.
 * @ghidraAddress 0x21fd74
 */
+ (void)setNavigationBarHidden:(BOOL)navigationBarHidden;

/**
 * @brief The localised reward app-list navigation-bar title.
 * @return The localised title from the reward message bundle.
 * @ghidraAddress 0x21fdcc
 */
+ (nullable NSString *)getNavigationTitle;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
