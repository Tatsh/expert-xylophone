/** @file
 * A single row in the ranking leaderboard table. It is a @c UITableViewCell subclass that draws a
 * rounded, optionally top- or bottom-cornered background and holds three labels (rank, name, and
 * score).
 *
 * This is a minimal interface declaring only the members messaged by @c RBRankingTableView; the
 * full class is reconstructed separately.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class RBRankingTableCell, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A ranking leaderboard row showing a player's rank, name, and score.
 */
@interface RBRankingTableCell : UITableViewCell

/** @brief The label showing the entry's rank. */
@property(strong, nonatomic, nullable) UILabel *labelRank;
/** @brief The label showing the entry's player name. */
@property(strong, nonatomic, nullable) UILabel *labelName;
/** @brief The label showing the entry's formatted score. */
@property(strong, nonatomic, nullable) UILabel *labelScore;
/** @brief The fill colour of the row background. */
@property(strong, nonatomic, nullable) UIColor *fillColor;
/** @brief The stroke colour of the row background outline. */
@property(strong, nonatomic, nullable) UIColor *strokeColor;
/** @brief Whether the row is the first (top) row, which rounds its top corners. */
@property(nonatomic, assign) BOOL isTop;
/** @brief Whether the row is the last (bottom) row, which rounds its bottom corners. */
@property(nonatomic, assign) BOOL isLast;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
