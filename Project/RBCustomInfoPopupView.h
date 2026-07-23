/** @file
 * The confirmation popup shown when the player taps an unlockable item. It presents the item's
 * artwork, its lime-point cost, and yes/no buttons that confirm or cancel the unlock.
 *
 * Speculative interface: only the members @c RBUnlockView uses are declared here. Reconstructed from
 * Ghidra project rb458, program rb458 (class @c RBCustomInfoPopupView, image base 0x100000000).
 */

#import <UIKit/UIKit.h>

@class RBNumberLabel;
@class RBUnlockPackageItemData;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The unlock-confirmation popup.
 */
@interface RBCustomInfoPopupView : UIView

/**
 * @brief Create the popup with the given frame.
 * @param frame The view's frame rectangle.
 * @return The initialised view, or @c nil.
 */
- (nullable instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief Fade the popup in.
 */
- (void)showAnimation;

/**
 * @brief Fade the popup out and remove it.
 */
- (void)hideAnimation;

/**
 * @brief The item being confirmed.
 */
@property(strong, nonatomic, nullable) RBUnlockPackageItemData *itemData;

/**
 * @brief The label showing the player's current lime-point balance.
 */
@property(strong, nonatomic, nullable) RBNumberLabel *pointLabel;

/**
 * @brief The confirm button.
 */
@property(strong, nonatomic, nullable) UIButton *yesButton;

/**
 * @brief The cancel button.
 */
@property(strong, nonatomic, nullable) UIButton *noButton;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
