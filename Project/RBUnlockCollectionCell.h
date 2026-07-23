/** @file
 * A single unlockable-item cell inside an @c RBUnlockCollectionView. It layers the item's artwork,
 * a lock/unlock frame, a dimming overlay for unaffordable items, a "new" badge, an unlocked-state
 * overlay, and a point-cost label, and carries the item's model data. Setting @c itemData
 * asynchronously loads the item's artwork (downloading a music item's cover through an
 * @c ImageDownloader when needed).
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c RBUnlockCollectionCell, image
 * base 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

@class ImageDownloader;
@class RBNumberLabel;
@class RBUnlockPackageItemData;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief An unlockable-item cell.
 */
@interface RBUnlockCollectionCell : UICollectionViewCell

/**
 * @brief Create the cell and build its artwork, frame, dimming, point-label, badge, and unlock
 * subviews.
 *
 * Calls through to @c super, then adds the layered subviews to the cell's background view: the
 * artwork image view, the (initially hidden) frame overlay, a black rounded dimming view whose
 * alpha reflects the interactive state, the point-cost @c RBNumberLabel (drawn with the lime glyph
 * style), the (initially hidden) "new" badge, and the (initially hidden) unlock overlay. The cell
 * starts enabled and claims exclusive touch.
 * @param frame The cell's frame rectangle.
 * @return The initialised cell, or @c nil.
 * @ghidraAddress 0x18fa28
 */
- (nullable instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief Lay out the framed backdrop, artwork, dimming, point-label, unlock, and badge subviews
 * relative to the cell and to one another.
 * @ghidraAddress 0x191130
 */
- (void)layoutSubviews;

/**
 * @brief Reset the cell for reuse: re-enable it, reveal the point label, clear the artwork, and hide
 * the unlock overlay.
 * @ghidraAddress 0x1917fc
 */
- (void)prepareForReuse;

/**
 * @brief Track the highlight state, dimming the interactive overlay while the enabled cell is
 * pressed.
 * @param highlighted Whether the cell is currently highlighted.
 * @ghidraAddress 0x190300
 */
- (void)setHighlighted:(BOOL)highlighted;

/**
 * @brief The item model backing this cell.
 *
 * Setting a new item stores it, then asynchronously loads its artwork into @c imageView, sizes the
 * artwork and frame views by font variant, and sets @c pointLabel to the item's point cost. For a
 * music item the placeholder artwork is shown immediately and the cover is downloaded through
 * @c imageDownloader.
 * @ghidraAddress 0x192640 (getter)
 * @ghidraAddress 0x190448 (setter)
 */
@property(strong, nonatomic, nullable) RBUnlockPackageItemData *itemData;

/**
 * @brief The cell's artwork image view.
 * @ghidraAddress 0x192558 (getter)
 * @ghidraAddress 0x192568 (setter)
 */
@property(strong, nonatomic, nullable) UIImageView *imageView;

/**
 * @brief The lock/unlock frame overlay drawn over the artwork.
 * @ghidraAddress 0x1925a0 (getter)
 * @ghidraAddress 0x1925b0 (setter)
 */
@property(strong, nonatomic, nullable) UIImageView *frameImageView;

/**
 * @brief The point-cost label, drawn with the lime digit-glyph style.
 * @ghidraAddress 0x1925f8 (getter)
 * @ghidraAddress 0x192608 (setter)
 */
@property(strong, nonatomic, nullable) RBNumberLabel *pointLabel;

/**
 * @brief The "new" badge overlay, shown while an unlocked music track is still un-downloaded.
 * @ghidraAddress 0x192650 (getter)
 * @ghidraAddress 0x192660 (setter)
 */
@property(strong, nonatomic, nullable) UIImageView *badgeView;

/**
 * @brief The overlay revealed once the item has been unlocked.
 * @ghidraAddress 0x192698 (getter)
 * @ghidraAddress 0x1926a8 (setter)
 */
@property(strong, nonatomic, nullable) UIImageView *unlockView;

/**
 * @brief The black rounded dimming view whose alpha reflects the interactive state.
 * @ghidraAddress 0x1926e0 (getter)
 * @ghidraAddress 0x1926f0 (setter)
 */
@property(strong, nonatomic, nullable) UIView *disableView;

/**
 * @brief The downloader that fetches a music item's cover artwork.
 * @ghidraAddress 0x192728 (getter)
 * @ghidraAddress 0x192738 (setter)
 */
@property(strong, nonatomic, nullable) ImageDownloader *imageDownloader;

/**
 * @brief The index path the cell is currently laid out at.
 * @ghidraAddress 0x192510 (getter)
 * @ghidraAddress 0x192520 (setter)
 */
@property(strong, nonatomic, nullable) NSIndexPath *indexPath;

/**
 * @brief Whether the cell may be tapped to unlock its item.
 *
 * Setting the value dims the interactive overlay and mirrors the flag onto
 * @c userInteractionEnabled.
 * @ghidraAddress 0x1925e8 (getter)
 * @ghidraAddress 0x1903b0 (setter)
 */
@property(nonatomic, assign) BOOL enabled;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
