/** @file
 * The sort-order selector for the store manage page. Presented as a pushed controller on the phone
 * and inside a popover on the pad, it lets the player pick the tune list's sort order (download
 * order, artist reading, or title reading) and reports the choice back to its owning
 * @c RBStoreManageViewController.
 *
 * Minimal stub: only the surface @c RBStoreManageViewController messages is declared here; the
 * full class is reconstructed separately.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class
 * @c RBStoreManageSortViewController, image base 0x100000000). @ghidraAddress values are offsets
 * relative to the image base.
 */

#import <UIKit/UIKit.h>

@class RBStoreManageViewController;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The store manage page's sort-order selector.
 */
@interface RBStoreManageSortViewController : UIViewController

/**
 * @brief The manage page this selector reports its choice to, held weakly to avoid a retain cycle.
 */
@property(nonatomic, weak, nullable) RBStoreManageViewController *manageViewCtrl;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
