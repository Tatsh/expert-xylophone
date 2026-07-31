/** @file
 * The pad two-up extend-note table cell, holding a left and a right @c StoreExtendNoteView
 * product view side by side across the cell's content view. Its @c initWithStyle:reuseIdentifier:
 * builds both views at fixed frames and adds them to the content view. Used by
 * @c RBStoreExtendPageViewController on the pad layout (the phone layout uses
 * @c StoreExtendNoteCellPhone instead).
 *
 * The class derives from @c StoreTableCellBase, which supplies the @c leftView and @c rightView
 * product tiles and the reuse and teardown hooks. The one method this cell defines is
 * @c initWithStyle:reuseIdentifier: (0xfdb8), whose super call confirms that base.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c StoreExtendNoteCell, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

#import "StoreExtendNoteView.h"
#import "StoreTableCellBase.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The pad-layout two-up extend-note table cell.
 */
@interface StoreExtendNoteCell : StoreTableCellBase

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
