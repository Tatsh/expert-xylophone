/**
 * @file
 * The on-disk RBFF chart-note record, @c RbffChartNote.
 */

#pragma once

/**
 * @brief One note as it is stored in the RBFF chart stream: a 40-byte little-endian record the
 * parser deserialises into the richer in-memory @c RbffNoteRecord.
 *
 * The fields are read in stream order by @c DeserializeNoteRecord. The trailing @c // +0xNN comments
 * document the on-disk byte offsets.
 */
struct RbffChartNote {
    int nTimeA = {};              // +0x00: the note's primary time.
    int nTimeB = {};              // +0x04: the note's secondary (end) time.
    short nNoteId = {};           // +0x08: the note identifier.
    short nStartTime = {};        // +0x0a: the note's start time.
    signed char nKind = {};       // +0x0c: the note kind.
    signed char nPointCount = {}; // +0x0d: the number of path points.
    short pathPoints[8] = {};     // +0x0e: the eight path-point coordinates.
    signed char nSide = {};       // +0x1e: the play side.
    signed char nType = {};       // +0x1f: the note type.
    signed char nHoldFlag = {};   // +0x20: the hold flag.
    signed char reserved1 = {};   // +0x21: reserved.
    short nChainLink = {};        // +0x22: the chain-link id.
    short nChainPartner = {};     // +0x24: the chain-partner id.
    short reserved2 = {};         // +0x26: reserved.
};

/**
 * @brief Deserialises one @c RbffChartNote from a little-endian byte stream, advancing the cursor.
 * @param pRecord The destination chart-note record.
 * @param ppCursor The stream cursor, advanced past the record on return.
 * @return Always 1.
 * @ghidraAddress 0x12e944
 */
int DeserializeNoteRecord(RbffChartNote *pRecord, const unsigned char **ppCursor);

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
