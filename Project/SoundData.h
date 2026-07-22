/** @file
 * A decoded audio asset used by the game's sound engine. On construction the object resolves a
 * sound file (from the application's document directory or main bundle, trying the @c .mp3, @c .wav,
 * and @c .m4a extensions in turn), opens it with @c ExtAudioFile, and configures a signed 16-bit
 * interleaved PCM client format. In buffered mode the whole file is decoded up front into a
 * per-channel play buffer; in streaming mode the file stays open and frames are read on demand.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class SoundData, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <AudioToolbox/AudioToolbox.h>
#import <Foundation/Foundation.h>

/**
 * @brief A decoded (or streamed) audio asset that vends interleaved PCM frames into a caller
 * supplied @c AudioBufferList.
 */
@interface SoundData : NSObject

/**
 * @brief The name the asset was created with, used to locate the backing file.
 * @ghidraAddress 0x34b40
 */
@property(nonatomic, readonly) NSString *fileName;

/**
 * @brief The number of channels in the decoded PCM stream.
 * @ghidraAddress 0x34b50
 */
@property(nonatomic, readonly) unsigned int channels;

/**
 * @brief The total number of frames in the asset.
 * @ghidraAddress 0x34b60
 */
@property(nonatomic, readonly) long long totalFrames;

/**
 * @brief The client PCM stream format the asset was decoded into.
 * @ghidraAddress 0x34b30
 */
@property(nonatomic, readonly) AudioStreamBasicDescription *format;

/**
 * @brief Creates an asset for the named sound file and prepares it for playback.
 * @param fileName The base name of the sound file to load.
 * @param stream Whether to stream the file on demand (@c YES) or decode it fully into memory
 * (@c NO).
 * @return The prepared asset, or @c nil if initialisation failed.
 * @ghidraAddress 0x34310
 */
- (instancetype)initWithContentsFileName:(NSString *)fileName Stream:(BOOL)stream;

/**
 * @brief Resolves and opens the backing file, configures the client PCM format, and either decodes
 * the whole file into a per-channel play buffer or leaves it open for streaming.
 * @param fileName The base name of the sound file to load.
 * @param stream Whether to stream the file on demand (@c YES) or decode it fully into memory
 * (@c NO).
 * @ghidraAddress 0x34454
 */
- (void)prepare:(NSString *)fileName Stream:(BOOL)stream;

/**
 * @brief Fills a buffer list with interleaved PCM frames starting at a given frame, optionally
 * looping back to the start when the end of the asset is reached.
 * @param startFrame The frame index to begin reading from.
 * @param frameCount The number of frames requested.
 * @param loop Whether to wrap around to the start of the asset once the end is reached.
 * @param buffer The buffer list to fill; its @c mData pointers receive the copied frames.
 * @param outNextFrame On return, the frame index playback should resume from (0 after a wrap).
 * @return @c YES when the asset has been exhausted without looping, otherwise @c NO.
 * @ghidraAddress 0x34908
 */
- (BOOL)getData:(long long)startFrame
         Frames:(long long)frameCount
           Loop:(BOOL)loop
         Buffer:(AudioBufferList *)buffer
            Out:(long long *)outNextFrame;

@end

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
