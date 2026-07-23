/** @file
 * The genre-select list controller presented from the store page. It shows the pack store's genres
 * in a single-section @c UITableView, one row per genre, and forwards the chosen genre back to the
 * hosting @c RBStorePageViewController (through @c switchToGenre: and @c hideGenreSelect:) when a
 * row is tapped. It is pushed on the phone and hosted in a popover on the pad, and sizes its
 * preferred content to the genre count.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c RBStoreGenreViewController,
 * image base 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

#import "RBBaseViewController.h"

@class RBStorePackList;
@class RBStorePageViewController;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The genre-select list controller shown from the pack store page.
 */
@interface RBStoreGenreViewController
    : RBBaseViewController <UITableViewDelegate, UITableViewDataSource>

/**
 * @brief The genre list table.
 */
@property(nonatomic, strong, nullable) UITableView *tableView;

/**
 * @brief The pack-list model whose genres are listed. Held without ownership; the store page owns
 * it.
 */
@property(nonatomic, assign, nullable) RBStorePackList *packListCtrl;

/**
 * @brief The store page that presented the controller, notified when a genre is selected. Held
 * without ownership to avoid a retain cycle back to the presenter.
 */
@property(nonatomic, assign, nullable) RBStorePageViewController *storeViewCtrl;

/**
 * @brief Build the genre table and size the preferred content to the genre count.
 * @ghidraAddress 0x1ca638
 */
- (void)loadView;

/**
 * @brief Set the navigation title to the localised "Category" string as the view appears.
 * @param animated Whether the appearance is animated.
 * @ghidraAddress 0x1cab0c
 */
- (void)viewWillAppear:(BOOL)animated;

/**
 * @brief Provide the cell for the genre at the given row.
 * @param tableView The genre table.
 * @param indexPath The row index path whose row selects the genre.
 * @return The configured genre cell.
 * @ghidraAddress 0x1cabe8
 */
- (nullable UITableViewCell *)tableView:(nonnull UITableView *)tableView
                  cellForRowAtIndexPath:(nonnull NSIndexPath *)indexPath;

/**
 * @brief The number of sections in the genre table.
 * @param tableView The genre table.
 * @return Always one section.
 * @ghidraAddress 0x1caf08
 */
- (NSInteger)numberOfSectionsInTableView:(nonnull UITableView *)tableView;

/**
 * @brief The number of genre rows in the section.
 * @param tableView The genre table.
 * @param section The section index.
 * @return The number of genres.
 * @ghidraAddress 0x1caf10
 */
- (NSInteger)tableView:(nonnull UITableView *)tableView numberOfRowsInSection:(NSInteger)section;

/**
 * @brief Genre-cell display hook. Intentionally does nothing.
 * @param tableView The genre table.
 * @param cell The cell about to be displayed.
 * @param indexPath The row index path of the cell.
 * @ghidraAddress 0x1caf78
 */
- (void)tableView:(nonnull UITableView *)tableView
      willDisplayCell:(nonnull UITableViewCell *)cell
    forRowAtIndexPath:(nonnull NSIndexPath *)indexPath;

/**
 * @brief The height of a genre row.
 * @param tableView The genre table.
 * @param indexPath The row index path.
 * @return The fixed genre-row height.
 * @ghidraAddress 0x1caf7c
 */
- (CGFloat)tableView:(nonnull UITableView *)tableView
    heightForRowAtIndexPath:(nonnull NSIndexPath *)indexPath;

/**
 * @brief Handle a genre row tap: notify the store page of the selected genre and dismiss.
 * @param tableView The genre table.
 * @param indexPath The tapped row index path, whose row selects the genre.
 * @ghidraAddress 0x1caf88
 */
- (void)tableView:(nonnull UITableView *)tableView
    didSelectRowAtIndexPath:(nonnull NSIndexPath *)indexPath;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
