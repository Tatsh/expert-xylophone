/** @file
 * The genre-select list controller presented from the store page. This is a minimal stub declaring
 * only the surface @c RBStorePageViewController relies on; the full controller is reconstructed
 * separately.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c RBStoreGenreViewController, image
 * base 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

@class RBStorePackList;
@class RBStorePageViewController;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The genre-select list controller.
 */
@interface RBStoreGenreViewController : UIViewController

/**
 * @brief The pack-list model whose genres are listed.
 */
@property(nonatomic, weak, nullable) RBStorePackList *packListCtrl;

/**
 * @brief The store page that presented the controller.
 */
@property(nonatomic, weak, nullable) RBStorePageViewController *storeViewCtrl;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
