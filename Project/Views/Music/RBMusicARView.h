/** @file
 * The per-difficulty achievement-rate readout hosted by @c RBMusicView on the music-select
 * screen. It renders the achievement rate as a row of image glyphs: a trailing percent sign, one
 * fractional (tenths) digit, a decimal point, and the integer digits, laid out from a fixed pool of
 * six @c UIImageView subviews.
 *
 * The glyph set and layout direction depend on the active theme
 * (@c RBUserSettingData.thema): the Colette theme (@c RBUserSettingDataThemeColette) draws the
 * @c det_ar1 / @c det_ar2 glyphs right-to-left with the integer digits in the large @c det_ar1
 * style and the fractional digit in the small @c det_ar2 style, while the other themes draw the
 * @c det_ran percent and decimal glyphs with @c det_bpm digits left-to-right.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c RBMusicARView, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base. The soft-float glyph
 * measurement, centring, and per-glyph frame positioning in @c UpdateScore: were recovered from the
 * arm64 disassembly, where the decompiler folds the floating-point register moves into
 * pseudo-variables.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief An image-glyph achievement-rate percentage display.
 */
@interface RBMusicARView : UIView

/**
 * @brief Create the readout, sizing the view, building its pool of six reusable glyph image views,
 * and blanking the display.
 * @param frame The view frame; its width and height are overridden with the fixed readout size.
 * @return The initialised view, or @c nil.
 * @ghidraAddress 0xc142c
 */
- (nullable instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief Rebuild the glyph row for the given achievement rate.
 * @param achievementRate The achievement rate; it is scaled by 1000 and split into digits, with the
 * decimal point placed after the first (tenths) digit.
 * @ghidraAddress 0xc1690
 */
- (void)UpdateScore:(float)achievementRate;

/**
 * @brief The pool of six reusable glyph image views, ordered from the least significant glyph.
 * @ghidraAddress 0xc2034 (getter)
 * @ghidraAddress 0xc2044 (setter)
 */
@property(strong, nonatomic, nullable) NSMutableArray<UIImageView *> *scoreImageArray;

/**
 * @brief The height of the large (integer-digit) glyph style, used to baseline-align the smaller
 * glyphs.
 * @ghidraAddress 0xc207c (getter)
 * @ghidraAddress 0xc208c (setter)
 */
@property(assign, nonatomic) float numHeightL;

/**
 * @brief The height of the small (fractional-digit, percent, and decimal) glyph style.
 * @ghidraAddress 0xc209c (getter)
 * @ghidraAddress 0xc20ac (setter)
 */
@property(assign, nonatomic) float numHeightS;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
