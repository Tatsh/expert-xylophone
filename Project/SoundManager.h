/** @file
 * A low-level sound-effect mixer manager singleton. Unlike @c AudioManager (which drives the
 * engine's cached voice player and streamed bus mixer), this manager owns a small @c AUGraph of
 * its own: an embedded three-dimensional mixer node feeding a remote-I/O output node. It keeps a
 * pool of decoded @c SoundData assets and a bank of @c SoundPlayer voices, one per mixer input
 * element, and streams each playing voice's frames into the graph through a per-element render
 * callback.
 *
 * A sound file is loaded once into the asset pool with @c -loadFile:Stream: and addressed
 * afterwards by its pool index. Playing an asset finds a free voice, points it at the asset, and
 * installs the render callback on the voice's mixer input; the callback tears itself down and
 * stops the voice when the asset is exhausted. The whole graph can be started and stopped as a
 * unit, which the application uses to gate audio while suspended.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class SoundManager, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <AudioToolbox/AudioToolbox.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A self-contained @c AUGraph sound-effect mixer that plays pooled @c SoundData assets
 * through a bank of @c SoundPlayer voices.
 */
@interface SoundManager : NSObject

#pragma mark Singleton

/**
 * @brief The shared sound manager, created on first use.
 * @ghidraAddress 0x34bb0
 * @return The shared @c SoundManager.
 */
+ (instancetype)getInstance;

#pragma mark Graph lifecycle

/**
 * @brief Start the mixer graph if it has been initialised and is not already running.
 * @ghidraAddress 0x35380
 */
- (void)startSystem;
/**
 * @brief Stop the mixer graph if it has been initialised and is running.
 * @ghidraAddress 0x353d4
 */
- (void)stopSystem;

#pragma mark Asset pool

/**
 * @brief Load a sound file into the asset pool, reusing an existing slot when the file is already
 *        loaded.
 * @ghidraAddress 0x34eec
 * @param fileName The base name of the sound file to load.
 * @param stream Whether to stream the file on demand rather than decode it fully into memory.
 * @return The asset's pool index, or @c -1 when the pool is full.
 */
- (int)loadFile:(NSString *)fileName Stream:(BOOL)stream;
/**
 * @brief Release the pooled asset at a given index.
 * @ghidraAddress 0x35038
 * @param index The asset's pool index.
 * @return @c YES when a loaded asset was released.
 */
- (BOOL)releaseData:(int)index;

#pragma mark Playback

/**
 * @brief Play the pooled asset at a given index on the first free voice.
 * @ghidraAddress 0x35074
 * @param index The asset's pool index.
 * @param loop Whether the voice should loop the asset. Reserved; the original build ignores it.
 * @return The voice index playing the asset, or @c -1 when no voice was free.
 */
- (int)play:(int)index Loop:(BOOL)loop;
/**
 * @brief Stop the voice at a given index if it is playing.
 * @ghidraAddress 0x35198
 * @param index The voice index.
 * @return Always @c YES.
 */
- (BOOL)stop:(int)index;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
