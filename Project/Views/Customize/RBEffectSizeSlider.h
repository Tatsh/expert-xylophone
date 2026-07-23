/** @file
 * The explosion (bounds-effect-size) slider control used on the customise screen (created by
 * @c RBCustomSelectCollectionView). It is a custom @c UISlider drawn as a track sprite (the base
 * view) with a small grip sprite, plus a row of digit-image views that render the effect-size
 * value as a fixed-point numeric readout of the form @c N.M (a whole digit, a decimal point, and a
 * fractional digit).
 *
 * The value maps to a bounds-effect size in the inclusive range @c barMin ... @c barMax (that is,
 * 0 ... 3) in half-unit steps, seeded from @c RBUserSettingData.boundsEffectSize. Dragging the
 * grip snaps the horizontal touch position to a half-unit value and updates the readout.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c RBEffectSizeSlider, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief An effect-size slider with a fixed-point numeric digit readout.
 */
@interface RBEffectSizeSlider : UISlider

/**
 * @brief Create the slider, building its track sprite, grip sprite, and digit-image readout, and
 * seed its value from the stored bounds-effect-size setting.
 * @param digit The number of whole-digit places notionally drawn in the readout (the readout
 * itself is a fixed @c N.M layout of one whole digit, a decimal point, and one fractional digit).
 * @return The initialised slider, or @c nil.
 * @ghidraAddress 0x3ac30
 */
- (nullable instancetype)initWithDigit:(int)digit;

/**
 * @brief Set the current value, clamp it to the range, reposition the grip, and refresh the digit
 * readout.
 * @param value The effect-size value; it is clamped to @c barMin ... @c barMax.
 * @ghidraAddress 0x3b96c
 */
- (void)setValue:(float)value;

/**
 * @brief Map a touch point to a half-unit value, snap it, and update the slider.
 * @param point The touch location in the slider's coordinate space.
 * @ghidraAddress 0x3bde0
 */
- (void)sliderChangeWithTouchPoint:(CGPoint)point;

/**
 * @brief The number of whole-digit places notionally drawn in the readout.
 */
@property(assign, nonatomic) int digit;

/**
 * @brief The clamped current value (a bounds-effect size in half-unit steps).
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
 * @brief The digit glyph images (@c cus_nms_0 ... @c cus_nms_9 followed by @c cus_nms_dot).
 */
@property(strong, nonatomic, nullable) NSMutableArray<UIImage *> *numImages;

/**
 * @brief The digit-place image views that make up the readout: the whole digit, the decimal point,
 * and the fractional digit.
 */
@property(strong, nonatomic, nullable) NSMutableArray<UIImageView *> *numImageViews;

/**
 * @brief The rectangle within the track along which the grip travels.
 */
@property(assign, nonatomic) CGRect barRect;

/**
 * @brief The lowest selectable value (0).
 */
@property(assign, nonatomic) int barMin;

/**
 * @brief The highest selectable value (3).
 */
@property(assign, nonatomic) int barMax;

/**
 * @brief The track pixels per half-unit value, used to convert between touch position and value.
 */
@property(assign, nonatomic) float step;

/**
 * @brief The value increment per grip step (half a unit).
 */
@property(assign, nonatomic) float stepValue;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
