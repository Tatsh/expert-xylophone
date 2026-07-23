/** @file
 * The in-app store tab controller. Despite the @c Controller suffix it is a @c UITabBarController
 * subclass (via @c RBBaseTabBarController) that hosts the store's four tabs: the song-pack store,
 * the extend-note store, the purchase-management screen, and the campaign screen, each wrapped in
 * its own @c RBNavigationController. It also owns the modal download dialog and the dimming cover
 * view shown over the tabs while a download runs. @c RBMenuView pushes it onto the application's
 * navigation controller when the store button is tapped.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c RBStoreTabController, image
 * base 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

#import "RBBaseTabBarController.h"

@class RBMenuView;
@class RBNavigationController;
@class RBStoreExtendPageViewController;
@class RBCampaignViewController;
@class RBPrivilegesViewController;
@class StoreDialogView;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The store's tab bar controller, hosting the pack, extend-note, manage, and campaign tabs.
 */
@interface RBStoreTabController : RBBaseTabBarController

/**
 * @brief Builds the four store tabs and their navigation controllers, then selects the tab a
 *        pending open request (pack, campaign, or extend-note identifier) asks for.
 * @return The initialised controller, or @c nil on failure.
 * @ghidraAddress 0x1d537c
 */
- (nullable instancetype)init;

/**
 * @brief Creates the dimming cover view and the modal download dialog, sizing the dialog and its
 *        message font for the phone or pad layout.
 * @ghidraAddress 0x1d6018
 */
- (void)loadView;

/**
 * @brief Shows the modal download dialog with a fade-in, disabling its abort button and routing
 *        its delegate callbacks to the given receiver. Ignores the request while an animation is
 *        in flight.
 * @param delegate The dialog delegate to receive the download-dialog callbacks.
 * @return @c YES if the dialog began showing, @c NO if an animation was already running.
 * @ghidraAddress 0x1d655c
 */
- (BOOL)showModalDialog:(nullable id)delegate;

/**
 * @brief Hides the modal download dialog with a fade-out and stops the download UI on completion.
 * @return Always @c YES.
 * @ghidraAddress 0x1d68c4
 */
- (BOOL)hideModalDialog;

/**
 * @brief Selects the store tab with the given index, unless a tab-switch animation is running.
 * @param index The store tab index (pack, extend-note, manage, or campaign).
 * @ghidraAddress 0x1d754c
 */
- (void)selectTab:(int)index;

/**
 * @brief Re-opens the store for a queued open request, switching to the matching tab and forcing
 *        the relevant detail view open on the pack, campaign, or extend-note page controller.
 * @ghidraAddress 0x1d6f6c
 */
- (void)forceOpen;

/**
 * @brief Back-button action: stops the pack promotion, restores the menu BGM, reloads the music
 *        list, pops the store's navigation stack to the root, and tears the store controller down
 *        in the host menu view.
 * @param sender The bar button item that fired the action.
 * @ghidraAddress 0x1d6c20
 */
- (void)pushBarBtnBack:(nullable id)sender;

/**
 * @brief The menu view that hosts the store, held weakly to avoid a retain cycle.
 */
@property(weak, nonatomic, nullable) RBMenuView *musicMenuView;

/**
 * @brief The dimming cover view shown over the tabs while a download runs.
 */
@property(strong, nonatomic, nullable) UIView *coverView;

/**
 * @brief The modal download dialog.
 */
@property(strong, nonatomic, nullable) StoreDialogView *modalDialog;

/**
 * @brief The navigation controller wrapping the song-pack store page.
 */
@property(strong, nonatomic, nullable) RBNavigationController *mainNavCtrl;

/**
 * @brief The navigation controller wrapping the extend-note store page.
 */
@property(strong, nonatomic, nullable) RBNavigationController *extendNoteNavCtrl;

/**
 * @brief The extend-note store page controller hosted by @c extendNoteNavCtrl.
 */
@property(strong, nonatomic, nullable) RBStoreExtendPageViewController *extendNotePageViewCtrl;

/**
 * @brief The navigation controller wrapping the purchase-management page.
 */
@property(strong, nonatomic, nullable) RBNavigationController *manageNavCtrl;

/**
 * @brief The navigation controller wrapping the privileges page.
 */
@property(strong, nonatomic, nullable) RBNavigationController *privilegesNavCtrl;

/**
 * @brief The navigation controller wrapping the campaign store page.
 */
@property(strong, nonatomic, nullable) RBNavigationController *campaignNavCtrl;

/**
 * @brief The privileges page controller.
 */
@property(strong, nonatomic, nullable) RBPrivilegesViewController *privilegesViewCtrl;

/**
 * @brief The campaign store page controller hosted by @c campaignNavCtrl.
 */
@property(strong, nonatomic, nullable) RBCampaignViewController *campaignViewCtrl;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C++
// kate: hl Objective-C++;
// vim: set ft=objcpp :
