//
//  cacamixer.mm
//  REFLEC BEAT plus
//
//  The Core Audio voice mixer (the caplayer engine's caCAMixer / CAComponent). Reconstructed from
//  Ghidra project rb458, program rb458. @ghidraAddress values are relative to the program image
//  base.
//

#include "cacamixer.h"

#include <cstring>

#include "casound.h"

/** @ghidraAddress 0x4b3e8 */
OSStatus RenderVoiceAudioCallback(void *pRefCon,
                                  AudioUnitRenderActionFlags *pActionFlags,
                                  const AudioTimeStamp *pTimeStamp,
                                  UInt32 nBusNumber,
                                  UInt32 nFrames,
                                  AudioBufferList *pData) {
    // The AURenderCallback wired onto each mixer input. The action flags, timestamp, bus, and frame
    // count are unused: the voice pointer arrives as the reference, and it fills the single output
    // buffer directly.
    (void)pActionFlags;
    (void)pTimeStamp;
    (void)nBusNumber;
    (void)nFrames;
    auto *pVoice = static_cast<caVoice *>(pRefCon);
    if (pVoice != nullptr) {
        AudioBuffer &buffer = pData->mBuffers[0];
        std::memset(buffer.mData, 0, buffer.mDataByteSize);
        pVoice->FillPcm(buffer.mData, static_cast<int>(buffer.mDataByteSize));
    }
    return noErr;
}

// The mixer's decibel-gain lookup table, indexed by the engine volume level. Seeded in the engine
// data segment.
// @ghidraAddress 0x2eef58
extern const float g_aVoiceGainTable[];

namespace {

// The client PCM format the mixer plays: 16-bit signed packed linear PCM, one frame per packet.
constexpr int kClientBitsPerChannel = 16;
constexpr int kClientBytesPerChannel = kClientBitsPerChannel / 8;

// The spatial-mixer gain parameter (k3DMixerParam_Gain) and its output scope, and the render-
// callback property; the mixer's stream-format property is set on the input scope.
constexpr AudioUnitParameterID kMixerGainParam = 3;
constexpr AudioUnitScope kMixerGainScope = kAudioUnitScope_Output;

// The play handle packs the voice generation in its low 16 bits and the bus index above.
constexpr int kHandleBusShift = 16;

// The failure sentinel returned when a voice cannot be bound.
constexpr unsigned int kInvalidHandle = 0xffffffff;

// The largest mixer bus count the graph configuration accepts.
constexpr int kMaxVoiceCount = 0x1000;

// The gain-table index applied as the default master gain when the graph starts (full volume).
constexpr int kDefaultMasterGainIndex = 0x7f;

// The output stream format: 32 kHz stereo 16-bit linear PCM. The binary stores the format flags as
// the literal 0xc2c (signed integer | packed | non-interleaved, with the sample-fraction field the
// 3D mixer's RemoteIO input expects); it is used verbatim.
constexpr double kOutputSampleRate = 32000.0;
constexpr int kOutputBitsPerChannel = 16;
constexpr int kOutputChannels = 2;
constexpr int kOutputBytesPerFrame = 4;
constexpr UInt32 kOutputFormatFlags = 0xc2c;

// The per-voice element-count and stream-format AudioUnit properties, and the spatial-mixer gain
// parameter reset to zero during configuration.
constexpr AudioUnitPropertyID kElementCountProperty = kAudioUnitProperty_ElementCount;
constexpr AudioUnitParameterID kMixerGainParamReset = 3;

} // namespace

/** @ghidraAddress 0x4b084 */
unsigned int caCAMixer::EnqueueVoiceBuffer(caSource *pSource, int nBus, int nVolume) {
    caVoice *pVoice = m_pVoiceArray[nBus];
    // Reuse the voice only when it is free or has finished playing.
    if (pVoice->m_nState != caVoice::kStateFinished && pVoice->m_nState != caVoice::kStateFree) {
        return kInvalidHandle;
    }
    pVoice->m_pSource = pSource;
    const unsigned short nGeneration = pVoice->m_wGeneration + 1;
    pVoice->m_wGeneration = nGeneration;

    // Build the signed-16-bit LPCM stream format from the source's rate and channel count.
    AudioStreamBasicDescription asbd = {};
    asbd.mSampleRate = pSource->GetSampleRate();
    asbd.mFormatID = kAudioFormatLinearPCM;
    asbd.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
    asbd.mBitsPerChannel = kClientBitsPerChannel;
    asbd.mChannelsPerFrame = static_cast<UInt32>(pSource->GetChannelCount());
    asbd.mBytesPerPacket = asbd.mChannelsPerFrame * kClientBytesPerChannel;
    asbd.mFramesPerPacket = 1;
    asbd.mBytesPerFrame = asbd.mBytesPerPacket;
    if (AudioUnitSetProperty(m_pMixerUnit,
                             kAudioUnitProperty_StreamFormat,
                             kAudioUnitScope_Input,
                             nBus,
                             &asbd,
                             sizeof(asbd)) != noErr) {
        return kInvalidHandle;
    }

    InstallVoiceRenderCallback(nBus);
    ApplyVoicePanParam(nVolume, nBus);
    pVoice->m_nBytesRead = 0;
    pVoice->m_nReadPos = 0;
    pVoice->m_nState = caVoice::kStatePrepared;
    return static_cast<unsigned int>(nGeneration) |
           static_cast<unsigned int>(nBus << kHandleBusShift);
}

/** @ghidraAddress 0x4b238 */
unsigned int caCAMixer::FindFreeVoiceAndEnqueue(caSource *pSource, int nVolume) {
    // Bind the sound to the first voice that is free or has finished playing.
    for (int nBus = 0; nBus < m_nVoiceCount; ++nBus) {
        const int nState = m_pVoiceArray[nBus]->m_nState;
        if (nState == caVoice::kStateFree || nState == caVoice::kStateFinished) {
            return EnqueueVoiceBuffer(pSource, nBus, nVolume);
        }
    }
    return kInvalidHandle;
}

/** @ghidraAddress 0x4b174 */
void caCAMixer::InstallVoiceRenderCallback(int nBus) {
    if (nBus >= m_nVoiceCount) {
        return;
    }
    caVoice *pVoice = m_pVoiceArray[nBus];
    if (pVoice->m_bCallbackBound) {
        return;
    }
    AURenderCallbackStruct callback = {};
    callback.inputProc = RenderVoiceAudioCallback;
    callback.inputProcRefCon = pVoice;
    if (AudioUnitSetProperty(m_pMixerUnit,
                             kAudioUnitProperty_SetRenderCallback,
                             kAudioUnitScope_Input,
                             nBus,
                             &callback,
                             sizeof(callback)) == noErr) {
        pVoice->m_bCallbackBound = true;
    }
}

/** @ghidraAddress 0x4b1e8 */
bool caCAMixer::ApplyVoicePanParam(int nVolume, int nBus) {
    if (nBus >= m_nVoiceCount) {
        return false;
    }
    // Parameter 3 on the spatial mixer is the master gain (the "pan" name is a misnomer).
    return AudioUnitSetParameter(
               m_pMixerUnit, kMixerGainParam, kMixerGainScope, 0, g_aVoiceGainTable[nVolume], 0) ==
           noErr;
}

// Resolves a raw play handle to its live voice, or nullptr when the index is out of range or the
// generation does not match (a stale handle). The voice index is the handle's high bits and the
// generation is its low 16 bits.
caVoice *caCAMixer::ResolveVoice(unsigned int hVoice) {
    const int nBus = static_cast<int>(hVoice >> kHandleBusShift);
    if (nBus >= m_nVoiceCount) {
        return nullptr;
    }
    caVoice *pVoice = m_pVoiceArray[nBus];
    if (pVoice == nullptr || pVoice->m_wGeneration != (hVoice & 0xffff)) {
        return nullptr;
    }
    return pVoice;
}

/** @ghidraAddress 0x4b28c */
unsigned int caCAMixer::StartVoice(unsigned int hVoice) {
    caVoice *pVoice = ResolveVoice(hVoice);
    if (pVoice == nullptr) {
        return 0;
    }
    // Only a prepared (1) or paused (3) voice may start; both satisfy (state | 2) == 3.
    if ((pVoice->m_nState | 2) != caVoice::kStatePaused) {
        return 0;
    }
    pVoice->m_nState = caVoice::kStatePlaying;
    return 1;
}

/** @ghidraAddress 0x4b2e4 */
unsigned int caCAMixer::StopVoice(unsigned int hVoice) {
    caVoice *pVoice = ResolveVoice(hVoice);
    if (pVoice == nullptr) {
        return 0;
    }
    pVoice->m_nState = caVoice::kStateFinished;
    return 1;
}

/** @ghidraAddress 0x4b32c */
unsigned int caCAMixer::PauseVoice(unsigned int hVoice) {
    caVoice *pVoice = ResolveVoice(hVoice);
    if (pVoice == nullptr) {
        return 0;
    }
    pVoice->m_nState = caVoice::kStatePaused;
    return 1;
}

/** @ghidraAddress 0x4b374 */
int caCAMixer::GetVoiceState(unsigned int hVoice) {
    caVoice *pVoice = ResolveVoice(hVoice);
    return pVoice != nullptr ? pVoice->m_nState : -1;
}

/** @ghidraAddress 0x4b42c */
unsigned int caCAMixer::StopAndClearVoice(unsigned int hVoice) {
    caVoice *pVoice = ResolveVoice(hVoice);
    if (pVoice != nullptr) {
        pVoice->m_nState = caVoice::kStateFinished;
        pVoice->m_pSource = nullptr;
    }
    return 1;
}

/** @ghidraAddress 0x4acd0 */
bool caCAMixer::BuildAudioUnitGraph() {
    // The RemoteIO output unit and the embedded 3D spatial mixer, both Apple components.
    AudioComponentDescription outputDesc = {};
    outputDesc.componentType = kAudioUnitType_Output;
    outputDesc.componentSubType = kAudioUnitSubType_RemoteIO;
    outputDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    AudioComponentDescription mixerDesc = {};
    mixerDesc.componentType = kAudioUnitType_Mixer;
    mixerDesc.componentSubType = kAudioUnitSubType_AU3DMixerEmbedded;
    mixerDesc.componentManufacturer = kAudioUnitManufacturer_Apple;

    if (NewAUGraph(&m_pAUGraph) != noErr) {
        return false;
    }
    if (AUGraphAddNode(m_pAUGraph, &outputDesc, &m_nOutputNode) != noErr ||
        AUGraphAddNode(m_pAUGraph, &mixerDesc, &m_nMixerNode) != noErr) {
        return false;
    }
    // Route the mixer output into the output unit's input, then open the graph and fetch the units.
    if (AUGraphConnectNodeInput(m_pAUGraph, m_nMixerNode, 0, m_nOutputNode, 0) != noErr) {
        return false;
    }
    if (AUGraphOpen(m_pAUGraph) != noErr ||
        AUGraphNodeInfo(m_pAUGraph, m_nOutputNode, nullptr, &m_pOutputUnit) != noErr) {
        return false;
    }
    return AUGraphNodeInfo(m_pAUGraph, m_nMixerNode, nullptr, &m_pMixerUnit) == noErr;
}

/** @ghidraAddress 0x4adb4 */
bool caCAMixer::ConfigureAudioUnitGraph(int nVoiceCount) {
    if (nVoiceCount >= kMaxVoiceCount) {
        return false;
    }

    // Size the mixer's input element (bus) count.
    UInt32 nElementCount = static_cast<UInt32>(nVoiceCount);
    if (AudioUnitSetProperty(m_pMixerUnit,
                             kElementCountProperty,
                             kAudioUnitScope_Input,
                             0,
                             &nElementCount,
                             sizeof(nElementCount)) != noErr) {
        m_nVoiceCount = 0;
        return false;
    }
    m_nVoiceCount = nVoiceCount;

    // Allocate the per-bus voice slots, each starting free with no source.
    m_pVoiceArray = new caVoice *[nVoiceCount];
    for (int nBus = 0; nBus < nVoiceCount; ++nBus) {
        auto *pVoice = new caVoice();
        pVoice->m_pSource = nullptr;
        pVoice->m_bCallbackBound = false;
        pVoice->m_wGeneration = 0;
        pVoice->m_nState = caVoice::kStateFree;
        m_pVoiceArray[nBus] = pVoice;
    }

    // Set the RemoteIO output format to 32 kHz stereo 16-bit LPCM.
    AudioStreamBasicDescription outputAsbd = {};
    outputAsbd.mSampleRate = kOutputSampleRate;
    outputAsbd.mFormatID = kAudioFormatLinearPCM;
    outputAsbd.mFormatFlags = kOutputFormatFlags;
    outputAsbd.mBytesPerPacket = kOutputBytesPerFrame;
    outputAsbd.mFramesPerPacket = 1;
    outputAsbd.mBytesPerFrame = kOutputBytesPerFrame;
    outputAsbd.mChannelsPerFrame = kOutputChannels;
    outputAsbd.mBitsPerChannel = kOutputBitsPerChannel;
    if (AudioUnitSetProperty(m_pOutputUnit,
                             kAudioUnitProperty_StreamFormat,
                             kAudioUnitScope_Input,
                             0,
                             &outputAsbd,
                             sizeof(outputAsbd)) != noErr) {
        return false;
    }

    // Reset the spatial-mixer master gain, then update and initialise the graph.
    if (AudioUnitSetParameter(
            m_pMixerUnit, kMixerGainParamReset, kAudioUnitScope_Output, 0, 0, 0) != noErr) {
        return false;
    }
    if (AUGraphUpdate(m_pAUGraph, nullptr) != noErr || AUGraphInitialize(m_pAUGraph) != noErr) {
        return false;
    }
    return AUGraphUpdate(m_pAUGraph, nullptr) == noErr;
}

/** @ghidraAddress 0x4af6c */
void caCAMixer::Start() {
    // Start the graph once; then (re)apply the default master gain regardless.
    if (!m_bIsRunning) {
        if (AUGraphStart(m_pAUGraph) != noErr) {
            return;
        }
        m_bIsRunning = true;
    }
    ApplyVoicePanParam(kDefaultMasterGainIndex, 0);
}

/** @ghidraAddress 0x4afc4 */
void caCAMixer::Stop() {
    if (m_bIsRunning && AUGraphStop(m_pAUGraph) == noErr) {
        m_bIsRunning = false;
    }
}

/** @ghidraAddress 0x4ac40 */
unsigned long caVoice::FillPcm(void *pDst, int nCount) {
    // Only a playing voice with a bound source produces samples.
    if (m_pSource == nullptr || m_nState != kStatePlaying) {
        return 0;
    }
    // Pull the next span from the source's ring buffer through this voice's own read cursors; a
    // zero-byte read means the source has drained, so the voice is marked finished.
    const int nRead = m_pSource->ReadRingBuffer(pDst, nCount, &m_nBytesRead, &m_nReadPos);
    if (nRead == 0) {
        m_nState = kStateFinished;
        return 0;
    }
    return static_cast<unsigned long>(nRead);
}
