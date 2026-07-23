/** @file
 * A single unlockable-item cell inside an @c RBUnlockCollectionView. It shows the item's artwork,
 * a lock/unlock frame, and a "new" badge, and carries the item's model data.
 *
 * Speculative interface: only the members @c RBUnlockView uses are declared here. Reconstructed from
 * Ghidra project rb458, program rb458 (class @c RBUnlockCollectionCell, image base 0x100000000).
 */

#import <UIKit/UIKit.h>

@class RBUnlockPackageItemData;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief An unlockable-item cell.
 */
@interface RBUnlockCollectionCell : UICollectionViewCell

/**
 * @brief The item model backing this cell.
 */
@property(strong, nonatomic, nullable) RBUnlockPackageItemData *itemData;

/**
 * @brief The cell's artwork image view.
 */
@property(strong, nonatomic, nullable) UIImageView *imageView;

/**
 * @brief The lock/unlock frame overlay drawn over the artwork.
 */
@property(strong, nonatomic, nullable) UIImageView *frameImageView;

/**
 * @brief The "new" badge overlay, hidden once the item has been seen.
 */
@property(strong, nonatomic, nullable) UIImageView *badgeView;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
