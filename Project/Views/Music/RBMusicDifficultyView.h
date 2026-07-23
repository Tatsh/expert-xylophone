/** @file
 * The difficulty-selector sub-view hosted by the music-select detail panel. It is the setting page
 * that holds the per-difficulty buttons (basic, medium, hard, and, when the song has an extended
 * chart, the extended button). Each button carries a difficulty icon, a selected-state flash
 * overlay, and a difficulty-level number image. Tapping a button plays the themed voice, records
 * the selection into this view's @c difficulty, and refreshes both this view and the hosting
 * @c RBMusicView.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c RBMusicDifficultyView, image
 * base 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

@class RBMusicView;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The difficulty-selector sub-view of the music-select detail panel.
 *
 * The binary's class_ro_t lists no adopted protocols (its @c baseProtocols pointer is null), so
 * this class adopts none.
 */
@interface RBMusicDifficultyView : UIView

#pragma mark Lifecycle

/**
 * @brief Create the difficulty selector for the given hosting detail view and build its buttons.
 *
 * Seeds @c difficulty from the shared @c RBUserSettingData, seeds @c layoutOffset from the theme
 * and font variant, then builds the buttons and shows the current selection.
 * @param frame The view's frame rectangle.
 * @param MusicSelectedBase The hosting music-select detail view, held weakly.
 * @return The initialised view, or @c nil.
 * @ghidraAddress 0xc7a64
 */
- (nullable instancetype)initWithFrame:(CGRect)frame
                     MusicSelectedBase:(nullable RBMusicView *)MusicSelectedBase;

#pragma mark View construction

/**
 * @brief Build every difficulty button from the hosting view's music data, creating the extended
 * button only when the song has an extended chart.
 * @ghidraAddress 0xc7c68
 */
- (void)SetupView;

/**
 * @brief Build one difficulty button: its difficulty icon, selected-state flash overlay, and
 * difficulty-level number image, then register it and wire its tap action.
 * @param CreateButton The button (difficulty slot) index.
 * @param Position The button centre.
 * @param Number The difficulty level shown by the number image.
 * @ghidraAddress 0xc8240
 */
- (void)CreateButton:(int)CreateButton Position:(CGPoint)Position Number:(int)Number;

#pragma mark Selection

/**
 * @brief Refresh every button so the selected difficulty is opaque and shown and the rest are
 * translucent and hidden.
 * @ghidraAddress 0xc8b7c
 */
- (void)ShowSelectDifficulty;

/**
 * @brief Button tap action: play the themed selection voice, record the new difficulty, and
 * refresh this view and the hosting detail view.
 * @param SelectDifficultyButton The tapped button.
 * @ghidraAddress 0xc8e90
 */
- (void)SelectDifficultyButton:(nullable UIButton *)SelectDifficultyButton;

/**
 * @brief Enable or disable every difficulty button.
 * @param enableButton Whether the buttons are enabled.
 * @ghidraAddress 0xc9000
 */
- (void)setEnableButton:(BOOL)enableButton;

/**
 * @brief The difficulty button at the given index.
 * @param getDifficultyButton The button (difficulty slot) index.
 * @return The difficulty button.
 * @ghidraAddress 0xc911c
 */
- (nullable UIButton *)getDifficultyButton:(int)getDifficultyButton;

/**
 * @brief Empty in this build; retained to match the binary's method table.
 * @param SetFlashEffectDuration The flash duration.
 * @param Start The flash start value.
 * @param End The flash end value.
 * @ghidraAddress 0xc8e8c
 */
- (void)SetFlashEffectDuration:(float)SetFlashEffectDuration Start:(float)Start End:(float)End;

#pragma mark Properties

/** @brief The selected difficulty slot. */
@property(assign, nonatomic) int difficulty;
/** @brief The horizontal layout offset applied to the buttons on the font-variant Colette. */
@property(assign, nonatomic) float layoutOffset;
/** @brief The hosting music-select detail view, held weakly. */
@property(weak, nonatomic, nullable) RBMusicView *musicSelectedBase;
/** @brief The per-button selected-state flash overlay image views. */
@property(strong, nonatomic, nullable) NSMutableArray *difficultySelectedImages;
/** @brief The per-button difficulty-level number image views. */
@property(strong, nonatomic, nullable) NSMutableArray *difficultyNumberImages;
/** @brief The difficulty buttons, indexed by difficulty slot. */
@property(strong, nonatomic, nullable) NSMutableArray *difficultyButtons;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C++
// kate: hl Objective-C++;
// vim: set ft=objcpp :
