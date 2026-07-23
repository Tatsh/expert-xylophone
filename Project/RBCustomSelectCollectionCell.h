/** @file
 * A customize item cell shown in an @c RBCustomSelectCollectionView grid. It hosts a single image
 * button whose image is loaded asynchronously, plus a hidden selected-state overlay that flashes
 * when the cell's item becomes the current selection.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c RBCustomSelectCollectionCell,
 * image base 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A single customize item cell.
 */
@interface RBCustomSelectCollectionCell : UICollectionViewCell

/**
 * @brief Build the cell's background view, item button, and hidden selection overlay.
 * @param frame The cell's frame rectangle.
 * @return The initialised cell, or @c nil.
 * @ghidraAddress 0x6e320
 */
- (nullable instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief The button that shows the item image. User interaction is disabled; the enclosing
 *        collection view handles selection.
 */
@property(strong, nonatomic, nullable) UIButton *itemButton;

/**
 * @brief The overlay shown over the selected item; hidden unless the cell is selected.
 */
@property(strong, nonatomic, nullable) UIImageView *selectedImageView;

/**
 * @brief Whether this cell's item is the current selection. Setting it shows or hides
 *        @c selectedImageView and starts or clears its flash effect. The binary's accessors are
 *        @c isSelected and @c setIsSelected:, distinct from @c UICollectionViewCell's own
 *        @c selected pair.
 * @ghidraAddress 0x6e680
 */
@property(nonatomic, assign, getter=isSelected, setter=setIsSelected:) BOOL itemSelected;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
