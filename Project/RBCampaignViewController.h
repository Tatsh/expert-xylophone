/**
 * @file
 * The campaign store page controller.
 *
 * It is the root controller of the store's campaign tab,
 * hosted by @c RBStoreTabController through its @c campaignNavCtrl. The page fetches the campaign
 * unlock list from the server, presents it in a table (phone) or a pad detail overlay, and drives
 * the serial-code, terms, item-info, sample-play, and download flows for each campaign item.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c RBCampaignViewController, image
 * base 0x100000000). The class has no embedded @c __FILE__ path, so it lives at the @c Project/
 * root alongside the other store view controllers. Ghidra addresses are offsets relative to the
 * image base.
 */

#import <UIKit/UIKit.h>

#import "Downloader.h"
#import "ImageDownloader.h"
#import "RBBaseViewController.h"
#import "StoreDownloadManager.h"

@class RBStoreTabController;
@class StoreCampaignDetailViewPad;

NS_ASSUME_NONNULL_BEGIN

/**
 * The campaign store page, the campaign tab's root controller.
 *
 * Conforms to the table view's data source and delegate, the plain and image @c Downloader
 * delegates, and the @c StoreDownloadManager delegate.
 */
@interface RBCampaignViewController :
    RBBaseViewController <UITableViewDelegate,
                          UITableViewDataSource,
                          DownloaderDelegate,
                          ImageDownloaderDelegate,
                          StoreDownloadManagerDelegate>

/**
 * The hosting store tab controller, used to drive the shared modal download dialog.
 */
@property(nonatomic, weak, nullable) RBStoreTabController *parent;
/**
 * The campaign-item list table (phone layout; on the pad it backs the same list behind the
 * detail overlay).
 */
@property(nonatomic, strong, nullable) UITableView *tableView;
/**
 * The "Now Loading" label shown while the initial campaign list request is in flight.
 */
@property(nonatomic, strong, nullable) UILabel *loadingLabel;
/**
 * The centred error label shown when the campaign list cannot be loaded.
 */
@property(nonatomic, strong, nullable) UILabel *errorLabel;
/**
 * The downloader fetching the campaign unlock list.
 */
@property(nonatomic, strong, nullable) Downloader *infoDownloader;
/**
 * The downloader fetching a single purchased tune's music info.
 */
@property(nonatomic, strong, nullable) Downloader *musicInfoDownloader;
/**
 * The downloader that verifies an entered campaign serial code.
 */
@property(nonatomic, strong, nullable) Downloader *termsChecker;
/**
 * The downloader fetching a campaign item's download URL.
 */
@property(nonatomic, strong, nullable) Downloader *itemURLDownloader;
/**
 * The downloader fetching a campaign item's audio sample.
 */
@property(nonatomic, strong, nullable) Downloader *sampleDownloader;
/**
 * The multi-file download manager active during a campaign item install.
 */
@property(nonatomic, strong, nullable) StoreDownloadManager *dlManager;
/**
 * The resource-update alert (unused by this page; kept from the shared store layout).
 */
@property(nonatomic, strong, nullable) UIAlertView *downloadAlertView;
/**
 * The application-update alert shown when an item needs a newer client.
 */
@property(nonatomic, strong, nullable) UIAlertView *updateAlertView;
/**
 * The shared "delete" cell image (kept from the store layout).
 */
@property(nonatomic, strong, nullable) UIImage *imgDelete;
/**
 * The shared "download" cell image (kept from the store layout).
 */
@property(nonatomic, strong, nullable) UIImage *imgDownload;
/**
 * The campaign items to display, each a @c StoreCampaignItemInfo from the unlock list.
 */
@property(nonatomic, strong, nullable) NSMutableArray *downloadMusicList;
/**
 * The in-flight banner-artwork downloaders, keyed by campaign identifier.
 */
@property(nonatomic, strong, nullable) NSMutableDictionary *imageDownloaderList;
/**
 * The raw campaign unlock list returned by the server.
 */
@property(nonatomic, strong, nullable) NSArray *unlockMusicCheckList;
/**
 * The serial-code input alert currently on screen, if any.
 */
@property(nonatomic, strong, nullable) UIAlertView *alertView;
/**
 * Set once the first campaign-list request has failed, so the second failure surfaces an
 * error rather than silently retrying.
 */
@property(nonatomic, assign) BOOL firstDownloadFailed;
/**
 * The dimming cover behind the pad detail overlay (pad layout only).
 */
@property(nonatomic, strong, nullable) UIView *coverViewPad;
/**
 * The in-place campaign item detail view (pad layout only).
 */
@property(nonatomic, strong, nullable) StoreCampaignDetailViewPad *itemDetailViewPad;

/**
 * Initialises the page for the given hosting store tab controller.
 * @param parent The store tab controller that hosts the page.
 * @return The initialised controller.
 * @ghidraAddress 0x1f8e2c
 */
- (nullable instancetype)initWithParent:(nullable RBStoreTabController *)parent;

/**
 * Requests the campaign unlock list from the server.
 * @ghidraAddress 0x1fa700
 */
- (void)downloadCampaignList;

/**
 * Starts playing the audio sample for the row named by @c samplePlayedIndex.
 * @ghidraAddress 0x1fb228
 */
- (void)sampleStart;
/**
 * Stops any playing audio sample and clears @c samplePlayedIndex.
 * @ghidraAddress 0x1fb410
 */
- (void)sampleStop;
/**
 * Opens the external link attached to the sender's row in Safari.
 * @param sender The tapped link control; its tag is the row index.
 * @ghidraAddress 0x1fb5c0
 */
- (void)pushExternalLink:(nullable id)sender;
/**
 * Handles a campaign cell's action button: info download, terms, update, or serial-code.
 * @param sender The tapped cell button; its tag is the row index.
 * @ghidraAddress 0x1fb72c
 */
- (void)pushCellButton:(nullable id)sender;
/**
 * Opens the pad in-place detail overlay for the campaign item at the given row.
 * @param index The row index into @c downloadMusicList.
 * @ghidraAddress 0x1fb934
 */
- (void)showDetailView:(NSInteger)index;
/**
 * Dismisses the pad detail overlay when its dimming cover is tapped.
 * @param sender The tap gesture recogniser.
 * @ghidraAddress 0x1fbdac
 */
- (void)handleTapCoverView:(nullable id)sender;
/**
 * Records the working item's granted experience into @c RBExperienceData.
 * @ghidraAddress 0x1fc128
 */
- (void)updateExperienceData;
/**
 * Presents an error state: hides the table and loading label and shows @c errorLabel.
 * @param message The message to display.
 * @ghidraAddress 0x1fdcb4
 */
- (void)showError:(nullable NSString *)message;
/**
 * Cancels an in-flight install and hides the modal download dialog.
 * @param sender The dialog's abort control.
 * @ghidraAddress 0x1fddf4
 */
- (void)storeDialogCancel:(nullable id)sender;
/**
 * Does nothing (the campaign tab has no dedicated close animation).
 * @ghidraAddress 0x1fe4f8
 */
- (void)storeClose;
/**
 * Opens the campaign detail for a pending open-store request once the list has loaded.
 * @ghidraAddress 0x1fe4fc
 */
- (void)forceOpenCampaignDetailView;
/**
 * Reloads the unlock table and refreshes the row list (used after an external change).
 * @ghidraAddress 0x1fec00
 */
- (void)reloadUnlockList;
/**
 * Re-applies any downloaded banner artwork to the visible rows and reloads the table.
 * @ghidraAddress 0x1fec34
 */
- (void)refreshMusicList;
/**
 * Rebuilds @c downloadMusicList from @c unlockMusicCheckList and recomputes the badge.
 * @ghidraAddress 0x1ff038
 */
- (void)refreshUnlockTable;
/**
 * Recomputes the tab-bar badge count from the new-unlock flags of the current items.
 * @ghidraAddress 0x1ff470
 */
- (void)refreshUnlockBadge;
/**
 * Sets the campaign tab-bar item's badge value (cleared when the count is not positive).
 * @param badgeCnt The number of new unlocks.
 * @ghidraAddress 0x1ff5cc
 */
- (void)setBadgeCnt:(int)badgeCnt;
/**
 * Pushes the phone campaign detail view controller for the given campaign item.
 * @param item The @c StoreCampaignItemInfo to show.
 * @ghidraAddress 0x1ffa44
 */
- (void)showDetailViewForPhone:(nullable id)item;
/**
 * Requests the working item's campaign item info from the server.
 * @ghidraAddress 0x1ffe00
 */
- (void)itemInfoDownload;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
