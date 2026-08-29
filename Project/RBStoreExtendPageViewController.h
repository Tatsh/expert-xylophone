/**
 * @file
 * The extend-note store page controller.
 *
 * It is the root controller of the store's extend-note tab
 * and is an @c RBBaseViewController subclass owned through @c RBStoreTabController's
 * @c extendNoteNavCtrl. It lists the purchasable extend-note packs, drives their purchase,
 * restore, and download flows, and hosts the pad-layout note-detail overlay.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class
 * @c RBStoreExtendPageViewController, image base 0x100000000). Ghidra addresses are offsets
 * relative to the image base.
 */

#import <StoreKit/StoreKit.h>
#import <UIKit/UIKit.h>

#import "ImageDownloader.h"
#import "RBBaseViewController.h"
#import "RBPurchaseManager.h"
#import "RBStoreExtendNoteList.h"
#import "StoreDownloadManager.h"
#import "StoreExtendNoteInfoDownloader.h"
#import "StoreExtendNoteView.h"

@class Downloader;
@class RBStoreExtendNoteList;
@class RBStoreTabController;
@class StoreExtendNoteDetailViewPad;
@class StoreExtendNoteInfo;
@class StoreExtendNoteInfoDownloader;

NS_ASSUME_NONNULL_BEGIN

/**
 * The extend-note store page, the extend-note tab's root controller.
 *
 * The binary's runtime protocol name for the purchase-manager delegate is
 * @c PurchaseManagerDelegate; the committed @c RBPurchaseManager.h declares it as
 * @c RBPurchaseManagerDelegate with matching selectors, so the page conforms to
 * @c RBPurchaseManagerDelegate.
 */
@interface RBStoreExtendPageViewController :
    RBBaseViewController <UITableViewDataSource,
                          UITableViewDelegate,
                          SKStoreProductViewControllerDelegate,
                          StoreExtendNoteListDelegate,
                          RBPurchaseManagerDelegate,
                          ImageDownloaderDelegate,
                          StoreDownloadManagerDelegate,
                          StoreTableCellViewBaseDelegate,
                          StoreExtendNoteInfoDownloaderDelegate,
                          UIAlertViewDelegate,
                          UIPopoverControllerDelegate>

/**
 * The store tab controller that hosts this page.
 */
@property(nonatomic, weak, nullable) RBStoreTabController *parent;
/**
 * The extend-note catalogue list controller that drives fetching.
 */
@property(nonatomic, strong, nullable) RBStoreExtendNoteList *extendNoteListCtrl;
/**
 * The per-product artwork downloaders, keyed by boxed product identifier.
 */
@property(nonatomic, strong, nullable) NSMutableDictionary *artworkDownloaders;
/**
 * The currently running batch download manager, or @c nil while idle.
 */
@property(nonatomic, strong, nullable) StoreDownloadManager *downloadManager;
/**
 * The extend-note info being purchased or installed.
 */
@property(nonatomic, strong, nullable) StoreExtendNoteInfo *purchasingExtendNoteInfo;
/**
 * The pad pack-table header label.
 */
@property(nonatomic, strong, nullable) UILabel *packTableLabel;
/**
 * The pad "show more" button.
 */
@property(nonatomic, strong, nullable) UIButton *showMoreButton;
/**
 * The pad "show more" activity indicator.
 */
@property(nonatomic, strong, nullable) UIActivityIndicatorView *showMoreIndicator;
/**
 * The pad dimming cover view behind the note-detail overlay.
 */
@property(nonatomic, strong, nullable) UIView *coverViewPad;
/**
 * The pad note-detail overlay view.
 */
@property(nonatomic, strong, nullable) StoreExtendNoteDetailViewPad *extendNoteDetailViewPad;
/**
 * The product identifiers still pending restore resolution.
 */
@property(nonatomic, strong, nullable) NSMutableArray *restoreProductID;
/**
 * The resolved extend-note records collected during a restore.
 */
@property(nonatomic, strong, nullable) NSMutableArray *restoreExtendNoteInfo;
/**
 * The restore navigation-bar button.
 */
@property(nonatomic, strong, nullable) UIBarButtonItem *restoreButton;
/**
 * The in-flight extend-note info downloader used during restore.
 */
@property(nonatomic, strong, nullable) StoreExtendNoteInfoDownloader *storeExtendNoteInfoDownloader;
/**
 * The cached stretchable even-row pack background image.
 */
@property(nonatomic, strong, nullable) UIImage *packBgImage0;
/**
 * The cached stretchable odd-row pack background image.
 */
@property(nonatomic, strong, nullable) UIImage *packBgImage1;
/**
 * The purchase-limit-type selection alert, retained while it is shown.
 */
@property(nonatomic, strong, nullable) UIAlertView *purchaseLimitTypeSelectView;
/**
 * The banner background image view.
 */
@property(nonatomic, strong, nullable) UIImageView *bannerBgView;
/**
 * The sample-BGM play/stop button.
 */
@property(nonatomic, strong, nullable) UIButton *samplePlayButton;
/**
 * The "play" glyph for the sample button.
 */
@property(nonatomic, strong, nullable) UIImage *playImage;
/**
 * The "stop" glyph for the sample button.
 */
@property(nonatomic, strong, nullable) UIImage *stopImage;
/**
 * The sample-music name label.
 */
@property(nonatomic, strong, nullable) UILabel *sampleMusicLabel;
/**
 * The in-app StoreKit product page, presented for affiliate iTunes links.
 */
@property(nonatomic, strong, nullable) SKStoreProductViewController *itunesViewCtrl;
/**
 * The pack identifier queued to open once a pack is selected, or @c -1 when none pends.
 */
@property(nonatomic, assign) int moveToPackID;
/**
 * The in-flight user-age check request.
 */
@property(nonatomic, strong, nullable) Downloader *userAgeSender;

/**
 * Initialises the page for the given hosting store tab controller.
 * @param parent The store tab controller that hosts the page.
 * @return The initialised controller.
 * @ghidraAddress 0x15a0b8
 */
- (nullable instancetype)initWithParent:(nullable RBStoreTabController *)parent;

/**
 * Replaces the page content with the given error message.
 * @param message The error message to display.
 * @ghidraAddress 0x15c660
 */
- (void)showError:(nullable NSString *)message;

/**
 * Prompts the player to confirm an App Store restore.
 * @param sender The bar button that triggered the restore.
 * @ghidraAddress 0x15c810
 */
- (void)pushBarBtnRestore:(nullable id)sender;

/**
 * Presents the terms-of-service view over the page.
 * @ghidraAddress 0x15c880
 */
- (void)showTerms;

/**
 * Posts the user-age and purchase-limit-type payload to the server.
 * @ghidraAddress 0x15c9a4
 */
- (void)sendUserAge;

/**
 * Forces the extend-note detail view open for a queued extend-note open request.
 * @ghidraAddress 0x15db50
 */
- (void)forceOpenExtendNoteDetailView;

/**
 * Opens the pad note-detail overlay for the given product identifier.
 * @param productID The extend-note product identifier.
 * @ghidraAddress 0x15e6f4
 */
- (void)openExtendNoteDetailViewWithPID:(int)productID;

/**
 * Begins downloading the files for the given extend note.
 * @param info The extend-note record to download.
 * @ghidraAddress 0x15f160
 */
- (void)startDownloadExtendNote:(nullable StoreExtendNoteInfo *)info;

/**
 * Reports whether the current purchase would exceed the configured spending limit.
 * @param product The product about to be purchased.
 * @return @c YES when a spending-limit alert was raised and the purchase must not proceed.
 * @ghidraAddress 0x15f9a0
 */
- (BOOL)checkAttainLimitPurchase:(nullable SKProduct *)product;

/**
 * Begins purchasing the given extend note.
 * @param info The extend-note record to purchase.
 * @ghidraAddress 0x15fbec
 */
- (void)startPurchase:(nullable StoreExtendNoteInfo *)info;

/**
 * Closes the note-detail view, popping it on the phone or dismissing the pad overlay.
 * @ghidraAddress 0x15fec0
 */
- (void)detailViewClose;

/**
 * Records the given extend note as purchased, optionally persisting the change.
 * @param info The extend-note record to register.
 * @param save Whether to persist the purchased notes afterwards.
 * @ghidraAddress 0x1601d8
 */
- (void)updateExtendNoteInfo:(nullable StoreExtendNoteInfo *)info Save:(BOOL)save;

/**
 * Reloads the table cell that displays the given extend note.
 * @param info The extend-note record whose cell should be refreshed.
 * @ghidraAddress 0x1602b8
 */
- (void)updatePurchasedTableCell:(nullable StoreExtendNoteInfo *)info;

/**
 * Re-registers and re-downloads the pack musics for the given extend note.
 * @param info The extend-note record to re-download.
 * @ghidraAddress 0x160838
 */
- (void)reDownloadPackMusics:(nullable StoreExtendNoteInfo *)info;

/**
 * Appends the given resolved extend-note record to the restore working set.
 * @param info The resolved extend-note record.
 * @ghidraAddress 0x160ed8
 */
- (void)addRestoreExtendNoteInfo:(nullable StoreExtendNoteInfo *)info;

/**
 * Resolves the next pending restore products synchronously.
 * @return @c YES when there were pending products to resolve, @c NO otherwise.
 * @ghidraAddress 0x161040
 */
- (BOOL)nextRestoreExtendNoteInfo;

/**
 * Registers every restored note as purchased and prompts to download any missing assets.
 * @ghidraAddress 0x161314
 */
- (void)askDownloadAllNotes;

/**
 * Downloads the assets for the restored notes that are missing on disk.
 * @ghidraAddress 0x161804
 */
- (void)restoreDownloadAllNotes;

/**
 * Pushes the phone note-detail controller for the given product identifier.
 * @param pid The extend-note product identifier.
 * @ghidraAddress 0x165598
 */
- (void)showDetailViewForPhone:(int)pid;

/**
 * Fetches the next page of extend notes.
 * @ghidraAddress 0x165708
 */
- (void)selectShowMore;

/**
 * Cancels every in-flight artwork download.
 * @ghidraAddress 0x166184
 */
- (void)stopDownloadArtworks;

/**
 * Puts the page into its loading state.
 * @ghidraAddress 0x166f14
 */
- (void)showLoadingView;

/**
 * Opens the given iTunes affiliate URL, in-app when it carries affiliate parameters.
 * @param url The iTunes URL forwarded from the detail view.
 * @ghidraAddress 0x167340
 */
- (void)storeDetailViewOpenItunesWithURL:(nullable NSURL *)url;

/**
 * Opens the given iTunes URL, in-app when it carries affiliate parameters.
 * @param url The iTunes URL to open.
 * @ghidraAddress 0x167404
 */
- (void)openItunesWithURL:(nullable NSURL *)url;

/**
 * Dismisses the in-app iTunes product page.
 * @ghidraAddress 0x16777c
 */
- (void)closeItunesWithURL;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C++
// kate: hl Objective-C++;
// vim: set ft=objcpp :
