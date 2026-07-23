/** @file
 * The "other" (miscellaneous) options sub-view of the music-select detail panel. It is the last
 * page of @c RBMusicView's paged setting scroll and presents up to four mutually-related play-mode
 * toggles: pastel-versus, ghost style, full-just-reflec, and full-combo. Each toggle is a container
 * @c UIView holding a labelled base image, a movable highlight image, and a slider bar image, and a
 * tap gesture recogniser flips the corresponding @c RBUserSettingData flag, animates the highlight,
 * plays the toggle sound effect, and refreshes the host's decide button. The pastel toggle is only
 * built on the non-white themes; on the white theme only the three remaining toggles are shown.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c RBMusicOtherView, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

@class RBMusicView;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The play-mode toggle identifier passed to @c -updateSwitchWithType:.
 *
 * The raw values are the order the highlight-refresh switch uses, which is the reverse of the
 * on-screen column order on the non-white themes.
 */
typedef NS_ENUM(NSInteger, RBMusicOtherSwitchType) {
    RBMusicOtherSwitchTypePastel = 0,     /*!< The pastel-versus toggle. */
    RBMusicOtherSwitchTypeGhost = 1,      /*!< The ghost-style toggle. */
    RBMusicOtherSwitchTypeJustReflec = 2, /*!< The full-just-reflec toggle. */
    RBMusicOtherSwitchTypeFullCombo = 3,  /*!< The full-combo toggle. */
};

/**
 * @brief The miscellaneous play-mode toggle sub-view hosted by @c RBMusicView.
 */
@interface RBMusicOtherView : UIView

#pragma mark Lifecycle

/**
 * @brief Create the toggle sub-view for the given host detail view and build its toggles.
 *
 * Calls through to @c super, stores the host, seeds the full-combo and full-just-reflec toggle
 * state from @c RBUserSettingData, clears the pastel flag on the white theme, and builds the
 * toggles.
 * @param frame The view's frame rectangle.
 * @param MusicSelectedBase The hosting music-select detail view.
 * @return The initialised view, or @c nil.
 * @ghidraAddress 0x1a477c
 */
- (nullable instancetype)initWithFrame:(CGRect)frame
                     MusicSelectedBase:(nullable RBMusicView *)MusicSelectedBase;

#pragma mark View construction

/**
 * @brief Build every toggle row: its container, base image, highlight image, bar image, and tap
 * gesture recogniser, and set its initial highlight position.
 *
 * Four toggles are built on the non-white themes (pastel, ghost, full-just-reflec, and full-combo,
 * laid out in quarter-width columns); on the white theme the pastel toggle is dropped and the other
 * three are laid out in third-width columns.
 * @ghidraAddress 0x1a4a38
 */
- (void)SetupView;

/**
 * @brief Animate the highlight image of the given toggle to its on or off position.
 *
 * Reads the toggle's current @c RBUserSettingData flag and slides the highlight to the right end of
 * the bar when the flag is on, or to the left end when it is off.
 * @param updateSwitchWithType The toggle to refresh.
 * @ghidraAddress 0x1a6d00
 */
- (void)updateSwitchWithType:(RBMusicOtherSwitchType)updateSwitchWithType;

#pragma mark Toggle handlers

/**
 * @brief Toggle full-combo mode, refresh its highlight, clear the conflicting modes, play the
 * toggle sound, and refresh the host's decide button.
 * @param tapFc The tap gesture recogniser.
 * @ghidraAddress 0x1a62c0
 */
- (void)tapFc:(nullable UITapGestureRecognizer *)tapFc;

/**
 * @brief Toggle full-just-reflec mode, refresh its highlight, clear the conflicting modes, play the
 * toggle sound, and refresh the host's decide button.
 * @param tapJr The tap gesture recogniser.
 * @ghidraAddress 0x1a652c
 */
- (void)tapJr:(nullable UITapGestureRecognizer *)tapJr;

/**
 * @brief Cycle ghost style, refresh its highlight, clear the conflicting modes when it turns on,
 * play the toggle sound, and refresh the host's decide button.
 * @param tapGhost The tap gesture recogniser.
 * @ghidraAddress 0x1a6758
 */
- (void)tapGhost:(nullable UITapGestureRecognizer *)tapGhost;

/**
 * @brief Toggle pastel-versus mode, refresh its highlight, clear the conflicting modes when it
 * turns on, play the toggle sound, and refresh the host's decide button.
 * @param tapPastel The tap gesture recogniser.
 * @ghidraAddress 0x1a6a5c
 */
- (void)tapPastel:(nullable UITapGestureRecognizer *)tapPastel;

#pragma mark Properties

/** @brief Whether full-combo mode is on, mirrored from @c RBUserSettingData. */
@property(nonatomic, assign) BOOL isFcMode;
/** @brief The full-combo toggle's container view. */
@property(nonatomic, assign, nullable) UIView *fcView;
/** @brief The rest position rectangle of the full-combo highlight along its bar. */
@property(nonatomic, assign) CGRect fcBarRect;
/** @brief The movable full-combo highlight image. */
@property(nonatomic, assign, nullable) UIImageView *fcSelectedImage;

/** @brief Whether full-just-reflec mode is on, mirrored from @c RBUserSettingData. */
@property(nonatomic, assign) BOOL isJrMode;
/** @brief The full-just-reflec toggle's container view. */
@property(nonatomic, assign, nullable) UIView *jrView;
/** @brief The rest position rectangle of the full-just-reflec highlight along its bar. */
@property(nonatomic, assign) CGRect jrBarRect;
/** @brief The movable full-just-reflec highlight image. */
@property(nonatomic, assign, nullable) UIImageView *jrSelectedImage;

/** @brief Whether ghost mode is on, mirrored from @c RBUserSettingData. */
@property(nonatomic, assign) BOOL isGhostMode;
/** @brief The ghost toggle's container view. */
@property(nonatomic, assign, nullable) UIView *ghostView;
/** @brief The rest position rectangle of the ghost highlight along its bar. */
@property(nonatomic, assign) CGRect ghostBarRect;
/** @brief The movable ghost highlight image. */
@property(nonatomic, assign, nullable) UIImageView *ghostSelectedImage;

/** @brief Whether pastel mode is on, mirrored from @c RBUserSettingData. */
@property(nonatomic, assign) BOOL isPastelMode;
/** @brief The pastel toggle's container view. */
@property(nonatomic, assign, nullable) UIView *pastelView;
/** @brief The rest position rectangle of the pastel highlight along its bar. */
@property(nonatomic, assign) CGRect pastelBarRect;
/** @brief The movable pastel highlight image. */
@property(nonatomic, assign, nullable) UIImageView *pastelSelectedImage;

/** @brief The hosting music-select detail view. */
@property(nonatomic, weak, nullable) RBMusicView *musicSelectedBase;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
