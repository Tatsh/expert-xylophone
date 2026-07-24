/** @file
 * The background-music manager singleton. It is a thin façade over @c AudioManager that owns the
 * game's non-tune background music: the shared loop played behind the menus, and the dedicated
 * title-screen and result-screen loops. It loads a track's bundled @c .m4a asset into the audio
 * manager, plays, pauses, and stops it with a fade duration, and keeps two flags that track
 * whether a track is currently loaded and whether one has been pushed aside by a temporary
 * overlay.
 *
 * The track a plain @c -LoadMusicSelect request loads is chosen from the user's stored background
 * music preference (@c -[RBUserSettingData bgmType]); the title and result loops instead embed
 * the user's current theme name (@c -[RBUserSettingData themaName]) in their asset path. Every
 * playback request is forwarded to the shared @c AudioManager, so the manager holds no audio
 * player of its own.
 *
 * The push and pop pair overlays one background track on top of another: pushing suspends the
 * current track through the audio manager's own background-music stack, and popping restores it.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class RBBGMManager, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The background-music manager singleton.
 */
@interface RBBGMManager : NSObject

#pragma mark Singleton

/**
 * @brief The shared background-music manager, created on first use.
 * @ghidraAddress 0x69e50
 * @return The shared @c RBBGMManager.
 */
+ (instancetype)getInstance;

#pragma mark Track loading

/**
 * @brief Load the menu background track chosen by the user's stored preference, looping, replacing
 *        any current track.
 * @ghidraAddress 0x6a324
 */
- (void)LoadMusicSelect;
/**
 * @brief Load a menu background track selected by its preference index, looping, replacing any
 *        current track.
 * @ghidraAddress 0x6a1cc
 * @param type The background-music preference index, used to pick the asset's name suffix.
 * @param loop Whether the track should loop indefinitely.
 */
- (void)LoadMusicType:(int)type Loop:(BOOL)loop;
/**
 * @brief Load the title-screen background track for the user's current theme.
 * @ghidraAddress 0x6a3b4
 * @param loop Whether the track should loop indefinitely.
 */
- (void)LoadMusicTitleWithLoop:(BOOL)loop;
/**
 * @brief Load the result-screen background track for the user's current theme.
 * @ghidraAddress 0x6a560
 * @param loop Whether the track should loop indefinitely.
 */
- (void)LoadMusicResultWithLoop:(BOOL)loop;
/**
 * @brief Load a background track from an in-memory audio data object, marking a track as loaded
 *        and handing the data to the audio manager.
 * @ghidraAddress 0x6a70c
 * @param data The encoded audio data, or @c nil to load nothing.
 * @param loop Whether the track should loop indefinitely.
 */
- (void)LoadMusic:(nullable NSData *)data Loop:(BOOL)loop;
/**
 * @brief Push any current track aside, then load a new background track from an in-memory audio
 *        data object, so the new track can later be popped to restore the previous one.
 * @ghidraAddress 0x6a7b4
 * @param data The encoded audio data, or @c nil to load nothing.
 * @param loop Whether the track should loop indefinitely.
 * @return @c YES when a track was pushed aside.
 */
- (BOOL)LoadMusicWithPush:(nullable NSData *)data Loop:(BOOL)loop;
/**
 * @brief Release the current track, popping and releasing a pushed-aside track as well, and clear
 *        both track flags.
 * @ghidraAddress 0x69ef8
 */
- (void)RelaseMusic;

#pragma mark Playback

/**
 * @brief Play the loaded background track, fading in over @p time seconds.
 * @ghidraAddress 0x69fac
 * @param time The fade-in duration in seconds.
 * @return @c YES when a track was loaded and playback started.
 */
- (BOOL)PlayMusic:(float)time;
/**
 * @brief Pause the loaded background track, fading out over @p time seconds.
 * @ghidraAddress 0x6a03c
 * @param time The fade-out duration in seconds.
 */
- (void)PauseMusic:(float)time;
/**
 * @brief Stop the loaded background track, fading out over @p time seconds.
 * @ghidraAddress 0x6a0c8
 * @param time The fade-out duration in seconds.
 */
- (void)StopMusic:(float)time;
/**
 * @brief Seek the loaded background track back to its start, when a track is loaded.
 * @ghidraAddress 0x6a154
 */
- (void)SeekToTop;

#pragma mark Overlay stack

/**
 * @brief Push the current track onto the audio manager's background-music stack, marking it pushed
 *        aside and no longer the active track.
 * @ghidraAddress 0x6a854
 * @return @c YES when there was a loaded track to push.
 */
- (BOOL)pushMusic;
/**
 * @brief Restore the track previously pushed aside by @c -pushMusic, marking it the active track
 *        again.
 * @ghidraAddress 0x6a8f0
 * @return @c YES when there was a pushed-aside track to restore.
 */
- (BOOL)popMusic;
/**
 * @brief Whether a track has been pushed aside and not yet restored.
 * @ghidraAddress 0x6a980
 * @return @c YES when a pushed-aside track is waiting.
 */
- (BOOL)isPushMusic;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
