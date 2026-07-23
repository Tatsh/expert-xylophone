/** @file
 * A control that renders a numeric value using image-based digit glyphs from the customize screen's
 * unlock artwork. It has no text layer: @c drawRect: splits the current @c number into decimal
 * digits and draws a themed glyph image per digit, bottom-aligned and laid out right to left, with
 * the glyph set and formatting chosen by @c imageType. Setting either property redraws the control.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class RBNumberLabel, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <CoreGraphics/CoreGraphics.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The digit-glyph style RBNumberLabel draws its number with.
 */
typedef NS_ENUM(NSInteger, RBNumberLabelImageType) {
    RBNumberLabelImageTypeNormal = 0,  /*!< Whole-number glyphs (@c cus_unlock_nm_0 …
                                        *   @c cus_unlock_nm_9). */
    RBNumberLabelImageTypeDecimal = 1, /*!< One decimal place: the number is scaled by ten, the
                                        *   fractional digit is drawn with the small glyphs
                                        *   (@c cus_unlock_nms_0 …) followed by a small decimal
                                        *   point (@c cus_unlock_nms_dp), and the remaining digits
                                        *   use the big glyphs (@c cus_unlock_nmb_0 …). */
    RBNumberLabelImageTypeLime = 2,    /*!< Lime-badged glyphs (@c cus_unlock_0 … @c cus_unlock_9)
                                        *   preceded by the @c cus_unlock_lime prefix image and
                                        *   centred horizontally. */
};

/**
 * @brief A control that draws a number as a row of image-based digit glyphs.
 */
@interface RBNumberLabel : UIControl

/**
 * @brief Create the label with the given frame.
 *
 * Calls through to @c super, gives the control a clear background, and resets the number to zero.
 * @param frame The control's frame rectangle.
 * @return The initialised control, or @c nil.
 * @ghidraAddress 0x200778
 */
- (nullable instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief Draw the current number as image-based digit glyphs within @p rect.
 *
 * Calls through to @c super, then splits @c number (scaled by ten when @c imageType is
 * @c RBNumberLabelImageTypeDecimal) into its decimal digits and draws one themed glyph per digit,
 * bottom-aligned and laid out right to left, honouring the @c imageType formatting.
 * @param rect The rectangle to draw into.
 * @ghidraAddress 0x20089c
 */
- (void)drawRect:(CGRect)rect;

/**
 * @brief The value drawn by the control.
 *
 * Setting a new value redraws the control.
 */
@property(assign, nonatomic) float number;

/**
 * @brief The digit-glyph style and formatting used to draw the number.
 *
 * Setting a new style redraws the control.
 */
@property(assign, nonatomic) RBNumberLabelImageType imageType;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
