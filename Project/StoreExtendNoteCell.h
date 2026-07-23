/** @file
 * The pad two-up extend-note table cell, holding a left and a right @c StoreExtendNoteCellView
 * product view side by side across the cell's content view. Its @c initWithStyle:reuseIdentifier:
 * builds both views at fixed frames and adds them to the content view. Used by
 * @c RBStoreExtendPageViewController on the pad layout (the phone layout uses
 * @c StoreExtendNoteCellPhone instead).
 *
 * In the binary the class derives from @c StoreTableCellBase, which is where the @c leftView,
 * @c rightView, @c setBgImage:, and @c setBgColor: members actually live; that base is not yet
 * reconstructed, so it is flattened into @c UITableViewCell here and its members are declared on
 * this cell (mirroring the sibling @c StoreTableCell). The one method the class itself defines is
 * @c initWithStyle:reuseIdentifier:.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c StoreExtendNoteCell, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

#import "StoreExtendNoteCellView.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The pad-layout two-up extend-note table cell.
 */
@interface StoreExtendNoteCell : UITableViewCell

/**
 * @brief The left product view.
 *
 * Inherited from @c StoreTableCellBase in the binary; declared here while that base is
 * not yet reconstructed.
 */
@property(nonatomic, strong, nullable) StoreExtendNoteCellView *leftView;

/**
 * @brief The right product view.
 *
 * Inherited from @c StoreTableCellBase in the binary; declared here while that base is
 * not yet reconstructed.
 */
@property(nonatomic, strong, nullable) StoreExtendNoteCellView *rightView;

/**
 * @brief Sets the cell's shared background image.
 *
 * Inherited from @c StoreTableCellBase in the binary; declared here while that base is
 * not yet reconstructed.
 * @param image The background image.
 */
- (void)setBgImage:(nullable UIImage *)image;

/**
 * @brief Sets the cell's background tint colour.
 *
 * Inherited from @c StoreTableCellBase in the binary; declared here while that base is
 * not yet reconstructed.
 * @param color The background tint colour.
 */
- (void)setBgColor:(nullable UIColor *)color;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
