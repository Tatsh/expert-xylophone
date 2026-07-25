//
//  note_lane_tracker.mm
//  REFLEC BEAT plus
//
//  The chart lane-assignment tracker (NoteLaneTracker). Reconstructed from Ghidra project rb458,
//  program rb458. @ghidraAddress values are relative to the program image base.
//

#include "note_lane_tracker.h"

#include "Random.h"

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
// A lane slot's occupied span is held as its start time (aTimes[1]) and end time (aTimes[4]).
constexpr int kSlotSpanStart = 1;
constexpr int kSlotSpanEnd = 4;

// Extends one lane slot's occupied span to include [nTimeStart, nTimeEnd].
void ExtendSlotSpan(NoteLaneSlot &slot, int nTimeStart, int nTimeEnd) {
    // When the new span starts before the slot's recorded end, only push the end out; otherwise the
    // slot was free (or ended earlier), so reset its start too.
    if (nTimeStart < static_cast<int>(slot.aTimes[kSlotSpanEnd])) {
        if (static_cast<int>(slot.aTimes[kSlotSpanEnd]) < nTimeEnd) {
            slot.aTimes[kSlotSpanEnd] = nTimeEnd;
        }
    } else {
        slot.aTimes[kSlotSpanStart] = nTimeStart;
        slot.aTimes[kSlotSpanEnd] = nTimeEnd;
    }
}
} // namespace

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

    ExtendSlotSpan(pPlayerSlots[nLaneIndex], nTimeStart, nTimeEnd);
    if (!bSpread) {
        return;
    }
    // Extend the adjacent lanes: the one before (when present) and the one after (within bounds).
    if (nLaneIndex > 0) {
        ExtendSlotSpan(pPlayerSlots[nLaneIndex - 1], nTimeStart, nTimeEnd);
    }
    if (nLaneIndex + 1 < kLaneCount) {
        ExtendSlotSpan(pPlayerSlots[nLaneIndex + 1], nTimeStart, nTimeEnd);
    }
}
