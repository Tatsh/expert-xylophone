/** @file
 * The playlist screen's view controller. It is an @c RBBaseTableViewController subclass that
 * presents one of three related list surfaces selected by its @c playlistType and @c playlistNode
 * mode fields: the playlist root menu (all, new, level, and append rows plus the user's saved
 * playlists), the level-select node, and the add-to-playlist picker driven by a music set. Row
 * selection persists the chosen playlist filter through @c RBUserSettingData, edits the saved
 * playlists through @c RBPlaylistManager, and notifies its delegate. The music-or-artist sort
 * toggle in the navigation bar retitles the header and reloads the table.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c RBPlaylistViewController, image
 * base 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

#import "RBBaseTableViewController.h"

@class RBPlaylistViewController;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Receives notifications when the playlist controller finishes a selection.
 */
@protocol RBPlaylistViewControllerDelegate <NSObject>

@optional
/**
 * @brief Sent after a playlist filter row is selected.
 * @param viewController The playlist controller that made the selection.
 * @ghidraAddress 0x8a294
 */
- (void)didSelectPlaylistViewController:(RBPlaylistViewController *)viewController;
/**
 * @brief Sent after the music-or-artist sort segment changes.
 * @param viewController The playlist controller whose sort order changed.
 * @ghidraAddress 0x8a3e8
 */
- (void)didSelectMenuSortViewController:(RBPlaylistViewController *)viewController;

@end

/**
 * @brief The playlist list screen, a grouped table of playlist filters, level nodes, or an
 * add-to-playlist picker.
 */
@interface RBPlaylistViewController
    : RBBaseTableViewController <UITableViewDataSource, UITableViewDelegate>

#pragma mark - Properties

/**
 * @brief The delegate notified when a selection or sort change completes. Held weakly.
 */
@property(nonatomic, weak, nullable) id<RBPlaylistViewControllerDelegate> delegate;
/**
 * @brief The controller mode: @c 0 for the playlist menu or level node, @c 1 for the
 * add-to-playlist picker.
 */
@property(nonatomic, assign) NSInteger playlistType;
/**
 * @brief The node mode: @c 0 for the top-level menu, @c 1 for the level-select node.
 */
@property(nonatomic, assign) NSInteger playlistNode;
/**
 * @brief The music identifiers to add when a destination playlist is picked (add-to-playlist mode).
 */
@property(nonatomic, strong, nullable) NSMutableSet *musicSet;
/**
 * @brief The menu row descriptors (each a dictionary of @c title and @c text) for section zero.
 */
@property(nonatomic, strong, nullable) NSArray *menuItems;
/**
 * @brief The user's saved playlists, shown in section one.
 */
@property(nonatomic, strong, nullable) NSArray *playlistFiles;
/**
 * @brief The row text colour for the "music" sort order.
 */
@property(nonatomic, strong, nullable) UIColor *musicColor;
/**
 * @brief The row text colour for the "artist" sort order.
 */
@property(nonatomic, strong, nullable) UIColor *artistColor;
/**
 * @brief The colour applied to the currently selected filter row.
 */
@property(nonatomic, strong, nullable) UIColor *selectedRowColor;
/**
 * @brief The header title label's colour.
 */
@property(nonatomic, strong, nullable) UIColor *titleColor;
/**
 * @brief The navigation-bar button tint colour (used on pre-iOS 7).
 */
@property(nonatomic, strong, nullable) UIColor *buttonColor;
/**
 * @brief The navigation item's custom title label.
 */
@property(nonatomic, strong, nullable) UILabel *titleLabel;
/**
 * @brief The music-or-artist sort toggle shown in the navigation bar.
 */
@property(nonatomic, strong, nullable) UISegmentedControl *segmentedControl;

#pragma mark - Sort segment

/**
 * @brief The sort-segment change action: persist the sort order, notify the delegate, and retitle.
 * @param sender The sort segmented control.
 * @ghidraAddress 0x927ec
 */
- (void)valueChanged:(nullable id)sender;

#pragma mark - Data

/**
 * @brief Rebuild the menu rows (or the per-difficulty level counts) and reload the table.
 * @ghidraAddress 0x92944
 */
- (void)reloadData;

#pragma mark - Navigation-bar buttons

/**
 * @brief The "return" button action: pop this controller.
 * @param sender The return bar button item.
 * @ghidraAddress 0x93a7c
 */
- (void)returnButtonPush:(nullable id)sender;
/**
 * @brief The "close" button action: dismiss the presented navigation controller.
 * @param sender The close bar button item.
 * @ghidraAddress 0x93ae8
 */
- (void)closeButtonPush:(nullable id)sender;
/**
 * @brief The "new" (add) button action: push a playlist-create controller.
 * @param sender The add bar button item.
 * @ghidraAddress 0x93bd8
 */
- (void)addButtonPush:(nullable id)sender;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
