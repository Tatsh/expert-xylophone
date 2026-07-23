/** @file
 * The phone-layout pack detail controller pushed on the store's navigation stack. This is a minimal
 * stub declaring only the surface @c RBStorePageViewController relies on; the full controller is
 * reconstructed separately.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c RBStoreDetailViewController,
 * image base 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

#import "StorePackView.h"

@class StorePackInfo;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The phone-layout pack detail controller.
 */
@interface RBStoreDetailViewController : UIViewController

/**
 * @brief The delegate that drives the detail's purchase and download actions.
 */
@property(nonatomic, weak, nullable) id<StorePackViewDelegate> delegate;

/**
 * @brief The pack the detail displays.
 */
@property(nonatomic, strong, nullable) StorePackInfo *packInfo;

/**
 * @brief Set the purchase button label to the installing state.
 */
- (void)setButtonTextInstalling;

/**
 * @brief Set the purchase button label to the installed state.
 */
- (void)setButtonTextInstalled;

/**
 * @brief Recompute the purchase button label from the current ownership and download state.
 */
- (void)selfCheckButtonText;

/**
 * @brief Set the detail's purchase state.
 * @param state The purchase state.
 */
- (void)setPurchaseState:(NSInteger)state;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
