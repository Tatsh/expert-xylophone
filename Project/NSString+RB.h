/** @file
 * @c NSString convenience helpers used across the game: a URL query-component percent-encoder and a
 * family of font-based sizing and drawing helpers that re-implement the pre-iOS-7
 * @c NSString(UIStringDrawing) API on top of the modern attributed-string measurement and drawing
 * methods (@c sizeWithAttributes:, @c boundingRectWithSize:options:attributes:context:,
 * @c drawInRect:withAttributes:, and @c drawAtPoint:withAttributes:).
 *
 * Reconstructed from Ghidra project rb458, program rb458 (category @c NSString(RB), image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base. All eight instance
 * methods are recorded in the binary's category instance-method list and dispatch to an @c NSString
 * instance.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief URL and font-drawing helpers layered on @c NSString.
 */
@interface NSString (RB)

/**
 * @brief Percent-encode the receiver for use as a URL query component.
 *
 * Escapes the reserved set @c !*'();:@&=+$,/?#[] along with the percent sign itself, using UTF-8,
 * matching JavaScript's @c encodeURIComponent.
 * @return The percent-encoded string.
 * @ghidraAddress 0x1b82a4
 */
- (nullable NSString *)encodeURIComponent;

/**
 * @brief Measure the bounding size of the receiver rendered in a font.
 * @param font The font applied through @c NSFontAttributeName.
 * @return The size of the rendered text.
 * @ghidraAddress 0x1b82d0
 */
- (CGSize)sizeWithFont:(UIFont *)font;

/**
 * @brief Measure the receiver rendered in a font, wrapped to fit a bounding size.
 *
 * Forwards to @c sizeWithFont:constrainedToSize:lineBreakMode: with a line-break mode of
 * @c NSLineBreakByWordWrapping.
 * @param font The font applied through @c NSFontAttributeName.
 * @param size The size the text is constrained to fit within.
 * @return The size of the rendered text.
 * @ghidraAddress 0x1b83c4
 */
- (CGSize)sizeWithFont:(UIFont *)font constrainedToSize:(CGSize)size;

/**
 * @brief Measure the receiver rendered in a font, wrapped to fit a bounding size with a line-break
 * mode.
 *
 * Builds a left-aligned paragraph style with the given line-break mode and returns the size of the
 * rectangle reported by @c boundingRectWithSize:options:attributes:context: (using
 * @c NSStringDrawingUsesLineFragmentOrigin).
 * @param font The font applied through @c NSFontAttributeName.
 * @param size The size the text is constrained to fit within.
 * @param lineBreakMode The line-break mode applied through the paragraph style.
 * @return The size of the rendered text.
 * @ghidraAddress 0x1b83e4
 */
- (CGSize)sizeWithFont:(UIFont *)font
     constrainedToSize:(CGSize)size
         lineBreakMode:(NSLineBreakMode)lineBreakMode;

/**
 * @brief Draw the receiver inside a rectangle in a font.
 * @param rect The rectangle to draw within.
 * @param font The font applied through @c NSFontAttributeName.
 * @ghidraAddress 0x1b8578
 */
- (void)drawInRect:(CGRect)rect withFont:(UIFont *)font;

/**
 * @brief Draw the receiver inside a rectangle in a font, with a line-break mode and alignment.
 * @param rect The rectangle to draw within.
 * @param font The font applied through @c NSFontAttributeName.
 * @param lineBreakMode The line-break mode applied through the paragraph style.
 * @param alignment The text alignment applied through the paragraph style.
 * @ghidraAddress 0x1b8684
 */
- (void)drawInRect:(CGRect)rect
          withFont:(UIFont *)font
     lineBreakMode:(NSLineBreakMode)lineBreakMode
         alignment:(NSTextAlignment)alignment;

/**
 * @brief Draw the receiver at a point in a font.
 * @param point The point at which to start drawing.
 * @param font The font applied through @c NSFontAttributeName.
 * @ghidraAddress 0x1b881c
 */
- (void)drawAtPoint:(CGPoint)point withFont:(UIFont *)font;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
