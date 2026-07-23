/** @file
 * The theme-picker popup. It is an @c RBMusicMenuPopupView subclass that lets the player switch
 * the UI theme (@c RBUserSettingData.thema: Classic, Limelight, or Colette). It builds a paging
 * @c UIScrollView inside the popup's content view holding one full-page artwork per unlocked
 * theme (@c 05_theme/thema_classic, @c 05_theme/thema_limelight, and @c 05_theme/thema_colette),
 * an OK button, and — on the Colette theme — a gradation overlay. Paging the scroll view selects
 * a theme; the OK button commits it, persists the settings, and resets the game.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c RBThemaView, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

#import "RBMusicMenuPopupView.h"

@class RBSettingView;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The theme-selection popup presented over the music menu, paging one full-page artwork per
 * unlocked theme.
 */
@interface RBThemaView : RBMusicMenuPopupView <UIScrollViewDelegate>

#pragma mark Lifecycle

/**
 * @brief Create the theme popup, select the theme popup type, build its content, and mark the
 * control as exclusively touched.
 * @param frame The view's frame rectangle.
 * @return The initialised view, or @c nil.
 * @ghidraAddress 0x7104
 */
- (nullable instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief Build the theme popup content: the paging scroll view, one full-page artwork per unlocked
 * theme, the optional Colette gradation overlay, and the OK button; then scroll to the current
 * theme's page.
 * @ghidraAddress 0x7234
 */
- (void)setupView;

#pragma mark Layout

/**
 * @brief Re-run the theme selection from the scroll view's current offset after a layout pass.
 * @ghidraAddress 0x71a8
 */
- (void)layoutSubviews;

#pragma mark Actions

/**
 * @brief OK-button handler: play the decide sound, disable the button, fade the popup out, then
 * apply the selected theme, persist the settings, and reset the game.
 * @param yesButtonTouch The control that sent the action.
 * @ghidraAddress 0x8434
 */
- (void)yesButtonTouch:(nullable id)yesButtonTouch;

#pragma mark Scroll view delegate

/**
 * @brief Snap the paged offset to the nearest theme page, update the selected theme, and enable
 * the OK button only when the selection differs from the saved theme.
 * @param scrollViewDidScroll The theme scroll view.
 * @ghidraAddress 0x8740
 */
- (void)scrollViewDidScroll:(nullable UIScrollView *)scrollViewDidScroll;

#pragma mark Properties

/** @brief The paging scroll view that holds the per-theme artwork pages. */
@property(strong, nonatomic, nullable) UIScrollView *scrollView;
/** @brief The Classic theme's full-page artwork. */
@property(strong, nonatomic, nullable) UIImageView *classicView;
/** @brief The Limelight theme's full-page artwork. */
@property(strong, nonatomic, nullable) UIImageView *limelightView;
/** @brief The Colette theme's full-page artwork. */
@property(strong, nonatomic, nullable) UIImageView *coletteView;
/** @brief The OK button that commits the selected theme. */
@property(strong, nonatomic, nullable) UIButton *okButton;
/** @brief The currently selected theme (an @c RBUserSettingDataTheme value). */
@property(assign, nonatomic) int thema;
/** @brief The number of unlocked themes, driving the scroll view's content width. */
@property(assign, nonatomic) int unlockedThemaCount;
/** @brief The owning settings view, held weakly. */
@property(weak, nonatomic, nullable) RBSettingView *settingView;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C++
// kate: hl Objective-C++;
// vim: set ft=objcpp :
