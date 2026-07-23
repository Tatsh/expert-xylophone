/** @file
 * A single customize category's item grid, hosted by @c RBCustomSelectView. Each instance shows one
 * customization category (theme background music, tap shot, explosion, frame, background, note,
 * gauge, or timing) inside a framed background. Most categories present a paged
 * @c RBCollectionView of @c RBCustomSelectCollectionCell items with a @c UIPageControl; the note and
 * gauge categories instead lay out fixed image buttons, and the shot, explosion, and timing
 * categories add a slider control.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c RBCustomSelectCollectionView,
 * image base 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

#import "RBCollectionView.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The customization category a @c RBCustomSelectCollectionView presents.
 *
 * The value is passed to @c -initWithFrame:customizeType: and stored in the backing @c customizeType
 * ivar. It drives which catalogue of items the grid loads and which control layout it builds.
 * @c RBCustomSelectView builds one grid per category; the timing category is number @c 8 because
 * number @c 7 is unused.
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
 * @brief A single customize category's item grid.
 *
 * The class conforms to the collection view data source and delegate protocols for the categories
 * that host an @c RBCollectionView, and to @c RBCollectionView's own custom delegate for the paged
 * layout callback.
 */
@interface RBCustomSelectCollectionView
    : UIView <UICollectionViewDelegate, UICollectionViewDataSource, RBCollectionViewDelegate>

/**
 * @brief Create the grid with the given frame and customization category.
 * @param frame The grid's frame rectangle.
 * @param customizeType The category the grid presents.
 * @return The initialised grid, or @c nil.
 * @ghidraAddress 0x1555d8
 */
- (nullable instancetype)initWithFrame:(CGRect)frame
                         customizeType:(RBCustomizeItemType)customizeType;

/**
 * @brief Build the framed background and the category's controls (collection view, page control,
 *        buttons, or slider).
 * @ghidraAddress 0x155670
 */
- (void)setupView;

/**
 * @brief Rebuild the item catalogue for the current theme and reload the collection view.
 * @ghidraAddress 0x157bec
 */
- (void)reloadData;

/**
 * @brief Action for a note-size button: commit the tapped note type and refresh the button
 *        highlights.
 * @param sender The tapped note-size button.
 * @ghidraAddress 0x1574f8
 */
- (void)noteSizeTap:(nullable id)sender;

/**
 * @brief Action for a gauge-style button: commit the tapped gauge style and refresh the button
 *        highlights.
 * @param sender The tapped gauge-style button.
 * @ghidraAddress 0x15720c
 */
- (void)gaugeStyleTap:(nullable id)sender;

/**
 * @brief Action for a slider control: commit the shot volume, effect size, or judge-timing value
 *        keyed by the slider's tag.
 * @param sender The slider that changed, tagged with its @c RBCustomizeItemType.
 * @ghidraAddress 0x1577e4
 */
- (void)sliderChanged:(nullable id)sender;

/**
 * @brief The framed background image behind the category's controls.
 */
@property(strong, nonatomic, nullable) UIImageView *backgroundView;

/**
 * @brief The paged collection view for the categories that present a scrolling item grid.
 */
@property(strong, nonatomic, nullable) RBCollectionView *collectionView;

/**
 * @brief The page indicator shown below the collection view.
 */
@property(strong, nonatomic, nullable) UIPageControl *pageControl;

/**
 * @brief The item identifiers currently offered, boxed as @c NSNumber values.
 */
@property(strong, nonatomic, nullable) NSMutableArray<NSNumber *> *items;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
