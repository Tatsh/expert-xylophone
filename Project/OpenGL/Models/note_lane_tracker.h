/**
 * @file
 * The chart lane-assignment tracker, @c NoteLaneTracker.
 */

#pragma once

#include "note_lane_slot.h"

class Random;

/**
 * @brief Tracks per-lane occupancy while the chart parser assigns each note a play-field lane.
 *
 * Holds a lane slot for each of the two players' seven lanes and an attached @c Random used to pick
 * lanes. Built by the chart parser's lane pass and destroyed at its end. The class name is inferred
 * from its lane-assignment use.
 * Reconstructed type @c NoteLaneTracker: chart lane-assignment tracker.
 */
class NoteLaneTracker {
public:
    /** @brief The number of players. */
    static constexpr int kPlayerCount = 2;
    /** @brief The number of lanes each player has. */
    static constexpr int kLaneCount = 7;
    /** @brief The total number of lane slots, one per player per lane. */
    static constexpr int kSlotCount = kPlayerCount * kLaneCount;

    /**
     * @brief Constructs the tracker: marks every lane slot free.
     * @ghidraAddress 0x148c78
     */
    NoteLaneTracker();
    /**
     * @brief Destroys the tracker, releasing its attached note-data generator.
     *
     * The class is polymorphic (the compiler emits its vtable at offset 0), so the destructor is
     * virtual. The vtable holds the two Itanium destructor thunks — the complete-object variant
     * (@c 0x148c70, an empty body) and the deleting variant (@c 0x148c74, which tail-calls
     * @c operator @c delete) — plus the out-of-line deleting destructor (@c 0x148d20, which
     * installs the vtable, destroys the attached generator sub-object, and frees the tracker); all
     * fold into this one destructor.
     * @ghidraAddress 0x148cd8
     * @ghidraAddress 0x148c70
     * @ghidraAddress 0x148c74
     * @ghidraAddress 0x148d20
     */
    virtual ~NoteLaneTracker();

    /**
     * @brief Attaches a fresh lane-picking generator seeded with @p dwSeed.
     * @param dwSeed The seed (the game system's random seed).
     * @ghidraAddress 0x148d78
     */
    void SetNoteData(unsigned int dwSeed);

    /**
     * @brief Reserves a lane (and optionally its neighbours) for a note's time span.
     *
     * Extends the lane slot's occupied start/end range to cover @c [nTimeStart, nTimeStart +
     * nDuration]; when @p bSpread is set, the adjacent lanes are extended likewise. Only the first
     * three lane groups (@p nLane below 3) are reservable.
     * @param nTimeStart The span start time.
     * @param nDuration The span duration.
     * @param nPlayer The player side.
     * @param nLane The lane group (below 3).
     * @param bSpread Whether to extend onto the adjacent lanes.
     * @ghidraAddress 0x149178
     */
    void ReserveNoteLane(int nTimeStart, int nDuration, int nPlayer, int nLane, bool bSpread);

    /**
     * @brief Assigns a note to the least-conflicting lane for its time span.
     *
     * Expires lane slots whose span has passed, buckets the seven lanes by the highest assignment
     * pair that overlaps the note's span, and within the least-occupied bucket shuffles the
     * candidates and picks the first lane the caller allows in @p pLaneAllowed. The chosen lane
     * (and, for a spread note, its neighbours) is then reserved, with the chosen lane taking an
     * extra tail.
     * @param nTimeStart The span start time.
     * @param nDuration The span duration.
     * @param nPlayer The player side.
     * @param bShortTail Whether the chosen lane takes the short tail rather than the long one.
     * @param pLaneAllowed A seven-entry table of per-lane allowed flags (nonzero permits the lane).
     * @return The assigned lane index (0 to 6), or @c -1 when the span is empty.
     * @ghidraAddress 0x148dd8
     */
    int AssignNoteLane(int nTimeStart,
                       int nDuration,
                       int nPlayer,
                       int bShortTail,
                       const unsigned char *pLaneAllowed);

private:
    /**
     * @brief Fisher-Yates shuffle of an int array, used to break lane-assignment ties randomly.
     *
     * Ties are broken with the C library @c rand rather than the engine generator. (The binary
     * takes an ignored leading register argument, dropped here.)
     * @param pArray The int array to shuffle in place.
     * @param nCount The element count.
     * @ghidraAddress 0x14911c
     */
    static void ShuffleIndices(int *pArray, int nCount);

    // +0x00: the compiler-emitted vtable pointer (the class is polymorphic; see the virtual dtor).
    Random *m_pNoteData = {};               // +0x08: the attached lane-picking generator.
    NoteLaneSlot m_aSlots[kSlotCount] = {}; // +0x10: the per-player, per-lane occupancy slots.
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
