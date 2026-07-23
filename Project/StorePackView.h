/** @file
 * A single pack tile in the pad two-up store list, and the delegate protocol it uses to report a
 * tap. This is a minimal stub declaring only the surface @c RBStorePageViewController relies on; the
 * full view class is reconstructed separately.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c StorePackView, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

@class StorePackInfo;
@class StorePackView;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Tap callbacks a @c StorePackView sends to its delegate.
 */
@protocol StorePackViewDelegate <NSObject>

@optional

/**
 * @brief Sent when a pack tile is tapped.
 * @param packView The tapped pack tile.
 */
- (void)packViewSelected:(StorePackView *)packView;

/**
 * @brief Sent by the pack detail view when it should be dismissed.
 */
- (void)detailViewClose;

/**
 * @brief Sent by the pack detail view to begin buying the given pack.
 * @param packInfo The pack to buy.
 */
- (void)detailViewStartPurchase:(StorePackInfo *)packInfo;

/**
 * @brief Sent by the pack detail view to re-download an already-purchased pack's tunes.
 * @param packInfo The pack to re-download.
 */
- (void)reDownloadPackMusics:(StorePackInfo *)packInfo;

/**
 * @brief Sent by the pack detail view to switch to the sequence-extension store for a tune.
 */
- (void)switchToSpecialStore;

@end

/**
 * @brief A single pack tile in the two-up pad store list.
 */
@interface StorePackView : UIView

/**
 * @brief The delegate notified when the tile is tapped.
 */
@property(nonatomic, weak, nullable) id<StorePackViewDelegate> delegate;

/**
 * @brief The flattened pack-list index this tile displays.
 */
@property(nonatomic, assign) NSUInteger index;

/**
 * @brief The stretchable background image behind the tile.
 */
@property(nonatomic, strong, nullable) UIImage *bgImage;

/**
 * @brief The tile's artwork image.
 */
@property(nonatomic, strong, nullable) UIImage *artwork;

/**
 * @brief Populate the tile from the given pack and its flattened list index.
 * @param info The pack to display.
 * @param index The flattened pack-list index.
 */
- (void)loadPackInfo:(nullable StorePackInfo *)info index:(NSInteger)index;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
