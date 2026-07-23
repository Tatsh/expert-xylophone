/** @file
 * A pad pack-table cell hosting two extend-note product views (a left and a right half).
 *
 * Minimal interface; the full class is reconstructed separately.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c StoreExtendNoteCell, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

#import "StoreExtendNoteCellView.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A pad pack-table cell hosting two extend-note product views.
 */
@interface StoreExtendNoteCell : UITableViewCell

/**
 * @brief The left product view.
 */
@property(nonatomic, strong, nullable) StoreExtendNoteCellView *leftView;
/**
 * @brief The right product view.
 */
@property(nonatomic, strong, nullable) StoreExtendNoteCellView *rightView;

/**
 * @brief Sets the cell's shared background image.
 * @param image The background image.
 */
- (void)setBgImage:(nullable UIImage *)image;
/**
 * @brief Sets the cell's background tint colour.
 * @param color The background tint colour.
 */
- (void)setBgColor:(nullable UIColor *)color;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
