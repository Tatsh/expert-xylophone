/**
 * @file
 * The parsed chart note record, @c RbffNoteRecord.
 */

#pragma once

#include "note_chain_link.h"

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
    int nTimeA = {};                // +0x00: the note's primary time stamp.
    int nTimeB = {};                // +0x04: the note's secondary time stamp.
    int nNoteId = {};               // +0x08: the note identifier.
    int nStartTime = {};            // +0x0c: the note's start time.
    int nPointCount = {};           // +0x10: the number of path points.
    unsigned char m_aPad14[4] = {}; // +0x14
    short *pPathPoints = {};        // +0x18: the packed path-point array.
    int nKind = {};                 // +0x20: the note kind.
    int nSide = {};                 // +0x24: the note's play side.
    int nHoldKind = {};             // +0x28: the hold-note kind.
    int nType = {};                 // +0x2c: the note type.
    short aTargetCoords[3] = {};    // +0x30: the note's target coordinates (the first is scaled).
    short nTargetPad = {};          // +0x36: cleared alongside the target coordinates.
    unsigned int dwFlags = {};      // +0x38: the note flag bits.
    NoteChainLink chainLink = {};   // +0x3c: the 12-byte chain-link block threading chain notes.
    int nHitTime = {};              // +0x48: the scheduled hit time.
    int nHitWindow = {};            // +0x4c: the hit-window width.
    int nSideIndex = {}; // +0x50: the note's index within its side (assigned during install).
    int nLane = {};      // +0x54: the note's lane.
    int nLaneSlot = {};  // +0x58: the lane slot.
    unsigned char m_aPad5c[4] = {}; // +0x5c
    int nRoute = {};                // +0x60: the note's route.
    int nTargetCopy = {};           // +0x64: a copy of the first target coordinate.
    int nChainOffset = {};          // +0x68: the chain offset.
    int nColorTone = {};            // +0x6c: the colour tone.
    bool bBasicNote = {};           // +0x70: whether the note is a basic note.
    unsigned char m_aPad71[3] = {}; // +0x71
    int nDisplayLane = {};          // +0x74: the display lane.
    int nColorIndex = {};           // +0x78: the colour index.
    int nColor = {};                // +0x7c: the packed colour.
    int nLinkA = {};                // +0x80: the primary link.
    int nTimingSel = {};            // +0x84: the timing selector.
    unsigned char m_aPad88 = {};    // +0x88: padding before the green-target bitmap.
    // +0x89: the per-slot green-target availability bitmap (a byte per reachable target); the chart
    // lane pass clears the slots blocked by overlapping or chained notes.
    unsigned char aGreenTargets[11] = {};
    int nChosenTarget = {};         // +0x94: the note's chosen green target.
    bool bScrollVisible = {};       // +0x98: whether the note is on-screen (startSpeed < endSpeed).
    unsigned char m_aPad99[3] = {}; // +0x99
    float flScrollStartSpeed = {};  // +0x9c: the resolved scroll speed at the note's start.
    float flScrollEndSpeed = {};    // +0xa0: the resolved scroll speed at the note's end.
    unsigned char m_aPadA4[4] = {}; // +0xa4
    RbffSlideRecord *pSlideRecord = {}; // +0xa8: the slide sub-record, when present.
    int nSlidePointCount = {};          // +0xb0: the number of slide points.
    unsigned char m_aPadB4[4] = {};     // +0xb4

    /**
     * @brief Constructs a note record in its default per-note state before the chart parser fills
     * it: zeroes the timing, geometry, and link fields; seeds the empty chain-link block; and sets
     * the default lane and lane-slot (3), the timing-selector sentinel (-2), and the colour/link
     * sentinels (-1).
     * @ghidraAddress 0x12f780
     */
    RbffNoteRecord();
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
