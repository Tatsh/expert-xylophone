/**
 * @file
 * The note-chart reader/parser, @c MusicSheet.
 */

#pragma once

struct RbffNoteRecord;
struct RbffSlideRecord;

/**
 * @brief One sheet path node: a speed/scroll value and the chart time it takes effect.
 */
struct SheetPathNode {
    int nSpeed = {}; // +0x00: the scroll-speed value at this node.
    int nTime = {};  // +0x04: the chart time the node takes effect.
};

/**
 * @brief The note-chart reader: parses an RBFF chart blob into a pool of note records and holds the
 * per-chart timing, lane, and free-note state the play field reads.
 *
 * A polymorphic engine object of 152 bytes. The field layout is taken from the Ghidra data type; the
 * trailing @c // +0xNN comments document the original offsets for reference only, and access is
 * always through the named members.
 */
class MusicSheet {
public:
    /**
     * @brief Returns the note record at @p nIndex, or null when the index is out of range.
     * @param nIndex The note-record index.
     * @return The note record, or null.
     * @ghidraAddress 0x13183c
     */
    RbffNoteRecord *GetNoteRecordByIndex(int nIndex);

    /**
     * @brief Returns the speed-change path node at @p nIndex.
     *
     * Asserts the index is within the path-node count.
     * @param nIndex The path-node index.
     * @return A pointer to the path node.
     * @ghidraAddress 0x12f604
     */
    SheetPathNode *GetSheetPathNode(int nIndex);

    /**
     * @brief Counts the chart's late notes per side and computes its scroll timing.
     *
     * Walks the note records to find each side's side-object end time, counts the notes (and slide
     * records) whose end time is past it into the per-side counters, then selects a scroll-speed tier
     * from the chart note count and stores the scroll and remaining timings.
     * @return The computed remaining timing.
     * @ghidraAddress 0x131294
     */
    int CalculateChartTiming();

    /** @brief The byte stride between note records in the pool (@c sizeof(RbffNoteRecord)). */
    static constexpr int kNoteRecordStride = 0xb8;

    /** @brief The number of play sides the timing counters track. */
    static constexpr int kSideCount = 2;

private:
    void *m_pVtable = {};             // +0x00: the virtual-function table.
    int m_nVersion = {};              // +0x08: the parsed chart format version.
    SheetPathNode *m_pPathNodes = {}; // +0x10: the speed-change path nodes.
    int m_nPathPointCount = {};       // +0x18: the number of path nodes read.
    int m_nPathPointCapacity = {};    // +0x1c: the path-point buffer capacity.
    int m_nChartEndTime = {};         // +0x20: the chart's end time.
    int m_nSeedA = {};                // +0x24: a parse seed/scratch value.
    int m_nNoteCount = {};            // +0x28: the number of note records in the pool.
    int m_nTempoEventCount = {};      // +0x2c: the number of tempo events.
    int m_nFreeNoteCount = {};        // +0x30: the number of free (synthetic) notes.
    int m_nSlideRecordCount = {};     // +0x34: the number of slide records.
    int m_nChartEndTimeScaled = {};   // +0x38: the chart end time in scaled units.
    int m_nField3c = {};              // +0x3c: chart-parse scratch, still being worked out.
    int m_nChartNoteCount = {};       // +0x40: the note count used for the scroll-speed tier.
    // +0x44..+0x57 is chart-parse scratch, still being worked out.
    unsigned char m_aReserved44[0x14] = {};
    int m_aSideCount[kSideCount] = {};     // +0x58: the per-side late-note counts.
    int m_nScrollTiming = {};              // +0x60: the computed scroll timing.
    int m_nRemainTiming = {};              // +0x64: the computed remaining timing.
    RbffNoteRecord *m_pRecords = {};       // +0x68: the note-record pool (kNoteRecordStride each).
    RbffSlideRecord *m_pSlideRecords = {}; // +0x70: the slide-record array.
    int *m_pSideIndexArray = {};           // +0x78: the per-side note-index array.
    int *m_pIndexArrayB = {};              // +0x80: a second note-index array.
    int m_nFirstIndex = {};                // +0x88: the first active note index.
    int m_nIndexCount = {};                // +0x90: the active note-index count.
    unsigned char m_aTailPad[4] = {};      // +0x94: trailing padding.
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
