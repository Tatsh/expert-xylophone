/** @file
 * The application's root navigation controller. It is a thin @c UINavigationController subclass
 * that keeps the navigation bar opaque and hidden, forces the status bar hidden, and forwards its
 * autorotation decisions to whichever view controller is currently visible.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class RBNavigationController, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

/**
 * @brief Root navigation controller that defers rotation to its visible view controller.
 */
@interface RBNavigationController : UINavigationController

/**
 * @brief Configure the navigation bar after the view loads.
 *
 * Calls through to @c super and then makes the navigation bar opaque by clearing its
 * @c translucent flag.
 * @ghidraAddress 0x1c9804
 */
- (void)viewDidLoad;

/**
 * @brief Keep the status bar hidden while this navigation controller is on screen.
 * @return Always @c YES.
 * @ghidraAddress 0x1c988c
 */
- (BOOL)prefersStatusBarHidden;

/**
 * @brief Defer the autorotation decision to the currently visible view controller.
 * @return The value returned by the visible view controller's @c -shouldAutorotate.
 * @ghidraAddress 0x1c9894
 */
- (BOOL)shouldAutorotate;

/**
 * @brief Defer the supported orientations to the currently visible view controller.
 * @return The orientation mask returned by the visible view controller's
 * @c -supportedInterfaceOrientations.
 * @ghidraAddress 0x1c98f4
 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations;

@end

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
