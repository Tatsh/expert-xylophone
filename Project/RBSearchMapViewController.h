/** @file
 * The arcade-locator map screen. It is an @c RBBaseViewController subclass that hosts an
 * @c RBSearchMapView (the treasure-map view) full-screen. It installs a custom navigation bar with a
 * back button and a "current location" button, shows the map once the view has appeared, and toggles
 * the map's user-tracking mode when the location button is tapped. As the map's
 * @c SearchMapViewDelegate it reflects tracking-state changes onto the location button's selected
 * state.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c RBSearchMapViewController, image
 * base 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

#import "RBBaseViewController.h"
#import "RBSearchMapView.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Full-screen view controller that hosts the search map and its navigation-bar controls.
 */
@interface RBSearchMapViewController : RBBaseViewController <SearchMapViewDelegate>

/**
 * @brief Build the custom navigation-bar title view and the back and current-location buttons.
 * @ghidraAddress 0xe5748
 */
- (instancetype)init;

/**
 * @brief Navigation-bar action that plays the cancel sound and pops back to the previous screen.
 * @param sender The bar button that sent the action.
 * @ghidraAddress 0xe6238
 */
- (void)pushBarBtnBack:(nullable id)sender;

/**
 * @brief Navigation-bar action that toggles the hosted map's user-tracking mode.
 * @param sender The bar button that sent the action.
 * @ghidraAddress 0xe6300
 */
- (void)pushCurrent:(nullable id)sender;

/**
 * @brief Pop back to the previous screen without animation, restoring the navigation bar.
 * @ghidraAddress 0xe63a0
 */
- (void)forceClose;

/**
 * @brief The current-location toggle button shown on the right of the navigation bar.
 * @ghidraAddress 0xe64b0 (getter)
 * @ghidraAddress 0xe64c0 (setter)
 */
@property(strong, nonatomic, nullable) UIButton *currentLocation;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
