/** @file
 * The ranking (leaderboard) popup view. It is an @c RBMusicMenuPopupView configured with the
 * ranking popup type, presenting two overlaid @c RBRankingTableView leaderboards — a friend-scope
 * board and a total-scope board — inside the popup's content view, with a pair of tab buttons that
 * switch between them.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class RBRankingView, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

#import "RBMusicMenuPopupView.h"

@class RBRankingTableView;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Popup view that shows the friend and total ranking boards over the music menu.
 */
@interface RBRankingView : RBMusicMenuPopupView

#pragma mark Lifecycle

/**
 * @brief Create the ranking popup, select the ranking popup type, and build its content.
 * @param frame The view's frame rectangle.
 * @return The initialised view, or @c nil.
 * @ghidraAddress 0xdda2c
 */
- (nullable instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief Build the ranking content: the friend and total ranking table views, and the friend and
 * all tab buttons with their flash effects; then show the total board.
 * @ghidraAddress 0xddaec
 */
- (void)setupView;

#pragma mark Actions

/**
 * @brief Switch which ranking board is visible: show the friend board and its selected tab, or the
 * total board and its tab.
 * @param showFriend Whether to show the friend board (@c YES) or the total board (@c NO).
 * @ghidraAddress 0xdec60
 */
- (void)showFriend:(BOOL)showFriend;

/**
 * @brief Friend tab handler: play the cancel sound effect and show the friend board.
 * @ghidraAddress 0xdedf4
 */
- (void)SelectFriendButton;

/**
 * @brief All tab handler: play the cancel sound effect and show the total board.
 * @ghidraAddress 0xdee2c
 */
- (void)SelectAllButton;

#pragma mark Properties

/** @brief The optional title image view at the top of the content view. */
@property(strong, nonatomic, nullable) UIImageView *titleView;
/** @brief The optional scrolling base view that hosts the boards. */
@property(strong, nonatomic, nullable) UIView *scrollBaseView;
/** @brief The friend-scope ranking board. */
@property(strong, nonatomic, nullable) RBRankingTableView *friendRanking;
/** @brief The total-scope ranking board. */
@property(strong, nonatomic, nullable) RBRankingTableView *totalRanking;
/** @brief The friend tab button. */
@property(strong, nonatomic, nullable) UIButton *friendButton;
/** @brief The flash overlay drawn over the friend tab button. */
@property(strong, nonatomic, nullable) UIImageView *friendButtonEffect;
/** @brief The all (total) tab button. */
@property(strong, nonatomic, nullable) UIButton *allButton;
/** @brief The flash overlay drawn over the all tab button. */
@property(strong, nonatomic, nullable) UIImageView *allButtonEffect;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C++
// kate: hl Objective-C++;
// vim: set ft=objcpp :
