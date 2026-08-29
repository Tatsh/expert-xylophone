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
    if (nTimeStart < static_cast<int>(nEnd)) {
        if (static_cast<int>(nEnd) < nTimeEnd) {
            nEnd = nTimeEnd;
        }
    } else {
        nStart = nTimeStart;
        nEnd = nTimeEnd;
    }
}
