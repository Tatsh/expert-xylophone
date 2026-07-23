/** @file
 * A phone pack-table cell displaying a single extend-note product.
 *
 * Minimal interface; the full class is reconstructed separately.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c StoreExtendNoteCellPhone, image
 * base 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>

@class StoreExtendNoteInfo;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A phone pack-table cell displaying a single extend-note product.
 */
@interface StoreExtendNoteCellPhone : UITableViewCell

/**
 * @brief The layer the product artwork is drawn into.
 */
@property(nonatomic, strong, nullable) CALayer *artworkLayer;
/**
 * @brief The product-list index this cell displays.
 */
@property(nonatomic, assign) NSInteger index;

/**
 * @brief Loads the given extend-note record into the cell at the given product-list index.
 * @param info The extend-note record to display.
 * @param index The product-list index of the record.
 */
- (void)loadExtendNoteInfo:(nullable StoreExtendNoteInfo *)info index:(NSInteger)index;
/**
 * @brief Sets the cell's background image.
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
