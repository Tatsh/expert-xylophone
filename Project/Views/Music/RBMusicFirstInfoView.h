#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The first-time information overlay shown over the music-select detail panel.
 *
 * A translucent, full-screen @c UIView that presents the "how to select a song" hint imagery
 * (a close button plus the layered @c info_music, @c info_2, and @c info_1 artwork) and fades
 * itself in and out. Tapping the overlay dismisses it.
 */
@interface RBMusicFirstInfoView : UIView

/**
 * @brief Creates the overlay and lays out its close button and hint imagery for the current device
 * idiom.
 * @param frame The initial frame.
 * @return The initialised overlay, or @c nil if the superclass initialiser failed.
 * @ghidraAddress 0xc9370
 */
- (nullable instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief Builds the overlay's subviews: a close button (positioned differently on iPad and iPhone),
 * the flashing done-effect image, and the layered hint imagery, plus the dismiss tap recogniser.
 * @ghidraAddress 0xc93e4
 */
- (void)SetupView;

/**
 * @brief Fades the overlay fully in, guarding against a re-entrant animation.
 * @ghidraAddress 0xc9c10
 */
- (void)showAnimation;

/**
 * @brief Fades the overlay out and removes it from its superview, guarding against a re-entrant
 * animation.
 * @ghidraAddress 0xc9d78
 */
- (void)hideAnimation;

/**
 * @brief The dismiss tap handler; hides the overlay.
 * @param tap The recognising gesture.
 * @ghidraAddress 0xc9bf4
 */
- (void)tap:(UITapGestureRecognizer *)tap;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
