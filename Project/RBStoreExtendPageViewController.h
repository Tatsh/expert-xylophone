/** @file
 * The extend-note store page controller. It is the root controller of the store's extend-note tab
 * and is an @c RBBaseViewController subclass owned through @c RBStoreTabController's
 * @c extendNoteNavCtrl. It lists the purchasable extend-note packs, drives their purchase,
 * restore, and download flows, and hosts the pad-layout note-detail overlay.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class
 * @c RBStoreExtendPageViewController, image base 0x100000000). @ghidraAddress values are offsets
 * relative to the image base.
 */

#import <StoreKit/StoreKit.h>
#import <UIKit/UIKit.h>

#import "ImageDownloader.h"
#import "RBBaseViewController.h"
#import "RBPurchaseManager.h"
#import "RBStoreExtendNoteList.h"
#import "StoreDownloadManager.h"
#import "StoreExtendNoteCellView.h"
#import "StoreExtendNoteInfoDownloader.h"

@class Downloader;
@class RBStoreExtendNoteList;
@class RBStoreTabController;
@class StoreExtendNoteDetailViewPad;
@class StoreExtendNoteInfo;
@class StoreExtendNoteInfoDownloader;

NS_ASSUME_NONNULL_BEGIN

// The following file-scope NSString globals are runtime-populated localised strings held in the
// application's __DATA segment (zero-initialised at link time and assigned during startup). They
// are declared here so the implementation can reference them by name; they are never defined in
// the reconstructed source. This mirrors how neEngineBridge.h declares g_pLocalizedDelete and its
// siblings.

/**
 * @brief The extend-note page title, used for the navigation item, the tab-bar item, and the pad
 * pack-table header label.
 * @ghidraAddress 0x3cfd98
 */
extern NSString *const g_pStoreExtendTitle;
/**
 * @brief The "show more" button and footer-cell title.
 * @ghidraAddress 0x3cfd70
 */
extern NSString *const g_pStoreShowMoreTitle;
/**
 * @brief The floating banner label text.
 * @ghidraAddress 0x3cfd18
 */
extern NSString *const g_pStoreBannerTitle;
/**
 * @brief The loading/footer title text.
 * @ghidraAddress 0x3cfca8
 */
extern NSString *const g_pStoreLoadingTitle;
/**
 * @brief The fallback message shown when the server connection fails.
 * @ghidraAddress unknown (runtime-populated __DATA NSString slot)
 */
extern NSString *const g_pStoreServerConnectFailed;
/**
 * @brief The message shown when the catalogue has no extend notes.
 * @ghidraAddress 0x3cfd60
 */
extern NSString *const g_pStoreNoExtendNotes;
/**
 * @brief The modal-dialog message shown while an extend note is installing.
 * @ghidraAddress unknown (runtime-populated __DATA NSString slot)
 */
extern NSString *const g_pStoreInstallingMessage;
/**
 * @brief The modal-dialog message shown while a purchase is in progress.
 * @ghidraAddress unknown (runtime-populated __DATA NSString slot)
 */
extern NSString *const g_pStorePurchasingMessage;
/**
 * @brief The message shown when a purchase cannot proceed.
 * @ghidraAddress unknown (runtime-populated __DATA NSString slot)
 */
extern NSString *const g_pStorePurchaseFailedMessage;
/**
 * @brief The sample-BGM stopped label text.
 * @ghidraAddress unknown (runtime-populated __DATA NSString slot)
 */
extern NSString *const g_pStoreSampleStoppedMessage;
/**
 * @brief The message shown when a download fails.
 * @ghidraAddress unknown (runtime-populated __DATA NSString slot)
 */
extern NSString *const g_pStoreDownloadFailedMessage;
/**
 * @brief The modal-dialog message shown while an App Store restore runs.
 * @ghidraAddress 0x3cfd00
 */
extern NSString *const g_pStoreRestoreInProgressMessage;
/**
 * @brief The modal-dialog message shown while restored notes download.
 * @ghidraAddress unknown (runtime-populated __DATA NSString slot)
 */
extern NSString *const g_pStoreDownloadInProgressMessage;

/**
 * @brief The extend-note store page, the extend-note tab's root controller.
 *
 * The binary's runtime protocol name for the purchase-manager delegate is
 * @c PurchaseManagerDelegate; the committed @c RBPurchaseManager.h declares it as
 * @c RBPurchaseManagerDelegate with matching selectors, so the page conforms to
 * @c RBPurchaseManagerDelegate.
 */
@interface RBStoreExtendPageViewController
    : RBBaseViewController <UITableViewDataSource,
                            UITableViewDelegate,
                            SKStoreProductViewControllerDelegate,
                            StoreExtendNoteListDelegate,
                            RBPurchaseManagerDelegate,
                            ImageDownloaderDelegate,
                            StoreDownloadManagerDelegate,
                            StoreTableCellViewBaseDelegate,
                            StoreExtendNoteInfoDownloaderDelegate,
                            UIPopoverControllerDelegate>

/**
 * @brief The store tab controller that hosts this page.
 */
@property(nonatomic, weak, nullable) RBStoreTabController *parent;
/**
 * @brief The extend-note catalogue list controller that drives fetching.
 */
@property(nonatomic, strong, nullable) RBStoreExtendNoteList *extendNoteListCtrl;
/**
 * @brief The per-product artwork downloaders, keyed by boxed product identifier.
 */
@property(nonatomic, strong, nullable) NSMutableDictionary *artworkDownloaders;
/**
 * @brief The currently running batch download manager, or @c nil while idle.
 */
@property(nonatomic, strong, nullable) StoreDownloadManager *downloadManager;
/**
 * @brief The extend-note info being purchased or installed.
 */
@property(nonatomic, strong, nullable) StoreExtendNoteInfo *purchasingExtendNoteInfo;
/**
 * @brief The pad pack-table header label.
 */
@property(nonatomic, strong, nullable) UILabel *packTableLabel;
/**
 * @brief The pad "show more" button.
 */
@property(nonatomic, strong, nullable) UIButton *showMoreButton;
/**
 * @brief The pad "show more" activity indicator.
 */
@property(nonatomic, strong, nullable) UIActivityIndicatorView *showMoreIndicator;
/**
 * @brief The pad dimming cover view behind the note-detail overlay.
 */
@property(nonatomic, strong, nullable) UIView *coverViewPad;
/**
 * @brief The pad note-detail overlay view.
 */
@property(nonatomic, strong, nullable) StoreExtendNoteDetailViewPad *extendNoteDetailViewPad;
/**
 * @brief The product identifiers still pending restore resolution.
 */
@property(nonatomic, strong, nullable) NSMutableArray *restoreProductID;
/**
 * @brief The resolved extend-note records collected during a restore.
 */
@property(nonatomic, strong, nullable) NSMutableArray *restoreExtendNoteInfo;
/**
 * @brief The restore navigation-bar button.
 */
@property(nonatomic, strong, nullable) UIBarButtonItem *restoreButton;
/**
 * @brief The in-flight extend-note info downloader used during restore.
 */
@property(nonatomic, strong, nullable) StoreExtendNoteInfoDownloader *storeExtendNoteInfoDownloader;
/**
 * @brief The cached stretchable even-row pack background image.
 */
@property(nonatomic, strong, nullable) UIImage *packBgImage0;
/**
 * @brief The cached stretchable odd-row pack background image.
 */
@property(nonatomic, strong, nullable) UIImage *packBgImage1;
/**
 * @brief The purchase-limit-type selection alert, retained while it is shown.
 */
@property(nonatomic, strong, nullable) UIAlertView *purchaseLimitTypeSelectView;
/**
 * @brief The banner background image view.
 */
@property(nonatomic, strong, nullable) UIImageView *bannerBgView;
/**
 * @brief The sample-BGM play/stop button.
 */
@property(nonatomic, strong, nullable) UIButton *samplePlayButton;
/**
 * @brief The "play" glyph for the sample button.
 */
@property(nonatomic, strong, nullable) UIImage *playImage;
/**
 * @brief The "stop" glyph for the sample button.
 */
@property(nonatomic, strong, nullable) UIImage *stopImage;
/**
 * @brief The sample-music name label.
 */
@property(nonatomic, strong, nullable) UILabel *sampleMusicLabel;
/**
 * @brief The in-app StoreKit product page, presented for affiliate iTunes links.
 */
@property(nonatomic, strong, nullable) SKStoreProductViewController *itunesViewCtrl;
/**
 * @brief The pack identifier queued to open once a pack is selected, or @c -1 when none pends.
 */
@property(nonatomic, assign) int moveToPackID;
/**
 * @brief The in-flight user-age check request.
 */
@property(nonatomic, strong, nullable) Downloader *userAgeSender;

/**
 * @brief Initialises the page for the given hosting store tab controller.
 * @param parent The store tab controller that hosts the page.
 * @return The initialised controller.
 * @ghidraAddress 0x15a0b8
 */
- (nullable instancetype)initWithParent:(nullable RBStoreTabController *)parent;

/**
 * @brief Replaces the page content with the given error message.
 * @param message The error message to display.
 * @ghidraAddress 0x15c660
 */
- (void)showError:(nullable NSString *)message;

/**
 * @brief Prompts the player to confirm an App Store restore.
 * @param sender The bar button that triggered the restore.
 * @ghidraAddress 0x15c810
 */
- (void)pushBarBtnRestore:(nullable id)sender;

/**
 * @brief Presents the terms-of-service view over the page.
 * @ghidraAddress 0x15c880
 */
- (void)showTerms;

/**
 * @brief Posts the user-age and purchase-limit-type payload to the server.
 * @ghidraAddress 0x15c9a4
 */
- (void)sendUserAge;

/**
 * @brief Forces the extend-note detail view open for a queued extend-note open request.
 * @ghidraAddress 0x15db50
 */
- (void)forceOpenExtendNoteDetailView;

/**
 * @brief Opens the pad note-detail overlay for the given product identifier.
 * @param productID The extend-note product identifier.
 * @ghidraAddress 0x15e6f4
 */
- (void)openExtendNoteDetailViewWithPID:(int)productID;

/**
 * @brief Begins downloading the files for the given extend note.
 * @param info The extend-note record to download.
 * @ghidraAddress 0x15f160
 */
- (void)startDownloadExtendNote:(nullable StoreExtendNoteInfo *)info;

/**
 * @brief Reports whether the current purchase would exceed the configured spending limit.
 * @param product The product about to be purchased.
 * @return @c YES when a spending-limit alert was raised and the purchase must not proceed.
 * @ghidraAddress 0x15f9a0
 */
- (BOOL)checkAttainLimitPurchase:(nullable SKProduct *)product;

/**
 * @brief Begins purchasing the given extend note.
 * @param info The extend-note record to purchase.
 * @ghidraAddress 0x15fbec
 */
- (void)startPurchase:(nullable StoreExtendNoteInfo *)info;

/**
 * @brief Closes the note-detail view, popping it on the phone or dismissing the pad overlay.
 * @ghidraAddress 0x15fec0
 */
- (void)detailViewClose;

/**
 * @brief Records the given extend note as purchased, optionally persisting the change.
 * @param info The extend-note record to register.
 * @param save Whether to persist the purchased notes afterwards.
 * @ghidraAddress 0x1601d8
 */
- (void)updateExtendNoteInfo:(nullable StoreExtendNoteInfo *)info Save:(BOOL)save;

/**
 * @brief Reloads the table cell that displays the given extend note.
 * @param info The extend-note record whose cell should be refreshed.
 * @ghidraAddress 0x1602b8
 */
- (void)updatePurchasedTableCell:(nullable StoreExtendNoteInfo *)info;

/**
 * @brief Re-registers and re-downloads the pack musics for the given extend note.
 * @param info The extend-note record to re-download.
 * @ghidraAddress 0x160838
 */
- (void)reDownloadPackMusics:(nullable StoreExtendNoteInfo *)info;

/**
 * @brief Appends the given resolved extend-note record to the restore working set.
 * @param info The resolved extend-note record.
 * @ghidraAddress 0x160ed8
 */
- (void)addRestoreExtendNoteInfo:(nullable StoreExtendNoteInfo *)info;

/**
 * @brief Resolves the next pending restore products synchronously.
 * @return @c YES when there were pending products to resolve, @c NO otherwise.
 * @ghidraAddress 0x161040
 */
- (BOOL)nextRestoreExtendNoteInfo;

/**
 * @brief Registers every restored note as purchased and prompts to download any missing assets.
 * @ghidraAddress 0x161314
 */
- (void)askDownloadAllNotes;

/**
 * @brief Downloads the assets for the restored notes that are missing on disk.
 * @ghidraAddress 0x161804
 */
- (void)restoreDownloadAllNotes;

/**
 * @brief Pushes the phone note-detail controller for the given product identifier.
 * @param pid The extend-note product identifier.
 * @ghidraAddress 0x165598
 */
- (void)showDetailViewForPhone:(int)pid;

/**
 * @brief Fetches the next page of extend notes.
 * @ghidraAddress 0x165708
 */
- (void)selectShowMore;

/**
 * @brief Cancels every in-flight artwork download.
 * @ghidraAddress 0x166184
 */
- (void)stopDownloadArtworks;

/**
 * @brief Puts the page into its loading state.
 * @ghidraAddress 0x166f14
 */
- (void)showLoadingView;

/**
 * @brief Opens the given iTunes affiliate URL, in-app when it carries affiliate parameters.
 * @param url The iTunes URL forwarded from the detail view.
 * @ghidraAddress 0x167340
 */
- (void)storeDetailViewOpenItunesWithURL:(nullable NSString *)url;

/**
 * @brief Opens the given iTunes URL, in-app when it carries affiliate parameters.
 * @param url The iTunes URL to open.
 * @ghidraAddress 0x167404
 */
- (void)openItunesWithURL:(nullable NSString *)url;

/**
 * @brief Dismisses the in-app iTunes product page.
 * @ghidraAddress 0x16777c
 */
- (void)closeItunesWithURL;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C++
// kate: hl Objective-C++;
// vim: set ft=objcpp :
