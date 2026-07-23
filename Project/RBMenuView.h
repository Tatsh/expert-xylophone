/** @file
 * The music-menu hub view that hosts the settings, popups, tutorial overlay, and the menu chrome.
 *
 * Speculative, partial interface: only the members the already-reconstructed callers use are
 * declared here. The full hub is reconstructed separately. Reconstructed from Ghidra project
 * rb458, program rb458 (class @c RBMenuView, image base 0x100000000).
 */

#import <UIKit/UIKit.h>

#import "RBMenuTutorialView.h"

@class RBViewController;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Music-menu hub view.
 */
@interface RBMenuView : UIView

/**
 * @brief Create the menu hub owned by the given view controller.
 * @param frame The view's frame rectangle.
 * @param viewController The hosting view controller.
 * @return The initialised view, or @c nil.
 */
- (nullable instancetype)initWithFrame:(CGRect)frame
                        viewController:(nullable RBViewController *)viewController;

/**
 * @brief Present @p view over the menu, or dismiss the current one when @p view is @c nil.
 * @param view The view to show, or @c nil to dismiss.
 */
- (void)setShowView:(nullable UIView *)view;

/**
 * @brief Begin the pastel highlight for a tutorial step (used by @c RBMenuTutorialView on show).
 */
- (void)setPastelForTutorialStart;

/**
 * @brief End the pastel highlight for a tutorial step (used by @c RBMenuTutorialView on hide).
 */
- (void)setPastelForTutorialEnd;

/**
 * @brief The song grid the music-select tutorial step highlights.
 * @return The collection view.
 */
- (nullable UIView *)getCollectionView;

/**
 * @brief The tutorial song's cell the music-select tutorial step highlights.
 * @return The tutorial music cell.
 */
- (nullable UIView *)getTutorialMusicCell;

/**
 * @brief The settings button the settings tutorial step highlights.
 * @return The settings button.
 */
- (nullable UIView *)getSettingButton;

/**
 * @brief Dismiss the customize popup at the end of the customize tutorial.
 */
- (void)closeCustomize;

/**
 * @brief Reload the menu's music data after the purchased-music catalogue changes.
 */
- (void)reloadMusicData;

/**
 * @brief The view currently shown over the menu.
 */
@property(strong, nonatomic, nullable) UIView *showView;

/**
 * @brief The in-menu tutorial overlay.
 */
@property(strong, nonatomic, nullable) RBMenuTutorialView *tutorialView;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
