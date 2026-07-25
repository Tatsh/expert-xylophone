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
 * @brief The parser-local staging record @c ReadRbffNoteRecord fills before its fields are unpacked
 * into the pooled @c RbffNoteRecord.
 *
 * A tightly packed ~64-byte layout distinct from the 184-byte in-memory record. The trailing
 * @c // +0xNN comments document the byte offsets.
 */
struct RbffNoteReadRecord {
    int nTimeA = {};             // +0x00
    int nTimeB = {};             // +0x04
    short nNoteId = {};          // +0x08
    short nStartTime = {};       // +0x0a
    short nPointCount = {};      // +0x0c: the number of path points that follow.
    short reserved0e = {};       // +0x0e: padding before the aligned path-point pointer.
    short *pPathPoints = {};     // +0x10: the allocated path-point array.
    signed char nKind = {};      // +0x18
    signed char nSide = {};      // +0x19
    signed char nHoldKind = {};  // +0x1a
    signed char reserved1b = {}; // +0x1b
    short aTargetCoords[4] = {}; // +0x1c: the four target coordinates.
    unsigned int nFlags = {};    // +0x24
    signed char nField28 = {};   // +0x28
    signed char nField29 = {};   // +0x29
    short nField2a = {};         // +0x2a
    int nType = {};              // +0x2c
    short nChainLink = {};       // +0x30: chain-link sentinel (0xffff when unset).
    short nChainPartner = {};    // +0x32: chain-partner sentinel (0xffff when unset).
    int nField34 = {};           // +0x34: filled with the chain payload's high word.
    int nChainExtra = {};        // +0x38: extra chain payload read only when the flag bit is set.
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
 * @brief Zeroes a note staging record and sets its chain-link sentinels to the unset value.
 * @param pRecord The staging record to initialise.
 * @ghidraAddress 0x12ea78
 */
void InitNoteChainData(RbffNoteReadRecord *pRecord);

/**
 * @brief Frees a note staging record's path-point array, clearing the pointer.
 * @param pRecord The staging record whose path array is freed.
 * @return The staging record.
 * @ghidraAddress 0x12eaac
 */
RbffNoteReadRecord *FreeNotePathArray(RbffNoteReadRecord *pRecord);

/**
 * @brief Reads one note record from an RBFF stream into a staging record, allocating its path array.
 * @param pOut The destination staging record.
 * @param ppCursor The stream cursor, advanced past the record on return.
 * @return Always 1.
 * @ghidraAddress 0x12eb28
 */
int ReadRbffNoteRecord(RbffNoteReadRecord *pOut, const unsigned char **ppCursor);

/**
 * @brief Zeroes a tempo-event record before it is read.
 * @param pEvent The tempo event to clear.
 * @ghidraAddress 0x12eb10
 */
void ClearNoteChartHeader(RbffTempoEvent *pEvent);

/**
 * @brief Zeroes a chart sub-record before it is read.
 * @param pRecord The sub-record to clear.
 * @ghidraAddress 0x12eb20
 */
void ClearNotePair(RbffChartHeaderRecord *pRecord);

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
