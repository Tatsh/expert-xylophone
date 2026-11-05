/**
 * @file
 * The pad-layout campaign item detail view.
 *
 * It is a self-contained @c UIView overlay (the pad
 * counterpart to @c RBCampaignDetailViewController) that draws a bound campaign item's artwork,
 * name, artist, difficulty levels, acquisition button, external link, audio sample control, and a
 * scrolling detail pane carrying the banner, description, and copyright.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c StoreCampaignDetailViewPad,
 * image base 0x100000000). Ghidra addresses are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

#import "Downloader.h"

@class StoreButtonView;
@class StoreCampaignItemInfo;
@class StoreImageView;

NS_ASSUME_NONNULL_BEGIN

/**
 * The pad campaign item detail overlay.
 *
 * The overlay adopts @c DownloaderDelegate to drive its own audio-sample download, and forwards a
 * @c detailViewClose callback to its @c delegate (the campaign list page) when its alert is
 * dismissed.
 */
@interface StoreCampaignDetailViewPad : UIView <DownloaderDelegate>

/**
 * The bound campaign item currently displayed.
 */
@property(nonatomic, strong, nullable) StoreCampaignItemInfo *itemInfo;
/**
 * The list page that receives the overlay's close and button callbacks.
 */
@property(nonatomic, weak, nullable) id delegate;
/**
 * The campaign identifier of the bound item.
 */
@property(nonatomic, assign) int campaignID;
/**
 * The container that holds the artwork, labels, and acquisition buttons.
 */
@property(nonatomic, strong, nullable) UIView *itemView;
/**
 * The artwork tile.
 */
@property(nonatomic, strong, nullable) StoreImageView *artworkView;
/**
 * The campaign-title label at the top of the item container.
 */
@property(nonatomic, strong, nullable) UILabel *labelTitle;
/**
 * The item-name label.
 */
@property(nonatomic, strong, nullable) UILabel *labelItemName;
/**
 * The artist-name label.
 */
@property(nonatomic, strong, nullable) UILabel *labelArtistName;
/**
 * The difficulty-levels label.
 */
@property(nonatomic, strong, nullable) UILabel *labelLevels;
/**
 * The item-identifier label.
 */
@property(nonatomic, strong, nullable) UILabel *labelID;
/**
 * The primary acquisition button.
 */
@property(nonatomic, strong, nullable) StoreButtonView *downloadBtn;
/**
 * The external-link button.
 */
@property(nonatomic, strong, nullable) StoreButtonView *linkBtn;
/**
 * The audio-sample play/stop button.
 */
@property(nonatomic, strong, nullable) UIButton *sampleBtn;
/**
 * The downloader driving the audio sample fetch.
 */
@property(nonatomic, strong, nullable) Downloader *sampleDownloader;
/**
 * The loading indicator shown while the detail pane populates.
 */
@property(nonatomic, strong, nullable) UIActivityIndicatorView *indicator;
/**
 * The activity indicator overlaid on the sample button while it downloads.
 */
@property(nonatomic, strong, nullable) UIActivityIndicatorView *indicatorSample;
/**
 * The playing-state glyph shown on the sample button.
 */
@property(nonatomic, strong, nullable) UIImageView *playingView;
/**
 * The loading label shown while the detail pane populates.
 */
@property(nonatomic, strong, nullable) UILabel *labelLoading;
/**
 * The scrolling detail pane holding the banner, description, and copyright.
 */
@property(nonatomic, strong, nullable) UIScrollView *detailView;
/**
 * The campaign banner tile inside the detail pane.
 */
@property(nonatomic, strong, nullable) StoreImageView *bannerView;
/**
 * The campaign description text view inside the detail pane.
 */
@property(nonatomic, strong, nullable) UITextView *descriptionTextView;
/**
 * The copyright text view inside the detail pane.
 * @ghidraAddress 0x47744 (getter), 0x47754 (setter)
 */
@property(nonatomic, strong, nullable) UITextView *copyrightView;

/**
 * Binds a campaign item and row tag to the overlay, laying out every subview for it.
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
 * Reveals the bound campaign item's detail once the open animation completes.
 * @ghidraAddress 0x45a38
 */
- (void)showItemInfo;
/**
 * Clears the bound campaign item, resetting the overlay to its idle appearance.
 * @ghidraAddress 0x44f74
 */
- (void)removeItemInfo;
/**
 * Cancels any in-flight artwork or sample loading in the overlay.
 * @ghidraAddress 0x45364
 */
- (void)cancelLoading;
/**
 * Stops any playing audio sample and cancels an in-flight sample download.
 * @ghidraAddress 0x45368
 */
- (void)sampleStop;
/**
 * Marks the overlay's install as complete so it reflects the downloaded state.
 * @param flag @c YES once the item has finished downloading.
 * @ghidraAddress 0x46f48
 */
- (void)setDownloadFlag:(BOOL)flag;
/**
 * Reports whether a tune item's archive is already present on disk.
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
