/** @file
 * @c SFSafariViewController status-bar preference. The application presents the in-app browser
 * full screen, so the category overrides the controller's status-bar preference to hide it.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (category
 * @c SFSafariViewController(RB), image base 0x100000000). Ghidra addresses are offsets
 * relative to the image base.
 *
 * The category has one method and its class is not named in the file: the class a category extends
 * is bound at load time, so it was recovered from the import the category's class field binds to.
 */

#import <SafariServices/SafariServices.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Status-bar preference override for the in-app browser.
 *
 * The category adds no state and overrides a single @c UIViewController preference, so it takes
 * effect on every @c SFSafariViewController the application presents.
 */
@interface SFSafariViewController (RB)

/**
 * @brief Whether the presented browser hides the status bar.
 * @return Always @c YES.
 * @ghidraAddress 0x20f48
 */
- (BOOL)prefersStatusBarHidden;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
