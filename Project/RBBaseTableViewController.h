/** @file
 * Shared base class for the application's grouped table screens. It is a @c UITableViewController
 * subclass that hides the status bar, paints the table's background white, and drives every
 * autorotation decision from a single rule: when the region uses the iPad (wide) layout and
 * background music is playing, the interface is locked to the orientation that is already on
 * screen; otherwise all orientations are permitted. Concrete @c RB* table view controllers inherit
 * this behaviour. The class adds no ivars, properties, or protocols of its own.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c RBBaseTableViewController, image
 * base 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Grouped table view controller base that hides the status bar, whitens the table
 *        background, and locks rotation while music plays.
 */
@interface RBBaseTableViewController : UITableViewController

/**
 * @brief Loads the view, then paints the table's background white.
 * @ghidraAddress 0x20282c
 */
- (void)viewDidLoad;

/**
 * @brief Keep the status bar hidden while this view controller is on screen.
 * @return Always @c YES.
 * @ghidraAddress 0x2028f8
 */
- (BOOL)prefersStatusBarHidden;

/**
 * @brief Decide whether the view controller may autorotate.
 * @return @c NO only when the iPad (wide) layout is active and background music is playing;
 * otherwise @c YES.
 * @ghidraAddress 0x202900
 */
- (BOOL)shouldAutorotate;

/**
 * @brief Report the interface orientations this view controller supports.
 * @return @c UIInterfaceOrientationMaskAll when the phone (standard) layout is active; otherwise the
 * orientation is constrained to portrait or landscape-left depending on the current orientation
 * while music is playing.
 * @ghidraAddress 0x202930
 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations;

/**
 * @brief Report the preferred orientation for a modal presentation.
 * @return Always @c UIInterfaceOrientationPortrait.
 * @ghidraAddress 0x20298c
 */
- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation;

/**
 * @brief Legacy (pre-iOS 6) autorotation predicate for a specific interface orientation.
 * @param interfaceOrientation The candidate interface orientation.
 * @return @c YES for the phone (standard) layout; for the wide variant, @c YES only for the portrait
 * orientations while no music is playing.
 * @ghidraAddress 0x202994
 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
