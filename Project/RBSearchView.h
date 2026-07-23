/** @file
 * The music-search popup overlay. It is an @c RBMusicMenuPopupView subclass (popup type
 * @c RBMusicMenuPopupViewTypeSearch) that the pad build of @c RBMenuView presents over the
 * music-menu screen; it hosts an @c RBSearchMapView inside the base popup's content view and a
 * current-position button that recentres the map. As the map's delegate it tracks the user's
 * position, updating the current-position button's selected state.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class RBSearchView, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

#import "RBMusicMenuPopupView.h"
#import "RBSearchMapView.h"

@class RBSettingView;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The search popup: a map view with a recentre button, presented over the music menu.
 */
@interface RBSearchView : RBMusicMenuPopupView <SearchMapViewDelegate>

/**
 * @brief Create the search popup with the given frame.
 *
 * Calls through to @c super, selects the search popup type, and builds the popup chrome.
 * @param frame The view's frame rectangle.
 * @return The initialised view, or @c nil.
 * @ghidraAddress 0xe650c
 */
- (nullable instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief Build the search content: the current-position button and the embedded map view laid out
 * inside the base popup's content view for the current theme.
 * @ghidraAddress 0xe661c
 */
- (void)setupView;

/**
 * @brief Fade the popup in and tell the map to show its initial view.
 * @ghidraAddress 0xe6598
 */
- (void)showAnimation;

/**
 * @brief Clear the shown-map flag, tell the map it disappeared, and fade the popup out.
 * @ghidraAddress 0xe6ed0
 */
- (void)hideAnimation;

/**
 * @brief Current-position button action: toggle the map's user-tracking mode.
 * @param sender The control that sent the action.
 * @ghidraAddress 0xe6e74
 */
- (void)selectCurrentPosition:(nullable id)sender;

/**
 * @brief Map delegate callback: reflect the map's user-tracking state in the current-position
 * button's selected state.
 * @param tracking Whether the map is tracking the user's position.
 * @ghidraAddress 0xe6f94
 */
- (void)didChangeUserTracking:(BOOL)tracking;

/**
 * @brief The embedded map view, created lazily by @c setupView.
 */
@property(strong, nonatomic, nullable) RBSearchMapView *map;

/**
 * @brief The button that recentres the map on the user's current position.
 */
@property(strong, nonatomic, nullable) UIButton *currentPositionButton;

/**
 * @brief The owning settings view, if this popup was presented from settings.
 */
@property(weak, nonatomic, nullable) RBSettingView *settingView;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
