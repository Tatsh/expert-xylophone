/** @file
 * The phone campaign item detail view controller, pushed from the campaign list.
 *
 * Minimal stub for the surface @c RBCampaignViewController messages; the full class is
 * reconstructed separately. Reconstructed from Ghidra project rb458, program rb458 (class
 * @c RBCampaignDetailViewController, image base 0x100000000).
 */

#import <UIKit/UIKit.h>

@class StoreCampaignItemInfo;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The phone campaign item detail view controller.
 */
@interface RBCampaignDetailViewController : UIViewController

/**
 * @brief Initialises the controller for the given campaign item.
 * @param itemInfo The campaign item to show.
 * @return The initialised controller.
 */
- (nullable instancetype)initWithItemInfo:(nullable StoreCampaignItemInfo *)itemInfo;
/**
 * @brief Rebinds the campaign item after its install completes so the detail reflects it.
 * @param itemInfo The updated campaign item.
 */
- (void)setInfo:(nullable StoreCampaignItemInfo *)itemInfo;
/**
 * @brief Sets the delegate that receives detail-view callbacks (the campaign page).
 * @param delegate The delegate.
 */
- (void)setDelegate:(nullable id)delegate;
/**
 * @brief Records the row index of the shown item in the campaign list.
 * @param workingIndex The row index.
 */
- (void)setWorkingIndex:(int)workingIndex;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
