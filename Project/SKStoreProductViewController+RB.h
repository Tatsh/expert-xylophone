/** @file
 * @c SKStoreProductViewController status-bar preference. The application presents the App Store
 * product sheet full screen, so the category overrides the controller's status-bar preference to
 * hide it.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (category
 * @c SKStoreProductViewController(RB), image base 0x100000000). @ghidraAddress values are offsets
 * relative to the image base.
 *
 * The category has one method and its class is not named in the file: the class a category extends
 * is bound at load time, so it was recovered from the import the category's class field binds to.
 */

#import <StoreKit/StoreKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SKStoreProductViewController (RB)

/**
 * @brief Whether the presented product sheet hides the status bar.
 * @return Always @c YES.
 * @ghidraAddress 0x88fb8
 */
- (BOOL)prefersStatusBarHidden;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
