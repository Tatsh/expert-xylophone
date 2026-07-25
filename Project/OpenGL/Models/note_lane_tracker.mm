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
