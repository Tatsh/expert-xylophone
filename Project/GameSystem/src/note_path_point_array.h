/**
 * @file
 * The growable note-chart path-point array, @c NotePathPointArray, and its entry type.
 *
 * Used by the @c CMusicSheet2 chart parsers. Each entry is an 8-byte pair of ints holding a node's
 * scroll speed (as raw float bits) and its time in milliseconds; the array grows by a fixed step
 * when full.
 */

#pragma once

//
//  note_path_point_array.h
//  REFLEC BEAT plus
//
//  A small growable array of note-chart path points used by the CMusicSheet2 chart parsers. Each
//  entry is an 8-byte pair of ints (a path point). The array grows by a fixed step when full.
//
//  Reconstructed from Ghidra project rb458, program rb458. @ghidraAddress values are relative to
//  the program image base.
//

/**
 * @brief One note-chart path point: a pair of ints stored in the growable array.
 * @ghidraAddress NotePathPoint (engine chart-parse struct)
 */
struct NotePathPoint {
    /**
     * @brief The node's scroll speed, held as the raw bit pattern of a float.
     *
     * The chart stores the speed in this int slot and the readers copy the bits out rather than
     * converting them, so the value is only meaningful once reinterpreted as a float.
     * +0x00
     */
    int x = {};
    int y = {}; /*!< The node's time, in milliseconds, along the chart. +0x04 */
};

/**
 * @brief A growable array of @c NotePathPoint entries, grown by @c kGrowStep when full.
 *
 * The layout matches the binary's inline array header: the entry buffer pointer, the live count,
 * and the allocated capacity.
 * @ghidraAddress NotePathPointArray (engine chart-parse struct: data +0x0, count +0x8, capacity
 * +0xc)
 */
class NotePathPointArray {
public:
    /** @brief The number of extra entries each grow reserves. */
    static constexpr int kGrowStep = 5;

    /**
     * @brief Reserves @p nCount zero-initialised entries and returns the buffer.
     *
     * The binary passes the array as an ignored first argument; the fresh buffer is returned in the
     * result register and stored by the caller.
     * @param nCount The number of entries to reserve.
     * @return The newly allocated, zeroed entry buffer.
     * @ghidraAddress 0x12f5b0
     */
    NotePathPoint *AllocateEntries(int nCount);
    /**
     * @brief Appends @p point, growing the buffer by @c kGrowStep entries when it is full.
     * @param point The path point to append.
     * @ghidraAddress 0x12f648
     */
    void Append(const NotePathPoint &point);

    /** @brief The number of live entries. */
    int GetCount() const {
        return m_nCount;
    }

    /** @brief The entry at @p nIndex. */
    NotePathPoint &operator[](int nIndex) {
        return m_pEntries[nIndex];
    }

    /** @brief Releases the entry buffer and clears the count and capacity. */
    void Free() {
        delete[] m_pEntries;
        m_pEntries = nullptr;
        m_nCount = 0;
        m_nCapacity = 0;
    }

    /** @brief Seeds an empty array with room for a single entry (the reader's initial state). */
    void Reserve() {
        m_pEntries = AllocateEntries(1);
        m_nCount = 0;
        m_nCapacity = 1;
    }

private:
    NotePathPoint *m_pEntries = {}; // +0x00 the entry buffer
    int m_nCount = {};              // +0x08 live entry count
    int m_nCapacity = {};           // +0x0c allocated entry count
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
