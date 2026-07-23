/** @file
 * The phone-layout table cell that hosts the promotion banner carousel (a @c StorePromotionView)
 * or the sample-play controls. The cell owns no state of its own; it exists only to relay its own
 * bounds to a tag-identified promotion subview during layout, so the carousel tracks the cell's
 * width as the table lays out.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c StorePromotionTableCell, image
 * base 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The phone-layout promotion / sample-controls table cell.
 *
 * The binary class declares no own ivars, properties, protocols, or class methods; its only method
 * is a @c -layoutSubviews override. The hosting @c RBStorePageViewController builds the cell with
 * the inherited @c -initWithStyle:reuseIdentifier: and adds either the promotion view or the
 * sample-controls to its content view.
 */
@interface StorePromotionTableCell : UITableViewCell

/**
 * @brief Lay out the cell, then size the hosted promotion view to the cell's bounds.
 *
 * After the superclass layout runs, the cell looks up the promotion subview by its tag in the
 * content view; if present, it sets that subview's frame to the content view's bounds and forwards
 * the cell's bounds size to the subview via @c -setImageViewSize:.
 * @ghidraAddress 0xff368
 */
- (void)layoutSubviews;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
