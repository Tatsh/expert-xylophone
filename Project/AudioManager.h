/** @file
 * The game's central audio manager singleton. It owns two engine-side sound subsystems reached
 * through the C++ audio bridge: a @c caPlayerMgr voice player (the @c sePlayer subsystem, which
 * plays cached one-shot sound effects and short voices) and an @c AudioSourceSlot bus manager (the
 * @c seAVPlayer subsystem, which streams grouped sources through mixer buses). On top of those it
 * layers ObjC @c AVAudioPlayer instances for the looping background music and the currently playing
 * voice line, together with fade-in and fade-out timing, an interruption and suspend or resume state
 * machine, and a background-music stack used to overlay one tune on top of another.
 *
 * Sound effects are addressed by an opaque handle whose top nibble tags which subsystem owns it and
 * whether it was registered by index or by call name; the low 28 bits are the raw engine index. The
 * manager keeps parallel look-up tables (@c seNameList, @c seRidList, and the @c seType dictionary)
 * so a caller may release or re-address a source by either its call name or its resource identifier.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class AudioManager, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The central audio manager singleton, also the delegate of its background-music and voice
 * @c AVAudioPlayer instances.
 */
@interface AudioManager : NSObject <AVAudioPlayerDelegate>

#pragma mark Singleton

/**
 * @brief The shared audio manager, created on first use.
 * @ghidraAddress 0x3d0c4
 * @return The shared @c AudioManager.
 */
+ (instancetype)sharedManager;

#pragma mark System lifecycle

/**
 * @brief Schedule the deferred engine start on the current run loop and mark the manager started.
 * @ghidraAddress 0x3d3ec
 */
- (void)systemStart;
/**
 * @brief Tear down the engine audio context and release the background-music and voice players.
 * @ghidraAddress 0x3d4c4
 */
- (void)systemTerminate;
/**
 * @brief Stop the engine audio graph, pause every bus, and suspend both the music and voice players.
 * @ghidraAddress 0x40d6c
 */
- (void)systemSuspend;
/**
 * @brief Restart the engine audio graph, resume every bus, and resume both the music and voice
 *        players.
 * @ghidraAddress 0x40e00
 */
- (void)systemResume;
/**
 * @brief Whether the deferred engine start has run.
 * @ghidraAddress 0x4101c
 * @return @c YES once @c -systemStart has taken effect.
 */
- (BOOL)isStart;

#pragma mark Background music

/**
 * @brief Load background music from an in-memory data object, replacing any current music.
 * @ghidraAddress 0x3d638
 * @param data The encoded audio data, or @c nil to load nothing.
 * @param loop Whether the music should loop indefinitely.
 * @return @c YES when the player was created successfully.
 */
- (BOOL)loadBgmData:(nullable NSData *)data isLoop:(BOOL)loop;
/**
 * @brief Load background music by copying a raw byte buffer into an @c NSData first.
 * @param bytes The raw encoded-audio bytes.
 * @param length The buffer length in bytes.
 * @param loop Whether the music should loop indefinitely.
 * @return @c YES when the player was created successfully.
 * @ghidraAddress 0x3d764
 */
- (BOOL)loadBgmDataWithBytes:(const void *)bytes length:(int)length isLoop:(BOOL)loop;
/**
 * @brief Load background music from a raw byte buffer without copying it.
 * @param bytes The raw encoded-audio bytes.
 * @param length The buffer length in bytes.
 * @param loop Whether the music should loop indefinitely.
 * @return @c YES when the player was created successfully.
 * @ghidraAddress 0x3d7ec
 */
- (BOOL)loadBgmDataWithBytesNoCopy:(void *)bytes length:(int)length isLoop:(BOOL)loop;
/**
 * @brief Load background music from a raw byte buffer without copying it, optionally freeing the
 *        buffer when the data is deallocated.
 * @param bytes The raw encoded-audio bytes.
 * @param length The buffer length in bytes.
 * @param freeWhenDone Whether the data object should free @p bytes when it is deallocated.
 * @param loop Whether the music should loop indefinitely.
 * @return @c YES when the player was created successfully.
 * @ghidraAddress 0x3d874
 */
- (BOOL)loadBgmDataWithBytesNoCopy:(void *)bytes
                            length:(int)length
                      freeWhenDone:(BOOL)freeWhenDone
                            isLoop:(BOOL)loop;
/**
 * @brief Play the loaded background music, fading in over @p time seconds when it exceeds the
 *        no-fade threshold.
 * @ghidraAddress 0x3f994
 * @param time The fade-in duration in seconds.
 * @return @c YES when playback started.
 */
- (BOOL)playBgm:(double)time;
/**
 * @brief Stop the background music, fading out over @p time seconds when it exceeds the no-fade
 *        threshold.
 * @ghidraAddress 0x3fc1c
 * @param time The fade-out duration in seconds.
 * @return @c YES when there was a player to stop.
 */
- (BOOL)stopBgm:(double)time;
/**
 * @brief Pause the background music, fading out over @p time seconds when it exceeds the no-fade
 *        threshold.
 * @ghidraAddress 0x3fd48
 * @param time The fade-out duration in seconds.
 * @return @c YES when there was a player to pause.
 */
- (BOOL)onPauseBgm:(double)time;
/**
 * @brief Whether the background music is currently playing.
 * @ghidraAddress 0x40018
 * @return @c YES when the background-music player is playing.
 */
- (BOOL)isPlayingBgm;
/**
 * @brief The background music's current playback position, in seconds.
 * @ghidraAddress 0x3fe30
 * @return The current time, or @c 0 when there is no player.
 */
- (double)bgmCurrentTime;
/**
 * @brief The background music's device time, in seconds.
 * @ghidraAddress 0x3fed0
 * @return The device current time, or @c 0 when there is no player.
 */
- (double)bgmDeviceCurrentTime;
/**
 * @brief Seek the background music to a given position.
 * @ghidraAddress 0x3ff70
 * @param bgmCurrentTime The target position, in seconds.
 */
- (void)setBgmCurrentTime:(double)bgmCurrentTime;
/**
 * @brief Seek the background music back to the start.
 * @ghidraAddress 0x40660
 */
- (void)seekBgmToTop;
/**
 * @brief Push the current background music onto the stack and pause it, leaving no active music.
 * @ghidraAddress 0x4048c
 */
- (void)pushBgm;
/**
 * @brief Restore the background music previously saved by @c -pushBgm.
 * @ghidraAddress 0x405a4
 */
- (void)popBgm;
/**
 * @brief Stop the background-music player and release it, leaving no loaded music.
 * @ghidraAddress 0x3e868
 */
- (void)releaseBgm;

#pragma mark Voice

/**
 * @brief Load a voice line from an in-memory data object, replacing any current voice.
 * @ghidraAddress 0x3d8fc
 * @param data The encoded audio data, or @c nil to load nothing.
 * @param loop Whether the voice should loop indefinitely.
 * @return @c YES when the player was created successfully.
 */
- (BOOL)loadVoiceData:(nullable NSData *)data isLoop:(BOOL)loop;
/**
 * @brief Play the loaded voice line, resuming from the saved position after a pause.
 * @ghidraAddress 0x406b8
 * @return @c YES when there was a player to play.
 */
- (BOOL)playVoice;
/**
 * @brief Stop the voice line.
 * @ghidraAddress 0x407bc
 * @return @c YES when there was a player to stop.
 */
- (BOOL)stopVoice;
/**
 * @brief Pause the voice line, saving its position so @c -playVoice can resume it.
 * @ghidraAddress 0x40860
 * @return @c YES when there was a player to pause.
 */
- (BOOL)onPauseVoice;
/**
 * @brief Whether the voice line is currently playing.
 * @ghidraAddress 0x40948
 * @return @c YES when the voice player is playing.
 */
- (BOOL)isPlayingVoice;
/**
 * @brief Release the loaded voice line and its player.
 * @ghidraAddress 0x3e8d4
 */
- (void)releaseVoice;

#pragma mark Sound effect loading

/**
 * @brief Load a sound effect from a file, registering it under an optional call name and group.
 * @ghidraAddress 0x3dc48
 * @param path The file path of the sound effect.
 * @param loop Whether the sound effect should loop.
 * @param callName The name to register the source under, or @c nil to address it by index.
 * @param group The mixer group: @c 0 selects the cached voice subsystem, non-zero the bus manager.
 * @return The tagged resource handle, or @c 0xffffffff on failure or when registered by call name.
 */
- (int)loadSe:(nullable NSString *)path
       isLoop:(BOOL)loop
     callName:(nullable NSString *)callName
        group:(int)group;
/**
 * @brief Release a loaded sound effect addressed by call name or resource identifier.
 * @ghidraAddress 0x3e1a4
 * @param callName The call name of the source, or @c nil to address it by resource identifier.
 * @param resourceId The resource identifier, used when @p callName is @c nil.
 */
- (void)releaseSe:(nullable NSString *)callName resourceId:(int)resourceId;
/**
 * @brief Release every loaded sound effect from both subsystems and clear the look-up tables.
 * @ghidraAddress 0x3e580
 */
- (void)releaseSeAll;

#pragma mark Sound effect playback

/**
 * @brief Play a sound effect addressed by call name or resource identifier, at its group volume.
 * @ghidraAddress 0x3ec00
 * @param callName The call name of the source, or @c nil to address it by resource identifier.
 * @param resourceId The resource identifier, used when @p callName is @c nil.
 * @return The play handle, or @c 0xffffffff on failure.
 */
- (unsigned int)playSe:(nullable NSString *)callName resourceId:(int)resourceId;
/**
 * @brief Play a sound effect at an explicit volume.
 * @ghidraAddress 0x3ece8
 * @param callName The call name of the source, or @c nil to address it by resource identifier.
 * @param resourceId The resource identifier, used when @p callName is @c nil.
 * @param volume The playback volume.
 * @return The play handle, or @c 0xffffffff on failure.
 */
- (unsigned int)playSe:(nullable NSString *)callName resourceId:(int)resourceId Volume:(int)volume;
/**
 * @brief Play a sound effect on a specific mixer group.
 * @ghidraAddress 0x3edd0
 * @param callName The call name of the source, or @c nil to address it by resource identifier.
 * @param resourceId The resource identifier, used when @p callName is @c nil.
 * @param groupId The mixer group to play on.
 * @return The play handle, or @c 0xffffffff on failure.
 */
- (unsigned int)playSeSetGroup:(nullable NSString *)callName
                    resourceId:(int)resourceId
                       groupId:(int)groupId;
/**
 * @brief Stop a playing sound effect.
 * @ghidraAddress 0x3ee78
 * @param handle The play handle to stop.
 * @return @c YES when a matching instance was found.
 */
- (BOOL)stopSe:(unsigned int)handle;
/**
 * @brief Pause a playing sound effect.
 * @ghidraAddress 0x3eefc
 * @param handle The play handle to pause.
 * @return @c YES when a matching instance was found.
 */
- (BOOL)onPauseSe:(unsigned int)handle;
/**
 * @brief Resume a paused sound effect.
 * @ghidraAddress 0x3ef80
 * @param handle The play handle to resume.
 * @return @c YES when a matching instance was found.
 */
- (BOOL)offPauseSe:(unsigned int)handle;
/**
 * @brief Whether a sound effect is currently playing.
 * @ghidraAddress 0x3f004
 * @param handle The play handle to query.
 * @return @c YES when the instance is playing.
 */
- (BOOL)isPlayingSe:(unsigned int)handle;
/**
 * @brief Pause every active sound-effect instance.
 * @ghidraAddress 0x3f090
 * @return Always @c YES.
 */
- (BOOL)onPauseSeAll;
/**
 * @brief Resume every active sound-effect instance.
 * @ghidraAddress 0x3f110
 * @return Always @c YES.
 */
- (BOOL)offPauseSeAll;
/**
 * @brief Stop every active sound-effect instance.
 * @ghidraAddress 0x3f190
 * @return Always @c YES.
 */
- (BOOL)stopSeAll;
/**
 * @brief Stop the background music, the voice line, and every sound effect.
 * @ghidraAddress 0x3f210
 * @return Always @c YES.
 */
- (BOOL)stopAll;

#pragma mark Volume

/**
 * @brief Set the playback volume for a mixer group.
 * @ghidraAddress 0x3f624
 * @param seVolume The volume, ignored when it is @c 128 or greater.
 * @param groupId The mixer group: @c 0 selects the cached voice subsystem, non-zero the bus manager.
 */
- (void)setSeVolume:(int)seVolume groupId:(int)groupId;

#pragma mark Properties

/**
 * @brief The call names of the sources registered by name.
 * @ghidraAddress 0x4102c (getter)
 * @ghidraAddress 0x4103c (setter)
 */
@property(nonatomic, strong, nullable) NSMutableArray *seNameList;
/**
 * @brief The resource identifiers of the sources registered by index.
 * @ghidraAddress 0x41074 (getter)
 * @ghidraAddress 0x41084 (setter)
 */
@property(nonatomic, strong, nullable) NSMutableArray *seRidList;
/**
 * @brief The background-music @c AVAudioPlayer.
 * @ghidraAddress 0x410bc (getter)
 * @ghidraAddress 0x410cc (setter)
 */
@property(nonatomic, strong, nullable) AVAudioPlayer *bgmPlayer;
/**
 * @brief The voice @c AVAudioPlayer.
 * @ghidraAddress 0x41104 (getter)
 * @ghidraAddress 0x41114 (setter)
 */
@property(nonatomic, strong, nullable) AVAudioPlayer *voicePlayer;
/**
 * @brief The active background-music fade timer.
 * @ghidraAddress 0x4114c (getter)
 * @ghidraAddress 0x4115c (setter)
 */
@property(nonatomic, strong, nullable) NSTimer *fadeTimer;
/**
 * @brief The saved background-music position, in seconds.
 * @ghidraAddress 0x41194 (getter)
 * @ghidraAddress 0x411a4 (setter)
 */
@property(nonatomic, assign) double bgmPlayTime;
/**
 * @brief The saved voice position used to resume after a pause, in seconds.
 * @ghidraAddress 0x411b4 (getter)
 * @ghidraAddress 0x411c4 (setter)
 */
@property(nonatomic, assign) double voicePlayTime;
/**
 * @brief The background-music player saved by @c -pushBgm and restored by @c -popBgm.
 * @ghidraAddress 0x411d4 (getter)
 * @ghidraAddress 0x411e4 (setter)
 */
@property(nonatomic, strong, nullable) AVAudioPlayer *stackBgm;
/**
 * @brief The map from a source's call name or resource identifier to its mixer group.
 * @ghidraAddress 0x4121c (getter)
 * @ghidraAddress 0x4122c (setter)
 */
@property(nonatomic, strong, nullable) NSMutableDictionary *seType;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C++
// kate: hl Objective-C++;
// vim: set ft=objcpp :
