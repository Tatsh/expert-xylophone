/** @file
 * The shot-volume slider control used on the customise screen (created by
 * @c RBCustomSelectCollectionView when the customise item is the shot type). It is a custom
 * @c UISlider drawn as a track sprite (the base view) overlaid by a gauge sprite whose width
 * fills in proportion to the value.
 *
 * The value is a normalised volume in the inclusive range @c 0.0 ... @c 1.0, seeded by the caller
 * from @c RBUserSettingData.shotVolume. Dragging the gauge maps the horizontal touch position to a
 * fraction of the bar rectangle and updates the gauge fill.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c RBVolumeSlider, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A shot-volume slider with a proportional gauge fill.
 */
@interface RBVolumeSlider : UISlider

/**
 * @brief Create the slider, building its track sprite and gauge sprite, sizing the control to the
 * track's bounds, and seeding the gauge to an empty (zero) fill.
 * @return The initialised slider, or @c nil.
 * @ghidraAddress 0x16eb90
 */
- (nullable instancetype)init;

/**
 * @brief Set the current value, clamp it to @c 0.0 ... @c 1.0, and resize the gauge fill to that
 * fraction of the bar width.
 * @param value The volume; it is clamped to @c 0.0 ... @c 1.0.
 * @ghidraAddress 0x16eef4
 */
- (void)setValue:(float)value;

/**
 * @brief Map a touch point to a value as its fraction of the bar rectangle, clamp it to
 * @c 0.0 ... @c 1.0, and update the slider.
 * @param point The touch location in the slider's coordinate space.
 * @ghidraAddress 0x16eff0
 */
- (void)sliderChangeWithTouchPoint:(CGPoint)point;

/**
 * @brief The normalised current volume (@c 0.0 ... @c 1.0).
 */
@property(assign, nonatomic) float value;

/**
 * @brief The track sprite the gauge fills over.
 */
@property(strong, nonatomic, nullable) UIView *baseView;

/**
 * @brief The gauge sprite whose width is the value's fraction of the bar rectangle.
 */
@property(strong, nonatomic, nullable) UIImageView *gaugeView;

/**
 * @brief The rectangle within the track over which the gauge fills; its width is the full-value
 * gauge width.
 */
@property(assign, nonatomic) CGRect barRect;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
