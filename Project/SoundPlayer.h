/** @file
 * A single mixer-voice wrapper around a decoded @c SoundData asset. It tracks a playback cursor
 * into the asset and streams frames into a caller-supplied buffer list on demand, driven by the
 * owning @c SoundManager graph's per-element render callback.
 *
 * This is a speculative interface covering only the surface @c SoundManager depends on; the full
 * class is reconstructed separately. Declared in the owner's real header in the no-seams style the
 * rest of the tree uses.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class SoundPlayer, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <AudioToolbox/AudioToolbox.h>
#import <Foundation/Foundation.h>

@class SoundData;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A single mixer voice that streams a decoded @c SoundData asset into a buffer list.
 */
@interface SoundPlayer : NSObject

/**
 * @brief The asset the voice is playing, assignable only while the voice is idle.
 * @ghidraAddress 0x354fc (getter)
 * @ghidraAddress 0x35498 (setter)
 */
@property(nonatomic, strong, nullable) SoundData *soundData;
/**
 * @brief The playback cursor, in frames, into the current asset.
 * @ghidraAddress 0x3557c (getter)
 * @ghidraAddress 0x3550c (setter)
 */
@property(nonatomic, assign) long long currentFrame;
/**
 * @brief Whether the voice loops its asset.
 * @ghidraAddress 0x355ac (getter)
 * @ghidraAddress 0x3558c (setter)
 */
@property(nonatomic, assign) BOOL loop;

/**
 * @brief Start playing the current asset from the cursor.
 * @ghidraAddress 0x355bc
 */
- (void)play;
/**
 * @brief Whether the voice is currently playing.
 * @ghidraAddress 0x355dc
 * @return @c YES while the voice is playing.
 */
- (BOOL)isPlaying;
/**
 * @brief Mark playback as ended, releasing the voice back to the idle pool.
 * @ghidraAddress 0x355ec
 */
- (void)endPlay;
/**
 * @brief Stop the voice.
 * @ghidraAddress 0x355fc
 */
- (void)stop;
/**
 * @brief Whether the voice has reached the end of its asset.
 * @ghidraAddress 0x35610
 * @return @c YES once the asset is exhausted.
 */
- (BOOL)isStop;
/**
 * @brief Fill a buffer list with the next frames of the current asset, advancing the cursor.
 * @ghidraAddress 0x35620
 * @param buffer The buffer list to fill.
 * @param frames The number of frames requested.
 */
- (void)loadData:(AudioBufferList *)buffer Frames:(unsigned int)frames;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
