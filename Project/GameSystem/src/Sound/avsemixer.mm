#include "avsemixer.h"

#import "AVBus.h"

namespace {
constexpr unsigned int kBusHandleIdMask = 0xffff;
constexpr int kBusHandleIndexShift = 16;
// Volumes arrive as an integer 0..127 and the voices take a 0..1 gain.
constexpr float kVolumeScale = 127.0f;
constexpr int kBusStatusPlaying = AVBusStatusPlaying;
} // namespace

/** @ghidraAddress 0x47c7c */
void AVSeMixer::InitializeBusArray(int nVoiceCount) {
    m_pBuses = [[NSMutableArray alloc] init];
    m_nVoiceCount = nVoiceCount;
    for (int nVoice = 0; nVoice < m_nVoiceCount; ++nVoice) {
        [m_pBuses addObject:[[AVBus alloc] init]];
    }
}

/** @ghidraAddress 0x4836c */
bool AVSeMixer::IsBusFree(int nIndex) {
    return static_cast<int>([m_pBuses[nIndex] status]) != kBusStatusPlaying;
}

/** @ghidraAddress 0x47f88 */
int AVSeMixer::FindFreeBusIndex() {
    for (int nIndex = 0; nIndex < m_nVoiceCount; ++nIndex) {
        if (IsBusFree(nIndex)) {
            return nIndex;
        }
    }
    return -1;
}

/** @ghidraAddress 0x480c0 */
AVBus *AVSeMixer::BusForHandle(unsigned int dwHandle) {
    const int nIndex = static_cast<int>((dwHandle >> kBusHandleIndexShift) & kBusHandleIdMask);
    if (nIndex >= m_nVoiceCount) {
        return nil;
    }
    AVBus *pBus = m_pBuses[nIndex];
    if ([pBus currentID] != (dwHandle & kBusHandleIdMask)) {
        return nil;
    }
    return pBus;
}

/** @ghidraAddress 0x47eb4 */
unsigned int AVSeMixer::AcquireBusForSource(AudioSourceSlot::SourceRecord *pSource,
                                            unsigned int nVolume) {
    const int nIndex = FindFreeBusIndex();
    if (nIndex == -1) {
        return 0xffffffff;
    }
    AVBus *pBus = m_pBuses[nIndex];
    [pBus removeSource];
    const unsigned int dwCurrentId = [pBus setSource:pSource];
    [pBus prepare];
    const unsigned int dwHandle =
        (dwCurrentId & kBusHandleIdMask) | (nIndex << kBusHandleIndexShift);
    SetBusVolumeByHandle(dwHandle, static_cast<int>(nVolume));
    return dwHandle;
}

/** @ghidraAddress 0x483d8 */
void AVSeMixer::RemoveSourceFromBuses(AudioSourceSlot::SourceRecord *pSource) {
    for (int nIndex = 0; nIndex < m_nVoiceCount; ++nIndex) {
        AVBus *pBus = m_pBuses[nIndex];
        if ([pBus isSameSource:pSource]) {
            [pBus removeSource];
        }
    }
}

/** @ghidraAddress 0x48058 */
bool AVSeMixer::PlayBusByHandle(unsigned int dwHandle) {
    AVBus *pBus = BusForHandle(dwHandle);
    if (pBus != nil) {
        [pBus play];
    }
    return pBus != nil;
}

/** @ghidraAddress 0x48158 */
bool AVSeMixer::StopBusByHandle(unsigned int dwHandle) {
    AVBus *pBus = BusForHandle(dwHandle);
    if (pBus != nil) {
        [pBus stop];
    }
    return pBus != nil;
}

/** @ghidraAddress 0x481c0 */
bool AVSeMixer::PauseBusByHandle(unsigned int dwHandle) {
    AVBus *pBus = BusForHandle(dwHandle);
    if (pBus != nil) {
        [pBus pause];
    }
    return pBus != nil;
}

/** @ghidraAddress 0x4849c */
void AVSeMixer::StopAndClearBusByHandle(unsigned int dwHandle) {
    AVBus *pBus = BusForHandle(dwHandle);
    if (pBus != nil) {
        [pBus stop];
        [pBus removeSource];
    }
}

/** @ghidraAddress 0x48228 */
int AVSeMixer::GetBusStatusByHandle(unsigned int dwHandle) {
    AVBus *pBus = BusForHandle(dwHandle);
    if (pBus == nil) {
        return -1;
    }
    return static_cast<int>([pBus status]);
}

/** @ghidraAddress 0x47fdc */
bool AVSeMixer::SetBusVolumeByHandle(unsigned int dwHandle, int nVolume) {
    AVBus *pBus = BusForHandle(dwHandle);
    if (pBus != nil) {
        [pBus setVolume:static_cast<float>(nVolume) / kVolumeScale];
    }
    return pBus != nil;
}

/** @ghidraAddress 0x47d5c */
void AVSeMixer::SuspendAllBuses() {
    // The binary pauses a freshly allocated throwaway AVBus each iteration, not the pooled voices.
    for (int nVoice = 0; nVoice < m_nVoiceCount; ++nVoice) {
        AVBus *pBus = [[AVBus alloc] init];
        [pBus pause];
    }
}

/** @ghidraAddress 0x47e08 */
void AVSeMixer::ResumeAllBuses() {
    // As in SuspendAllBuses, the binary un-pauses a throwaway AVBus, not the pooled voices.
    for (int nVoice = 0; nVoice < m_nVoiceCount; ++nVoice) {
        AVBus *pBus = [[AVBus alloc] init];
        [pBus offPause];
    }
}

/** @ghidraAddress 0x48290 */
void AVSeMixer::SetAllBusVolume(int nVolume) {
    const float flVolume = static_cast<float>(nVolume) / kVolumeScale;
    const NSUInteger nCount = m_pBuses.count;
    for (NSUInteger nIndex = 0; nIndex < nCount; ++nIndex) {
        AVBus *pBus = m_pBuses[nIndex];
        if (pBus != nil) {
            [pBus setVolume:flVolume];
        }
    }
}
