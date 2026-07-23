/** @file
 * The ranking leaderboard table view. It is a @c UITableView subclass that loads and displays a
 * scored ranking for a given player scope (friend or total). Only the members messaged by
 * @c RBRankingView are declared here; the full class is reconstructed separately.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class RBRankingTableView, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A ranking leaderboard table, scoped to the friend or total ranking.
 */
@interface RBRankingTableView : UITableView

/**
 * @brief Select the ranking scope: the friend ranking (@c 1) or the total ranking (@c 0).
 * @param playerScope The scope identifier.
 */
- (void)setPlayerScope:(int)playerScope;

/**
 * @brief Load the ranking entries for the current scope.
 */
- (void)loadRanking;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
