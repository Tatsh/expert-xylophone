/** @file
 * A self-contained OpenAL one-shot sound-effect player. Each instance owns its own OpenAL device
 * and context, a single buffer, and a single source. On initialisation it decodes an audio file to
 * signed 16-bit PCM through Core Audio (@c ExtAudioFile) and hands the samples to the buffer with
 * the @c alBufferDataStatic extension (which references the samples in place rather than copying
 * them), then wires the buffer to the source as a non-looping one-shot. @c -sePlay triggers a
 * playback and @c -terminate tears the whole OpenAL graph down and frees the decoded samples.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class SePlayer, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A single OpenAL sound source that decodes one audio file and plays it as a one-shot.
 */
@interface SePlayer : NSObject

/**
 * @brief Decode an audio file to 16-bit PCM and prepare an OpenAL source that plays it.
 * @ghidraAddress 0x176f4
 * @param path The file path of the sound effect to decode and load.
 * @return The initialised player, or @c nil when @c NSObject initialisation fails.
 */
- (nullable instancetype)initWithPath:(nonnull NSString *)path;
/**
 * @brief Play the loaded sound effect from the start.
 * @ghidraAddress 0x17a54
 */
- (void)sePlay;
/**
 * @brief Stop playback, delete the OpenAL buffer and source, destroy the context and device, and
 *        free the decoded samples.
 * @ghidraAddress 0x17a64
 */
- (void)terminate;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
