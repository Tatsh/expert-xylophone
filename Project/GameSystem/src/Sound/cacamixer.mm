#include "cacamixer.h"

#include <cstring>

#include "casource.h"

/** @ghidraAddress 0x4b3e8 */
OSStatus RenderVoiceAudioCallback(void *pRefCon,
                                  AudioUnitRenderActionFlags *pActionFlags,
                                  const AudioTimeStamp *pTimeStamp,
                                  UInt32 nBusNumber,
                                  UInt32 nFrames,
                                  AudioBufferList *pData) {
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

constexpr int kVoiceGainLevelCount = 128;

// @ghidraAddress 0x2eef58
const float g_aVoiceGainTable[kVoiceGainLevelCount] = {
    -120.0f,  -42.076f, -36.055f, -32.534f, -30.035f, -28.097f, -26.513f, -25.174f, -24.014f,
    -22.991f, -22.076f, -21.248f, -20.492f, -19.797f, -19.154f, -18.554f, -17.994f, -17.467f,
    -16.971f, -16.501f, -16.055f, -15.632f, -15.228f, -14.842f, -14.472f, -14.117f, -13.777f,
    -13.449f, -13.133f, -12.828f, -12.534f, -12.249f, -11.973f, -11.706f, -11.446f, -11.195f,
    -10.95f,  -10.712f, -10.48f,  -10.255f, -10.035f, -9.82f,   -9.611f,  -9.407f,  -9.207f,
    -9.012f,  -8.821f,  -8.634f,  -8.451f,  -8.272f,  -8.097f,  -7.925f,  -7.756f,  -7.591f,
    -7.428f,  -7.269f,  -7.112f,  -6.959f,  -6.808f,  -6.659f,  -6.513f,  -6.369f,  -6.228f,
    -6.089f,  -5.952f,  -5.818f,  -5.685f,  -5.555f,  -5.426f,  -5.299f,  -5.174f,  -5.051f,
    -4.929f,  -4.81f,   -4.691f,  -4.575f,  -4.46f,   -4.346f,  -4.234f,  -4.124f,  -4.014f,
    -3.906f,  -3.8f,    -3.695f,  -3.59f,   -3.488f,  -3.386f,  -3.286f,  -3.186f,  -3.088f,
    -2.991f,  -2.895f,  -2.8f,    -2.706f,  -2.614f,  -2.522f,  -2.431f,  -2.341f,  -2.252f,
    -2.163f,  -2.076f,  -1.99f,   -1.904f,  -1.819f,  -1.735f,  -1.652f,  -1.57f,   -1.488f,
    -1.408f,  -1.328f,  -1.248f,  -1.17f,   -1.092f,  -1.015f,  -0.938f,  -0.862f,  -0.787f,
    -0.712f,  -0.638f,  -0.565f,  -0.492f,  -0.42f,   -0.349f,  -0.278f,  -0.208f,  -0.138f,
    -0.069f,  0.0f,
};

namespace {

constexpr int kClientBitsPerChannel = 16;
constexpr int kClientBytesPerChannel = kClientBitsPerChannel / 8;

constexpr AudioUnitParameterID kMixerGainParam = 3;
constexpr AudioUnitScope kMixerGainScope = kAudioUnitScope_Output;

// A play handle packs the voice generation in its low 16 bits and the bus index above.
constexpr int kHandleBusShift = 16;

constexpr unsigned int kInvalidHandle = 0xffffffff;

constexpr int kMaxVoiceCount = 0x1000;

constexpr int kDefaultMasterGainIndex = 0x7f;

// The binary stores the output format flags as the literal 0xc2c; it is used verbatim.
constexpr double kOutputSampleRate = 32000.0;
constexpr int kOutputBitsPerChannel = 16;
constexpr int kOutputChannels = 2;
constexpr int kOutputBytesPerFrame = 4;
constexpr UInt32 kOutputFormatFlags = 0xc2c;

constexpr AudioUnitPropertyID kElementCountProperty = kAudioUnitProperty_ElementCount;
constexpr AudioUnitParameterID kMixerGainParamReset = 3;

} // namespace

/** @ghidraAddress 0x4b084 */
unsigned int caCAMixer::EnqueueVoiceBuffer(caSource *pSource, int nBus, int nVolume) {
    caVoice *pVoice = m_pVoiceArray[nBus];
    if (pVoice->GetState() != caVoice::kStateFinished &&
        pVoice->GetState() != caVoice::kStateFree) {
        return kInvalidHandle;
    }
    pVoice->SetSource(pSource);
    const unsigned short nGeneration = pVoice->GetGeneration() + 1;
    pVoice->SetGeneration(nGeneration);

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
    pVoice->ResetReadCursors();
    pVoice->SetState(caVoice::kStatePrepared);
    return static_cast<unsigned int>(nGeneration) |
           static_cast<unsigned int>(nBus << kHandleBusShift);
}

/** @ghidraAddress 0x4b238 */
unsigned int caCAMixer::FindFreeVoiceAndEnqueue(caSource *pSource, int nVolume) {
    for (int nBus = 0; nBus < m_nVoiceCount; ++nBus) {
        const int nState = m_pVoiceArray[nBus]->GetState();
        if (nState == caVoice::kStateFree || nState == caVoice::kStateFinished) {
            return EnqueueVoiceBuffer(pSource, nBus, nVolume);
        }
    }
    return kInvalidHandle;
}

/** @ghidraAddress 0x4b3b0 */
void caCAMixer::ClearVoicesUsingBuffer(caSource *pSource) {
    for (int nBus = 0; nBus < m_nVoiceCount; ++nBus) {
        if (m_pVoiceArray[nBus]->GetSource() == pSource) {
            m_pVoiceArray[nBus]->SetSource(nullptr);
        }
    }
}

/** @ghidraAddress 0x4b174 */
void caCAMixer::InstallVoiceRenderCallback(int nBus) {
    if (nBus >= m_nVoiceCount) {
        return;
    }
    caVoice *pVoice = m_pVoiceArray[nBus];
    if (pVoice->IsCallbackBound()) {
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
        pVoice->SetCallbackBound(true);
    }
}

/** @ghidraAddress 0x4b1e8 */
bool caCAMixer::ApplyVoicePanParam(int nVolume, int nBus) {
    if (nBus >= m_nVoiceCount) {
        return false;
    }
    // Parameter 3 on the spatial mixer is the master gain, so the "pan" name is a misnomer.
    return AudioUnitSetParameter(
               m_pMixerUnit, kMixerGainParam, kMixerGainScope, 0, g_aVoiceGainTable[nVolume], 0) ==
           noErr;
}

caVoice *caCAMixer::ResolveVoice(unsigned int hVoice) {
    const int nBus = static_cast<int>(hVoice >> kHandleBusShift);
    if (nBus >= m_nVoiceCount) {
        return nullptr;
    }
    caVoice *pVoice = m_pVoiceArray[nBus];
    if (pVoice == nullptr || pVoice->GetGeneration() != (hVoice & 0xffff)) {
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
    if ((pVoice->GetState() | 2) != caVoice::kStatePaused) {
        return 0;
    }
    pVoice->SetState(caVoice::kStatePlaying);
    return 1;
}

/** @ghidraAddress 0x4b2e4 */
unsigned int caCAMixer::StopVoice(unsigned int hVoice) {
    caVoice *pVoice = ResolveVoice(hVoice);
    if (pVoice == nullptr) {
        return 0;
    }
    pVoice->SetState(caVoice::kStateFinished);
    return 1;
}

/** @ghidraAddress 0x4b32c */
unsigned int caCAMixer::PauseVoice(unsigned int hVoice) {
    caVoice *pVoice = ResolveVoice(hVoice);
    if (pVoice == nullptr) {
        return 0;
    }
    pVoice->SetState(caVoice::kStatePaused);
    return 1;
}

/** @ghidraAddress 0x4b374 */
int caCAMixer::GetVoiceState(unsigned int hVoice) {
    caVoice *pVoice = ResolveVoice(hVoice);
    return pVoice != nullptr ? pVoice->GetState() : -1;
}

/** @ghidraAddress 0x4b42c */
unsigned int caCAMixer::StopAndClearVoice(unsigned int hVoice) {
    caVoice *pVoice = ResolveVoice(hVoice);
    if (pVoice != nullptr) {
        pVoice->SetState(caVoice::kStateFinished);
        pVoice->SetSource(nullptr);
    }
    return 1;
}

/** @ghidraAddress 0x4acd0 */
bool caCAMixer::BuildAudioUnitGraph() {
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
    if (AUGraphConnectNodeInput(m_pAUGraph, m_nMixerNode, 0, m_nOutputNode, 0) != noErr) {
        return false;
    }
    if (AUGraphOpen(m_pAUGraph) != noErr ||
        AUGraphNodeInfo(m_pAUGraph, m_nOutputNode, nullptr, &m_pOutputUnit) != noErr) {
        return false;
    }
    return AUGraphNodeInfo(m_pAUGraph, m_nMixerNode, nullptr, &m_pMixerUnit) == noErr;
}

/** @ghidraAddress 0x4ac94 */
bool caCAMixer::GraphSetup(int nVoiceCount) {
    return BuildAudioUnitGraph() && ConfigureAudioUnitGraph(nVoiceCount);
}

/** @ghidraAddress 0x4affc */
void caCAMixer::Terminate() {
    if (m_bIsRunning && AUGraphStop(m_pAUGraph) == noErr) {
        m_bIsRunning = false;
    }
    if (DisposeAUGraph(m_pAUGraph) != noErr) {
        return;
    }
    if (m_pVoiceArray == nullptr) {
        return;
    }
    for (int nBus = 0; nBus < m_nVoiceCount; ++nBus) {
        caVoice *pVoice = m_pVoiceArray[nBus];
        pVoice->SetSource(nullptr);
        delete pVoice;
    }
    delete[] m_pVoiceArray;
    m_pVoiceArray = nullptr;
}

/** @ghidraAddress 0x4adb4 */
bool caCAMixer::ConfigureAudioUnitGraph(int nVoiceCount) {
    if (nVoiceCount >= kMaxVoiceCount) {
        return false;
    }

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

    m_pVoiceArray = new caVoice *[nVoiceCount];
    for (int nBus = 0; nBus < nVoiceCount; ++nBus) {
        auto *pVoice = new caVoice();
        pVoice->SetSource(nullptr);
        pVoice->SetCallbackBound(false);
        pVoice->SetGeneration(0);
        pVoice->SetState(caVoice::kStateFree);
        m_pVoiceArray[nBus] = pVoice;
    }

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
    if (!m_bIsRunning) {
        if (AUGraphStart(m_pAUGraph) != noErr) {
            return;
        }
        m_bIsRunning = true;
    }
    ApplyVoicePanParam(kDefaultMasterGainIndex, 0);
}

/** @ghidraAddress 0x4afbc */
void caCAMixer::SetAllVolume(int nVolume) {
    ApplyVoicePanParam(nVolume, 0);
}

/** @ghidraAddress 0x4afc4 */
void caCAMixer::Stop() {
    if (m_bIsRunning && AUGraphStop(m_pAUGraph) == noErr) {
        m_bIsRunning = false;
    }
}
