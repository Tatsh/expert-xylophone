/** @file
 * A rounded store action button with a configurable gradient fill and a distinct disabled colour.
 *
 * Shared across the store user interface (the campaign detail and extend-note detail pages hold
 * @c downloadBtn and @c linkBtn instances of it). Reconstructed from Ghidra project rb458, program
 * rb458 (class @c StoreButtonView, image base 0x100000000).
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A rounded @c UIButton subclass that paints its own gradient fill, disabled fill, and a
 *        grey inner-shadow border.
 *
 * The control redraws itself whenever its fill colour, disabled colour, corner radius, highlighted
 * state, or selected state changes.
 */
@interface StoreButtonView : UIButton

/**
 * @brief The enabled fill colour, used as the basis for the drawn gradient.
 *
 * Lazily defaults to @c +[UIColor blueColor] when it has never been set.
 */
@property(nonatomic, strong, null_resettable) UIColor *buttonColor;
/**
 * @brief The fill colour used while the control is disabled.
 *
 * Lazily defaults to @c +[UIColor grayColor] when it has never been set.
 */
@property(nonatomic, strong, null_resettable) UIColor *disabledColor;
/**
 * @brief The corner radius of the rounded fill, in points.
 */
@property(nonatomic) CGFloat cornerRadius;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
