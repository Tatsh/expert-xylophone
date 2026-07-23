/** @file
 * The ranking leaderboard table view. It is a @c UITableView subclass that loads a scored ranking
 * for a given player scope (friend or total) from Game Center and renders one @c RBRankingTableCell
 * per entry. It also serves as its own @c UITableViewDataSource and @c UITableViewDelegate.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class RBRankingTableView, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <GameKit/GameKit.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A ranking leaderboard table, scoped to the friend or total ranking.
 */
@interface RBRankingTableView : UITableView <UITableViewDataSource, UITableViewDelegate>

#pragma mark Lifecycle

/**
 * @brief Create the ranking table, configure its appearance, and build the "show more" footer
 * button and the status message label.
 * @param frame The table's frame rectangle.
 * @param style The table view style.
 * @return The initialised table, or @c nil.
 * @ghidraAddress 0xda63c
 */
- (nullable instancetype)initWithFrame:(CGRect)frame style:(UITableViewStyle)style;

#pragma mark Loading

/**
 * @brief Load the ranking entries for the current scope. For the friend scope this first loads the
 * local player's friends; for the total scope it loads the first page of scores directly.
 * @ghidraAddress 0xdc174
 */
- (void)loadRanking;

/**
 * @brief Load a page of Game Center scores for the current scope into the table.
 * @param count The number of rows to request (clamped to @c 100).
 * @ghidraAddress 0xdb628
 */
- (void)load:(NSUInteger)count;

/**
 * @brief Clear the table by reloading its data.
 * @ghidraAddress 0xdc508
 */
- (void)clear;

/**
 * @brief The number of rows to display: the number of loaded scores, plus one when the local
 * player's own rank falls beyond the loaded page.
 * @return The row count.
 * @ghidraAddress 0xdb460
 */
- (NSUInteger)numEntries;

/**
 * @brief Show the Game Center connection error: set the message label's text if it is visible, or
 * otherwise present the shared Game Center error alert.
 * @ghidraAddress 0xdb558
 */
- (void)errorMsg;

#pragma mark Actions

/**
 * @brief The "show more" footer button handler: disable the button and load the next page.
 * @param sender The button that was pressed.
 * @ghidraAddress 0xdc514
 */
- (void)pushLoadNext:(nullable id)sender;

#pragma mark Properties

/** @brief The outline colour applied to each row, chosen from the current theme. */
@property(strong, nonatomic, nullable) UIColor *strokeColor;
/** @brief The table footer view that hosts the "show more" button. */
@property(strong, nonatomic, nullable) UIView *footer;
/** @brief The "show more" button that loads the next page of scores. */
@property(strong, nonatomic, nullable) UIButton *buttonLoadNext;
/** @brief The loaded Game Center scores for the current scope. */
@property(strong, nonatomic, nullable) NSMutableArray<GKScore *> *arrayScore;
/** @brief The player display names, indexed to match @c arrayScore. */
@property(strong, nonatomic, nullable) NSMutableArray<NSString *> *arrayName;
/** @brief The status message label shown when there is no data or an error occurs. */
@property(strong, nonatomic, nullable) UILabel *msgLabel;
/** @brief The local player's own score, appended as an extra row when out of the loaded page. */
@property(strong, nonatomic, nullable) GKScore *localPlayerScore;
/** @brief The leaderboard player scope: friend or global. */
@property(nonatomic, assign) GKLeaderboardPlayerScope playerScope;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
