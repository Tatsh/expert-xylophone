/** @file
 * The Applilink reward-network advert facade. Only the class methods @c RBRewardListView calls are
 * declared here.
 *
 * Speculative interface reconstructed from Ghidra project rb458, program rb458 (class
 * @c RewardNetwork, image base 0x100000000). @ghidraAddress values are offsets relative to the
 * image base.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The companion-application reward-advert facade over the Applilink SDK.
 *
 * The advert screen reports back through an informal delegate: the delegate implements
 * @c appListDidAppear, @c appListDidDisappear, and @c appListFailLoadWithError: as it needs them.
 */
@interface RewardNetwork : NSObject

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
 * @brief Close the reward-advert screen.
 * @ghidraAddress 0x21f808
 */
+ (void)closeAdScreen;

/**
 * @brief Query the reward-advert status asynchronously, invoking @p block with the status code and
 * an error when the SDK is unavailable.
 * @param block The completion block, called with the ad-status code and an optional error.
 * @ghidraAddress 0x21fc14
 */
+ (void)getAdStatusWithBlock:(nullable void (^)(NSInteger status, NSError *_Nullable error))block;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
