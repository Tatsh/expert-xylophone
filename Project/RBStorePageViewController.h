/** @file
 * The song-pack store page controller. It is the root controller of the store's first tab (the
 * pack store) and is an @c RBBaseViewController subclass owned through @c RBStoreTabController's
 * @c mainNavCtrl. It lists purchasable song packs in a table (three sections on the phone, a
 * two-up single section on the pad), drives the pack detail, promotion, genre-select, and sample
 * playback surfaces, and owns the in-app-purchase, restore, and download flows through
 * @c RBPurchaseManager, @c StoreDownloadManager, and the store info downloaders.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c RBStorePageViewController,
 * image base 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <StoreKit/StoreKit.h>
#import <UIKit/UIKit.h>

#import "Downloader.h"
#import "ImageDownloader.h"
#import "RBBaseViewController.h"
#import "RBPurchaseManager.h"
#import "StoreDownloadManager.h"
#import "StoreExtendNoteInfoDownloader.h"
#import "StorePackInfoDownloader.h"
#import "StorePackListDelegate.h"
#import "StorePackView.h"
#import "StorePromotionView.h"

@class Downloader;
@class RBStoreGenreViewController;
@class RBStorePackList;
@class RBStoreTabController;
@class StoreDialogView;
@class StoreExtendNoteInfo;
@class StorePackDetailViewPad;
@class StorePackInfo;
@class StorePackListGenre;
@class StoreMusicInfo;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The song-pack store page, the first store tab's root controller.
 */
@interface RBStorePageViewController : RBBaseViewController <UITableViewDataSource,
                                                             UITableViewDelegate,
                                                             SKStoreProductViewControllerDelegate,
                                                             StorePackListDelegate,
                                                             RBPurchaseManagerDelegate,
                                                             ImageDownloaderDelegate,
                                                             StoreDownloadManagerDelegate,
                                                             StorePackViewDelegate,
                                                             StorePackInfoDownloaderDelegate,
                                                             StoreExtendNoteInfoDownloaderDelegate,
                                                             StorePromotionViewDelegate,
                                                             UIPopoverControllerDelegate>

#pragma mark - Properties

/**
 * @brief The store tab controller that hosts the page. Held weakly to avoid a retain cycle.
 */
@property(nonatomic, weak, nullable) RBStoreTabController *parent;
/**
 * @brief The pack-list model driving the table's contents.
 */
@property(nonatomic, strong, nullable) RBStorePackList *packListCtrl;
/**
 * @brief The per-pack artwork downloaders, keyed by pack identifier.
 */
@property(nonatomic, strong, nullable) NSMutableDictionary *artworkDownloaders;
/**
 * @brief The batch download runner for the current pack's tunes.
 */
@property(nonatomic, strong, nullable) StoreDownloadManager *downloadManager;
/**
 * @brief The pack whose purchase or download is currently in flight.
 */
@property(nonatomic, strong, nullable) StorePackInfo *purchasingPackInfo;
/**
 * @brief The rotating promotion banner shown above the pack list.
 */
@property(nonatomic, strong, nullable) StorePromotionView *promotionView;
/**
 * @brief The pad-layout "PACK" table title label.
 */
@property(nonatomic, strong, nullable) UILabel *packTableLabel;
/**
 * @brief The trailing "show more" button that fetches the next page of packs.
 */
@property(nonatomic, strong, nullable) UIButton *showMoreButton;
/**
 * @brief The spinner shown on the "show more" button while a page is being fetched.
 */
@property(nonatomic, strong, nullable) UIActivityIndicatorView *showMoreIndicator;
/**
 * @brief The pad-layout dimming cover shown behind the pack detail panel.
 */
@property(nonatomic, strong, nullable) UIView *coverViewPad;
/**
 * @brief The pad-layout pack detail panel.
 */
@property(nonatomic, strong, nullable) StorePackDetailViewPad *packDetailViewPad;
/**
 * @brief The product identifiers awaiting restore resolution.
 */
@property(nonatomic, strong, nullable) NSMutableArray *restoreProductID;
/**
 * @brief The packs resolved during the current restore flow.
 */
@property(nonatomic, strong, nullable) NSMutableArray *restorePackInfo;
/**
 * @brief The restore bar button item.
 */
@property(nonatomic, strong, nullable) UIBarButtonItem *restoreButton;
/**
 * @brief The in-flight pack-info detail downloader used during restore.
 */
@property(nonatomic, strong, nullable) StorePackInfoDownloader *storePackInfoDownloader;
/**
 * @brief The extend-note product identifiers awaiting restore resolution.
 */
@property(nonatomic, strong, nullable) NSMutableArray *restoreProductExtendNoteID;
/**
 * @brief The extend notes resolved during the current restore flow.
 */
@property(nonatomic, strong, nullable) NSMutableArray *restoreExtendNoteInfo;
/**
 * @brief The in-flight extend-note detail downloader used during restore.
 */
@property(nonatomic, strong, nullable) StoreExtendNoteInfoDownloader *storeExtendNoteInfoDownloader;
/**
 * @brief The stretchable even-row pack-cell background image.
 */
@property(nonatomic, strong, nullable) UIImage *packBgImage0;
/**
 * @brief The stretchable odd-row pack-cell background image.
 */
@property(nonatomic, strong, nullable) UIImage *packBgImage1;
/**
 * @brief The purchase-limit-type selection alert.
 */
@property(nonatomic, strong, nullable) UIAlertView *purchaseLimitTypeSelectView;
/**
 * @brief The genre-select bar button item.
 */
@property(nonatomic, strong, nullable) UIBarButtonItem *genreButton;
/**
 * @brief The genre currently displayed in the pack list.
 */
@property(nonatomic, strong, nullable) StorePackListGenre *currentGenre;
/**
 * @brief The genre-select view controller.
 */
@property(nonatomic, strong, nullable) RBStoreGenreViewController *genreViewCtrl;
/**
 * @brief The pad-layout popover hosting the genre-select controller.
 */
@property(nonatomic, strong, nullable) UIPopoverController *genrePopoverCtrl;
/**
 * @brief The navigation controller wrapping the genre-select controller.
 */
@property(nonatomic, strong, nullable) UINavigationController *genreNavCtrl;
/**
 * @brief The "TOP" bar button item that scrolls the pack list to the top.
 */
@property(nonatomic, strong, nullable) UIBarButtonItem *topButton;
/**
 * @brief The pad-layout sample-banner background image view.
 */
@property(nonatomic, strong, nullable) UIImageView *bannerBgView;
/**
 * @brief The sample play/stop toggle button.
 */
@property(nonatomic, strong, nullable) UIButton *samplePlayButton;
/**
 * @brief The image shown on @c samplePlayButton while sample playback is enabled.
 */
@property(nonatomic, strong, nullable) UIImage *playImage;
/**
 * @brief The image shown on @c samplePlayButton while sample playback is disabled.
 */
@property(nonatomic, strong, nullable) UIImage *stopImage;
/**
 * @brief The label showing the currently playing sample tune name.
 */
@property(nonatomic, strong, nullable) UILabel *sampleMusicLabel;
/**
 * @brief The presented iTunes store product view controller, if any.
 */
@property(nonatomic, strong, nullable) SKStoreProductViewController *itunesViewCtrl;
/**
 * @brief The in-flight age-verification request, if any.
 */
@property(nonatomic, strong, nullable) Downloader *userAgeSender;

#pragma mark - Lifecycle

/**
 * @brief Initialises the page for the given hosting store tab controller.
 * @param parent The store tab controller that hosts the page.
 * @return The initialised controller.
 * @ghidraAddress 0x1dcf88
 */
- (nullable instancetype)initWithParent:(nullable RBStoreTabController *)parent;

#pragma mark - Pack list callbacks

/**
 * @brief Handle a successful pack-list load: relay out the table, bar buttons, and overlays.
 * @param packList The pack list that finished loading.
 * @ghidraAddress 0x1e156c
 */
- (void)packListDownloadSuccess:(RBStorePackList *)packList;
/**
 * @brief Handle a pack-list load failure with an inline alert or a full-screen error.
 * @param packList The pack list that failed.
 * @param errorMessage The failure message, or @c nil to use the default connection-failed message.
 * @ghidraAddress 0x1e2a6c
 */
- (void)packListDownloadError:(RBStorePackList *)packList
                 errorMessage:(nullable NSString *)errorMessage;
/**
 * @brief Handle an empty pack-list result.
 * @param packList The pack list that returned no packs.
 * @ghidraAddress 0x1e2f24
 */
- (void)packListDownloadNothing:(RBStorePackList *)packList;
/**
 * @brief Handle a pack tile tap by opening its detail view.
 * @param packView The tapped pack view.
 * @ghidraAddress 0x1e3018
 */
- (void)packViewSelected:(StorePackView *)packView;

#pragma mark - Detail view

/**
 * @brief Force the pack detail view open for a queued pack open request.
 * @ghidraAddress 0x1e26d0
 */
- (void)forceOpenPackDetailView;
/**
 * @brief Open the pack detail view for the given pack identifier (pad layout).
 * @param packId The pack identifier to display.
 * @ghidraAddress 0x1e31ac
 */
- (void)openPackDetailViewWithPackId:(int)packId;
/**
 * @brief Push the pack detail controller for the given pack identifier (phone layout).
 * @param packID The pack identifier to display.
 * @ghidraAddress 0x1ebe6c
 */
- (void)showDetailViewForPhone:(int)packID;
/**
 * @brief Close the pack detail view.
 * @ghidraAddress 0x1e55cc
 */
- (void)detailViewClose;

#pragma mark - Purchase

/**
 * @brief Whether buying the given product would exceed the configured purchase limit.
 * @param product The product about to be bought.
 * @return @c YES when the limit is reached (and an alert was shown), @c NO otherwise.
 * @ghidraAddress 0x1e50ac
 */
- (BOOL)checkAttainLimitPurchase:(SKProduct *)product;
/**
 * @brief Begin buying the given pack after the purchase-limit check passes.
 * @param packInfo The pack to buy.
 * @ghidraAddress 0x1e52f8
 */
- (void)detailViewStartPurchase:(StorePackInfo *)packInfo;
/**
 * @brief POST the user's age and purchase-limit type to the age-verification endpoint, then begin
 * the purchase on success.
 * @ghidraAddress 0x1e0c40
 */
- (void)sendUserAge;

#pragma mark - Download

/**
 * @brief Start downloading the tunes of the given pack that are missing on disk.
 * @param packInfo The pack whose tunes to download.
 * @ghidraAddress 0x1e4858
 */
- (void)startDownloadPackMusics:(StorePackInfo *)packInfo;
/**
 * @brief Re-record the pack's music info, then re-download its tunes.
 * @param packInfo The pack to re-download.
 * @ghidraAddress 0x1e6058
 */
- (void)reDownloadPackMusics:(StorePackInfo *)packInfo;

#pragma mark - Restore

/**
 * @brief Restore bar-button action: confirm and begin restoring purchases.
 * @param sender The restore bar button item.
 * @ghidraAddress 0x1e14fc
 */
- (void)pushBarBtnRestore:(nullable id)sender;
/**
 * @brief Record a resolved restored pack and remove its product identifier from the pending set.
 * @param packInfo The resolved pack.
 * @ghidraAddress 0x1e66f8
 */
- (void)addRestorePackInfo:(StorePackInfo *)packInfo;
/**
 * @brief Record a resolved restored extend note and remove its product identifier from the pending
 * set.
 * @param info The resolved extend-note info.
 * @ghidraAddress 0x1ef40c
 */
- (void)addRestoreExtendNoteInfo:(StoreExtendNoteInfo *)info;
/**
 * @brief Resolve the next pending restore product, kicking off a detail download if needed.
 * @return @c YES while there is still restore work in flight, @c NO when the queue is exhausted.
 * @ghidraAddress 0x1e6860
 */
- (BOOL)nextRestorePackInfo;
/**
 * @brief Ask the user whether to download every restored tune, or dismiss when nothing is missing.
 * @ghidraAddress 0x1e6f30
 */
- (void)askDownloadAllMusics;
/**
 * @brief Download every missing restored tune and extend note.
 * @ghidraAddress 0x1e7788
 */
- (void)restoreDownloadAllMusics;
/**
 * @brief Cancel the in-flight restore download and restore the detail button state.
 * @ghidraAddress 0x1e942c
 */
- (void)restoreDownloadCancel;

#pragma mark - Music info

/**
 * @brief Record every tune of the given pack as purchased, optionally persisting.
 * @param packInfo The pack whose tunes to record.
 * @param save Whether to persist the purchased-music list afterwards.
 * @ghidraAddress 0x1e5890
 */
- (void)updateMusicInfo:(StorePackInfo *)packInfo Save:(BOOL)save;
/**
 * @brief Record the given extend note as purchased, optionally persisting.
 * @param info The extend note to record.
 * @param save Whether to persist the purchased-notes list afterwards.
 * @ghidraAddress 0x1ef7c0
 */
- (void)updateExtendNoteInfo:(StoreExtendNoteInfo *)info Save:(BOOL)save;
/**
 * @brief Reload the table cell that shows the given purchased pack.
 * @param packInfo The purchased pack whose cell to reload.
 * @ghidraAddress 0x1e5ad8
 */
- (void)updatePurchasedTableCell:(StorePackInfo *)packInfo;

#pragma mark - Genre and sample

/**
 * @brief Switch the pack list to the genre at the given index.
 * @param genreIndexNumber The boxed genre index.
 * @ghidraAddress 0x1ede24
 */
- (void)switchToGenre:(NSNumber *)genreIndexNumber;
/**
 * @brief Present the genre-select surface (pushed on the phone, popover on the pad).
 * @param sender The genre bar button item.
 * @ghidraAddress 0x1ee3ac
 */
- (void)presentGenreSelect:(nullable id)sender;
/**
 * @brief Dismiss the genre-select surface.
 * @param sender The dismissing control.
 * @ghidraAddress 0x1ee610
 */
- (void)hideGenreSelect:(nullable id)sender;
/**
 * @brief Show the loading overlay and hide the table.
 * @ghidraAddress 0x1ee7a4
 */
- (void)showLoadingView;
/**
 * @brief Set the sample tune name shown in the sample label.
 * @param name The tune name, or @c nil to clear.
 * @ghidraAddress 0x1eeb58
 */
- (void)setPlaySampleName:(nullable NSString *)name;
/**
 * @brief The sample-play toggle button action.
 * @param sender The sample-play button.
 * @ghidraAddress 0x1e3f3c
 */
- (void)pushSampleButton:(nullable id)sender;
/**
 * @brief The "show more" button action: fetch the next page of packs.
 * @ghidraAddress 0x1ec078
 */
- (void)selectShowMore;
/**
 * @brief The "TOP" button action: scroll the pack list to the top.
 * @param sender The "TOP" button.
 * @ghidraAddress 0x1ef324
 */
- (void)goToTop:(nullable id)sender;

#pragma mark - Promotion, cover, and special store

/**
 * @brief Stop the pack promotion presentation.
 * @ghidraAddress 0x1eec14
 */
- (void)stopPromotion;
/**
 * @brief Handle a tap on the pad dimming cover by closing the pack detail panel.
 * @param sender The tap gesture recogniser.
 * @ghidraAddress 0x1e432c
 */
- (void)handleTapCoverView:(nullable UIGestureRecognizer *)sender;
/**
 * @brief Switch to the special store tab.
 * @ghidraAddress 0x1ef76c
 */
- (void)switchToSpecialStore;

#pragma mark - iTunes and terms

/**
 * @brief Open an iTunes URL through the application's root view controller.
 * @param url The iTunes URL to open.
 * @ghidraAddress 0x1eedb0
 */
- (void)storeDetailViewOpenItunesWithURL:(nullable NSURL *)url;
/**
 * @brief Open an iTunes URL, presenting an in-app store product page when possible.
 * @param url The iTunes URL to open.
 * @ghidraAddress 0x1eee74
 */
- (void)openItunesWithURL:(nullable NSURL *)url;
/**
 * @brief Dismiss the presented iTunes store product page.
 * @ghidraAddress 0x1ef1ec
 */
- (void)closeItunesWithURL;
/**
 * @brief Show the store terms overlay.
 * @ghidraAddress 0x1ef8a0
 */
- (void)showTerms;

#pragma mark - Errors and alerts

/**
 * @brief Show the full-screen error message overlay.
 * @param message The error message to display.
 * @ghidraAddress 0x1e0a90
 */
- (void)showError:(NSString *)message;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
