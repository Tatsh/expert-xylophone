/** @file
 * A customize item cell shown in an @c RBCustomSelectCollectionView grid. It hosts a single image
 * button whose image is loaded asynchronously, and tracks whether its item is the current selection.
 *
 * Speculative interface: only the members @c RBCustomSelectCollectionView uses are declared here.
 * Reconstructed from Ghidra project rb458, program rb458 (class @c RBCustomSelectCollectionCell,
 * image base 0x100000000).
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A single customize item cell.
 */
@interface RBCustomSelectCollectionCell : UICollectionViewCell

/**
 * @brief The button that shows the item image and receives the selection highlight.
 */
@property(strong, nonatomic, nullable) UIButton *itemButton;

/**
 * @brief Whether this cell's item is the current selection. The binary's accessors are @c isSelected
 * and @c setIsSelected:, distinct from @c UICollectionViewCell's own @c selected pair.
 */
@property(nonatomic, assign, getter=isSelected, setter=setIsSelected:) BOOL itemSelected;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
