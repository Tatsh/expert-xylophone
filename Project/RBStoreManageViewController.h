/** @file
 * The purchase-management store page. It is the root controller of the store's manage tab, an
 * @c RBBaseViewController subclass owned through @c RBStoreTabController's @c manageNavCtrl. The
 * page lists every purchased tune in a grouped @c UITableView, lets the player re-download or
 * delete a tune (and its extend notes), and offers a "sort" selector that reorders the list by
 * download order, artist reading, or title reading using a @c UILocalizedIndexedCollation. Sort
 * metadata that is missing locally is fetched with a @c Downloader, and re-downloads run through a
 * @c StoreDownloadManager while the host tab controller shows its modal dialog.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c RBStoreManageViewController,
 * image base 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

#import "Downloader.h"
#import "RBBaseViewController.h"
#import "StoreDownloadManager.h"

@class RBStoreManageSortViewController;
@class RBStoreTabController;
@class StoreDownloadManager;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The purchase-management store page, the manage tab's root controller.
 *
 * It is the table's data source and delegate, receives @c Downloader and @c StoreDownloadManager
 * callbacks, and drives the sort-selection popover (on the pad) or pushed controller (on the
 * phone) that its @c RBStoreManageSortViewController presents.
 */
@interface RBStoreManageViewController : RBBaseViewController <UITableViewDelegate,
                                                               UITableViewDataSource,
                                                               StoreDownloadManagerDelegate,
                                                               DownloaderDelegate,
                                                               UIPopoverControllerDelegate>

/**
 * @brief Initialises the page for the given hosting store tab controller.
 *
 * Sets the navigation and tab-bar titles and icons, builds the delete and download button images,
 * the "sort" and "top" bar buttons (the sort button only in the Japanese region), the eleven
 * kana index-section titles, and an initially fully-expanded section-open state, then loads and
 * sorts the purchased-tune list.
 * @param parent The store tab controller that hosts the page.
 * @return The initialised controller, or @c nil on failure.
 * @ghidraAddress 0x1cddc0
 */
- (nullable instancetype)initWithParent:(nullable RBStoreTabController *)parent;

/**
 * @brief Builds the purchased-tune table, the sort view controller and its navigation controller,
 *        and (on the pad) the sort popover.
 * @ghidraAddress 0x1ce97c
 */
- (void)loadView;

/**
 * @brief Presents the sort selector: pushes the sort controller on the phone, or toggles the sort
 *        popover from the tapped bar button on the pad.
 * @param sender The bar button item that fired the action.
 * @ghidraAddress 0x1cf0ec
 */
- (void)presentSortSelect:(nullable id)sender;

/**
 * @brief Dismisses the sort selector (popping the pushed controller or dismissing the popover) and
 *        re-enables the back button.
 * @param sender The control that requested the dismissal.
 * @ghidraAddress 0x1cf2cc
 */
- (void)hideSortSelect:(nullable id)sender;

/**
 * @brief Switches the list to the given sort order, re-titling the sort button. When the sort
 *        metadata dictionary is not yet available, prompts to download it instead.
 * @param sort The new sort-order index, boxed as an @c NSNumber.
 * @param title The sort button title for the chosen order.
 * @ghidraAddress 0x1cf3f4
 */
- (void)switchToSort:(nullable NSNumber *)sort title:(nullable NSString *)title;

/**
 * @brief Toggles the sort button between its ascending and descending titles and reloads the
 *        table, or prompts to download the sort metadata when it is missing.
 * @ghidraAddress 0x1cf77c
 */
- (void)SelectSort;

/**
 * @brief Returns the tune dictionary at the given section and row for the current sort order.
 * @param section The table section index.
 * @param row The row index within the section.
 * @return The tune's catalogue dictionary.
 * @ghidraAddress 0x1cf9ec
 */
- (nullable NSDictionary *)getSortedDictionary:(NSUInteger)section row:(NSUInteger)row;

/**
 * @brief Rebuilds the sorted, sectioned tune list from the given purchased-tune dictionary for the
 *        current sort order and records the purchased-tune count.
 * @param list The purchased-tune dictionary to sort.
 * @return The sorted, sectioned array.
 * @ghidraAddress 0x1cfb48
 */
- (nullable NSArray *)sortList:(nullable NSDictionary *)list;

/**
 * @brief Scrolls the table back to the top.
 * @param sender The bar button item that fired the action.
 * @ghidraAddress 0x1d1080
 */
- (void)goToTop:(nullable id)sender;

/**
 * @brief Toggles a section's expanded state and reloads it.
 * @param sender The section header cell that fired the action; its @c section identifies the row.
 * @ghidraAddress 0x1d1130
 */
- (void)toggleOpen:(nullable id)sender;

/**
 * @brief The per-cell action button handler: re-downloads a not-yet-present tune (showing the host
 *        tab's modal dialog) or prompts to delete a present one.
 * @param sender The cell's action button; its tag encodes the section and row.
 * @ghidraAddress 0x1d24bc
 */
- (void)pushCellButton:(nullable id)sender;

/**
 * @brief Downloads the tune and every purchased extend note for the working section and row
 *        through a @c StoreDownloadManager batch.
 * @ghidraAddress 0x1d2ab8
 */
- (void)startDownloadMusic;

/**
 * @brief Cancels any in-flight downloads and hides the host tab's modal dialog.
 * @param sender The dialog control that requested cancellation.
 * @ghidraAddress 0x1d3b10
 */
- (void)storeDialogCancel:(nullable id)sender;

/**
 * @brief The store tab controller that hosts the page, held weakly to avoid a retain cycle.
 * @ghidraAddress 0x1d4ab4 (getter)
 * @ghidraAddress 0x1d4ad4 (setter)
 */
@property(nonatomic, weak, nullable) RBStoreTabController *parent;
/**
 * @brief The purchased-tune table.
 * @ghidraAddress 0x1d4ae8 (getter)
 * @ghidraAddress 0x1d4af8 (setter)
 */
@property(nonatomic, strong, nullable) UITableView *tableView;
/**
 * @brief The downloader fetching a tune's info JSON before its files are downloaded.
 * @ghidraAddress 0x1d4b30 (getter)
 * @ghidraAddress 0x1d4b40 (setter)
 */
@property(nonatomic, strong, nullable) Downloader *infoDownloader;
/**
 * @brief The batch download manager running the current tune's file downloads.
 * @ghidraAddress 0x1d4b78 (getter)
 * @ghidraAddress 0x1d4b88 (setter)
 */
@property(nonatomic, strong, nullable) StoreDownloadManager *dlManager;
/**
 * @brief The confirm-delete alert view.
 * @ghidraAddress 0x1d4bc0 (getter)
 * @ghidraAddress 0x1d4bd0 (setter)
 */
@property(nonatomic, strong, nullable) UIAlertView *deleteAlertView;
/**
 * @brief The confirm-download-sort-metadata alert view.
 * @ghidraAddress 0x1d4c08 (getter)
 * @ghidraAddress 0x1d4c18 (setter)
 */
@property(nonatomic, strong, nullable) UIAlertView *downloadAlertView;
/**
 * @brief The delete-action button image.
 * @ghidraAddress 0x1d4c50 (getter)
 * @ghidraAddress 0x1d4c60 (setter)
 */
@property(nonatomic, strong, nullable) UIImage *imgDelete;
/**
 * @brief The download-action button image.
 * @ghidraAddress 0x1d4c98 (getter)
 * @ghidraAddress 0x1d4ca8 (setter)
 */
@property(nonatomic, strong, nullable) UIImage *imgDownload;
/**
 * @brief The tune-title label built for a cell.
 * @ghidraAddress 0x1d4ce0 (getter)
 * @ghidraAddress 0x1d4cf0 (setter)
 */
@property(nonatomic, strong, nullable) UILabel *labelName;
/**
 * @brief The tune-artist label built for a cell.
 * @ghidraAddress 0x1d4d28 (getter)
 * @ghidraAddress 0x1d4d38 (setter)
 */
@property(nonatomic, strong, nullable) UILabel *labelArtist;
/**
 * @brief The "sort" bar button item (Japanese region only).
 * @ghidraAddress 0x1d4d70 (getter)
 * @ghidraAddress 0x1d4d80 (setter)
 */
@property(nonatomic, strong, nullable) UIBarButtonItem *sortButton;
/**
 * @brief The "top" bar button item.
 * @ghidraAddress 0x1d4db8 (getter)
 * @ghidraAddress 0x1d4dc8 (setter)
 */
@property(nonatomic, strong, nullable) UIBarButtonItem *topButton;
/**
 * @brief The downloader fetching the sort-metadata list.
 * @ghidraAddress 0x1d4e00 (getter)
 * @ghidraAddress 0x1d4e10 (setter)
 */
@property(nonatomic, strong, nullable) Downloader *sortDataDownloader;
/**
 * @brief The sort-metadata dictionary (artist and title readings keyed by tune identifier).
 * @ghidraAddress 0x1d4e48 (getter)
 * @ghidraAddress 0x1d4e58 (setter)
 */
@property(nonatomic, strong, nullable) NSMutableDictionary *sortDict;
/**
 * @brief The sorted, sectioned tune list backing the table.
 * @ghidraAddress 0x1d4e90 (getter)
 * @ghidraAddress 0x1d4ea0 (setter)
 */
@property(nonatomic, strong, nullable) NSMutableArray *sortedList;
/**
 * @brief The purchased-tune count captured after the last sort, used to detect changes.
 * @ghidraAddress 0x1d4ed8 (getter)
 * @ghidraAddress 0x1d4ee8 (setter)
 */
@property(nonatomic, assign) NSUInteger latestArrayCount;
/**
 * @brief The sort-order index requested while the sort metadata is still downloading.
 * @ghidraAddress 0x1d4ef8 (getter)
 * @ghidraAddress 0x1d4f08 (setter)
 */
@property(nonatomic, assign) NSUInteger tmpCurrentSortIndex;
/**
 * @brief The sort button title requested while the sort metadata is still downloading.
 * @ghidraAddress 0x1d4f18 (getter)
 * @ghidraAddress 0x1d4f28 (setter)
 */
@property(nonatomic, strong, nullable) NSString *tmpCurrentSortTitle;
/**
 * @brief The active sort-order index.
 * @ghidraAddress 0x1d4f60 (getter)
 * @ghidraAddress 0x1d4f70 (setter)
 */
@property(nonatomic, assign) NSUInteger currentSortIndex;
/**
 * @brief The sort-selection page controller.
 * @ghidraAddress 0x1d4f80 (getter)
 * @ghidraAddress 0x1d4f90 (setter)
 */
@property(nonatomic, strong, nullable) RBStoreManageSortViewController *sortViewCtrl;
/**
 * @brief The popover presenting the sort selector on the pad.
 * @ghidraAddress 0x1d4fc8 (getter)
 * @ghidraAddress 0x1d4fd8 (setter)
 */
@property(nonatomic, strong, nullable) UIPopoverController *sortPopoverCtrl;
/**
 * @brief The navigation controller wrapping the sort selector.
 * @ghidraAddress 0x1d5010 (getter)
 * @ghidraAddress 0x1d5020 (setter)
 */
@property(nonatomic, strong, nullable) UINavigationController *sortNavCtrl;
/**
 * @brief The kana index-section titles.
 * @ghidraAddress 0x1d5058 (getter)
 * @ghidraAddress 0x1d5068 (setter)
 */
@property(nonatomic, strong, nullable) NSArray *sectionList;
/**
 * @brief Names of purchased tunes that had no sort-metadata entry.
 * @ghidraAddress 0x1d50a0 (getter)
 * @ghidraAddress 0x1d50b0 (setter)
 */
@property(nonatomic, strong, nullable) NSMutableArray *notFoundMusicList;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
