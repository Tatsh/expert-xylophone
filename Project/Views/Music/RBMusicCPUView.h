/** @file
 * The CPU-rival LEVEL setting sub-view. It is the third page of the music-detail setting scroll
 * hosted by @c RBMusicView: a horizontal slider bar over which a draggable marker selects the CPU
 * rival's LEVEL (zero through nine). A tap or the marker's animated glide seeds the shared
 * @c RBUserSettingData.cpuLevel through the hosting @c RBMusicView.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c RBMusicCPUView, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

@class RBMusicView;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The CPU-rival LEVEL setting sub-view presented on the music-detail setting scroll.
 *
 * The binary's @c class_ro_t carries no @c baseProtocols list, so the class adopts no protocols.
 */
@interface RBMusicCPUView : UIView

#pragma mark Lifecycle

/**
 * @brief Create the CPU-level sub-view, seed its level from the shared user settings, and build it.
 *
 * Calls through to @c super, stores the hosting detail view, seeds @c level from
 * @c RBUserSettingData.cpuLevel, resets the previous-sound handle, selects the slider-type variant
 * for the current theme and iPad idiom, and builds the slider.
 * @param frame The view's frame rectangle.
 * @param MusicSelectedBase The hosting music-detail view.
 * @return The initialised view, or @c nil.
 * @ghidraAddress 0xc6864
 */
- (nullable instancetype)initWithFrame:(CGRect)frame
                     MusicSelectedBase:(nullable RBMusicView *)MusicSelectedBase;

#pragma mark View construction

/**
 * @brief Build the slider bar, its container, and the level marker, and wire the tap gesture.
 * @ghidraAddress 0xc6a84
 */
- (void)SetupView;

#pragma mark Interaction

/**
 * @brief Tap handler: map the tap's location along the bar to a LEVEL (zero through nine) and select
 * it.
 * @param tap The tap gesture recogniser.
 * @ghidraAddress 0xc7410
 */
- (void)tap:(nullable UITapGestureRecognizer *)tap;

/**
 * @brief Select the given LEVEL: clamp it to the range zero through nine, store it, glide the marker
 * to its slot, and play the level-change sound effect (unless it is already playing).
 * @param SelectLevel The requested LEVEL.
 * @ghidraAddress 0xc7604
 */
- (void)SelectLevel:(int)SelectLevel;

#pragma mark Properties

/** @brief The selected CPU rival LEVEL, zero through nine. */
@property(nonatomic, assign) int level;
/** @brief The draggable LEVEL marker image. */
@property(strong, nonatomic, nullable) UIImageView *selectedImage;
/** @brief The slider bar background image. */
@property(strong, nonatomic, nullable) UIImageView *sliderView;
/** @brief The container that hosts the slider bar and marker. */
@property(strong, nonatomic, nullable) UIView *barBase;
/** @brief The slider layout variant selected for the current theme and iPad idiom. */
@property(nonatomic, assign) int sliderType;
/** @brief The hosting music-detail view, held weakly. */
@property(weak, nonatomic, nullable) RBMusicView *musicSelectedBase;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C++
// kate: hl Objective-C++;
// vim: set ft=objcpp :
