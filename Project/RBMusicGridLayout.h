/** @file
 * A paged collection-view layout that arranges equal-sized item cells into a grid of whole
 * screen-pages, scrolling horizontally one page at a time. Unlike @c UICollectionViewFlowLayout,
 * this is a direct @c UICollectionViewLayout subclass that reimplements the grid metrics itself:
 * it derives a column and row count from the page (collection-view bounds) size, the per-item
 * size, the inter-item and line spacing, and a per-page content inset, then distributes any
 * leftover horizontal and vertical slack evenly as extra spacing between cells. It is used by the
 * customize and unlock collection views (via @c RBCollectionView) to lay their @c RBMusicCell
 * items out a page at a time.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c RBMusicGridLayout, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A paged grid layout that packs equal-sized cells into horizontally-scrolling pages.
 */
@interface RBMusicGridLayout : UICollectionViewLayout

/**
 * @brief The minimum spacing between successive rows of cells.
 * @ghidraAddress 0x16e0a8 (getter)
 * @ghidraAddress 0x16e0b8 (setter)
 */
@property(nonatomic, assign) CGFloat minimumLineSpacing;

/**
 * @brief The minimum spacing between successive items within a row.
 * @ghidraAddress 0x16e0c8 (getter)
 * @ghidraAddress 0x16e0d8 (setter)
 */
@property(nonatomic, assign) CGFloat minimumInteritemSpacing;

/**
 * @brief The size of each item cell.
 * @ghidraAddress 0x16e0e8 (getter)
 * @ghidraAddress 0x16e0fc (setter)
 */
@property(nonatomic, assign) CGSize itemSize;

/**
 * @brief The content inset applied within each page.
 * @ghidraAddress 0x16e110 (getter)
 * @ghidraAddress 0x16e128 (setter)
 */
@property(nonatomic, assign) UIEdgeInsets pageInset;

/**
 * @brief The number of rows that fit on a single page, derived during @c -prepareLayout.
 * @ghidraAddress 0x16e140 (getter)
 * @ghidraAddress 0x16e150 (setter)
 */
@property(nonatomic, assign) NSInteger rowCount;

/**
 * @brief The number of columns that fit on a single page, derived during @c -prepareLayout.
 * @ghidraAddress 0x16e160 (getter)
 * @ghidraAddress 0x16e170 (setter)
 */
@property(nonatomic, assign) NSInteger colCount;

/**
 * @brief The total number of pages, derived during @c -prepareLayout.
 * @ghidraAddress 0x16e180 (getter)
 * @ghidraAddress 0x16e190 (setter)
 */
@property(nonatomic, assign) NSInteger pageCount;

/**
 * @brief The number of items that fit on a single page (@c rowCount times @c colCount).
 * @ghidraAddress 0x16e1a0 (getter)
 * @ghidraAddress 0x16e1b0 (setter)
 */
@property(nonatomic, assign) NSInteger pageItemCount;

/**
 * @brief The scrolling direction of the layout.
 * @ghidraAddress 0x16e1c0 (getter)
 * @ghidraAddress 0x16e1d0 (setter)
 */
@property(nonatomic, assign) UICollectionViewScrollDirection scrollDirection;

/**
 * @brief The size of a single page, taken from the collection view's bounds.
 * @ghidraAddress 0x16e1e0 (getter)
 * @ghidraAddress 0x16e1f4 (setter)
 */
@property(nonatomic, assign) CGSize pageSize;

/**
 * @brief The overall content size, spanning every page horizontally.
 * @ghidraAddress 0x16e208 (getter)
 * @ghidraAddress 0x16e21c (setter)
 */
@property(nonatomic, assign) CGSize contentSize;

/**
 * @brief Per-page rectangles. Declared by the class but not populated by the layout pass.
 * @ghidraAddress 0x16e230 (getter)
 * @ghidraAddress 0x16e240 (setter)
 */
@property(nonatomic, strong, nullable) NSArray<NSValue *> *pageRects;

/**
 * @brief The total number of items across every section, cached during @c -prepareLayout.
 * @ghidraAddress 0x16e278 (getter)
 * @ghidraAddress 0x16e288 (setter)
 */
@property(nonatomic, assign) NSInteger itemCount;

/**
 * @brief The computed layout attributes, one per item, produced by @c -prepareLayout.
 * @ghidraAddress 0x16e298 (getter)
 * @ghidraAddress 0x16e2a8 (setter)
 */
@property(nonatomic, strong, nullable) NSMutableArray<UICollectionViewLayoutAttributes *> *layouts;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
