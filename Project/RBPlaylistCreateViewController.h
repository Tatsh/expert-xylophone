/** @file
 * The playlist-creation screen's view controller. It is an @c RBBaseViewController subclass that
 * presents a single-line text field over a white view so the player can name a new playlist. The
 * navigation bar carries a "done" button that trims the entered name and, when non-empty, adds the
 * playlist through @c RBPlaylistManager before popping, plus a "Return" button that pops without
 * saving. The text field's content drives the "done" button's enabled state, limits the name to
 * 128 characters, and treats the on-screen keyboard's return key as a commit. It is pushed by
 * @c RBPlaylistViewController's -addButtonPush:.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c RBPlaylistCreateViewController,
 * image base 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

#import "RBBaseViewController.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The playlist-creation screen: a named-playlist text-entry form.
 */
@interface RBPlaylistCreateViewController : RBBaseViewController <UITextFieldDelegate>

#pragma mark - Properties

/**
 * @brief The playlist-name entry field. The controller is its delegate and its editing target.
 */
@property(nonatomic, strong, nullable) UITextField *textField;
/**
 * @brief The navigation item's custom title label.
 */
@property(nonatomic, strong, nullable) UILabel *titleLabel;
/**
 * @brief The header title label's colour.
 */
@property(nonatomic, strong, nullable) UIColor *titleColor;
/**
 * @brief The colour applied to the currently selected row (kept for theme parity with the sibling
 * playlist screens; unused by this form).
 */
@property(nonatomic, strong, nullable) UIColor *selectedRowColor;
/**
 * @brief The navigation-bar button tint colour (used on pre-iOS 7).
 */
@property(nonatomic, strong, nullable) UIColor *buttonColor;

#pragma mark - Navigation-bar buttons

/**
 * @brief The "done" button action: trim the entered name and, when non-empty, add the playlist and
 * synchronise, then pop this controller.
 * @param sender The done bar button item.
 * @ghidraAddress 0x90530
 */
- (void)doneButtonPush:(nullable id)sender;
/**
 * @brief The "Return" button action: pop this controller without saving.
 * @param sender The return bar button item.
 * @ghidraAddress 0x9070c
 */
- (void)backButtonPush:(nullable id)sender;

#pragma mark - Text field

/**
 * @brief The text-field editing-changed action: enable the "done" button only while the name has at
 * least one character.
 * @param sender The playlist-name text field.
 * @ghidraAddress 0x90778
 */
- (void)fieldChanged:(nullable id)sender;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
