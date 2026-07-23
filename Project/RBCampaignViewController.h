/** @file
 * The campaign store page controller. It is the root controller of the store's campaign tab and is
 * an @c RBBaseViewController subclass owned through @c RBStoreTabController's @c campaignNavCtrl.
 * Only the surface that @c RBStoreTabController messages is declared here; the full class is
 * reconstructed separately.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c RBCampaignViewController, image
 * base 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

#import "RBBaseViewController.h"

@class RBStoreTabController;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The campaign store page, the campaign tab's root controller.
 */
@interface RBCampaignViewController : RBBaseViewController

/**
 * @brief Initialises the page for the given hosting store tab controller.
 * @param parent The store tab controller that hosts the page.
 * @return The initialised controller.
 */
- (nullable instancetype)initWithParent:(nullable RBStoreTabController *)parent;

/**
 * @brief Forces the campaign detail view open for a queued campaign open request.
 */
- (void)forceOpenCampaignDetailView;

/**
 * @brief Reloads the campaign unlock table after a purchase, download, or deletion.
 * @ghidraAddress 0x1ff038
 */
- (void)refreshUnlockTable;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
