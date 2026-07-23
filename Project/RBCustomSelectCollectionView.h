/** @file
 * A single customize category's item grid, hosted by @c RBCustomSelectView. Each instance shows one
 * customization category (theme background music, tap shot, explosion, frame, background, note,
 * gauge, or timing) as a scrolling collection of @c RBCustomSelectCollectionCell items.
 *
 * Speculative interface: only the members @c RBCustomSelectView uses are declared here.
 * Reconstructed from Ghidra project rb458, program rb458 (class @c RBCustomSelectCollectionView,
 * image base 0x100000000).
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The customization category a @c RBCustomSelectCollectionView presents.
 *
 * The value is passed to @c -initWithFrame:customizeType: and drives which catalogue of items the
 * grid loads. @c RBCustomSelectView builds one grid per category; the timing category is number
 * @c 8 because number @c 7 is unused.
 */
typedef NS_ENUM(NSInteger, RBCustomizeItemType) {
    RBCustomizeItemTypeBgm = 0,       /*!< The theme background-music category. */
    RBCustomizeItemTypeShot = 1,      /*!< The tap shot-sound category. */
    RBCustomizeItemTypeExplosion = 2, /*!< The explosion-effect category. */
    RBCustomizeItemTypeFrame = 3,     /*!< The frame category. */
    RBCustomizeItemTypeBg = 4,        /*!< The background category. */
    RBCustomizeItemTypeNote = 5,      /*!< The note-skin category. */
    RBCustomizeItemTypeGauge = 6,     /*!< The gauge category (non-default font layout only). */
    RBCustomizeItemTypeTiming = 8,    /*!< The judge-timing category. */
};

/**
 * @brief A single customize category's scrolling item grid.
 */
@interface RBCustomSelectCollectionView : UIView

/**
 * @brief Create the grid with the given frame and customization category.
 * @param frame The grid's frame rectangle.
 * @param customizeType The category the grid presents.
 * @return The initialised grid, or @c nil.
 */
- (nullable instancetype)initWithFrame:(CGRect)frame
                         customizeType:(RBCustomizeItemType)customizeType;

/**
 * @brief Reload the grid's item content.
 */
- (void)reloadData;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
