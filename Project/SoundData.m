//
//  SoundData.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class SoundData). Verified against the
//  arm64 disassembly (the -prepare:Stream: file-search variadic format strings and the
//  AudioBufferList and AudioStreamBasicDescription field arithmetic are dropped or garbled by the
//  decompiler).
//

#import "SoundData.h"

#include <stdlib.h>
#include <string.h>
#include <strings.h>

// Fills an AudioStreamBasicDescription for signed 16-bit interleaved linear PCM at the given sample
// rate and channel count. This lives in the plain-C engine layer, which is not C-safe to import, so
// the prototype is declared locally.
// @ghidraAddress 0x33ec8 (InitPcmFormatDescriptor)
// @ghidraAddress 0x2eee60 (g_dSoundDataSampleRate)
void InitPcmFormatDescriptor(AudioStreamBasicDescription *pAsbd,
                             double sampleRate,
                             int channelCount);

// The sample rate the client PCM format is configured for.
static const double kSoundDataSampleRate = 44100.0;

// The @c ExtAudioFileGetProperty selectors used while preparing the asset.
static const ExtAudioFilePropertyID kFileDataFormatProperty =
    kExtAudioFileProperty_FileDataFormat;
static const ExtAudioFilePropertyID kClientDataFormatProperty =
    kExtAudioFileProperty_ClientDataFormat;
static const ExtAudioFilePropertyID kFileLengthFramesProperty =
    kExtAudioFileProperty_FileLengthFrames;

// The candidate file-name extensions searched, in order, when locating the backing file.
static NSString *const kSoundDataExtensions[] = {@"mp3", @"wav", @"m4a"};
static const NSUInteger kSoundDataExtensionCount =
    sizeof(kSoundDataExtensions) / sizeof(kSoundDataExtensions[0]);

// The format string used to build a candidate path in a search directory: directory, name, and
// extension.
static NSString *const kSoundDataPathFormat = @"%@/%@.%@";

// The byte stride the buffered wrap-around and silence paths apply to the already-copied frame
// count when advancing each destination @c mData pointer. The original build hard-codes four bytes
// per frame here rather than reusing @c mBytesPerFrame.
static const long long kSoundDataWrapDestinationFrameStride = 4;

@interface SoundData () {
    // Internal fields populated by -prepare:Stream:. These are distinct from the read-only
    // property backing ivars below, which the original build leaves unset.
    unsigned int m_NumberOfChannels;
    long long m_TotalFrames;
    long long m_CurrentFrameCache;
    ExtAudioFileRef m_ExtAudioFile;
    AudioStreamBasicDescription m_Format;
    void **m_PlayBuffer;
    NSString *m_FileName;
    BOOL m_Stream;
}
@end

@implementation SoundData

- (instancetype)initWithContentsFileName:(NSString *)fileName Stream:(BOOL)stream {
    /** @ghidraAddress 0x34310 */
    self = [super init];
    if (self) {
        [self prepare:fileName Stream:stream];
    }
    return self;
}

- (void)prepare:(NSString *)fileName Stream:(BOOL)stream {
    /** @ghidraAddress 0x34454 */
    m_FileName = [NSString stringWithString:fileName];

    NSArray *documentDirectories =
        NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentDirectory = documentDirectories[0];

    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *path = [NSString stringWithFormat:kSoundDataPathFormat,
                                                documentDirectory,
                                                m_FileName,
                                                kSoundDataExtensions[0]];
    if (![fileManager fileExistsAtPath:path]) {
        NSUInteger extensionIndex = 1;
        do {
            if (extensionIndex >= kSoundDataExtensionCount) {
                path = nil;
                break;
            }
            path = [NSString stringWithFormat:kSoundDataPathFormat,
                                              documentDirectory,
                                              m_FileName,
                                              kSoundDataExtensions[extensionIndex]];
            ++extensionIndex;
        } while (![fileManager fileExistsAtPath:path]);
    }

    if (!path) {
        for (NSUInteger extensionIndex = 0; extensionIndex < kSoundDataExtensionCount;
             ++extensionIndex) {
            path = [[NSBundle mainBundle] pathForResource:m_FileName
                                                   ofType:kSoundDataExtensions[extensionIndex]];
            if (path) {
                break;
            }
        }
        if (!path) {
            return;
        }
    }

    NSURL *url = [NSURL fileURLWithPath:path];
    ExtAudioFileOpenURL((__bridge CFURLRef)url, &m_ExtAudioFile);

    UInt32 propertySize = sizeof(AudioStreamBasicDescription);
    AudioStreamBasicDescription fileFormat;
    ExtAudioFileGetProperty(
        m_ExtAudioFile, kFileDataFormatProperty, &propertySize, &fileFormat);
    m_NumberOfChannels = fileFormat.mChannelsPerFrame;

    InitPcmFormatDescriptor(&m_Format, kSoundDataSampleRate, (int)m_NumberOfChannels);
    ExtAudioFileSetProperty(m_ExtAudioFile,
                            kClientDataFormatProperty,
                            sizeof(AudioStreamBasicDescription),
                            &m_Format);

    propertySize = sizeof(long long);
    ExtAudioFileGetProperty(
        m_ExtAudioFile, kFileLengthFramesProperty, &propertySize, &m_TotalFrames);

    m_Stream = stream;
    if (stream) {
        m_CurrentFrameCache = 0;
        return;
    }

    // Buffered mode: decode the whole file into one contiguous buffer per channel and read it in a
    // single ExtAudioFileRead.
    m_PlayBuffer = (void **)malloc((size_t)m_NumberOfChannels * sizeof(void *));
    unsigned int channelCount = m_NumberOfChannels;
    AudioBufferList *bufferList;
    if (channelCount == 0) {
        bufferList = (AudioBufferList *)malloc(sizeof(AudioBufferList));
        bufferList->mNumberBuffers = 1;
    } else {
        size_t channelByteSize = (size_t)m_Format.mBytesPerFrame * m_TotalFrames;
        m_PlayBuffer[0] = malloc(channelByteSize);
        for (unsigned int channelIndex = 1; channelIndex < channelCount; ++channelIndex) {
            m_PlayBuffer[channelIndex] = malloc(channelByteSize);
        }
        bufferList = (AudioBufferList *)malloc(sizeof(AudioBufferList) +
                                               (size_t)(channelCount - 1) * sizeof(AudioBuffer));
        bufferList->mNumberBuffers = 1;
        for (unsigned int channelIndex = 0; channelIndex < channelCount; ++channelIndex) {
            bufferList->mBuffers[channelIndex].mNumberChannels = channelCount;
            bufferList->mBuffers[channelIndex].mDataByteSize =
                m_Format.mBytesPerFrame * (unsigned int)m_TotalFrames;
            bufferList->mBuffers[channelIndex].mData = m_PlayBuffer[channelIndex];
        }
    }

    UInt32 framesToRead = (UInt32)m_TotalFrames;
    ExtAudioFileRead(m_ExtAudioFile, &framesToRead, bufferList);
    free(bufferList);
    ExtAudioFileDispose(m_ExtAudioFile);
    m_ExtAudioFile = nullptr;
}

- (BOOL)getData:(long long)startFrame
         Frames:(long long)frameCount
           Loop:(BOOL)loop
         Buffer:(AudioBufferList *)buffer
            Out:(long long *)outNextFrame {
    /** @ghidraAddress 0x34908 */
    if (!m_Stream) {
        long long framesRemaining = m_TotalFrames - startFrame;
        long long framesToCopy = (frameCount <= framesRemaining) ? frameCount : framesRemaining;
        unsigned int channelCount = buffer->mNumberBuffers;
        if (channelCount != 0) {
            unsigned int bytesPerFrame = m_Format.mBytesPerFrame;
            for (unsigned int channelIndex = 0; channelIndex < buffer->mNumberBuffers;
                 ++channelIndex) {
                memcpy(buffer->mBuffers[channelIndex].mData,
                       (char *)m_PlayBuffer[channelIndex] + bytesPerFrame * startFrame,
                       bytesPerFrame * framesToCopy);
            }
        }
        *outNextFrame = framesToCopy + startFrame;
        if (frameCount <= framesRemaining) {
            return NO;
        }
        long long framesLeft = frameCount - framesToCopy;
        if (loop) {
            if (channelCount != 0) {
                for (unsigned int channelIndex = 0; channelIndex < buffer->mNumberBuffers;
                     ++channelIndex) {
                    memcpy((char *)buffer->mBuffers[channelIndex].mData +
                               framesToCopy * kSoundDataWrapDestinationFrameStride,
                           m_PlayBuffer[channelIndex],
                           m_Format.mBytesPerFrame * framesLeft);
                }
            }
            *outNextFrame = framesLeft;
            return NO;
        }
        if (channelCount != 0) {
            for (unsigned int channelIndex = 0; channelIndex < buffer->mNumberBuffers;
                 ++channelIndex) {
                bzero((char *)buffer->mBuffers[channelIndex].mData +
                          framesToCopy * kSoundDataWrapDestinationFrameStride,
                      (size_t)m_Format.mBytesPerFrame * (frameCount - framesToCopy));
            }
        }
        return NO;
    }

    // Streaming mode: seek if necessary and read frames directly from the file.
    if (m_CurrentFrameCache != startFrame) {
        ExtAudioFileSeek(m_ExtAudioFile, startFrame);
        m_CurrentFrameCache = startFrame;
    }
    UInt32 framesRead = (UInt32)frameCount;
    OSStatus status = ExtAudioFileRead(m_ExtAudioFile, &framesRead, buffer);
    if (status != noErr) {
        return YES;
    }
    *outNextFrame = framesRead + startFrame;
    if (framesRead != frameCount) {
        if (!loop) {
            return YES;
        }
        ExtAudioFileSeek(m_ExtAudioFile, 0);
        m_CurrentFrameCache = 0;
        *outNextFrame = 0;
    }
    return NO;
}

- (AudioStreamBasicDescription *)format {
    /** @ghidraAddress 0x34b30 */
    return &m_Format;
}

- (void)dealloc {
    /** @ghidraAddress 0x34398 */
    if (m_ExtAudioFile) {
        ExtAudioFileDispose(m_ExtAudioFile);
    }
    if (m_PlayBuffer) {
        if (m_NumberOfChannels != 0) {
            free(m_PlayBuffer[0]);
            for (unsigned int channelIndex = 1; channelIndex < m_NumberOfChannels;
                 ++channelIndex) {
                free(m_PlayBuffer[channelIndex]);
            }
        }
        free(m_PlayBuffer);
    }
}

@end
