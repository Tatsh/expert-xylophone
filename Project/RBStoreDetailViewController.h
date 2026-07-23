/** @file
 * The phone-layout pack detail controller pushed onto the store's navigation stack by
 * @c RBStorePageViewController. It shows a pack's artwork and purchase button in a table header,
 * one row per contained tune (with sample playback), and trailing copyright and terms-of-use rows,
 * and it drives the buy or download action through its delegate.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c RBStoreDetailViewController,
 * image base 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

#import "Downloader.h"
#import "ImageDownloader.h"
#import "RBBaseViewController.h"
#import "StorePackInfoDownloader.h"
#import "StorePackView.h"

@class Downloader;
@class StoreDetailHeaderView;
@class StorePackInfo;
@class StorePackInfoDownloader;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The phone-layout pack detail controller.
 */
@interface RBStoreDetailViewController : RBBaseViewController <UITableViewDataSource,
                                                               UITableViewDelegate,
                                                               UIAlertViewDelegate,
                                                               ImageDownloaderDelegate,
                                                               StorePackInfoDownloaderDelegate,
                                                               DownloaderDelegate>

/**
 * @brief The delegate that drives the detail's purchase and download actions.
 */
@property(nonatomic, weak, nullable) id<StorePackViewDelegate> delegate;

/**
 * @brief The pack the detail displays.
 */
@property(nonatomic, strong, nullable) StorePackInfo *packInfo;

/**
 * @brief The table header showing the pack artwork and purchase button.
 */
@property(nonatomic, strong, nullable) StoreDetailHeaderView *headerView;

/**
 * @brief The table listing the pack's tunes.
 */
@property(nonatomic, strong, nullable) UITableView *packTableView;

/**
 * @brief The spinner shown over the loading label while the pack detail downloads.
 */
@property(nonatomic, strong, nullable) UIActivityIndicatorView *accessingIndicator;

/**
 * @brief The centred loading label shown while the pack detail downloads.
 */
@property(nonatomic, strong, nullable) UILabel *accessingLabel;

/**
 * @brief The downloader that fetches the pack's full detail (tune list) when it is not yet loaded.
 */
@property(nonatomic, strong, nullable) StorePackInfoDownloader *storePackInfoDownloader;

/**
 * @brief The downloader for the currently-playing tune sample.
 */
@property(nonatomic, strong, nullable) Downloader *sampleDownloader;

/**
 * @brief The stretchable even-row tune-cell background image.
 */
@property(nonatomic, strong, nullable) UIImage *packBGImage0;

/**
 * @brief The stretchable odd-row tune-cell background image.
 */
@property(nonatomic, strong, nullable) UIImage *packBGImage1;

/**
 * @brief The per-tune artwork downloads, keyed by the tune's table index path.
 */
@property(nonatomic, strong, nullable) NSMutableDictionary *artworkDownloaders;

/**
 * @brief The network-error alert shown when the pack-detail download fails.
 */
@property(nonatomic, strong, nullable) UIAlertView *packinfoDownloadAlertView;

/**
 * @brief Whether the controller is being dismissed, used to route the network-error alert's cancel
 * action to a detail close.
 */
@property(nonatomic, assign) BOOL closingFlag;

/**
 * @brief Load and display the pack's detail, fetching the full tune list if it is not yet present.
 * @ghidraAddress 0x1d88a4
 */
- (void)loadInfo;

/**
 * @brief Populate the header and table from the loaded pack and begin its header-artwork download.
 * @ghidraAddress 0x1d8510
 */
- (void)showPackInfo;

/**
 * @brief Stop any sample playback and cancel the sample download.
 * @ghidraAddress 0x1d8aa0
 */
- (void)stopSample;

/**
 * @brief Whether every tune in the pack is already downloaded.
 * @return @c YES when the pack is fully downloaded.
 * @ghidraAddress 0x1d90f4
 */
- (BOOL)allDownloaded;

/**
 * @brief Recompute the purchase button label from the current ownership and download state.
 * @ghidraAddress 0x1d9290
 */
- (void)selfCheckButtonText;

/**
 * @brief Set the purchase button label to the purchasable state, showing the price.
 * @ghidraAddress 0x1d9408
 */
- (void)setButtonTextBuy;

/**
 * @brief Set the purchase button label to the installable state.
 * @ghidraAddress 0x1d95d8
 */
- (void)setButtonTextInstall;

/**
 * @brief Set the purchase button label to the installing state.
 * @ghidraAddress 0x1d96e8
 */
- (void)setButtonTextInstalling;

/**
 * @brief Set the purchase button label to the installed state.
 * @ghidraAddress 0x1d97f8
 */
- (void)setButtonTextInstalled;

/**
 * @brief Set the detail's purchase state.
 * @param state @c YES while a purchase is in progress (disabling the button).
 * @ghidraAddress 0x1d9028
 */
- (void)setPurchaseState:(BOOL)state;

/**
 * @brief Cancel and clear every in-flight tune-artwork download.
 * @ghidraAddress 0x1dc1e4
 */
- (void)stopDownloadArtworks;

/**
 * @brief Open the given iTunes URL through the root view controller.
 * @param url The iTunes URL to open.
 * @ghidraAddress 0x1dc914
 */
- (void)storeDetailViewOpenItunesWithURL:(nullable NSURL *)url;

/**
 * @brief Switch to the sequence-extension store for the given extend-note product identifier.
 * @param pid The extend-note product identifier, boxed as an @c NSNumber.
 * @ghidraAddress 0x1dc9d8
 */
- (void)switchToSpecialStore:(nullable NSNumber *)pid;

/**
 * @brief A tune sample finished downloading; begin playing it if it is still the selected row.
 * @param sender The tapped tune cell.
 * @ghidraAddress 0x1d8c18
 */
- (void)finishBgm:(nullable id)sender;

/**
 * @brief The purchase button action: begin buying or re-downloading the pack through the delegate.
 * @param sender The purchase button.
 * @ghidraAddress 0x1d8d84
 */
- (void)doPurchase:(nullable id)sender;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
