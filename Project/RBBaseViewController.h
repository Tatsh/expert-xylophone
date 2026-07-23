/** @file
 * Shared base class for the application's full-screen view controllers. It is a thin
 * @c UIViewController subclass that hides the status bar and drives every autorotation decision
 * from a single rule: when the region uses the iPad (wide) layout and background music is playing,
 * the interface is locked to the orientation that is already on screen; otherwise all orientations
 * are permitted. Concrete @c RB* view controllers inherit this behaviour.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class RBBaseViewController, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Full-screen view controller base that hides the status bar and locks rotation while music
 * plays.
 */
@interface RBBaseViewController : UIViewController

/**
 * @brief Keep the status bar hidden while this view controller is on screen.
 * @return Always @c YES.
 * @ghidraAddress 0x202740
 */
- (BOOL)prefersStatusBarHidden;

/**
 * @brief Decide whether the view controller may autorotate.
 * @return @c NO only when the iPad (wide) layout is active and background music is playing;
 * otherwise @c YES.
 * @ghidraAddress 0x202748
 */
- (BOOL)shouldAutorotate;

/**
 * @brief Report the interface orientations this view controller supports.
 * @return @c UIInterfaceOrientationMaskAll when the phone (standard) layout is active; otherwise the
 * orientation is constrained to portrait or landscape-left depending on the current orientation
 * while music is playing.
 * @ghidraAddress 0x202778
 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations;

/**
 * @brief Report the preferred orientation for a modal presentation.
 * @return Always @c UIInterfaceOrientationPortrait.
 * @ghidraAddress 0x2027d4
 */
- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation;

/**
 * @brief Legacy (pre-iOS 6) autorotation predicate for a specific interface orientation.
 * @param interfaceOrientation The candidate interface orientation.
 * @return @c YES for the phone (standard) layout; for the wide variant, @c YES only for the portrait
 * orientations while no music is playing.
 * @ghidraAddress 0x2027dc
 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
