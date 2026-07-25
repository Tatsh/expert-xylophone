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
 * @brief A note path-point staging record used while parsing (28 bytes), zeroed before use.
 */
struct RbffPathPoint {
    unsigned char aData[28] =
        {}; // The path-point fields, cleared to zero before the reader fills them.
};

/**
 * @brief One RBFF tempo/speed-change event as stored in the chart stream (36 bytes).
 */
struct RbffTempoEvent {
    unsigned char aData[36] = {}; // The raw 36-byte event payload, copied verbatim by the reader.
};

/**
 * @brief One RBFF chart sub-record (a slide/header entry) read from the stream: three shorts and two
 * ints, with four trailing reserved bytes.
 */
struct RbffChartHeaderRecord {
    unsigned short nField0 = {}; // +0x00
    unsigned short nField2 = {}; // +0x02
    unsigned short nField4 = {}; // +0x04
    // +0x06 is two bytes of padding before the first int.
    unsigned short reserved6 = {};
    int nValueA = {}; // +0x08
    int nValueB = {}; // +0x0c
};

/**
 * @brief Deserialises one @c RbffChartNote from a little-endian byte stream, advancing the cursor.
 * @param pRecord The destination chart-note record.
 * @param ppCursor The stream cursor, advanced past the record on return.
 * @return Always 1.
 * @ghidraAddress 0x12e944
 */
int DeserializeNoteRecord(RbffChartNote *pRecord, const unsigned char **ppCursor);

/**
 * @brief Zeroes a note path-point staging record before the reader fills it.
 * @param pPoint The path-point record to clear.
 * @ghidraAddress 0x12ea68
 */
void InitPathPoint(RbffPathPoint *pPoint);

/**
 * @brief Reads one 36-byte RBFF tempo event from the stream, advancing the cursor.
 * @param pOut The destination tempo event.
 * @param ppCursor The stream cursor, advanced past the event on return.
 * @return Always 1.
 * @ghidraAddress 0x12ed14
 */
int ReadRbffTempoEvent(RbffTempoEvent *pOut, const unsigned char **ppCursor);

/**
 * @brief Deserialises one RBFF chart sub-record (three shorts, two ints, four reserved bytes),
 * advancing the cursor.
 * @param pRecord The destination sub-record.
 * @param ppCursor The stream cursor, advanced past the record on return.
 * @return Always 1.
 * @ghidraAddress 0x12ed44
 */
int DeserializeChartHeaderRecord(RbffChartHeaderRecord *pRecord, const unsigned char **ppCursor);

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
