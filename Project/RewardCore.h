/** @file
 * Minimal reconstructed interface for the Applilink reward SDK's private @c RewardCore singleton.
 *
 * @c RewardCore is the reward SDK's stateful core; the public @c RewardNetwork facade forwards every
 * call to @c [RewardCore sharedInstance]. Only the selectors @c RewardNetwork messages are declared
 * here. Reconstructed from Ghidra project rb458, program rb458.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The reward SDK's stateful core singleton.
 */
@interface RewardCore : NSObject

/**
 * @brief The shared @c RewardCore instance (created with @c dispatch_once).
 * @return The shared instance.
 * @ghidraAddress 0x2079d0
 */
+ (instancetype)sharedInstance;

/**
 * @brief The SDK initialisation flag: non-zero once the install record has been posted.
 * @return The initialisation flag.
 * @ghidraAddress 0x207a80
 */
@property(readonly, nonatomic) int initializeFlg;

/**
 * @brief Open the reward-advert screen inside @p parentView at @p adLocation, reporting to
 * @p delegate.
 * @param parentView The view that hosts the advert screen.
 * @param adLocation The ad-location identifier.
 * @param requestCode The request code forwarded to the SDK.
 * @param delegate The advert-screen delegate.
 * @ghidraAddress 0x20a0dc
 */
- (void)openAdScreenWithParentView:(nullable UIView *)parentView
                        adLocation:(nullable NSString *)adLocation
                       requestCode:(NSInteger)requestCode
                          delegate:(nullable id)delegate;

/**
 * @brief Close the reward-advert screen.
 * @ghidraAddress 0x20ac1c
 */
- (void)closeAdScreen;

/**
 * @brief Query the all-install flag asynchronously.
 * @param callback The completion block, called with the all-install flag and an optional error.
 * @ghidraAddress 0x208bf0
 */
- (void)allInstallFlgWithCallback:(nullable void (^)(NSInteger flg,
                                                     NSError *_Nullable error))callback;

/**
 * @brief Query the ad-display status asynchronously.
 * @param callback The completion block, called with the status dictionary and an optional error.
 * @ghidraAddress 0x208e48
 */
- (void)getAdDisplayStatusWithCallback:(nullable void (^)(NSDictionary *_Nullable status,
                                                          NSError *_Nullable error))callback;

/**
 * @brief Query the app-list (reward-advert) status asynchronously.
 * @param block The completion block, called with the ad-status code and an optional error.
 * @ghidraAddress 0x209a90
 */
- (void)getAppListStatusWithBlock:(nullable void (^)(NSInteger status,
                                                     NSError *_Nullable error))block;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
