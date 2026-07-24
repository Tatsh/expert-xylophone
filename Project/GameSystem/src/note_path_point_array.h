#pragma once

//
//  note_path_point_array.h
//  REFLEC BEAT plus
//
//  A small growable array of note-chart path points used by the MusicSheet chart parsers. Each
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
    int m_nX = {}; // +0x00
    int m_nY = {}; // +0x04
};

/**
 * @brief A growable array of @c NotePathPoint entries, grown by @c kGrowStep when full.
 *
 * The layout matches the binary's inline array header: the entry buffer pointer, the live count,
 * and the allocated capacity.
 * @ghidraAddress NotePathPointArray (engine chart-parse struct: data +0x0, count +0x8, capacity
 * +0xc)
 */
struct NotePathPointArray {
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

    NotePathPoint *m_pEntries = {}; // +0x00 the entry buffer
    int m_nCount = {};              // +0x08 live entry count
    int m_nCapacity = {};           // +0x0c allocated entry count
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
