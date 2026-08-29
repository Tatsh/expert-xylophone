#import "SePlayer.h"

#import <AudioToolbox/AudioToolbox.h>
#import <OpenAL/al.h>
#import <OpenAL/alc.h>

// alBufferDataStatic references the caller's samples in place, so they must outlive the buffer.
typedef ALvoid (*AlBufferDataStaticProc)(
    ALuint buffer, ALenum format, ALvoid *data, ALsizei size, ALsizei frequency);

static const UInt32 kMaxChannelCount = 2;
static const UInt32 kBitsPerChannel = 16;
static const UInt32 kBytesPerChannel = 2;

// @ghidraAddress 0x17840
static void *LoadAudioFileToPcm(NSURL *url, ALsizei *outSize, ALenum *outFormat, ALsizei *outFreq) {
    SInt64 frameCount = 0;
    UInt32 propertySize = sizeof(AudioStreamBasicDescription);
    ExtAudioFileRef audioFile = NULL;
    void *pcmData = NULL;
    if (ExtAudioFileOpenURL((__bridge CFURLRef)url, &audioFile) == noErr) {
        AudioStreamBasicDescription fileFormat;
        if (ExtAudioFileGetProperty(
                audioFile, kExtAudioFileProperty_FileDataFormat, &propertySize, &fileFormat) ==
                noErr &&
            fileFormat.mChannelsPerFrame <= kMaxChannelCount) {
            AudioStreamBasicDescription clientFormat;
            clientFormat.mSampleRate = fileFormat.mSampleRate;
            clientFormat.mChannelsPerFrame = fileFormat.mChannelsPerFrame;
            clientFormat.mBytesPerPacket = fileFormat.mChannelsPerFrame * kBytesPerChannel;
            clientFormat.mFramesPerPacket = 1;
            clientFormat.mBitsPerChannel = kBitsPerChannel;
            clientFormat.mFormatID = kAudioFormatLinearPCM;
            clientFormat.mFormatFlags =
                kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
            clientFormat.mBytesPerFrame = clientFormat.mBytesPerPacket;
            if (ExtAudioFileSetProperty(audioFile,
                                        kExtAudioFileProperty_ClientDataFormat,
                                        sizeof(clientFormat),
                                        &clientFormat) == noErr) {
                propertySize = sizeof(frameCount);
                if (ExtAudioFileGetProperty(audioFile,
                                            kExtAudioFileProperty_FileLengthFrames,
                                            &propertySize,
                                            &frameCount) == noErr) {
                    UInt32 byteSize = (UInt32)(clientFormat.mBytesPerFrame * frameCount);
                    pcmData = malloc(byteSize);
                    if (pcmData != NULL) {
                        AudioBufferList bufferList;
                        bufferList.mNumberBuffers = 1;
                        bufferList.mBuffers[0].mNumberChannels = clientFormat.mChannelsPerFrame;
                        bufferList.mBuffers[0].mDataByteSize = byteSize;
                        bufferList.mBuffers[0].mData = pcmData;
                        UInt32 framesToRead = (UInt32)frameCount;
                        if (ExtAudioFileRead(audioFile, &framesToRead, &bufferList) == noErr) {
                            *outSize = (ALsizei)byteSize;
                            *outFormat = clientFormat.mChannelsPerFrame < kMaxChannelCount ?
                                             AL_FORMAT_MONO16 :
                                             AL_FORMAT_STEREO16;
                            *outFreq = (ALsizei)clientFormat.mSampleRate;
                            goto done;
                        }
                        free(pcmData);
                    }
                }
            }
        }
        pcmData = NULL;
    }
done:
    if (audioFile != NULL) {
        ExtAudioFileDispose(audioFile);
    }
    return pcmData;
}

// @ghidraAddress 0x179c8 (CallAlBufferDataStatic)
// @ghidraAddress 0x3dc238 (g_alBufferDataStaticProc)
static void
CallAlBufferDataStatic(ALuint buffer, ALenum format, void *data, ALsizei size, ALsizei frequency);

// @ghidraAddress 0x3dc238
static AlBufferDataStaticProc g_alBufferDataStaticProc = NULL;

@implementation SePlayer {
    ALuint soundBuffer;
    ALuint soundSource;
    ALCdevice *soundDevice;
    void *soundData;
    ALCcontext *soundContext;
}

- (nullable instancetype)initWithPath:(nonnull NSString *)path {
    /** @ghidraAddress 0x176f4 */
    self = [super init];
    if (self != nil) {
        soundDevice = alcOpenDevice(NULL);
        if (soundDevice != NULL) {
            soundContext = alcCreateContext(soundDevice, NULL);
            alcMakeContextCurrent(soundContext);
            alGenBuffers(1, &soundBuffer);
            alGenSources(1, &soundSource);
        }
        ALsizei size = 0;
        ALenum format = 0;
        ALsizei sampleRate = 0;
        NSURL *url = [NSURL fileURLWithPath:path];
        soundData = LoadAudioFileToPcm(url, &size, &format, &sampleRate);
        CallAlBufferDataStatic(soundBuffer, format, soundData, size, sampleRate);
        alSourcei(soundSource, AL_LOOPING, 0);
        alSourcei(soundSource, AL_BUFFER, (ALint)soundBuffer);
    }
    return self;
}

- (void)sePlay {
    /** @ghidraAddress 0x17a54 */
    alSourcePlay(soundSource);
}

- (void)terminate {
    /** @ghidraAddress 0x17a64 */
    alSourceStop(soundSource);
    alDeleteBuffers(1, &soundBuffer);
    alDeleteSources(1, &soundSource);
    alcDestroyContext(soundContext);
    alcCloseDevice(soundDevice);
    free(soundData);
    soundBuffer = 0;
    soundSource = 0;
    soundContext = NULL;
    soundDevice = NULL;
    soundData = NULL;
}

@end

#pragma mark - Audio decoding

static void
CallAlBufferDataStatic(ALuint buffer, ALenum format, void *data, ALsizei size, ALsizei frequency) {
    /** @ghidraAddress 0x179c8 */
    if (g_alBufferDataStaticProc == NULL) {
        g_alBufferDataStaticProc =
            (AlBufferDataStaticProc)alcGetProcAddress(NULL, "alBufferDataStatic");
        if (g_alBufferDataStaticProc == NULL) {
            return;
        }
    }
    g_alBufferDataStaticProc(buffer, format, data, size, frequency);
}
