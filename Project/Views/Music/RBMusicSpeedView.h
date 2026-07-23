#import <UIKit/UIKit.h>

@class RBMusicView;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The high-SPEED (scroll-speed) setting sub-view hosted by @c RBMusicView.
 *
 * The view draws a horizontal speed bar (@c sliderView) with a draggable selected-image marker
 * (@c selectedImage) over a transparent @c barBase. A tap or the animation-driven glide maps the
 * touch position along the bar to one of eleven speed steps (0 through 10), stores it back into
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
 * @ghidraAddress 0xdf74
 */
- (nullable instancetype)initWithFrame:(CGRect)frame
                     MusicSelectedBase:(nullable RBMusicView *)MusicSelectedBase;

/**
 * @brief Builds the bar, marker, and tap recogniser. @ghidraAddress 0xe158
 */
- (void)SetupView;

/**
 * @brief Maps a tap along the speed bar to a speed step and commits it. @ghidraAddress 0xeb9c
 * @param tap The tap gesture recogniser.
 */
- (void)tap:(nullable UITapGestureRecognizer *)tap;

/**
 * @brief Clamps the given step to 0 through 10, stores it, plays the change sound effect, animates
 *        the marker, and refreshes the host's decide button. @ghidraAddress 0xeda0
 * @param SelectSpeed The candidate speed step.
 */
- (void)SelectSpeed:(int)SelectSpeed;

/**
 * @brief The selected speed step, 0 through 10.
 * @ghidraAddress 0xf0d0 (getter)
 * @ghidraAddress 0xf0e0 (setter)
 */
@property(nonatomic, assign) int speed;
/**
 * @brief The slider style flag, seeded to 0 by the initialiser.
 * @ghidraAddress 0xf1fc (getter)
 * @ghidraAddress 0xf20c (setter)
 */
@property(nonatomic, assign) int sliderType;
/**
 * @brief The draggable marker drawn over the bar at the current speed. @c strong.
 * @ghidraAddress 0xf124 (getter)
 * @ghidraAddress 0xf134 (setter)
 */
@property(strong, nonatomic, nullable) UIImageView *selectedImage;
/**
 * @brief The horizontal speed bar image. @c strong.
 * @ghidraAddress 0xf16c (getter)
 * @ghidraAddress 0xf17c (setter)
 */
@property(strong, nonatomic, nullable) UIImageView *sliderView;
/**
 * @brief The transparent container the marker is centred within. @c strong.
 * @ghidraAddress 0xf1b4 (getter)
 * @ghidraAddress 0xf1c4 (setter)
 */
@property(strong, nonatomic, nullable) UIView *barBase;
/**
 * @brief The hosting music-detail view the selection is reported back to. @c weak.
 * @ghidraAddress 0xf0f0 (getter)
 * @ghidraAddress 0xf110 (setter)
 */
@property(weak, nonatomic, nullable) RBMusicView *musicSelectedBase;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C++
// kate: hl Objective-C++;
// vim: set ft=objcpp :
