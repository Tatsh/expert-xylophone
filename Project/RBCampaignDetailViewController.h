/** @file
 * The phone campaign item detail page, pushed from the campaign list. It shows one campaign item's
 * artwork, name, artist, difficulty levels, banner, description, and copyright, and drives its
 * acquisition (info download, terms description, application-update prompt, or serial-code entry)
 * through the shared unlock flow. It plays the item's audio sample, opens the item's external link,
 * and reports close events back to its delegate (the campaign list page).
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class RBCampaignDetailViewController,
 * image base 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

#import "Downloader.h"
#import "RBBaseViewController.h"

@class StoreButtonView;
@class StoreCampaignItemInfo;
@class StoreImageView;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The phone campaign item detail view controller.
 */
@interface RBCampaignDetailViewController
    : RBBaseViewController <DownloaderDelegate, UIAlertViewDelegate>

/**
 * @brief The campaign item shown on the page.
 * @ghidraAddress 0xb3f4 (getter), 0xb404 (setter)
 */
@property(nonatomic, strong, nullable) StoreCampaignItemInfo *itemInfo;
/**
 * @brief The delegate that receives the detail page's close callbacks (the campaign list page).
 * @ghidraAddress 0xb43c (getter), 0xb45c (setter)
 */
@property(nonatomic, weak, nullable) id delegate;
/**
 * @brief The row index of the shown item in the campaign list.
 * @ghidraAddress 0xb470 (getter), 0xb480 (setter)
 */
@property(nonatomic, assign) int workingIndex;
/**
 * @brief The vertically scrolling container that holds the detail layout.
 * @ghidraAddress 0xb490 (getter), 0xb4a0 (setter)
 */
@property(nonatomic, strong, nullable) UIScrollView *mainView;
/**
 * @brief The header panel holding the artwork, labels, and action buttons.
 * @ghidraAddress 0xb4d8 (getter), 0xb4e8 (setter)
 */
@property(nonatomic, strong, nullable) UIView *itemView;
/**
 * @brief The item artwork thumbnail.
 * @ghidraAddress 0xb520 (getter), 0xb530 (setter)
 */
@property(nonatomic, strong, nullable) StoreImageView *artworkView;
/**
 * @brief The item name label.
 * @ghidraAddress 0xb568 (getter), 0xb578 (setter)
 */
@property(nonatomic, strong, nullable) UILabel *labelItemName;
/**
 * @brief The artist name label.
 * @ghidraAddress 0xb5b0 (getter), 0xb5c0 (setter)
 */
@property(nonatomic, strong, nullable) UILabel *labelArtistName;
/**
 * @brief The per-difficulty levels label.
 * @ghidraAddress 0xb5f8 (getter), 0xb608 (setter)
 */
@property(nonatomic, strong, nullable) UILabel *labelLevels;
/**
 * @brief The tune identifier label.
 * @ghidraAddress 0xb640 (getter), 0xb650 (setter)
 */
@property(nonatomic, strong, nullable) UILabel *labelID;
/**
 * @brief The acquisition (download or unlock) action button.
 * @ghidraAddress 0xb688 (getter), 0xb698 (setter)
 */
@property(nonatomic, strong, nullable) StoreButtonView *downloadBtn;
/**
 * @brief The external-link action button.
 * @ghidraAddress 0xb6d0 (getter), 0xb6e0 (setter)
 */
@property(nonatomic, strong, nullable) StoreButtonView *linkBtn;
/**
 * @brief The campaign identifier of the shown item.
 * @ghidraAddress 0xb718 (getter), 0xb728 (setter)
 */
@property(nonatomic, assign) int campaignID;
/**
 * @brief The in-flight audio-sample downloader.
 * @ghidraAddress 0xb738 (getter), 0xb748 (setter)
 */
@property(nonatomic, strong, nullable) Downloader *sampleDownloader;
/**
 * @brief The loading activity indicator.
 * @ghidraAddress 0xb780 (getter), 0xb790 (setter)
 */
@property(nonatomic, strong, nullable) UIActivityIndicatorView *indicator;
/**
 * @brief The sample-playback overlay drawn over the artwork.
 * @ghidraAddress 0xb7c8 (getter), 0xb7d8 (setter)
 */
@property(nonatomic, strong, nullable) UIView *sampleView;
/**
 * @brief The play glyph shown while a sample is playing.
 * @ghidraAddress 0xb810 (getter), 0xb820 (setter)
 */
@property(nonatomic, strong, nullable) UIImageView *playingView;
/**
 * @brief The row index whose audio sample is playing, or minus one when none is playing.
 * @ghidraAddress 0xb858 (getter), 0xb868 (setter)
 */
@property(nonatomic, assign) int samplePlayedIndex;
/**
 * @brief The loading label.
 * @ghidraAddress 0xb878 (getter), 0xb888 (setter)
 */
@property(nonatomic, strong, nullable) UILabel *labelLoading;
/**
 * @brief The server-access activity indicator.
 * @ghidraAddress 0xb8c0 (getter), 0xb8d0 (setter)
 */
@property(nonatomic, strong, nullable) UIActivityIndicatorView *accessingIndicator;
/**
 * @brief The server-access label.
 * @ghidraAddress 0xb908 (getter), 0xb918 (setter)
 */
@property(nonatomic, strong, nullable) UILabel *accessingLabel;
/**
 * @brief The keyed pool of in-flight banner-artwork downloaders.
 * @ghidraAddress 0xb950 (getter), 0xb960 (setter)
 */
@property(nonatomic, strong, nullable) NSMutableDictionary *artworkDownloaders;
/**
 * @brief The pack-info download alert view, dismissed when the page is left.
 * @ghidraAddress 0xb998 (getter), 0xb9a8 (setter)
 */
@property(nonatomic, strong, nullable) UIAlertView *packinfoDownloadAlertView;
/**
 * @brief Whether the page is closing, used to suppress delayed alert callbacks.
 * @ghidraAddress 0xb9e0 (getter), 0xb9f0 (setter)
 */
@property(nonatomic, assign) BOOL closingFlag;
/**
 * @brief The lower detail panel holding the banner, description, divider, and copyright.
 * @ghidraAddress 0xba00 (getter), 0xba10 (setter)
 */
@property(nonatomic, strong, nullable) UIView *detailView;
/**
 * @brief The campaign banner artwork.
 * @ghidraAddress 0xba48 (getter), 0xba58 (setter)
 */
@property(nonatomic, strong, nullable) StoreImageView *bannerView;
/**
 * @brief The campaign description text view.
 * @ghidraAddress 0xba90 (getter), 0xbaa0 (setter)
 */
@property(nonatomic, strong, nullable) UITextView *descriptionTextView;
/**
 * @brief The divider drawn between the description and copyright.
 * @ghidraAddress 0xbad8 (getter), 0xbae8 (setter)
 */
@property(nonatomic, strong, nullable) UIView *lineView;
/**
 * @brief The copyright text view.
 * @ghidraAddress 0xbb20 (getter), 0xbb30 (setter)
 */
@property(nonatomic, strong, nullable) UITextView *copyrightView;
/**
 * @brief The sample-playback activity indicator.
 * @ghidraAddress 0xbb68 (getter), 0xbb78 (setter)
 */
@property(nonatomic, strong, nullable) UIActivityIndicatorView *indicatorSample;

/**
 * @brief Initialises the controller for the given campaign item.
 *
 * Sets the navigation title to the item's campaign name.
 * @param itemInfo The campaign item to show.
 * @return The initialised controller.
 * @ghidraAddress 0x58fc
 */
- (nullable instancetype)initWithItemInfo:(nullable StoreCampaignItemInfo *)itemInfo;
/**
 * @brief Rebinds the campaign item and refreshes the whole detail layout to reflect it.
 * @param info The campaign item, or @c nil to clear the labels and show the placeholder artwork.
 * @ghidraAddress 0x5b34
 */
- (void)setInfo:(nullable StoreCampaignItemInfo *)info;
/**
 * @brief Marks the item's install as complete and re-styles the acquisition button accordingly.
 * @param downloadFlag @c YES once the item has finished downloading.
 * @ghidraAddress 0x64f8
 */
- (void)setDownloadFlag:(BOOL)downloadFlag;
/**
 * @brief Reports whether a downloadable tune's archive is already present on disk.
 * @param hasItem Zero identifies a downloadable tune; any other value reports no.
 * @param itemID The tune identifier whose archive is checked.
 * @return @c YES when the archive exists on disk.
 * @ghidraAddress 0x6684
 */
- (BOOL)hasItem:(int)hasItem itemID:(int)itemID;
/**
 * @brief Reveals the item and detail views and begins loading the artwork if needed.
 * @ghidraAddress 0x6798
 */
- (void)showItemInfo;
/**
 * @brief Reveals the item detail if an item is bound.
 * @ghidraAddress 0x6924
 */
- (void)loadInfo;
/**
 * @brief Starts looping playback of the downloaded audio sample.
 * @ghidraAddress 0x6978
 */
- (void)sampleStart;
/**
 * @brief Stops any playing audio sample and resets the sample view.
 * @ghidraAddress 0x6ad4
 */
- (void)sampleStop;
/**
 * @brief Opens the item's external link, stopping any playing sample first (bar-button action).
 * @param sender The tapped control.
 * @ghidraAddress 0x6c08
 */
- (void)pushExternalLink:(nullable id)sender;
/**
 * @brief Handles the acquisition button: info download, terms description, update prompt, or
 * serial-code entry, depending on the item's button state.
 * @param sender The tapped control.
 * @ghidraAddress 0x6dac
 */
- (void)pushButton:(nullable id)sender;
/**
 * @brief Resets the sample overlay to the stopped state.
 * @ghidraAddress 0x6fdc
 */
- (void)sampleViewStop;
/**
 * @brief Shows the sample overlay in the downloading state.
 * @ghidraAddress 0x70b4
 */
- (void)sampleViewDownloading;
/**
 * @brief Shows the sample overlay in the playing state.
 * @ghidraAddress 0x7198
 */
- (void)sampleViewPlaying;
/**
 * @brief Toggles sample playback when the artwork is tapped: download, cancel, or stop.
 * @ghidraAddress 0x7274
 */
- (void)handleTapArtworkView;
/**
 * @brief Stops the sample when background music finishes (notification handler).
 * @param notification The finished-BGM notification.
 * @ghidraAddress 0x74ec
 */
- (void)finishBgm:(nullable id)notification;
/**
 * @brief Opens the item's external link (link-button action).
 * @param sender The tapped control.
 * @ghidraAddress 0x7508
 */
- (void)pushLink:(nullable id)sender;
/**
 * @brief Begins downloading the acquisition info for the shown item.
 * @ghidraAddress 0x78b8
 */
- (void)itemInfoDownload;
/**
 * @brief Refreshes the whole detail layout: resizes the name label, banner, description, divider,
 * and copyright, and grows the scrolling content to fit.
 * @ghidraAddress 0xa970
 */
- (void)updateLayout;
/**
 * @brief Cancels and clears every in-flight banner-artwork downloader.
 * @ghidraAddress 0x7bec
 */
- (void)stopDownloadArtworks;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
