/** @file
 * The pad two-up store list's table cell, holding a left and a right @c StorePackView pack tile
 * side by side across the cell's content view. Its @c initWithStyle:reuseIdentifier: builds both
 * tiles at fixed frames and adds them to the content view; @c prepareForReuse and @c dealloc reset
 * the tiles. Used by @c RBStorePageViewController.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c StoreTableCell, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

#import "StorePackView.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The pad-layout two-up pack table cell.
 */
@interface StoreTableCell : UITableViewCell

/**
 * @brief The left pack tile.
 * @ghidraAddress 0x1047ec (getter)
 * @ghidraAddress 0x1047fc (setter)
 */
@property(nonatomic, strong, nullable) StorePackView *leftPackView;

/**
 * @brief The right pack tile.
 * @ghidraAddress 0x104834 (getter)
 * @ghidraAddress 0x104844 (setter)
 */
@property(nonatomic, strong, nullable) StorePackView *rightPackView;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
