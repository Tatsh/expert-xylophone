/**
 * @file
 * The chart lane-assignment tracker, @c NoteLaneTracker.
 */

#pragma once

class Random;

/**
 * @brief One lane's occupancy slot: three start/end time pairs marking the spans the lane is in use.
 *
 * A polymorphic 32-byte record (its own one-slot vtable plus six 32-bit time fields). Freshly
 * initialised, every time is the free sentinel. The trailing @c // +0xNN comments document the byte
 * offsets.
 */
struct NoteLaneSlot {
    void *pVtable = {};          // +0x00: the slot's vtable.
    unsigned int aTimes[6] = {}; // +0x08: three start/end time pairs (all the free sentinel).
};

/**
 * @brief Tracks per-lane occupancy while the chart parser assigns each note a play-field lane.
 *
 * Holds a lane slot for each of the two players' seven lanes and an attached @c Random used to pick
 * lanes. Built by the chart parser's lane pass and destroyed at its end. The class name is inferred
 * from its lane-assignment use.
 * @ghidraAddress NoteLaneTracker (chart lane-assignment tracker)
 */
class NoteLaneTracker {
public:
    // The number of players and the number of lanes each player has.
    static constexpr int kPlayerCount = 2;
    static constexpr int kLaneCount = 7;
    static constexpr int kSlotCount = kPlayerCount * kLaneCount;
    // The out-of-range time marking a lane slot free.
    static constexpr unsigned int kFreeTime = 0xfffe7961;

    /**
     * @brief Constructs the tracker: installs the vtables and marks every lane slot free.
     * @ghidraAddress 0x148c78
     */
    NoteLaneTracker();
    /**
     * @brief Destroys the tracker, releasing its attached note-data generator.
     * @ghidraAddress 0x148cd8
     */
    ~NoteLaneTracker();

    /**
     * @brief Attaches a fresh lane-picking generator seeded with @p dwSeed.
     * @param dwSeed The seed (the game system's random seed).
     * @ghidraAddress 0x148d78
     */
    void SetNoteData(unsigned int dwSeed);

private:
    void *m_pVtable = {};                   // +0x00: the tracker's vtable.
    Random *m_pNoteData = {};               // +0x08: the attached lane-picking generator.
    NoteLaneSlot m_aSlots[kSlotCount] = {}; // +0x10: the per-player, per-lane occupancy slots.
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
