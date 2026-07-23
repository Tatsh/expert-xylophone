/** @file
 * The in-game settings menu overlay. It slides a rounded panel of themed menu buttons down over the
 * music-select screen, letting the player open the how-to-play, customise, theme, map search,
 * notification, terms, and Applilink sub-screens, or dismiss the panel.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class RBSettingView, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

@class RBMusicView;
@class RBSettingMenuButton;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The settings menu overlay presented over the music-select screen.
 *
 * The panel (@c baseView) is styled per the current theme and hosts a vertical column of
 * @c RBSettingMenuButton controls. Opening and closing are animated by growing or shrinking the
 * panel from the top edge; a tap outside the panel dismisses it.
 */
@interface RBSettingView : UIView

/**
 * @brief Create the settings overlay and build its panel and buttons.
 *
 * Calls through to @c super with @p frame, then lays the panel and buttons out within
 * @p buttonFrame.
 * @param frame The overlay's frame rectangle (the full screen area).
 * @param buttonFrame The rectangle within which the panel and its buttons are laid out.
 * @return The initialised view, or @c nil.
 * @ghidraAddress 0xe9dac
 */
- (nullable instancetype)initWithFrame:(CGRect)frame ButtonFrame:(CGRect)buttonFrame;

/**
 * @brief Build the panel and its column of menu buttons.
 *
 * Reads the current theme to style @c baseView (background, border, and corner radius), then adds
 * one @c RBSettingMenuButton per menu entry, stacking them vertically. Applies the new-item flash
 * effect to the customise, how-to, theme, and Applilink buttons when their corresponding
 * @c RBUserSettingData flags or the unread-recommend count so indicate.
 * @param buttonFrame The rectangle within which the panel and buttons are laid out.
 * @ghidraAddress 0xe9e84
 */
- (void)setupView:(CGRect)buttonFrame;

/**
 * @brief Play the themed open sound effect and show the panel.
 * @ghidraAddress 0xeb0e4
 */
- (void)OpenView;

/**
 * @brief Play the themed cancel sound effect and hide the panel.
 *
 * Does nothing while an open or close animation is in progress.
 * @ghidraAddress 0xeb144
 */
- (void)CloseView;

/**
 * @brief Animate the panel open: fade the overlay in and grow the panel downward from the top edge.
 * @ghidraAddress 0xeb194
 */
- (void)showAnimation;

/**
 * @brief Animate the panel closed: disable the buttons and shrink the panel back up to the top edge.
 * @ghidraAddress 0xeb674
 */
- (void)hideAnimation;

/**
 * @brief Close-animation completion: notify the parent, remove the overlay, and clear the parent's
 * settings-view back-pointer.
 * @ghidraAddress 0xeb910
 */
- (void)hideAnimationEnd;

/**
 * @brief Dismiss the panel when a touch ends outside it.
 * @param touches The ended touches.
 * @param event The event the touches belong to.
 * @ghidraAddress 0xeb9c8
 */
- (void)touchesEnded:(nullable NSSet *)touches withEvent:(nullable UIEvent *)event;

/**
 * @brief Handle the customise button: open the customise sub-screen and clear the new-item flag.
 * @ghidraAddress 0xebbc0
 */
- (void)SelectCustomizeButton;

/**
 * @brief Handle the theme button: open the theme sub-screen and clear the new-theme flag.
 * @param sender The theme button.
 * @ghidraAddress 0xebcec
 */
- (void)selectThema:(nullable id)sender;

/**
 * @brief Handle the how-to-play button: open the how-to-play sub-screen and mark it as seen.
 * @ghidraAddress 0xebdf0
 */
- (void)SelectHowToPlayButton;

/**
 * @brief Handle the information button: open the notification-page sub-screen.
 * @ghidraAddress 0xebf1c
 */
- (void)SelectInfoButton;

/**
 * @brief Handle the terms button: open the terms-of-use sub-screen.
 * @ghidraAddress 0xebf94
 */
- (void)SelectTermButton;

/**
 * @brief Handle the Applilink button: open the Applilink sub-screen and clear the unread count.
 * @ghidraAddress 0xec00c
 */
- (void)SelectApplilinkButton;

/**
 * @brief Handle the exit button: close the panel.
 * @ghidraAddress 0xec0c0
 */
- (void)SelectExitButton;

/**
 * @brief Handle the map-search button: open the map-search sub-screen.
 * @param sender The map-search button.
 * @ghidraAddress 0xec0e0
 */
- (void)selectMap:(nullable id)sender;

/**
 * @brief The music-select view that presents this overlay.
 */
@property(weak, nonatomic, nullable) RBMusicView *parentView;

/**
 * @brief The themed panel that holds the menu buttons.
 */
@property(strong, nonatomic, nullable) UIView *baseView;

/**
 * @brief The how-to-play menu button.
 */
@property(strong, nonatomic, nullable) RBSettingMenuButton *howToButton;

/**
 * @brief The customise menu button.
 */
@property(strong, nonatomic, nullable) RBSettingMenuButton *customButton;

/**
 * @brief The theme menu button.
 */
@property(strong, nonatomic, nullable) RBSettingMenuButton *themaButton;

/**
 * @brief The map-search menu button.
 */
@property(strong, nonatomic, nullable) RBSettingMenuButton *searchButton;

/**
 * @brief The information menu button.
 */
@property(strong, nonatomic, nullable) RBSettingMenuButton *infoButton;

/**
 * @brief The Applilink menu button.
 */
@property(strong, nonatomic, nullable) RBSettingMenuButton *applilinkButton;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
