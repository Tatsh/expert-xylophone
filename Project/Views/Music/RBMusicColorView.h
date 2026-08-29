/**
 * @file
 * The play-colour and rival-alpha selector sub-view hosted by the music-select detail
 * panel.
 *
 * It is
 * the setting page that lets the player pick the play colour (colour @c 0, colour @c 1, or the
 * "both" random slot) and, on the alpha page, the rival ghost's opacity. It builds three colour
 * buttons, each stacking a base, selected-state, name, "you", and rival image, plus a pair of
 * alpha-change overlays; below them sit the alpha and colour toggle buttons and the
 * @c RBMusicColorBar slider. Tapping a colour button records the choice into @c color and
 * refreshes the readout; the alpha slider feeds @c rivalAlpha, which the hosting @c RBMusicView
 * copies
 * into @c RBUserSettingData.rivalAlpha when it starts a game.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c RBMusicColorView, image base
 * 0x100000000). Ghidra addresses are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

@class RBMusicColorBar;
@class RBMusicView;

NS_ASSUME_NONNULL_BEGIN

/**
 * The play-colour and rival-alpha selector sub-view of the music-select detail panel.
 *
 * The binary's class_ro_t lists no adopted protocols (its @c baseProtocols pointer is null), so
 * this class adopts none.
 */
@interface RBMusicColorView : UIView

#pragma mark Lifecycle

/**
 * Create the colour selector for the given hosting detail view and build its controls.
 *
 * Seeds @c color from @c RBUserSettingData.playerColor and @c rivalAlpha from
 * @c RBUserSettingData.rivalAlpha, seeds @c layoutOffset from the theme and iPad idiom, then
 * builds the buttons and shows the current selection.
 * @param frame The view's frame rectangle.
 * @param MusicSelectedBase The hosting music-select detail view, held weakly.
 * @return The initialised view, or @c nil.
 * @ghidraAddress 0xc2cc8
 */
- (nullable instancetype)initWithFrame:(CGRect)frame
                     MusicSelectedBase:(nullable RBMusicView *)MusicSelectedBase;

#pragma mark View construction

/**
 * Build the three colour buttons and their stacked image layers, then the alpha and colour
 * toggle buttons and the colour-bar slider.
 * @ghidraAddress 0xc2efc
 */
- (void)SetupView;

#pragma mark Selection

/**
 * Refresh every image layer so the currently selected colour is highlighted, the unselected
 * colours are dimmed, and the colour bar shows the current rival alpha.
 * @ghidraAddress 0xc41e4
 */
- (void)ShowSelect;

/**
 * Colour-button tap action: record the tapped button's colour, refresh the readout, and
 * play the themed selection voice.
 * @param SelectButton The tapped colour button.
 * @ghidraAddress 0xc62c8
 */
- (void)SelectButton:(nullable UIButton *)SelectButton;

/**
 * Switch to the alpha page: hide the first-info hint, show the colour toggle, dim the
 * colour buttons, apply the current rival alpha to the alpha-change overlays, and lock the setting
 * scroll.
 * @param selectAlphaButton The tapped alpha toggle button.
 * @ghidraAddress 0xc5230
 */
- (void)selectAlphaButton:(nullable UIButton *)selectAlphaButton;

/**
 * Switch back to the colour page: show the alpha toggle, restore the colour buttons, hide
 * the alpha-change overlays and colour bar, unlock the setting scroll, and refresh the readout.
 * @param selectColorButton The tapped colour toggle button.
 * @ghidraAddress 0xc5c5c
 */
- (void)selectColorButton:(nullable UIButton *)selectColorButton;

#pragma mark Properties

/** The selected play colour (@c 0, @c 1, or the "both" random slot). */
@property(assign, nonatomic) int color;
/**
 * The rival ghost opacity, clamped to the unit interval. Setting it re-applies the opacity
 * to the button and alpha-change overlays.
 */
@property(assign, nonatomic) float rivalAlpha;
/** The horizontal layout offset applied to the controls on the iPad idiom layout. */
@property(assign, nonatomic) float layoutOffset;
/** The hosting music-select detail view, held weakly. */
@property(weak, nonatomic, nullable) RBMusicView *musicSelectedBase;
/** The colour buttons, indexed by colour slot. */
@property(strong, nonatomic, nullable) NSMutableArray *buttons;
/** The per-button colour-name image views. */
@property(strong, nonatomic, nullable) NSMutableArray *buttonImages;
/** The per-button base image views. */
@property(strong, nonatomic, nullable) NSMutableArray *buttonImageBases;
/** The per-button selected-state image views. */
@property(strong, nonatomic, nullable) NSMutableArray *selectedImages;
/** The per-button "you" indicator image views. */
@property(strong, nonatomic, nullable) NSMutableArray *youImages;
/** The per-button rival indicator image views. */
@property(strong, nonatomic, nullable) NSMutableArray *rivalImages;
/** The per-colour alpha-change name image views shown on the alpha page. */
@property(strong, nonatomic, nullable) NSMutableArray *alphaChangeImages;
/** The per-colour alpha-change base image views shown on the alpha page. */
@property(strong, nonatomic, nullable) NSMutableArray *alphaChangeImageBases;
/** The rival-alpha slider. */
@property(strong, nonatomic, nullable) RBMusicColorBar *colorBar;
/** The toggle button that switches to the alpha page. */
@property(strong, nonatomic, nullable) UIButton *toAlphaButton;
/** The toggle button that switches back to the colour page. */
@property(strong, nonatomic, nullable) UIButton *toColorButton;
/** The first-time-info hint overlay on the alpha toggle, present until it is dismissed. */
@property(strong, nonatomic, nullable) UIImageView *firstInfo;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C++
// kate: hl Objective-C++;
// vim: set ft=objcpp :
