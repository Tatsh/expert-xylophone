//
//  note_lane_slot.mm
//  REFLEC BEAT plus
//
//  One lane's occupancy record (NoteLaneSlot). Reconstructed from Ghidra project rb458, program
//  rb458. The lane-assignment routines inline this object's own behaviour; it is de-inlined here.
//

#include "note_lane_slot.h"

void NoteLaneSlot::MarkFree() {
    for (unsigned int &nTime : m_aTimes) {
        nTime = kFreeTime;
    }
}

void NoteLaneSlot::ExpireBefore(int nTime) {
    for (int nPair = 0; nPair < kSpanPairCount; ++nPair) {
        if (static_cast<int>(m_aTimes[nPair + kSpanPairCount]) < nTime) {
            m_aTimes[nPair] = kFreeTime;
            m_aTimes[nPair + kSpanPairCount] = kFreeTime;
        }
    }
}

int NoteLaneSlot::ComputeOverlapBucket(int nTimeStart, int nTimeEnd) const {
    int nOverlap = 0;
    for (int nPair = 1; nPair < kSpanPairCount; ++nPair) {
        if (static_cast<int>(m_aTimes[nPair + kSpanPairCount]) >= nTimeStart &&
            static_cast<int>(m_aTimes[nPair]) <= nTimeEnd) {
            nOverlap = nPair;
        }
    }
    return nOverlap;
}

void NoteLaneSlot::ExtendSpanPair(int nPair, int nTimeStart, int nTimeEnd) {
    unsigned int &nStart = m_aTimes[nPair];
    unsigned int &nEnd = m_aTimes[nPair + kSpanPairCount];
    // When the new span starts before the pair's recorded end, only push the end out; otherwise the
    // pair was free (or ended earlier), so reset its start too.
    if (nTimeStart < static_cast<int>(nEnd)) {
        if (static_cast<int>(nEnd) < nTimeEnd) {
            nEnd = nTimeEnd;
        }
    } else {
        nStart = nTimeStart;
        nEnd = nTimeEnd;
    }
}
