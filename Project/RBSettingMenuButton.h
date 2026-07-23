/** @file
 * A single button in the in-game settings menu overlay. It is a @c UIControl that hosts an inner
 * @c UIButton styled with a themed, resizable background and foreground image for one menu entry
 * (how-to-play, customise, theme, map search, information, Applilink, or terms), plus a hidden
 * flashing effect image and effect-text image used to advertise unseen content.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class RBSettingMenuButton, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A themed settings-menu button hosting an inner @c UIButton and a flashing new-content
 * effect overlay.
 *
 * The owning @c RBSettingView creates one instance per menu entry with @c initWithFilename:, wires a
 * target/action onto its @c button, and calls @c setFlashEffect / @c removeFlashEffect to show or
 * hide the new-content flash.
 */
@interface RBSettingMenuButton : UIControl

/**
 * @brief Create the button for one menu entry and build its inner control and effect overlays.
 *
 * Calls through to @c super, then lays the inner @c button, background and foreground artwork, and
 * the (initially hidden) effect image and effect-text image out for the menu entry @p filename.
 * @param filename The menu-entry artwork index (0 how-to, 1 customise, 2 theme, 3 search, 5
 * information, 6 Applilink, 7 terms), selecting the themed image family.
 * @return The initialised button, or @c nil.
 * @ghidraAddress 0xe8fa8
 */
- (nullable instancetype)initWithFilename:(NSInteger)filename;

/**
 * @brief Build the inner control and the background, foreground, effect, and effect-text views.
 *
 * Sizes the receiver's bounds for the current theme and font variant, creates the inner @c button,
 * loads the resizable themed artwork for @p filename, and adds the two hidden effect image views.
 * @param filename The menu-entry artwork index selecting the themed image family.
 * @ghidraAddress 0xe902c
 */
- (void)setupView:(NSInteger)filename;

/**
 * @brief Show and start the fast flash on the effect image and effect-text image.
 * @ghidraAddress 0xe9a04
 */
- (void)setFlashEffect;

/**
 * @brief Hide the effect image and effect-text image and stop the effect-text flash.
 * @ghidraAddress 0xe9b20
 */
- (void)removeFlashEffect;

/**
 * @brief The inner button that carries the themed artwork and the caller's target/action.
 */
@property(strong, nonatomic, nullable) UIButton *button;

/**
 * @brief The flashing effect image shown over the button when new content is available.
 */
@property(strong, nonatomic, nullable) UIImageView *effectImageView;

/**
 * @brief The flashing effect-text image shown over the button when new content is available.
 */
@property(strong, nonatomic, nullable) UIImageView *effectTextImageView;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
