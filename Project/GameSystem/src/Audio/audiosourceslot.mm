//
//  audiosourceslot.mm
//  REFLEC BEAT plus
//
//  The AVFoundation sound-effect source manager (AudioSourceSlot). Reconstructed from Ghidra
//  project rb458, program rb458. @ghidraAddress values are relative to the program image base.
//

#include "audiosourceslot.h"

#include <cstring>

#import "avsemixer.h"

namespace {
// The source array is grown by this many slots when it is full; the manager starts with this many.
constexpr int kSourceSlotGrowStep = 20;
// A play handle carries a validity flag; when it is clear the handle resolves to no bus.
constexpr unsigned int kPlayHandleValidBit = 0x10000000;
constexpr unsigned int kPlayHandleBusMask = 0x0fffffff;

// Decodes an external play handle into the mixer's bus handle, or 0xffffffff when it is invalid.
unsigned int DecodePlayHandle(unsigned int handle) {
    return (handle & kPlayHandleValidBit) != 0 ? (handle & kPlayHandleBusMask) : 0xffffffff;
}
} // namespace

/** @ghidraAddress 0x4abcc */
int AudioSourceSlot::SourceRecord::Initialize(id sourceObject, bool bLoopValue) {
    source = [sourceObject copy];
    bLoop = bLoopValue;
    return 1;
}

/** @ghidraAddress 0x4ab8c */
int AudioSourceSlot::SourceRecord::Clear() {
    source = nil;
    companion = nil;
    return 1;
}

/** @ghidraAddress 0x4a5d4 */
void AudioSourceSlot::InitAudioSourceSlot() {
    m_pMixer = nullptr;
    m_pKeyMap = nil;
    m_pSourceArray = nullptr;
    m_nSourceCount = -1;
}

/** @ghidraAddress 0x4a5e8 */
void AudioSourceSlot::InitializeSourceManager(int nVoiceCount) {
    m_pMixer = new AVSeMixer;
    m_pMixer->InitializeBusArray(nVoiceCount);
    m_pKeyMap = [[NSMutableDictionary alloc] init];
    m_nSourceCount = kSourceSlotGrowStep;
    m_pSourceArray = new SourceRecord *[kSourceSlotGrowStep];
    std::memset(m_pSourceArray, 0, kSourceSlotGrowStep * sizeof(SourceRecord *));
}

/** @ghidraAddress 0x4aa9c */
int AudioSourceSlot::FindFreeSlotIndex() {
    for (int nIndex = 0; nIndex < m_nSourceCount; ++nIndex) {
        if (m_pSourceArray[nIndex] == nullptr) {
            return nIndex;
        }
    }
    // No free slot: grow the array by a fixed step, zeroing the new tail, and return the first new
    // index.
    const int nOldCount = m_nSourceCount;
    m_nSourceCount = nOldCount + kSourceSlotGrowStep;
    auto **pGrown = new SourceRecord *[m_nSourceCount];
    std::memcpy(pGrown, m_pSourceArray, nOldCount * sizeof(SourceRecord *));
    std::memset(pGrown + nOldCount, 0, (m_nSourceCount - nOldCount) * sizeof(SourceRecord *));
    delete[] m_pSourceArray;
    m_pSourceArray = pGrown;
    return nOldCount;
}

/** @ghidraAddress 0x4a690 */
unsigned int AudioSourceSlot::AddSource(id source, bool bLoop) {
    if (source == nil) {
        return 0xffffffff;
    }
    auto *pRecord = new SourceRecord;
    pRecord->Initialize(source, bLoop);
    const int nIndex = FindFreeSlotIndex();
    m_pSourceArray[nIndex] = pRecord;
    return static_cast<unsigned int>(nIndex);
}

/** @ghidraAddress 0x4a728 */
int AudioSourceSlot::RegisterSourceForKey(id source, NSString *callName, bool bLoop) {
    // Only register when the source is present and the call name is not already mapped.
    if (source == nil || m_pKeyMap[callName] != nil) {
        return 0;
    }
    const unsigned int nIndex = AddSource(source, bLoop);
    m_pKeyMap[callName] = @(nIndex);
    return 1;
}

/** @ghidraAddress 0x4a870 */
int AudioSourceSlot::RemoveSourceByIndex(int index) {
    if (index >= m_nSourceCount) {
        return 0;
    }
    SourceRecord *pRecord = m_pSourceArray[index];
    if (pRecord == nullptr) {
        return 0;
    }
    // Detach the record from any voice still playing it, then release its object references.
    m_pMixer->RemoveSourceFromBuses(pRecord);
    pRecord->Clear();
    return 1;
}

/** @ghidraAddress 0x4a8c0 */
int AudioSourceSlot::RemoveSourceByKey(NSString *callName) {
    NSNumber *pIndex = m_pKeyMap[callName];
    if (pIndex == nil) {
        return 0;
    }
    return RemoveSourceByIndex(pIndex.intValue);
}

/** @ghidraAddress 0x4a954 */
unsigned int AudioSourceSlot::AcquireBusForSourceIndex(int index) {
    if (index >= m_nSourceCount || m_pSourceArray[index] == nullptr) {
        return 0xffffffff;
    }
    // The mixer keys a voice by the record itself; tag the returned handle valid.
    return m_pMixer->AcquireBusForSource(m_pSourceArray[index], 0) | kPlayHandleValidBit;
}

/** @ghidraAddress 0x4a990 */
unsigned int AudioSourceSlot::AcquireBusForSourceKey(NSString *callName, int volume) {
    NSNumber *pIndex = m_pKeyMap[callName];
    if (pIndex == nil) {
        return 0xffffffff;
    }
    return AcquireBusForSourceIndex(pIndex.intValue);
}

/** @ghidraAddress 0x4aa34 */
bool AudioSourceSlot::PlayByHandle(unsigned int handle) {
    return m_pMixer->PlayBusByHandle(DecodePlayHandle(handle));
}

/** @ghidraAddress 0x4aa4c */
bool AudioSourceSlot::StopByHandle(unsigned int handle) {
    return m_pMixer->StopBusByHandle(DecodePlayHandle(handle));
}

/** @ghidraAddress 0x4aa64 */
bool AudioSourceSlot::PauseByHandle(unsigned int handle) {
    return m_pMixer->PauseBusByHandle(DecodePlayHandle(handle));
}

/** @ghidraAddress 0x4aa7c */
int AudioSourceSlot::GetStatusByHandle(unsigned int handle) {
    return m_pMixer->GetBusStatusByHandle(DecodePlayHandle(handle));
}

/** @ghidraAddress 0x4ab74 */
void AudioSourceSlot::StopAndClearByHandle(unsigned int handle) {
    m_pMixer->StopAndClearBusByHandle(DecodePlayHandle(handle));
}

/** @ghidraAddress 0x4a670 */
void AudioSourceSlot::PauseAllBuses() {
    if (m_pMixer != nullptr) {
        m_pMixer->SuspendAllBuses();
    }
}

/** @ghidraAddress 0x4a680 */
void AudioSourceSlot::ResumeAllBuses() {
    if (m_pMixer != nullptr) {
        m_pMixer->ResumeAllBuses();
    }
}

/** @ghidraAddress 0x4aa94 */
void AudioSourceSlot::SetAllVolume(int volume) {
    m_pMixer->SetAllBusVolume(volume);
}
