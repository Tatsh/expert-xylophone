/** @file
 * The trailing copyright and terms rows in the phone-layout pack detail table, each a single
 * multi-line label. This is a minimal stub declaring only the surface
 * @c RBStoreDetailViewController relies on; the full cell class is reconstructed separately.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c StoreDetailCopyrightCell, image
 * base 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The copyright or terms row in the pack detail table.
 */
@interface StoreDetailCopyrightCell : UITableViewCell

/**
 * @brief The label carrying the copyright notice or terms text.
 */
@property(nonatomic, strong, nullable) UILabel *labelCopyright;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
