/** @file
 * The song-pack store page controller. It is the root controller of the store's first tab (the
 * pack store) and is an @c RBBaseViewController subclass owned through @c RBStoreTabController's
 * @c mainNavCtrl. Only the surface that @c RBStoreTabController messages is declared here; the
 * full class is reconstructed separately.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c RBStorePageViewController,
 * image base 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

#import "RBBaseViewController.h"

@class RBStoreTabController;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The song-pack store page, the first store tab's root controller.
 */
@interface RBStorePageViewController : RBBaseViewController

/**
 * @brief Initialises the page for the given hosting store tab controller.
 * @param parent The store tab controller that hosts the page.
 * @return The initialised controller.
 */
- (nullable instancetype)initWithParent:(nullable RBStoreTabController *)parent;

/**
 * @brief Stops the pack promotion presentation.
 */
- (void)stopPromotion;

/**
 * @brief Forces the pack detail view open for a queued pack open request.
 */
- (void)forceOpenPackDetailView;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
