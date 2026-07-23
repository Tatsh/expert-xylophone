/** @file
 * A purchased-tune row cell for the store manage page. It carries the download or delete action
 * button whose tag encodes the tune's section and row.
 *
 * Minimal stub: only the surface @c RBStoreManageViewController messages is declared here; the
 * full class is reconstructed separately.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c RBStoreManageCell, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A purchased-tune row cell carrying a download/delete action button.
 */
@interface RBStoreManageCell : UITableViewCell

/**
 * @brief The row's download or delete action button.
 */
@property(nonatomic, strong, nullable) UIButton *button;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
