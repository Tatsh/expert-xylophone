//
//  note_lane_tracker.mm
//  REFLEC BEAT plus
//
//  The chart lane-assignment tracker (NoteLaneTracker). Reconstructed from Ghidra project rb458,
//  program rb458. @ghidraAddress values are relative to the program image base.
//

#include "note_lane_tracker.h"

#include <cstdlib>

#include "Random.h"

/** @ghidraAddress 0x14911c */
void ShuffleIndices(int *pArray, int nCount) {
    for (int i = 0; i < nCount; ++i) {
        const int nSwap = nCount != 0 ? std::rand() % nCount : 0;
        const int nTemp = pArray[i];
        pArray[i] = pArray[nSwap];
        pArray[nSwap] = nTemp;
    }
}

/** @ghidraAddress 0x148c78 */
NoteLaneTracker::NoteLaneTracker() {
    m_pNoteData = nullptr;
    // Every lane slot starts free: its six time fields hold the out-of-range sentinel.
    for (int nSlot = 0; nSlot < kSlotCount; ++nSlot) {
        for (unsigned int &nTime : m_aSlots[nSlot].aTimes) {
            nTime = kFreeTime;
        }
    }
}

/** @ghidraAddress 0x148cd8 */
NoteLaneTracker::~NoteLaneTracker() {
    delete m_pNoteData;
    m_pNoteData = nullptr;
}

/** @ghidraAddress 0x148d78 */
void NoteLaneTracker::SetNoteData(unsigned int dwSeed) {
    // Attach a fresh generator and reseed it.
    m_pNoteData = new Random();
    m_pNoteData->SetSeed(dwSeed);
}

namespace {
// A lane slot holds three occupancy pairs; pair p is {start = aTimes[p], end = aTimes[p + 3]}.
// ReserveNoteLane extends pair 1; AssignNoteLane extends pair 2 for the chosen lane and pair 1 for
// its neighbours and tail.
constexpr int kSpanPairCount = 3;
// The chosen lane's trailing tail length: long by default, short for a short-tail note.
constexpr int kLaneTailLong = 30;
constexpr int kLaneTailShort = 10;

// Extends lane slot occupancy pair @p nPair to include [nTimeStart, nTimeEnd].
void ExtendSlotSpanPair(NoteLaneSlot &slot, int nPair, int nTimeStart, int nTimeEnd) {
    unsigned int &nStart = slot.aTimes[nPair];
    unsigned int &nEnd = slot.aTimes[nPair + kSpanPairCount];
    // When the new span starts before the slot's recorded end, only push the end out; otherwise the
    // slot was free (or ended earlier), so reset its start too.
    if (nTimeStart < static_cast<int>(nEnd)) {
        if (static_cast<int>(nEnd) < nTimeEnd) {
            nEnd = nTimeEnd;
        }
    } else {
        nStart = nTimeStart;
        nEnd = nTimeEnd;
    }
}
} // namespace

/** @ghidraAddress 0x148dd8 */
int NoteLaneTracker::AssignNoteLane(
    int nTimeStart, int nDuration, int nPlayer, int bShortTail, const char *pLaneSkip) {
    if (nDuration < 1) {
        return -1;
    }
    const int nTimeEnd = nDuration + nTimeStart;
    NoteLaneSlot *pSlots = &m_aSlots[nPlayer * kLaneCount];

    // Expire every lane's occupancy pairs whose end time has passed.
    for (int nLane = 0; nLane < kLaneCount; ++nLane) {
        for (int p = 0; p < kSpanPairCount; ++p) {
            if (static_cast<int>(pSlots[nLane].aTimes[p + kSpanPairCount]) < nTimeStart) {
                pSlots[nLane].aTimes[p] = kFreeTime;
                pSlots[nLane].aTimes[p + kSpanPairCount] = kFreeTime;
            }
        }
    }

    // Bucket the lanes by how many of their pairs overlap the note's span (0, 1, or 2+).
    int aBucketCount[kSpanPairCount] = {};
    int aBucketLanes[kSpanPairCount][kLaneCount] = {};
    for (int nLane = 0; nLane < kLaneCount; ++nLane) {
        int nOverlap = 0;
        for (int p = 0; p < 2; ++p) {
            if (static_cast<int>(pSlots[nLane].aTimes[p + kSpanPairCount]) >= nTimeStart &&
                static_cast<int>(pSlots[nLane].aTimes[p]) <= nTimeEnd) {
                nOverlap = p + 1;
            }
        }
        aBucketLanes[nOverlap][aBucketCount[nOverlap]] = nLane;
        ++aBucketCount[nOverlap];
    }

    // From the least-occupied bucket down, shuffle the candidates and pick the first lane the caller
    // does not skip.
    for (int nBucket = 0; nBucket < kSpanPairCount; ++nBucket) {
        const int nCount = aBucketCount[nBucket];
        if (nCount <= 0) {
            continue;
        }
        // Only enter this bucket when at least one candidate is not skipped.
        bool bAnyFree = false;
        for (int k = 0; k < nCount; ++k) {
            if (pLaneSkip[aBucketLanes[nBucket][k]] == 0) {
                bAnyFree = true;
                break;
            }
        }
        if (!bAnyFree) {
            continue;
        }

        int *pOrder = new int[nCount];
        for (int k = 0; k < nCount; ++k) {
            pOrder[k] = k;
        }
        ShuffleIndices(pOrder, nCount);
        int nLane = 0;
        for (int k = 0; k < nCount; ++k) {
            nLane = aBucketLanes[nBucket][pOrder[k]];
            if (pLaneSkip[nLane] != 0) {
                break;
            }
        }
        delete[] pOrder;

        // Reserve the chosen lane on pair 2, its neighbours on pair 1, then extend the chosen lane's
        // pair-1 span by the tail.
        ExtendSlotSpanPair(pSlots[nLane], 2, nTimeStart, nTimeEnd);
        if (nLane >= 1) {
            ExtendSlotSpanPair(pSlots[nLane - 1], 1, nTimeStart, nTimeEnd);
        }
        if (nLane + 1 < kLaneCount) {
            ExtendSlotSpanPair(pSlots[nLane + 1], 1, nTimeStart, nTimeEnd);
        }
        const int nTail = bShortTail != 0 ? kLaneTailShort : kLaneTailLong;
        ExtendSlotSpanPair(pSlots[nLane], 1, nTimeEnd, nTail + nTimeEnd);
        return nLane;
    }
    return 0;
}

/** @ghidraAddress 0x149178 */
void NoteLaneTracker::ReserveNoteLane(
    int nTimeStart, int nDuration, int nPlayer, int nLane, bool bSpread) {
    // Only the first three lane groups are reservable.
    if (nLane > 2) {
        return;
    }
    const int nTimeEnd = nDuration + nTimeStart;
    const int nLaneIndex = nLane * 3;
    NoteLaneSlot *pPlayerSlots = &m_aSlots[nPlayer * kLaneCount];

    ExtendSlotSpanPair(pPlayerSlots[nLaneIndex], 1, nTimeStart, nTimeEnd);
    if (!bSpread) {
        return;
    }
    // Extend the adjacent lanes: the one before (when present) and the one after (within bounds).
    if (nLaneIndex > 0) {
        ExtendSlotSpanPair(pPlayerSlots[nLaneIndex - 1], 1, nTimeStart, nTimeEnd);
    }
    if (nLaneIndex + 1 < kLaneCount) {
        ExtendSlotSpanPair(pPlayerSlots[nLaneIndex + 1], 1, nTimeStart, nTimeEnd);
    }
}
