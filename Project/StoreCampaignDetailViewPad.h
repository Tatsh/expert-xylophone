/** @file
 * The in-place campaign item detail overlay used on the pad. It presents a campaign item's full
 * detail behind a dimming cover.
 *
 * Minimal stub for the surface @c RBCampaignViewController messages; the full class is
 * reconstructed separately. Reconstructed from Ghidra project rb458, program rb458 (class
 * @c StoreCampaignDetailViewPad, image base 0x100000000).
 */

#import <UIKit/UIKit.h>

@class StoreCampaignItemInfo;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The pad campaign item detail overlay.
 */
@interface StoreCampaignDetailViewPad : UIView

/**
 * @brief Binds a campaign item and row index to the overlay.
 * @param info The campaign item to display.
 * @param tag The row index.
 */
- (void)setInfo:(nullable StoreCampaignItemInfo *)info tag:(NSInteger)tag;
/**
 * @brief Reveals the bound campaign item's detail once the open animation completes.
 */
- (void)showItemInfo;
/**
 * @brief Clears the bound campaign item.
 */
- (void)removeItemInfo;
/**
 * @brief Cancels any in-flight artwork or sample loading in the overlay.
 */
- (void)cancelLoading;
/**
 * @brief Stops any playing audio sample in the overlay.
 */
- (void)sampleStop;
/**
 * @brief Marks the overlay's install as complete so it reflects the downloaded state.
 * @param downloadFlag @c YES once the item has finished downloading.
 */
- (void)setDownloadFlag:(BOOL)downloadFlag;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
