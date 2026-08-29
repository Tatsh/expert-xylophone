/**
 * @file
 * @brief The one-shot "how to select a tune" hint overlay for the music-select screen.
 *
 * It is a
 * full-screen @c UIView with a black background at 0.7 alpha, carrying a close button and the
 * layered @c 11_info hint artwork, that fades itself in after a short delay and fades out and
 * removes itself when tapped.
 *
 * The two device idioms build different subviews. The pad places the close button and the
 * @c info_music artwork at fixed positions. The phone centres that artwork, adds @c info_2 as a
 * subview of the artwork itself, and adds @c info_1 as a sibling on the overlay rather than on the
 * artwork.
 *
 * Two loose ends are worth knowing about. The close button's action is @c selectExit, for which no
 * implementation was found in this class or in the runtime metadata, so the tap recogniser is what
 * actually dismisses the overlay. And no reconstructed call site constructs this view at all:
 * @c RBMusicView reads @c RBUserSettingData.musicSelectedFirstInfo as an already-seen guard and
 * draws its own inline @c 11_info/info_1 image instead of building one of these.
 */

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
- (instancetype)initWithFrame:(CGRect)frame;

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
