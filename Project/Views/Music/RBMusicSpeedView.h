/**
 * @file
 * @brief The high-SPEED (scroll-speed) setting sub-view of the music-detail setting scroll hosted
 * by @c RBMusicView.
 *
 * It draws a horizontal bar image (@c sliderView) and layers a transparent
 * @c barBase container over it carrying the selected-step marker (@c selectedImage). A tap on the
 * bar - the only gesture the view installs - maps to one of eleven SPEED steps, writes the result
 * back into the shared @c RBUserSettingData.speedType, plays the themed change sound effect, and
 * asks the host to refresh its decide button.
 *
 * The layout is split by theme and by device idiom, and the geometry constants therefore come in
 * matched sets: @c -SetupView picks the bar and container frames from a Colette arm and a default
 * arm, each with its own pad and phone geometry, while @c -tap: picks the end-of-bar tap dead zone
 * from three arms (Limelight, Colette, and the default), again per idiom. A constant taken from
 * the wrong arm is right for one theme or one device only. One behaviour is surprising but
 * faithful: @c -SelectSpeed: clamps a step above ten to eleven rather than to ten.
 *
 * The implementation is Objective-C++ because @c -SelectSpeed: reaches the C++
 * @c SoundEffectManager engine singleton.
 */

#import <UIKit/UIKit.h>

@class RBMusicView;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The high-SPEED (scroll-speed) setting sub-view hosted by @c RBMusicView.
 *
 * The view draws a horizontal speed bar (@c sliderView) and layers a transparent @c barBase over
 * it, carrying the selected-image marker (@c selectedImage). A tap or the animation-driven glide
 * maps the touch position along the bar to one of eleven speed steps (0 through 10), stores it into
 * @c RBUserSettingData.speedType, plays the change sound effect, and asks the host to refresh its
 * decide button.
 *
 * The binary's @c class_ro_t carries no @c baseProtocols list, so the class adopts no protocols.
 */
@interface RBMusicSpeedView : UIView

/**
 * @brief Creates the speed sub-view for a page of the host's setting scroll.
 * @param frame The page frame inside the host's setting scroll view.
 * @param MusicSelectedBase The hosting music-detail view the selection is reported back to.
 * @return The initialised speed sub-view.
 * @ghidraAddress 0x10df74
 */
- (nullable instancetype)initWithFrame:(CGRect)frame
                     MusicSelectedBase:(nullable RBMusicView *)MusicSelectedBase;

/**
 * @brief Builds the bar, marker, and tap recogniser. @ghidraAddress 0xe158
 */
- (void)SetupView;

/**
 * @brief Maps a tap along the speed bar to a speed step and commits it. @ghidraAddress 0x10eb9c
 * @param tap The tap gesture recogniser.
 */
- (void)tap:(nullable UITapGestureRecognizer *)tap;

/**
 * @brief Clamps the given step to 0 through 10, stores it, plays the change sound effect, animates
 *        the marker, and refreshes the host's decide button. @ghidraAddress 0x10eda0
 * @param SelectSpeed The candidate speed step.
 */
- (void)SelectSpeed:(int)SelectSpeed;

/**
 * @brief The selected speed step, 0 through 10.
 * @ghidraAddress 0x10f0d0 (getter)
 * @ghidraAddress 0x10f0e0 (setter)
 */
@property(nonatomic, assign) int speed;
/**
 * @brief The slider style flag, seeded to 0 by the initialiser.
 * @ghidraAddress 0x10f1fc (getter)
 * @ghidraAddress 0x10f20c (setter)
 */
@property(nonatomic, assign) int sliderType;
/**
 * @brief The marker drawn over the bar at the current speed. @c strong.
 * @ghidraAddress 0x10f124 (getter)
 * @ghidraAddress 0x10f134 (setter)
 */
@property(strong, nonatomic, nullable) UIImageView *selectedImage;
/**
 * @brief The horizontal speed bar image. @c strong.
 * @ghidraAddress 0x10f16c (getter)
 * @ghidraAddress 0x10f17c (setter)
 */
@property(strong, nonatomic, nullable) UIImageView *sliderView;
/**
 * @brief The transparent container the marker is centred within. @c strong.
 * @ghidraAddress 0x10f1b4 (getter)
 * @ghidraAddress 0x10f1c4 (setter)
 */
@property(strong, nonatomic, nullable) UIView *barBase;
/**
 * @brief The hosting music-detail view the selection is reported back to. @c weak.
 * @ghidraAddress 0x10f0f0 (getter)
 * @ghidraAddress 0x10f110 (setter)
 */
@property(weak, nonatomic, nullable) RBMusicView *musicSelectedBase;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C++
// kate: hl Objective-C++;
// vim: set ft=objcpp :
