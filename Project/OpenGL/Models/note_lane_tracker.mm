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
#include "note_lane_slot.h"

/** @ghidraAddress 0x14911c */
void NoteLaneTracker::ShuffleIndices(int *pArray, int nCount) {
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
    for (NoteLaneSlot &slot : m_aSlots) {
        slot.MarkFree();
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
// The pair a lane's own occupancy uses (extended for neighbours and the tail), and the pair the
// chosen lane's note span itself takes.
constexpr int kNeighbourSpanPair = 1;
constexpr int kChosenSpanPair = 2;
// The chosen lane's trailing tail length: long by default, short for a short-tail note.
constexpr int kLaneTailLong = 30;
constexpr int kLaneTailShort = 10;
} // namespace

/** @ghidraAddress 0x148dd8 */
int NoteLaneTracker::AssignNoteLane(
    int nTimeStart, int nDuration, int nPlayer, int bShortTail, const unsigned char *pLaneAllowed) {
    if (nDuration < 1) {
        return -1;
    }
    const int nTimeEnd = nDuration + nTimeStart;
    NoteLaneSlot *pSlots = &m_aSlots[nPlayer * kLaneCount];

    // Expire every lane's occupancy pairs whose end time has passed.
    for (int nLane = 0; nLane < kLaneCount; ++nLane) {
        pSlots[nLane].ExpireBefore(nTimeStart);
    }

    // Bucket the lanes by the highest assignment pair (1 or 2) that overlaps the note's span; a
    // lane that overlaps neither goes in bucket 0.
    int aBucketCount[NoteLaneSlot::kSpanPairCount] = {};
    int aBucketLanes[NoteLaneSlot::kSpanPairCount][kLaneCount] = {};
    for (int nLane = 0; nLane < kLaneCount; ++nLane) {
        const int nOverlap = pSlots[nLane].ComputeOverlapBucket(nTimeStart, nTimeEnd);
        aBucketLanes[nOverlap][aBucketCount[nOverlap]] = nLane;
        ++aBucketCount[nOverlap];
    }

    // From the least-occupied bucket up, shuffle the candidates and pick the first lane the caller
    // allows (a nonzero @c pLaneAllowed entry).
    for (int nBucket = 0; nBucket < NoteLaneSlot::kSpanPairCount; ++nBucket) {
        const int nCount = aBucketCount[nBucket];
        if (nCount <= 0) {
            continue;
        }
        // Only enter this bucket when at least one candidate lane is allowed.
        bool bAnyAllowed = false;
        for (int k = 0; k < nCount; ++k) {
            if (pLaneAllowed[aBucketLanes[nBucket][k]] != 0) {
                bAnyAllowed = true;
                break;
            }
        }
        if (!bAnyAllowed) {
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
            if (pLaneAllowed[nLane] != 0) {
                break;
            }
        }
        delete[] pOrder;

        // Reserve the chosen lane on pair 2, its neighbours on pair 1, then extend the chosen
        // lane's pair-1 span by the tail.
        pSlots[nLane].ExtendSpanPair(kChosenSpanPair, nTimeStart, nTimeEnd);
        if (nLane >= 1) {
            pSlots[nLane - 1].ExtendSpanPair(kNeighbourSpanPair, nTimeStart, nTimeEnd);
        }
        if (nLane + 1 < kLaneCount) {
            pSlots[nLane + 1].ExtendSpanPair(kNeighbourSpanPair, nTimeStart, nTimeEnd);
        }
        const int nTail = bShortTail != 0 ? kLaneTailShort : kLaneTailLong;
        pSlots[nLane].ExtendSpanPair(kNeighbourSpanPair, nTimeEnd, nTail + nTimeEnd);
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

    pPlayerSlots[nLaneIndex].ExtendSpanPair(kNeighbourSpanPair, nTimeStart, nTimeEnd);
    if (!bSpread) {
        return;
    }
    // Extend the adjacent lanes: the one before (when present) and the one after (within bounds).
    if (nLaneIndex > 0) {
        pPlayerSlots[nLaneIndex - 1].ExtendSpanPair(kNeighbourSpanPair, nTimeStart, nTimeEnd);
    }
    if (nLaneIndex + 1 < kLaneCount) {
        pPlayerSlots[nLaneIndex + 1].ExtendSpanPair(kNeighbourSpanPair, nTimeStart, nTimeEnd);
    }
}
