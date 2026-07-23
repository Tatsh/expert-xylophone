/** @file
 * The campaign store list cell. It renders a campaign item's banner artwork over a shared pack
 * background, with a rounded, shadowed jacket placeholder that fades in once the banner download
 * finishes.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c StoreCampaignTableViewCell,
 * image base 0x100000000).
 */

#import <UIKit/UIKit.h>

@class StoreCampaignItemInfo;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief One campaign store list cell.
 *
 * The consumer @c RBCampaignViewController creates the cell with
 * @c initWithDeviceType:reuseIdentifier:tag: (which builds it on the
 * @c UITableViewCellStyleSubtitle base), sizes rows with @c cellHeight:, binds a campaign item with
 * @c setInfo:tag:, and later swaps in the downloaded banner with @c setArtwork:.
 */
@interface StoreCampaignTableViewCell : UITableViewCell

/**
 * @brief The banner-artwork image view that sits above the pack-background jacket.
 * @ghidraAddress 0x57204 (getter), 0x57214 (setter)
 */
@property(nonatomic, strong, nullable) UIImageView *artworkView;
/**
 * @brief The activity indicator shown while the banner artwork is downloading.
 * @ghidraAddress 0x5725c (getter), 0x5726c (setter)
 */
@property(nonatomic, strong, nullable) UIActivityIndicatorView *indicator;
/**
 * @brief The campaign identifier the cell currently displays.
 * @ghidraAddress 0x5724c (getter)
 */
@property(nonatomic, readonly) int campaignID;

/**
 * @brief The row height for the given device layout.
 * @param isPad Whether the pad layout is active.
 * @return The cell height in points (180 on pad, 100 on phone).
 * @ghidraAddress 0x56fa4
 */
+ (CGFloat)cellHeight:(BOOL)isPad;

/**
 * @brief Initialises the cell for the given device layout, reuse identifier, and row tag.
 *
 * The banner artwork alternates between two pack-background images based on the parity of @p tag.
 *
 * @param isPad Whether the pad layout is active.
 * @param reuseIdentifier The cell reuse identifier.
 * @param tag The row index; its parity selects the pack-background variant.
 * @return The initialised cell.
 * @ghidraAddress 0x56440
 */
- (nullable instancetype)initWithDeviceType:(BOOL)isPad
                            reuseIdentifier:(nullable NSString *)reuseIdentifier
                                        tag:(int)tag;
/**
 * @brief Binds a campaign item and row index to the cell.
 * @param info The campaign item to display, or @c nil to reset the cell to the jacket placeholder.
 * @param tag The row index.
 * @ghidraAddress 0x56c64
 */
- (void)setInfo:(nullable StoreCampaignItemInfo *)info tag:(int)tag;
/**
 * @brief Records whether the item is already downloaded and, if so, forces the purchased button
 * state.
 * @param downloadFlag Whether the campaign item has been downloaded.
 * @ghidraAddress 0x56e6c
 */
- (void)setDownloadFlag:(BOOL)downloadFlag;
/**
 * @brief Whether the given tune item already exists in the local music library.
 * @param itemType The campaign item type; only a tune (type 0) is checked.
 * @param itemID The music identifier to look up.
 * @return @c YES when the music data exists and its purchased file is present on disk.
 * @ghidraAddress 0x56e90
 */
- (BOOL)hasItem:(int)itemType itemID:(int)itemID;
/**
 * @brief The horizontal and vertical inset between the cell edge and the artwork.
 * @param isPad Whether the pad layout is active.
 * @return The artwork margin (@c width is 12 on pad and 10 on phone; @c height is always 10).
 * @ghidraAddress 0x56fc0
 */
- (CGSize)getArtworkMargin:(BOOL)isPad;
/**
 * @brief The artwork frame size for the given device layout.
 * @param isPad Whether the pad layout is active.
 * @return The artwork size in points (640x160 on pad, 320x80 on phone).
 * @ghidraAddress 0x56fd4
 */
- (CGSize)getItemSize:(BOOL)isPad;
/**
 * @brief Sets the banner artwork image after its download finishes, then fades the artwork in.
 * @param artwork The downloaded banner image.
 * @ghidraAddress 0x57004
 */
- (void)setArtwork:(nullable UIImage *)artwork;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
