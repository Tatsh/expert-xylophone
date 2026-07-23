/** @file
 * The judge-timing (delay-frame) slider control used on the customise screen (created by
 * @c RBCustomSelectCollectionView). It is a custom @c UISlider drawn as a track sprite (the base
 * view) with a small grip sprite, plus a row of digit-image views that render the signed timing
 * value as a numeric readout of a fixed digit count.
 *
 * The value maps to a whole delay-frame offset in the inclusive range @c barMin ... @c barMax
 * (that is, -10 ... 10), seeded from @c RBUserSettingData.delayFrame. Dragging the grip maps the
 * horizontal touch position to an integer value and updates the readout.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c RBTimingSlider, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A judge-timing (delay-frame) slider with a signed numeric digit readout.
 */
@interface RBTimingSlider : UISlider

/**
 * @brief Create the slider, building its track sprite, grip sprite, and digit-image readout, and
 * seed its value from the stored delay-frame setting.
 * @param digit The number of digit places to draw in the readout.
 * @return The initialised slider, or @c nil.
 * @ghidraAddress 0x17e3b0
 */
- (nullable instancetype)initWithDigit:(int)digit;

/**
 * @brief Set the current value, clamp it to the range, reposition the grip, and refresh the digit
 * readout.
 * @param value The timing value; it is clamped to @c barMin ... @c barMax.
 * @ghidraAddress 0x17efa8
 */
- (void)setValue:(float)value;

/**
 * @brief Map a touch point to a value, snap it to a whole frame, and update the slider.
 * @param point The touch location in the slider's coordinate space.
 * @ghidraAddress 0x17f4b4
 */
- (void)sliderChangeWithTouchPoint:(CGPoint)point;

/**
 * @brief The number of digit places drawn in the readout.
 */
@property(assign, nonatomic) int digit;

/**
 * @brief The clamped current value (a whole delay-frame offset).
 */
@property(assign, nonatomic) float value;

/**
 * @brief The track sprite the grip slides along.
 */
@property(strong, nonatomic, nullable) UIView *baseView;

/**
 * @brief The draggable grip sprite.
 */
@property(strong, nonatomic, nullable) UIImageView *gripView;

/**
 * @brief The digit glyph images (@c cus_nms_0 ... @c cus_nms_9 followed by @c cus_nms_minus).
 */
@property(strong, nonatomic, nullable) NSMutableArray<UIImage *> *numImages;

/**
 * @brief The digit-place image views that make up the readout, most significant first.
 */
@property(strong, nonatomic, nullable) NSMutableArray<UIImageView *> *numImageViews;

/**
 * @brief The rectangle within the track along which the grip travels.
 */
@property(assign, nonatomic) CGRect barRect;

/**
 * @brief The lowest selectable value (-10).
 */
@property(assign, nonatomic) int barMin;

/**
 * @brief The highest selectable value (10).
 */
@property(assign, nonatomic) int barMax;

/**
 * @brief The track pixels per unit value, used to convert between touch position and value.
 */
@property(assign, nonatomic) float step;

/**
 * @brief A per-step value declared alongside @c step; the binary never messages its accessors.
 */
@property(assign, nonatomic) float stepValue;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
