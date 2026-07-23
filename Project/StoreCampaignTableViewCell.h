/** @file
 * The campaign store list cell. It renders a campaign item's banner artwork and action button.
 *
 * Minimal stub for the surface @c RBCampaignViewController messages; the full class is
 * reconstructed separately. Reconstructed from Ghidra project rb458, program rb458 (class
 * @c StoreCampaignTableViewCell, image base 0x100000000).
 */

#import <UIKit/UIKit.h>

@class StoreCampaignItemInfo;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief One campaign store list cell.
 */
@interface StoreCampaignTableViewCell : UITableViewCell

/**
 * @brief The banner-artwork image view.
 */
@property(nonatomic, strong, nullable) UIImageView *artworkView;

/**
 * @brief The row height for the given device layout.
 * @param isPad Whether the pad layout is active.
 * @return The cell height in points.
 */
+ (CGFloat)cellHeight:(BOOL)isPad;

/**
 * @brief Initialises the cell for the given device layout, reuse identifier, and row tag.
 * @param isPad Whether the pad layout is active.
 * @param reuseIdentifier The cell reuse identifier.
 * @param tag The row index.
 * @return The initialised cell.
 */
- (nullable instancetype)initWithDeviceType:(BOOL)isPad
                            reuseIdentifier:(nullable NSString *)reuseIdentifier
                                        tag:(int)tag;
/**
 * @brief Binds a campaign item and row index to the cell.
 * @param info The campaign item to display.
 * @param tag The row index.
 */
- (void)setInfo:(nullable StoreCampaignItemInfo *)info tag:(int)tag;
/**
 * @brief The artwork frame size for the given device layout.
 * @param isPad Whether the pad layout is active.
 * @return The artwork size in points.
 */
- (CGSize)getItemSize:(BOOL)isPad;
/**
 * @brief Sets the banner artwork image after its download finishes.
 * @param artwork The downloaded banner image.
 */
- (void)setArtwork:(nullable UIImage *)artwork;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
