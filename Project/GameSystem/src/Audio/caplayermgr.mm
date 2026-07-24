//
//  caplayermgr.mm
//  REFLEC BEAT plus
//
//  The one-shot voice-player subsystem (the caplayer engine's caPlayerMgr). Reconstructed from
//  Ghidra project rb458, program rb458. @ghidraAddress values are relative to the program image
//  base.
//

#include "caplayermgr.h"

#include "cacamixer.h"
#include "casound.h"

namespace {

// The source-category tag OR'd into every play handle returned from this one-shot entry point, so
// callers can tell which subsystem produced the handle.
constexpr unsigned int kOneShotSourceTag = 0x20000000;

// The mask isolating the raw voice handle (index<<16 | generation) from the tagged handle.
constexpr unsigned int kHandleMask = 0x0fffffff;

// The sentinel returned when the sound index is out of range or unregistered.
constexpr unsigned int kInvalidHandle = 0xffffffff;

// Strips the one-shot source tag from a play handle, yielding the raw mixer handle, or the invalid
// sentinel when the tag is absent (so the mixer's index/generation check rejects it).
unsigned int DecodeVoiceHandle(unsigned int hTagged) {
    return (hTagged & kOneShotSourceTag) != 0 ? (hTagged & kHandleMask) : kInvalidHandle;
}

} // namespace

/** @ghidraAddress 0x4b998 */
unsigned int caPlayerMgr::PlaySoundByIndex(int index, int volume) {
    if (index >= m_nSourceCount || m_pSourceArray[index] == nullptr) {
        return kInvalidHandle;
    }
    return m_pMixer->FindFreeVoiceAndEnqueue(m_pSourceArray[index], volume) | kOneShotSourceTag;
}

/** @ghidraAddress 0x4b9d4 */
unsigned int caPlayerMgr::PlaySoundOnVoice(int resourceId, int busId, int volume) {
    if (resourceId < 0 || resourceId >= m_nSourceCount) {
        return kInvalidHandle;
    }
    caSource *pSource = m_pSourceArray[resourceId];
    if (pSource == nullptr) {
        return kInvalidHandle;
    }
    return m_pMixer->EnqueueVoiceBuffer(pSource, busId, volume) | kOneShotSourceTag;
}

/** @ghidraAddress 0x4b61c */
void caPlayerMgr::StartAudioGraph() {
    if (m_pMixer != nullptr) {
        m_pMixer->Start();
    }
}

/** @ghidraAddress 0x4b60c */
void caPlayerMgr::StopAudioGraph() {
    if (m_pMixer != nullptr) {
        m_pMixer->Stop();
    }
}

/** @ghidraAddress 0x4bb6c */
void caPlayerMgr::ResumeVoiceByHandle(unsigned int handle) {
    m_pMixer->StartVoice(DecodeVoiceHandle(handle));
}

/** @ghidraAddress 0x4bb9c */
void caPlayerMgr::PauseVoiceByHandle(unsigned int handle) {
    m_pMixer->PauseVoice(DecodeVoiceHandle(handle));
}

/** @ghidraAddress 0x4bb84 */
void caPlayerMgr::StopVoiceByHandle(unsigned int handle) {
    m_pMixer->StopVoice(DecodeVoiceHandle(handle));
}

/** @ghidraAddress 0x4bcac */
void caPlayerMgr::ReleaseVoiceByHandle(unsigned int handle) {
    m_pMixer->StopAndClearVoice(DecodeVoiceHandle(handle));
}

/** @ghidraAddress 0x4bbb4 */
int caPlayerMgr::GetVoiceStateByHandle(unsigned int handle) {
    return m_pMixer->GetVoiceState(DecodeVoiceHandle(handle));
}
