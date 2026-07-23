/** @file
 * A paged flow layout that adds a per-page content inset to a horizontal grid of equal-sized cells.
 * Used by the customize and unlock collection views to lay their item cells out one screen-page at
 * a time.
 *
 * Speculative interface: only the members other classes use are declared here. Reconstructed from
 * Ghidra project rb458, program rb458 (class @c RBMusicGridLayout, image base 0x100000000).
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A paged, per-page-inset grid flow layout.
 */
@interface RBMusicGridLayout : UICollectionViewFlowLayout

/**
 * @brief The content inset applied within each page.
 * @ghidraAddress 0x16e110 (getter)
 * @ghidraAddress 0x16e128 (setter)
 */
@property(nonatomic, assign) UIEdgeInsets pageInset;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
