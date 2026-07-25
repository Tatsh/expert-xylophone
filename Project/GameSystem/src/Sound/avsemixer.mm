//
//  avsemixer.mm
//  REFLEC BEAT plus
//
//  The AVFoundation sound-effect voice mixer (AVSeMixer). Reconstructed from Ghidra project rb458,
//  program rb458. @ghidraAddress values are relative to the program image base.
//

#include "avsemixer.h"

#import "AVBus.h"

namespace {
// Play handles pack the voice index into bits 16 and up and the voice's current id into the low 16.
constexpr unsigned int kBusHandleIdMask = 0xffff;
constexpr int kBusHandleIndexShift = 16;
// The mixer normalises an integer 0..127 volume to the 0..1 gain the voices take.
constexpr float kVolumeScale = 127.0f;
// FindFreeBusIndex and IsBusFree treat any status other than "playing" as reusable.
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
    // The handle only resolves when the voice still holds the id it was acquired with.
    if ([pBus currentID] != (dwHandle & kBusHandleIdMask)) {
        return nil;
    }
    return pBus;
}

/** @ghidraAddress 0x47eb4 */
unsigned int AVSeMixer::AcquireBusForSource(unsigned int dwSource, unsigned int nVolume) {
    const int nIndex = FindFreeBusIndex();
    if (nIndex == -1) {
        return 0xffffffff;
    }
    AVBus *pBus = m_pBuses[nIndex];
    [pBus removeSource];
    const unsigned int dwCurrentId = [pBus setSource:dwSource];
    [pBus prepare];
    const unsigned int dwHandle =
        (dwCurrentId & kBusHandleIdMask) | (nIndex << kBusHandleIndexShift);
    SetBusVolumeByHandle(dwHandle, static_cast<int>(nVolume));
    return dwHandle;
}

/** @ghidraAddress 0x483d8 */
void AVSeMixer::RemoveSourceFromBuses(unsigned int source) {
    for (int nIndex = 0; nIndex < m_nVoiceCount; ++nIndex) {
        AVBus *pBus = m_pBuses[nIndex];
        if ([pBus isSameSource:source]) {
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
    // The binary loops m_nVoiceCount times but allocates a fresh throwaway AVBus each iteration and
    // pauses that, rather than pausing the pooled voices — reproduced faithfully. (A newly created
    // voice begins paused, so this is effectively a no-op with an allocation per voice.)
    for (int nVoice = 0; nVoice < m_nVoiceCount; ++nVoice) {
        AVBus *pBus = [[AVBus alloc] init];
        [pBus pause];
    }
}

/** @ghidraAddress 0x47e08 */
void AVSeMixer::ResumeAllBuses() {
    // As with SuspendAllBuses, the binary allocates a throwaway AVBus per voice and un-pauses it
    // rather than touching the pooled voices — reproduced faithfully.
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
