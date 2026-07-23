/** @file
 * The pad-layout two-up pack table cell, holding a left and a right pack tile. This is a minimal
 * stub declaring only the surface @c RBStorePageViewController relies on; the full cell class is
 * reconstructed separately.
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
 */
@property(nonatomic, strong, nullable) StorePackView *leftPackView;

/**
 * @brief The right pack tile.
 */
@property(nonatomic, strong, nullable) StorePackView *rightPackView;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
