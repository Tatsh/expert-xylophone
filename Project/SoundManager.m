//
//  SoundManager.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class SoundManager). Verified against
//  the arm64 disassembly: the decompiler mis-modelled the float-PCM format helper as a vtable init
//  and dropped its sample-rate argument, and it renders the AUGraph node, unit, and ivar-array
//  arithmetic as raw pointer offsets. The render callback is a plain-C AURenderCallback, so this
//  file wires it up through AudioToolbox C APIs rather than Objective-C.
//

#import "SoundManager.h"

#import <AVFoundation/AVFoundation.h>

#import "SoundData.h"
#import "SoundPlayer.h"

// Fills an AudioStreamBasicDescription for 32-bit float interleaved linear PCM at the given sample
// rate and channel count. This lives in the plain-C engine layer, which is not C-safe to import, so
// the prototype is declared locally.
// @ghidraAddress 0x33e9c (InitFloatPcmFormatDescriptor)
// @ghidraAddress 0x2eee60 (g_dSoundDataSampleRate)
void InitFloatPcmFormatDescriptor(AudioStreamBasicDescription *pAsbd,
                                  double sampleRate,
                                  int channelCount);

// The sample rate the mixer output format is configured for.
static const double kSoundManagerSampleRate = 44100.0;

// The mixer output is a stereo stream.
static const int kOutputChannelCount = 2;

// The number of decoded assets the pool can hold.
static const int kSoundDataPoolCount = 10;

// The number of concurrent mixer voices, one per mixer input element.
static const int kSoundPlayerVoiceCount = 8;

// The sentinel returned when the asset pool is full or no voice is free.
static const int kInvalidSlot = -1;

// The audio component descriptions of the two graph nodes: an embedded three-dimensional mixer
// feeding a remote-I/O output.
// @ghidraAddress 0x2eee70 (g_abMixerComponentDescription)
static const AudioComponentDescription kMixerComponentDescription = {
    .componentType = kAudioUnitType_Mixer,
    .componentSubType = kAudioUnitSubType_AU3DMixerEmbedded,
    .componentManufacturer = kAudioUnitManufacturer_Apple,
};
// @ghidraAddress 0x2eee80 (g_abOutputComponentDescription)
static const AudioComponentDescription kOutputComponentDescription = {
    .componentType = kAudioUnitType_Output,
    .componentSubType = kAudioUnitSubType_RemoteIO,
    .componentManufacturer = kAudioUnitManufacturer_Apple,
};

// The graph node whose input elements feed the output; the sole output element index.
enum {
    kMixerBusInput = 0,
    kOutputBusOutput = 0,
};

// The mixer's input-element count.
static const UInt32 kMixerElementCount = 8;

@interface SoundManager () {
    // The decoded-asset pool. The 32-bit offsets are documentation only; access always goes through
    // these named fields.
    SoundData *m_SoundData[kSoundDataPoolCount]; // +0x08
    SoundPlayer *m_SoundPlayer[kSoundPlayerVoiceCount]; // +0x58
    BOOL m_InitGraph; // +0x98
    BOOL m_IsPlayGraph; // +0x99
    AUGraph m_Graph; // +0xa0
    AUNode m_MixerNode; // +0xa8
    AUNode m_OutputNode; // +0xac
    AudioUnit m_MixerUnit; // +0xb0
    AudioUnit m_OutputUnit; // +0xb8
}

// Configures the audio session and builds the mixer graph; called once from -init.
- (void)setupAudioSession;
- (void)prepareAUGraph;

// Installs (or clears) the render callback and stream format on a mixer input element, and returns
// the voice bound to a given index. Used by the file-private render callback.
- (void)setCallBack:(int)element DataFormat:(AudioStreamBasicDescription *)format;
- (void)unsetCallBack:(int)element;
- (SoundPlayer *)getSoundPlayer:(int)index;
@end

// Feeds the next frames of a voice's asset into a mixer input element, stopping the voice and
// unhooking its callback once the asset is exhausted. This is the standard AURenderCallback: the
// reference constant is the sound manager, the bus number is the voice (and mixer input element)
// index, and the buffer list receives the frames.
// @ghidraAddress 0x35274 (HandleSoundStreamCallback)
static OSStatus HandleSoundStreamCallback(void *inRefCon,
                                          AudioUnitRenderActionFlags *ioActionFlags,
                                          const AudioTimeStamp *inTimeStamp,
                                          UInt32 inBusNumber,
                                          UInt32 inNumberFrames,
                                          AudioBufferList *ioData) {
    SoundManager *manager = (__bridge SoundManager *)inRefCon;
    SoundPlayer *player = [manager getSoundPlayer:(int)inBusNumber];
    [player loadData:ioData Frames:inNumberFrames];
    if ([player isStop]) {
        [player endPlay];
        [manager unsetCallBack:(int)inBusNumber];
    }
    return noErr;
}

@implementation SoundManager

#pragma mark - Singleton

+ (instancetype)getInstance {
    /** @ghidraAddress 0x34bb0 */
    static SoundManager *instance = nil;
    if (instance == nil) {
        instance = [[SoundManager alloc] init];
    }
    return instance;
}

#pragma mark - Lifecycle

- (instancetype)init {
    /** @ghidraAddress 0x34c08 */
    self = [super init];
    if (self) {
        for (int slot = 0; slot < kSoundDataPoolCount; ++slot) {
            m_SoundData[slot] = nil;
        }
        for (int voice = 0; voice < kSoundPlayerVoiceCount; ++voice) {
            m_SoundPlayer[voice] = [[SoundPlayer alloc] init];
        }
        [self setupAudioSession];
        [self prepareAUGraph];
    }
    return self;
}

#pragma mark - Audio session and graph setup

- (void)setupAudioSession {
    /** @ghidraAddress 0x34cf8 */
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryAmbient error:nil];
    [session setActive:YES error:nil];
}

- (void)prepareAUGraph {
    /** @ghidraAddress 0x34d68 */
    NewAUGraph(&m_Graph);
    AUGraphAddNode(m_Graph, &kMixerComponentDescription, &m_MixerNode);
    AUGraphAddNode(m_Graph, &kOutputComponentDescription, &m_OutputNode);
    AUGraphConnectNodeInput(m_Graph, m_MixerNode, kMixerBusInput, m_OutputNode, kOutputBusOutput);
    AUGraphOpen(m_Graph);
    AUGraphNodeInfo(m_Graph, m_MixerNode, NULL, &m_MixerUnit);
    AUGraphNodeInfo(m_Graph, m_OutputNode, NULL, &m_OutputUnit);

    UInt32 elementCount = kMixerElementCount;
    AudioUnitSetProperty(m_MixerUnit, kAudioUnitProperty_ElementCount, kAudioUnitScope_Input,
                         kMixerBusInput, &elementCount, sizeof(elementCount));

    AudioStreamBasicDescription format;
    InitFloatPcmFormatDescriptor(&format, kSoundManagerSampleRate, kOutputChannelCount);
    AudioUnitSetProperty(m_OutputUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input,
                         kMixerBusInput, &format, sizeof(format));

    AUGraphUpdate(m_Graph, NULL);
    AUGraphInitialize(m_Graph);
    AUGraphStart(m_Graph);
    m_IsPlayGraph = YES;
    m_InitGraph = YES;
}

#pragma mark - Graph lifecycle

- (void)startSystem {
    /** @ghidraAddress 0x35380 */
    if (m_InitGraph && !m_IsPlayGraph) {
        AUGraphStart(m_Graph);
        m_IsPlayGraph = YES;
    }
}

- (void)stopSystem {
    /** @ghidraAddress 0x353d4 */
    if (m_InitGraph && m_IsPlayGraph) {
        AUGraphStop(m_Graph);
        m_IsPlayGraph = NO;
    }
}

#pragma mark - Asset pool

- (int)loadFile:(NSString *)fileName Stream:(BOOL)stream {
    /** @ghidraAddress 0x34eec */
    for (int slot = 0; slot < kSoundDataPoolCount; ++slot) {
        SoundData *data = m_SoundData[slot];
        if (data != nil && [data.fileName isEqualToString:fileName]) {
            return slot;
        }
    }
    for (int slot = 0; slot < kSoundDataPoolCount; ++slot) {
        if (m_SoundData[slot] == nil) {
            m_SoundData[slot] = [[SoundData alloc] initWithContentsFileName:fileName Stream:stream];
            return slot;
        }
    }
    return kInvalidSlot;
}

- (BOOL)releaseData:(int)index {
    /** @ghidraAddress 0x35038 */
    if (m_SoundData[index] != nil) {
        m_SoundData[index] = nil;
        return YES;
    }
    return NO;
}

#pragma mark - Playback

- (int)play:(int)index Loop:(BOOL)loop {
    /** @ghidraAddress 0x35074 */
    SoundData *data = m_SoundData[index];
    if (data != nil) {
        for (int voice = 0; voice < kSoundPlayerVoiceCount; ++voice) {
            SoundPlayer *player = m_SoundPlayer[voice];
            if (![player isPlaying]) {
                player.soundData = data;
                player.currentFrame = 0;
                [player play];
                [self setCallBack:voice DataFormat:data.format];
                return voice;
            }
        }
    }
    return kInvalidSlot;
}

- (BOOL)stop:(int)index {
    /** @ghidraAddress 0x35198 */
    SoundPlayer *player = m_SoundPlayer[index];
    if ([player isPlaying]) {
        [player stop];
    }
    return YES;
}

#pragma mark - Render callback

- (void)setCallBack:(int)element DataFormat:(AudioStreamBasicDescription *)format {
    /** @ghidraAddress 0x351f4 */
    AudioUnitSetProperty(m_MixerUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input,
                         element, format, sizeof(AudioStreamBasicDescription));
    AURenderCallbackStruct callback = {
        .inputProc = HandleSoundStreamCallback,
        .inputProcRefCon = (__bridge void *)self,
    };
    AudioUnitSetProperty(m_MixerUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input,
                         element, &callback, sizeof(callback));
}

- (void)unsetCallBack:(int)element {
    /** @ghidraAddress 0x3532c */
    AURenderCallbackStruct callback = {0};
    AudioUnitSetProperty(m_MixerUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input,
                         element, &callback, sizeof(callback));
}

- (SoundPlayer *)getSoundPlayer:(int)index {
    /** @ghidraAddress 0x3536c */
    return m_SoundPlayer[index];
}

@end
