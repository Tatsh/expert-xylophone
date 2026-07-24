//
//  caplayermgr.mm
//  REFLEC BEAT plus
//
//  The one-shot voice-player subsystem (the caplayer engine's caPlayerMgr). Reconstructed from
//  Ghidra project rb458, program rb458. @ghidraAddress values are relative to the program image
//  base.
//

#include "caplayermgr.h"

#include <cassert>

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

// The number of extra sound-array slots each grow reserves, and the initial slot count.
namespace {
constexpr int kSlotGrowStep = 20;
constexpr int kInitialSlotCount = 20;
} // namespace

/** @ghidraAddress 0x4b580 */
void caPlayerMgr::InitializeAudioContext(int channelCount) {
    // Build and start the mixer graph.
    m_pMixer = new caCAMixer();
    m_pMixer->GraphSetup(channelCount);
    m_pMixer->Start();
    // Create the call-name dictionary and the fixed-size sound-buffer slot array.
    m_pSourceDict = [[NSMutableDictionary alloc] init];
    m_nSourceCount = kInitialSlotCount;
    m_pSourceArray = new caSource *[kInitialSlotCount]();
}

/** @ghidraAddress 0x4b4a8 */
void caPlayerMgr::DestroyAudioContext() {
    // Tear down the mixer graph.
    if (m_pMixer != nullptr) {
        m_pMixer->Terminate();
        delete m_pMixer;
        m_pMixer = nullptr;
    }
    // Free every registered sound, re-reading the array and count after each delete to match the
    // binary's re-entrancy-safe loop, then free the slot array.
    for (int nSlot = 0; nSlot < m_nSourceCount; ++nSlot) {
        caSource *pSource = m_pSourceArray[nSlot];
        if (pSource != nullptr) {
            pSource->FreeBuffer();
            delete pSource;
            m_pSourceArray[nSlot] = nullptr;
        }
    }
    delete[] m_pSourceArray;
    m_pSourceArray = nullptr;
    // Drop the dictionary reference (ARC releases it).
    m_pSourceDict = nil;
}

/** @ghidraAddress 0x4b57c */
void caPlayerMgr::DestroyAudioContextWrapper() {
    DestroyAudioContext();
}

/** @ghidraAddress 0x4bbd4 */
unsigned int caPlayerMgr::FindOrGrowFreeSlot() {
    // Reuse the first empty slot if there is one.
    for (int nSlot = 0; nSlot < m_nSourceCount; ++nSlot) {
        if (m_pSourceArray[nSlot] == nullptr) {
            return static_cast<unsigned int>(nSlot);
        }
    }
    // Otherwise grow the array by a fixed step, copying the existing slots and zeroing the new ones,
    // and return the first new index.
    const int nOldCount = m_nSourceCount;
    const int nNewCount = nOldCount + kSlotGrowStep;
    m_nSourceCount = nNewCount;
    auto **pNewArray = new caSource *[nNewCount]();
    for (int nSlot = 0; nSlot < nOldCount; ++nSlot) {
        pNewArray[nSlot] = m_pSourceArray[nSlot];
    }
    delete[] m_pSourceArray;
    m_pSourceArray = pNewArray;
    return static_cast<unsigned int>(nOldCount);
}

/** @ghidraAddress 0x4b6c4 */
unsigned int caPlayerMgr::RegisterSource(caSource *pSource) {
    const unsigned int nSlot = FindOrGrowFreeSlot();
    m_pSourceArray[nSlot] = pSource;
    // The binary asserts the slot fits in 24 bits; a real free slot always does.
    assert((nSlot >> 24) == 0);
    return nSlot;
}

/** @ghidraAddress 0x4b62c */
int caPlayerMgr::CreateAndLoadSound(const char *szPath, bool bLoop) {
    if (szPath == nullptr) {
        return -1;
    }
    auto *pSource = new caSource();
    if (pSource->LoadFromPath(szPath, bLoop) != 0) {
        return static_cast<int>(RegisterSource(pSource));
    }
    delete pSource;
    return -1;
}

/** @ghidraAddress 0x4ba1c */
unsigned int caPlayerMgr::PlaySoundForKey(NSString *callName, int volume) {
    NSNumber *pId = m_pSourceDict[callName];
    if (pId == nil) {
        return kInvalidHandle;
    }
    return PlaySoundByIndex(pId.intValue, volume);
}

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

/** @ghidraAddress 0x4bac0 */
unsigned int caPlayerMgr::PlaySoundForKeyOnBus(NSString *callName, int busId, int volume) {
    NSNumber *pId = m_pSourceDict[callName];
    if (pId == nil) {
        return kInvalidHandle;
    }
    return PlaySoundOnVoice(pId.intValue, busId, volume);
}

/** @ghidraAddress 0x4b718 */
int caPlayerMgr::LoadAndCacheSoundForKey(const char *szPath, NSString *callName, bool bLoop) {
    // Skip work if the path is missing or the key is already cached.
    if (szPath == nullptr || m_pSourceDict[callName] != nil) {
        return 0;
    }
    auto *pSource = new caSource();
    if (pSource->LoadFromPath(szPath, bLoop) != 0) {
        const unsigned int nId = RegisterSource(pSource);
        m_pSourceDict[callName] = @(static_cast<int>(nId));
        return 1;
    }
    delete pSource;
    return 0;
}

/** @ghidraAddress 0x4b870 */
int caPlayerMgr::FreeSoundDataByIndex(int index) {
    if (index < 0 || index >= m_nSourceCount) {
        return 0;
    }
    caSource *pSource = m_pSourceArray[index];
    if (pSource == nullptr) {
        return 0;
    }
    // Detach the buffer from any active voice before releasing its PCM data.
    m_pMixer->ClearVoicesUsingBuffer(pSource);
    pSource->FreeBuffer();
    return 1;
}

/** @ghidraAddress 0x4b8cc */
int caPlayerMgr::FreeSoundForKey(NSString *callName) {
    NSNumber *pId = m_pSourceDict[callName];
    if (pId == nil) {
        return 0;
    }
    if (FreeSoundDataByIndex(pId.intValue) != 0) {
        [m_pSourceDict removeObjectForKey:callName];
        return 1;
    }
    return 0;
}

/** @ghidraAddress 0x4bbcc */
void caPlayerMgr::SetMasterVoiceParameter(int volume) {
    m_pMixer->SetAllVolume(volume);
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
