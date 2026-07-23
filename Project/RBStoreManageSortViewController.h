/** @file
 * The sort-order selector for the store manage page. Presented as a pushed controller on the phone
 * and inside a popover on the pad, it lists the tune list's sort orders in a table and reports the
 * chosen order back to its owning @c RBStoreManageViewController.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class
 * @c RBStoreManageSortViewController, image base 0x100000000). @ghidraAddress values are offsets
 * relative to the image base.
 */

#import <UIKit/UIKit.h>

#import "RBBaseViewController.h"

@class RBStoreManageViewController;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The store manage page's sort-order selector.
 *
 * A grouped-less @c UITableView lists the sort orders held in @c sortTitleList; selecting a row
 * tells the owning manage page to switch to that order through its @c switchToSort:title:
 * selector, then dismisses the selector through @c hideSortSelect:.
 */
@interface RBStoreManageSortViewController
    : RBBaseViewController <UITableViewDelegate, UITableViewDataSource>

/**
 * @brief Builds the sort-order table, sizes the popover content, and installs the table as the
 *        controller's view.
 *
 * Seeds @c sortTitleList with the four built-in sort-order titles when it is still empty, records
 * the row count in @c sortRuleCount, then builds an opaque, white, full-bleed table (the receiver
 * as both delegate and data source) and sets the preferred content size to a fixed width by the
 * row count times the per-row height, capped at a maximum.
 * @ghidraAddress 0x556e0
 */
- (void)loadView;

/**
 * @brief Sets the navigation title to the localised "sort" heading.
 * @param animated Whether the appearance is animated.
 * @ghidraAddress 0x55ca4
 */
- (void)viewWillAppear:(BOOL)animated;

/**
 * @brief The active sort-order index count, i.e. the number of rows and sort orders.
 * @ghidraAddress 0x563e0 (getter)
 * @ghidraAddress 0x563f0 (setter)
 */
@property(nonatomic, assign) NSUInteger sortRuleCount;
/**
 * @brief The sort-order titles shown in the table, one per row.
 * @ghidraAddress 0x56398 (getter)
 * @ghidraAddress 0x563a8 (setter)
 */
@property(nonatomic, strong, nullable) NSArray<NSString *> *sortTitleList;
/**
 * @brief The sort-order table.
 * @ghidraAddress 0x56350 (getter)
 * @ghidraAddress 0x56360 (setter)
 */
@property(nonatomic, strong, nullable) UITableView *tableView;
/**
 * @brief The manage page this selector reports its choice to.
 *
 * Held unretained (the binary's @c manageViewCtrl property is @c assign, and @c .cxx_destruct does
 * not release it); the manage page outlives the selector it owns.
 * @ghidraAddress 0x56330 (getter)
 * @ghidraAddress 0x56340 (setter)
 */
@property(nonatomic, assign, nullable) RBStoreManageViewController *manageViewCtrl;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
