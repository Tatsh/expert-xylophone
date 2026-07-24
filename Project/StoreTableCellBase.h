/** @file
 * The shared base table cell for the store list screens. It carries two @c StoreTableCellViewBase
 * product tiles (a left and a right slot) and, on construction, gives itself the store list's dark
 * neutral-grey background on both the cell and its content view and suppresses the selection
 * highlight. It does not build the tiles itself; the concrete subclasses do that. @c dealloc clears
 * each tile's delegate and @c prepareForReuse resets each tile. Its subclasses are @c StoreTableCell
 * (the pad two-up pack cell) and @c StorePackCell (the phone single-pack cell); a sibling base view,
 * @c StoreTableCellViewBase, is the tile type this cell hosts.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c StoreTableCellBase, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

@class StoreTableCellViewBase;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The shared base table cell for the store list screens.
 */
@interface StoreTableCellBase : UITableViewCell

/**
 * @brief The left product tile.
 * @ghidraAddress 0x42308 (getter)
 * @ghidraAddress 0x42318 (setter)
 */
@property(nonatomic, strong, nullable) StoreTableCellViewBase *leftView;

/**
 * @brief The right product tile.
 * @ghidraAddress 0x42350 (getter)
 * @ghidraAddress 0x42360 (setter)
 */
@property(nonatomic, strong, nullable) StoreTableCellViewBase *rightView;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
