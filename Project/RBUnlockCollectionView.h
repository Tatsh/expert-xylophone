/** @file
 * The horizontal experience-item picker for a single unlock package. Each package in the unlock
 * catalogue is rendered as one of these views inside the @c RBUnlockView scroll view; it stacks a
 * framed backdrop, the package title, and a paged @c RBCollectionView of @c RBUnlockCollectionCell
 * items, and reports taps back to its delegate.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c RBUnlockCollectionView, image
 * base 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

#import "RBCollectionView.h"

@class RBUnlockCollectionCell;
@class RBUnlockCollectionView;
@class RBUnlockPackageData;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Delegate notified when an item in an @c RBUnlockCollectionView is tapped.
 */
@protocol RBUnlockCollectionViewDelegate <NSObject>

/**
 * @brief The player tapped an enabled, interactive item cell.
 * @param view The collection view whose item was tapped.
 * @param cell The tapped cell.
 * @ghidraAddress 0x18dedc
 */
- (void)didSelectView:(RBUnlockCollectionView *)view selectedCell:(RBUnlockCollectionCell *)cell;

@end

/**
 * @brief The per-package experience-item picker.
 */
@interface RBUnlockCollectionView
    : UIView <RBCollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegate>

/**
 * @brief Create the picker for a single unlock package and build its subviews.
 * @param frame The view's frame rectangle.
 * @param experiencePackageData The package whose items are laid out.
 * @return The initialised view, or @c nil.
 * @ghidraAddress 0x18be3c
 */
- (nullable instancetype)initWithFrame:(CGRect)frame
                 experiencePackageData:(nullable RBUnlockPackageData *)experiencePackageData;

/**
 * @brief Build the framed backdrop, the package title label, the paged collection view, and (on the
 * non-default font) the page control, then reload the item content.
 * @ghidraAddress 0x18bf24
 */
- (void)setupView;

/**
 * @brief Refresh the title and, on the Limelight theme, its per-package colour, then reload the
 * collection view's items.
 * @ghidraAddress 0x18ce6c
 */
- (void)reloadData;

/**
 * @brief Update the page control's page count and visibility from the collection view's content and
 * frame width.
 * @param collectionView The collection view that finished laying out.
 * @ghidraAddress 0x18d274
 */
- (void)didLayoutSubviews:(RBCollectionView *)collectionView;

/**
 * @brief Bind the cell to its item and update its unlock, badge, and interaction state from
 * @c RBExperienceData and @c RBMusicManager.
 * @param cell The cell to reconfigure.
 * @ghidraAddress 0x18d380
 */
- (void)configureCell:(RBUnlockCollectionCell *)cell;

/**
 * @brief The delegate notified of item taps.
 */
@property(weak, nonatomic, nullable) id<RBUnlockCollectionViewDelegate> delegate;

/**
 * @brief The framed backdrop behind the title and items.
 */
@property(strong, nonatomic, nullable) UIImageView *backgroundView;

/**
 * @brief The package title label.
 */
@property(strong, nonatomic, nullable) UILabel *titleLabel;

/**
 * @brief The paged collection view laying out the item cells.
 */
@property(strong, nonatomic, nullable) RBCollectionView *collectionView;

/**
 * @brief The page control shown beneath the items on the non-default font.
 */
@property(strong, nonatomic, nullable) UIPageControl *pageControl;

/**
 * @brief The package whose items this picker lays out.
 */
@property(strong, nonatomic, nullable) RBUnlockPackageData *experiencePackageData;

/**
 * @brief The package's item entries, mirrored from @c experiencePackageData for the data source.
 */
@property(strong, nonatomic, nullable) NSArray *items;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
