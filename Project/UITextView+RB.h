/**
 * @file
 * @brief @c UITextView first-responder suppression.
 *
 * The application uses text views only to display
 * scrollable prose, never to accept input, so the category refuses first-responder status and the
 * keyboard never appears.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (category @c UITextView(RB), image base
 * 0x100000000). Ghidra addresses are offsets relative to the image base.
 *
 * The category has one method and its class is not named in the file: the class a category extends
 * is bound at load time, so it was recovered from the import the category's class field binds to.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief First-responder suppression for every text view in the application.
 *
 * The category adds no state and overrides a single @c UIResponder query, so it takes effect on
 * every @c UITextView the application creates and the keyboard never appears.
 */
@interface UITextView (RB)

/**
 * @brief Whether the receiver will accept first-responder status.
 * @return Always @c NO.
 * @ghidraAddress 0x366f0
 */
- (BOOL)canBecomeFirstResponder;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
