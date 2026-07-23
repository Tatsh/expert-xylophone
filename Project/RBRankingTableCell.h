/** @file
 * A single row in the ranking leaderboard table. It is a @c UITableViewCell subclass that draws a
 * rounded, optionally top- or bottom-cornered background split into three columns (rank, name, and
 * score) and holds the three labels for those columns.
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

#pragma mark Lifecycle

/**
 * @brief Create the row, building its rank, name, and score labels with per-device geometry and
 * fonts, and defaulting the fill and stroke colours to white.
 * @param style The cell style.
 * @param reuseIdentifier The reuse identifier, or @c nil.
 * @return The initialised cell, or @c nil.
 * @ghidraAddress 0xd922c
 */
- (nullable instancetype)initWithStyle:(UITableViewCellStyle)style
                       reuseIdentifier:(nullable NSString *)reuseIdentifier;

#pragma mark Drawing

/**
 * @brief Draw the row background: a stroked outline path and two filled column paths, rounding the
 * top corners when this is the first row and the bottom corners when it is the last.
 * @param rect The rectangle to draw.
 * @ghidraAddress 0xd9e1c
 */
- (void)drawRect:(CGRect)rect;

#pragma mark Properties

/** @brief The label showing the entry's rank. */
@property(strong, nonatomic, nullable) UILabel *labelRank;
/** @brief The label showing the entry's player name. */
@property(strong, nonatomic, nullable) UILabel *labelName;
/** @brief The label showing the entry's formatted score. */
@property(strong, nonatomic, nullable) UILabel *labelScore;
/** @brief The fill colour of the row background columns. */
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
