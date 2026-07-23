/** @file
 * The trailing copyright and terms rows in the phone-layout pack detail table, each a single
 * multi-line label. @c RBStoreDetailViewController dequeues this cell for both the copyright row and
 * the terms-of-use row, reusing the one class for both.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c StoreDetailCopyrightCell, image
 * base 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The copyright or terms row in the pack detail table.
 *
 * The cell holds a single word-wrapping label that renders either the pack's copyright notice or
 * the fixed terms-of-use sentence.
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
