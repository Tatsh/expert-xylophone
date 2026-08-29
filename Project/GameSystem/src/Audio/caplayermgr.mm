#include "caplayermgr.h"

#include <cassert>

#include "cacamixer.h"
#include "casource.h"

namespace {

constexpr unsigned int kOneShotSourceTag = 0x20000000;

// The raw voice handle is index << 16 | generation.
constexpr unsigned int kHandleMask = 0x0fffffff;

constexpr unsigned int kInvalidHandle = 0xffffffff;

unsigned int DecodeVoiceHandle(unsigned int hTagged) {
    return (hTagged & kOneShotSourceTag) != 0 ? (hTagged & kHandleMask) : kInvalidHandle;
}

} // namespace

namespace {
constexpr int kSlotGrowStep = 20;
constexpr int kInitialSlotCount = 20;
} // namespace

/** @ghidraAddress 0x4b580 */
void caPlayerMgr::InitializeAudioContext(int channelCount) {
    m_pMixer = new caCAMixer();
    m_pMixer->GraphSetup(channelCount);
    m_pMixer->Start();
    m_pSourceDict = [[NSMutableDictionary alloc] init];
    m_nSourceCount = kInitialSlotCount;
    m_pSourceArray = new caSource *[kInitialSlotCount]();
}

/** @ghidraAddress 0x4b4a8 */
void caPlayerMgr::DestroyAudioContext() {
    if (m_pMixer != nullptr) {
        m_pMixer->Terminate();
        delete m_pMixer;
        m_pMixer = nullptr;
    }
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
    m_pSourceDict = nil;
}

/** @ghidraAddress 0x4b57c */
void caPlayerMgr::DestroyAudioContextWrapper() {
    DestroyAudioContext();
}

/** @ghidraAddress 0x4b468 */
caPlayerMgr::~caPlayerMgr() {
    DestroyAudioContext();
}

/** @ghidraAddress 0x4bbd4 */
unsigned int caPlayerMgr::FindOrGrowFreeSlot() {
    for (int nSlot = 0; nSlot < m_nSourceCount; ++nSlot) {
        if (m_pSourceArray[nSlot] == nullptr) {
            return static_cast<unsigned int>(nSlot);
        }
    }
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
bool caPlayerMgr::ResumeVoiceByHandle(unsigned int handle) {
    return m_pMixer->StartVoice(DecodeVoiceHandle(handle)) != 0;
}

/** @ghidraAddress 0x4bb9c */
bool caPlayerMgr::PauseVoiceByHandle(unsigned int handle) {
    return m_pMixer->PauseVoice(DecodeVoiceHandle(handle)) != 0;
}

/** @ghidraAddress 0x4bb84 */
bool caPlayerMgr::StopVoiceByHandle(unsigned int handle) {
    return m_pMixer->StopVoice(DecodeVoiceHandle(handle)) != 0;
}

/** @ghidraAddress 0x4bcac */
void caPlayerMgr::ReleaseVoiceByHandle(unsigned int handle) {
    m_pMixer->StopAndClearVoice(DecodeVoiceHandle(handle));
}

/** @ghidraAddress 0x4bbb4 */
int caPlayerMgr::GetVoiceStateByHandle(unsigned int handle) {
    return m_pMixer->GetVoiceState(DecodeVoiceHandle(handle));
}
