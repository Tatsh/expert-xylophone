/** @file
 * The horizontal experience-item picker for a single unlock package. Each package in the unlock
 * catalogue is rendered as one of these collection views inside the @c RBUnlockView scroll view; it
 * lays out an @c RBUnlockCollectionCell per unlockable item and reports taps back to its delegate.
 *
 * Speculative interface: only the members @c RBUnlockView uses are declared here. Reconstructed from
 * Ghidra project rb458, program rb458 (class @c RBUnlockCollectionView, image base 0x100000000).
 */

#import <UIKit/UIKit.h>

@class RBUnlockCollectionCell;
@class RBUnlockPackageData;
@class RBUnlockCollectionView;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Delegate notified when an item in an @c RBUnlockCollectionView is tapped.
 */
@protocol RBUnlockCollectionViewDelegate <NSObject>

/**
 * @brief The player tapped an item cell.
 * @param view The collection view whose item was tapped.
 * @param cell The tapped cell.
 */
- (void)didSelectView:(RBUnlockCollectionView *)view selectedCell:(RBUnlockCollectionCell *)cell;

@end

/**
 * @brief The per-package experience-item picker.
 */
@interface RBUnlockCollectionView : UIView

/**
 * @brief Create the picker for a single unlock package.
 * @param frame The view's frame rectangle.
 * @param experiencePackageData The package whose items are laid out.
 * @return The initialised view, or @c nil.
 */
- (nullable instancetype)initWithFrame:(CGRect)frame
                 experiencePackageData:(nullable RBUnlockPackageData *)experiencePackageData;

/**
 * @brief Refresh the given cell's presentation after its item's unlock state changes.
 * @param cell The cell to reconfigure.
 */
- (void)configureCell:(nullable RBUnlockCollectionCell *)cell;

/**
 * @brief The delegate notified of item taps.
 */
@property(weak, nonatomic, nullable) id<RBUnlockCollectionViewDelegate> delegate;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
