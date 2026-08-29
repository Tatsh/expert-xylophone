/**
 * @file
 * One lane's occupancy record, @c NoteLaneSlot.
 */

#pragma once

/**
 * One lane's occupancy: three start/end time pairs marking the spans the lane is in use.
 *
 * A polymorphic 32-byte object: its ctor installs a one-slot vtable (the destructor) at @c +0x00,
 * so the six 32-bit time fields follow at @c +0x08. Freshly initialised, every time is the free
 * sentinel. The lane-assignment routines inline this object's own behaviour; it is de-inlined here
 * into named methods.
 */
class NoteLaneSlot {
public:
    /** The number of start/end occupancy pairs a lane slot holds. */
    static constexpr int kSpanPairCount = 3;
    /** The out-of-range time marking a span pair free. */
    static constexpr unsigned int kFreeTime = 0xfffe7961;

    /** Destroys the lane slot. The class is polymorphic, so the destructor is virtual. */
    virtual ~NoteLaneSlot() = default;

    /**
     * Marks every span pair free (sets all six time fields to the sentinel).
     */
    void MarkFree();

    /**
     * Frees any span pair whose end time has passed before @p nTime.
     * @param nTime The cutoff time.
     */
    void ExpireBefore(int nTime);

    /**
     * Returns the highest assignment pair whose span overlaps [@p nTimeStart, @p nTimeEnd].
     *
     * Pairs 1 and 2 are consulted; pair 0 is never used for assignment. Returns 2, then 1, for the
     * highest overlapping pair, or 0 when neither overlaps.
     * @param nTimeStart The span start time.
     * @param nTimeEnd The span end time.
     * @return The overlapping bucket index (0, 1, or 2).
     */
    int ComputeOverlapBucket(int nTimeStart, int nTimeEnd) const;

    /**
     * Extends span pair @p nPair to include [@p nTimeStart, @p nTimeEnd].
     *
     * When the new span starts before the pair's recorded end, only the end is pushed out;
     * otherwise the pair was free (or ended earlier), so both its start and end are reset.
     * @param nPair The span pair index (0 to 2).
     * @param nTimeStart The span start time.
     * @param nTimeEnd The span end time.
     */
    void ExtendSpanPair(int nPair, int nTimeStart, int nTimeEnd);

private:
    unsigned int m_aTimes[6] = {};
};
