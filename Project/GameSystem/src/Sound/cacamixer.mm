//
//  cacamixer.mm
//  REFLEC BEAT plus
//
//  The Core Audio voice mixer (the caplayer engine's caCAMixer / CAComponent). Reconstructed from
//  Ghidra project rb458, program rb458. @ghidraAddress values are relative to the program image
//  base.
//

#include "cacamixer.h"

#include "casound.h"

// The per-voice render callback the mixer installs; the render loop calls it to pull PCM for a
// voice. Defined elsewhere in the caplayer engine (@ghidraAddress 0x4b2xx).
OSStatus RenderVoiceAudioCallback(void *pRefCon,
                                  AudioUnitRenderActionFlags *pActionFlags,
                                  const AudioTimeStamp *pTimeStamp,
                                  UInt32 nBusNumber,
                                  UInt32 nFrames,
                                  AudioBufferList *pData);

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
    pVoice->m_dwBytesRead = 0;
    pVoice->m_dwReadPos = 0;
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
