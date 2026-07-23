/** @file
 * The per-difficulty numeric score readout hosted by @c RBMusicView. It renders a fixed four-digit
 * score as a row of image glyphs: one @c UIImageView per digit, laid out left to right, with the
 * leading (insignificant) zeros drawn at half opacity. The glyph set is chosen from the user's
 * theme and, on the themed layouts, from the selected difficulty grade.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c RBMusicScoreView, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The image-glyph numeric score readout for a single difficulty.
 *
 * The class has no adopted protocols: its class_ro_t baseProtocols list is null.
 */
@interface RBMusicScoreView : UIView

/**
 * @brief Create the readout and its four digit image views.
 *
 * Calls through to @c super, clears the background, allocates the four backing @c UIImageView
 * glyphs into @c scoreImageViews, adds each as a subview, and draws an initial score of zero.
 *
 * @param frame The view frame.
 * @return The initialised readout.
 * @ghidraAddress 0xc9ee8
 */
- (instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief Redraw the four digit glyphs for the given score.
 *
 * Splits @p UpdateScore into its four decimal digits, selects the themed (and, on the black and
 * brown themes, grade-specific) glyph image for each, positions them left to right, and dims the
 * leading insignificant zeros to half opacity.
 *
 * @param UpdateScore The score to display.
 * @ghidraAddress 0xca138
 */
- (void)UpdateScore:(int)UpdateScore;

/** @brief The difficulty grade selecting the themed glyph set. @ghidraAddress 0xca79c, 0xca7ac */
@property(assign) int grade;

/**
 * @brief The four backing digit image views, ordered from the most significant digit to the least.
 * @ghidraAddress 0xca7bc, 0xca7cc
 */
@property(strong, nonatomic, nullable) NSMutableArray<UIImageView *> *scoreImageViews;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
