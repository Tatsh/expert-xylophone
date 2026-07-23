/** @file
 * The pad-layout campaign item detail view. It is a self-contained @c UIView overlay (the pad
 * counterpart to @c RBCampaignDetailViewController) that draws a bound campaign item's artwork,
 * name, artist, difficulty levels, acquisition button, external link, audio sample control, and a
 * scrolling detail pane carrying the banner, description, and copyright.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c StoreCampaignDetailViewPad,
 * image base 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

#import "Downloader.h"

@class StoreButtonView;
@class StoreCampaignItemInfo;
@class StoreImageView;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The pad campaign item detail overlay.
 *
 * The overlay adopts @c DownloaderDelegate to drive its own audio-sample download, and forwards a
 * @c detailViewClose callback to its @c delegate (the campaign list page) when its alert is
 * dismissed.
 */
@interface StoreCampaignDetailViewPad : UIView <DownloaderDelegate>

/**
 * @brief The bound campaign item currently displayed.
 * @ghidraAddress 0x474d0 (getter), 0x474e0 (setter)
 */
@property(nonatomic, strong, nullable) StoreCampaignItemInfo *itemInfo;
/**
 * @brief The list page that receives the overlay's close and button callbacks.
 * @ghidraAddress 0x47518 (getter), 0x47538 (setter)
 */
@property(nonatomic, weak, nullable) id delegate;
/**
 * @brief The campaign identifier of the bound item.
 * @ghidraAddress 0x4781c (getter), 0x4782c (setter)
 */
@property(nonatomic, assign) int campaignID;
/**
 * @brief The container that holds the artwork, labels, and acquisition buttons.
 * @ghidraAddress 0x4754c (getter), 0x4755c (setter)
 */
@property(nonatomic, strong, nullable) UIView *itemView;
/**
 * @brief The artwork tile.
 * @ghidraAddress 0x475dc (getter), 0x475ec (setter)
 */
@property(nonatomic, strong, nullable) StoreImageView *artworkView;
/**
 * @brief The campaign-title label at the top of the item container.
 * @ghidraAddress 0x47624 (getter), 0x47634 (setter)
 */
@property(nonatomic, strong, nullable) UILabel *labelTitle;
/**
 * @brief The item-name label.
 * @ghidraAddress 0x4766c (getter), 0x4767c (setter)
 */
@property(nonatomic, strong, nullable) UILabel *labelItemName;
/**
 * @brief The artist-name label.
 * @ghidraAddress 0x476b4 (getter), 0x476c4 (setter)
 */
@property(nonatomic, strong, nullable) UILabel *labelArtistName;
/**
 * @brief The difficulty-levels label.
 * @ghidraAddress 0x476fc (getter), 0x4770c (setter)
 */
@property(nonatomic, strong, nullable) UILabel *labelLevels;
/**
 * @brief The item-identifier label.
 * @ghidraAddress 0x47744 (getter), 0x47754 (setter)
 */
@property(nonatomic, strong, nullable) UILabel *labelID;
/**
 * @brief The primary acquisition button.
 * @ghidraAddress 0x4778c (getter), 0x4779c (setter)
 */
@property(nonatomic, strong, nullable) StoreButtonView *downloadBtn;
/**
 * @brief The external-link button.
 * @ghidraAddress 0x477d4 (getter), 0x477e4 (setter)
 */
@property(nonatomic, strong, nullable) StoreButtonView *linkBtn;
/**
 * @brief The audio-sample play/stop button.
 * @ghidraAddress 0x47914 (getter), 0x47924 (setter)
 */
@property(nonatomic, strong, nullable) UIButton *sampleBtn;
/**
 * @brief The downloader driving the audio sample fetch.
 * @ghidraAddress 0x4783c (getter), 0x4784c (setter)
 */
@property(nonatomic, strong, nullable) Downloader *sampleDownloader;
/**
 * @brief The loading indicator shown while the detail pane populates.
 * @ghidraAddress 0x47884 (getter), 0x47894 (setter)
 */
@property(nonatomic, strong, nullable) UIActivityIndicatorView *indicator;
/**
 * @brief The activity indicator overlaid on the sample button while it downloads.
 * @ghidraAddress 0x47a7c (getter), 0x47a8c (setter)
 */
@property(nonatomic, strong, nullable) UIActivityIndicatorView *indicatorSample;
/**
 * @brief The playing-state glyph shown on the sample button.
 * @ghidraAddress 0x4795c (getter), 0x4796c (setter)
 */
@property(nonatomic, strong, nullable) UIImageView *playingView;
/**
 * @brief The loading label shown while the detail pane populates.
 * @ghidraAddress 0x478cc (getter), 0x478dc (setter)
 */
@property(nonatomic, strong, nullable) UILabel *labelLoading;
/**
 * @brief The scrolling detail pane holding the banner, description, and copyright.
 * @ghidraAddress 0x479a4 (getter), 0x479b4 (setter)
 */
@property(nonatomic, strong, nullable) UIScrollView *detailView;
/**
 * @brief The campaign banner tile inside the detail pane.
 * @ghidraAddress 0x479ec (getter), 0x479fc (setter)
 */
@property(nonatomic, strong, nullable) StoreImageView *bannerView;
/**
 * @brief The campaign description text view inside the detail pane.
 * @ghidraAddress 0x47a34 (getter), 0x47a44 (setter)
 */
@property(nonatomic, strong, nullable) UITextView *descriptionTextView;
/**
 * @brief The copyright text view inside the detail pane.
 * @ghidraAddress 0x47744 (getter), 0x47754 (setter)
 */
@property(nonatomic, strong, nullable) UITextView *copyrightView;

/**
 * @brief Binds a campaign item and row tag to the overlay, laying out every subview for it.
 *
 * When @p info is @c nil the labels are cleared and a placeholder jacket is shown. Otherwise the
 * item's name, artist, levels, identifier, artwork, link, and detail pane are populated, the
 * acquisition-button state is resolved, and a secret (hidden) item's name is masked.
 * @param info The campaign item to display, or @c nil to clear.
 * @param tag The row index, propagated to the acquisition and link buttons.
 * @ghidraAddress 0x46280
 */
- (void)setInfo:(nullable StoreCampaignItemInfo *)info tag:(NSInteger)tag;
/**
 * @brief Reveals the bound campaign item's detail once the open animation completes.
 * @ghidraAddress 0x45a38
 */
- (void)showItemInfo;
/**
 * @brief Clears the bound campaign item, resetting the overlay to its idle appearance.
 * @ghidraAddress 0x44f74
 */
- (void)removeItemInfo;
/**
 * @brief Cancels any in-flight artwork or sample loading in the overlay.
 * @ghidraAddress 0x45364
 */
- (void)cancelLoading;
/**
 * @brief Stops any playing audio sample and cancels an in-flight sample download.
 * @ghidraAddress 0x45368
 */
- (void)sampleStop;
/**
 * @brief Marks the overlay's install as complete so it reflects the downloaded state.
 * @param downloadFlag @c YES once the item has finished downloading.
 * @ghidraAddress 0x46f48
 */
- (void)setDownloadFlag:(BOOL)downloadFlag;
/**
 * @brief Reports whether a tune item's archive is already present on disk.
 * @param hasItem Zero identifies a downloadable tune; any other value reports no.
 * @param itemID The tune identifier whose archive is checked.
 * @return @c YES when the archive exists on disk.
 * @ghidraAddress 0x470d4
 */
- (BOOL)hasItem:(int)hasItem itemID:(int)itemID;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
