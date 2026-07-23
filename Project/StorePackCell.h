/** @file
 * The phone-layout single-pack table cell. This is a minimal stub declaring only the surface
 * @c RBStorePageViewController relies on; the full cell class is reconstructed separately.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c StorePackCell, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

@class StorePackInfo;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The phone-layout single-pack table cell.
 */
@interface StorePackCell : UITableViewCell

/**
 * @brief The layer whose contents hold the pack artwork.
 */
@property(nonatomic, strong, nullable) CALayer *artworkView;

/**
 * @brief The stretchable background image behind the cell.
 */
@property(nonatomic, strong, nullable) UIImage *bgImage;

/**
 * @brief The background tint colour.
 */
@property(nonatomic, strong, nullable) UIColor *bgColor;

/**
 * @brief Populate the cell from the given pack.
 * @param info The pack to display.
 */
- (void)loadPackInfo:(nullable StorePackInfo *)info;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
