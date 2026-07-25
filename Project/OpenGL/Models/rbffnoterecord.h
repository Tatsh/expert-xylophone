/**
 * @file
 * The parsed chart note record, @c RbffNoteRecord.
 */

#pragma once

/**
 * @brief One slide sub-record: a slide point's note index, timing selector, and value pair.
 *
 * The chart parser fills an array of these; @c CalculateChartTiming and the slide renderers index
 * it. The trailing @c // +0xNN comments document the original 24-byte layout.
 */
struct RbffSlideRecord {
    short nNoteIndex = {};  // +0x00: the owning note's index in the record pool.
    short nField2 = {};     // +0x02: a secondary slide field, still being worked out.
    int nTimingSel = {};    // +0x04: the timing selector.
    int nValueA = {};       // +0x08: the primary slide value.
    int nValueB = {};       // +0x0c: the secondary slide value.
    int nValueAScaled = {}; // +0x10: the primary value in scaled units.
    int nValueBScaled = {}; // +0x14: the secondary value in scaled units.
};

/**
 * @brief One parsed note from the chart: its timing, geometry, lane, and colour data.
 *
 * Populated when the chart is decoded and referenced by a live @c NoteModel through its
 * @c pRecord pointer. The trailing @c // +0xNN comments document the original member offsets for
 * reference only; the gaps are the record's less-used fields, reserved to preserve the 184-byte
 * layout.
 * @ghidraAddress RbffNoteRecord (engine chart-note struct, 184 bytes)
 */
struct RbffNoteRecord {
    int nTimeA = {};                    // +0x00: the note's primary time stamp.
    int nTimeB = {};                    // +0x04: the note's secondary time stamp.
    int nNoteId = {};                   // +0x08: the note identifier.
    int nStartTime = {};                // +0x0c: the note's start time.
    int nPointCount = {};               // +0x10: the number of path points.
    unsigned char m_aPad14[4] = {};     // +0x14
    short *pPathPoints = {};            // +0x18: the packed path-point array.
    int nKind = {};                     // +0x20: the note kind.
    int nSide = {};                     // +0x24: the note's play side.
    int nHoldKind = {};                 // +0x28: the hold-note kind.
    int nType = {};                     // +0x2c: the note type.
    unsigned char m_aPad30[8] = {};     // +0x30
    unsigned int dwFlags = {};          // +0x38: the note flag bits.
    short nChainLink = {};              // +0x3c: the chain-link index.
    unsigned char m_aPad3e[10] = {};    // +0x3e
    int nHitTime = {};                  // +0x48: the scheduled hit time.
    int nHitWindow = {};                // +0x4c: the hit-window width.
    unsigned char m_aPad50[4] = {};     // +0x50
    int nLane = {};                     // +0x54: the note's lane.
    int nLaneSlot = {};                 // +0x58: the lane slot.
    unsigned char m_aPad5c[4] = {};     // +0x5c
    int nRoute = {};                    // +0x60: the note's route.
    unsigned char m_aPad64[4] = {};     // +0x64
    int nChainOffset = {};              // +0x68: the chain offset.
    int nColorTone = {};                // +0x6c: the colour tone.
    bool bBasicNote = {};               // +0x70: whether the note is a basic note.
    unsigned char m_aPad71[3] = {};     // +0x71
    int nDisplayLane = {};              // +0x74: the display lane.
    int nColorIndex = {};               // +0x78: the colour index.
    int nColor = {};                    // +0x7c: the packed colour.
    int nLinkA = {};                    // +0x80: the primary link.
    int nTimingSel = {};                // +0x84: the timing selector.
    unsigned char m_aPad88[12] = {};    // +0x88
    int nLinkB = {};                    // +0x94: the secondary link.
    unsigned char m_aPad98[16] = {};    // +0x98
    RbffSlideRecord *pSlideRecord = {}; // +0xa8: the slide sub-record, when present.
    int nSlidePointCount = {};          // +0xb0: the number of slide points.
    unsigned char m_aPadB4[4] = {};     // +0xb4
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
