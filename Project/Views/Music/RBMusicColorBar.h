/** @file
 * The rival-alpha slider bar hosted by @c RBMusicColorView on its alpha page. It draws a
 * horizontal track (the base view) with a draggable grip image, and reports the grip's position
 * along the track as a normalised value in the unit interval. A tap or pan anywhere on the track
 * moves the grip and, when the hosting colour view is attached, pushes the new value into that
 * view's rival alpha via @c setRivalAlpha:.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c RBMusicColorBar, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

@class RBMusicColorView;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The rival-alpha slider bar of the music-select colour selector.
 *
 * The binary's class_ro_t lists no adopted protocols (its @c baseProtocols pointer is null), so
 * this class adopts none.
 */
@interface RBMusicColorBar : UIView

#pragma mark Lifecycle

/**
 * @brief Create the slider bar for the given hosting colour view and build its track and grip.
 * @param frame The bar's frame rectangle.
 * @param MusicSelectedColor The hosting colour selector view, held weakly.
 * @return The initialised bar, or @c nil.
 * @ghidraAddress 0xc20d0
 */
- (nullable instancetype)initWithFrame:(CGRect)frame
                    MusicSelectedColor:(nullable RBMusicColorView *)MusicSelectedColor;

#pragma mark View construction

/**
 * @brief Build the background image, tap and pan gesture recognisers, the track base view, and the
 * grip image view.
 * @ghidraAddress 0xc21b8
 */
- (void)SetupView;

#pragma mark Slider value

/**
 * @brief Move the grip to the given normalised position, store it, and push it to the hosting
 * colour view's rival alpha.
 *
 * The value is clamped to the unit interval before it is applied.
 * @param SetBar The requested normalised position.
 * @ghidraAddress 0xc27c8
 */
- (void)SetBar:(float)SetBar;

/**
 * @brief The current slider value as a single-precision number, an alias for @c sliderValue.
 * @ghidraAddress 0xc2974
 */
@property(assign, nonatomic) float alphaValue;

#pragma mark Properties

/** @brief The track base view the grip slides along. */
@property(strong, nonatomic, nullable) UIView *baseView;
/** @brief The draggable grip image view. */
@property(strong, nonatomic, nullable) UIImageView *gripView;
/** @brief The current grip position along the track, normalised to the unit interval. */
@property(assign, nonatomic) double sliderValue;
/** @brief The hosting colour selector view, held weakly. */
@property(weak, nonatomic, nullable) RBMusicColorView *musicSelectedColor;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
