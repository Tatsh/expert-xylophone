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
    int nTimeA = {};              /*!< The note's primary time. +0x00 */
    int nTimeB = {};              /*!< The note's secondary (end) time. +0x04 */
    short nNoteId = {};           /*!< The note identifier. +0x08 */
    short nStartTime = {};        /*!< The note's start time. +0x0a */
    signed char nKind = {};       /*!< The note kind. +0x0c */
    signed char nPointCount = {}; /*!< The number of path points. +0x0d */
    short pathPoints[8] = {};     /*!< The eight path-point coordinates. +0x0e */
    signed char nSide = {};       /*!< The play side. +0x1e */
    signed char nType = {};       /*!< The note type. +0x1f */
    signed char nHoldFlag = {};   /*!< The hold flag. +0x20 */
    signed char reserved1 = {};   /*!< Reserved. +0x21 */
    short nChainLink = {};        /*!< The chain-link id. +0x22 */
    short nChainPartner = {};     /*!< The chain-partner id. +0x24 */
    short reserved2 = {};         /*!< Reserved. +0x26 */
};

/**
 * @brief A note path-point staging record used while parsing (28 bytes), zeroed before use.
 */
struct RbffPathPoint {
    /** @brief The path-point fields, cleared to zero before the reader fills them. */
    unsigned char aData[28] = {};
};

/**
 * @brief The parser-local staging record @c ReadRbffNoteRecord fills before its fields are unpacked
 * into the pooled @c RbffNoteRecord.
 *
 * A tightly packed ~64-byte layout distinct from the 184-byte in-memory record. The trailing
 * @c // +0xNN comments document the byte offsets.
 */
struct RbffNoteReadRecord {
    int nTimeA = {};             /*!< The note's primary time. +0x00 */
    int nTimeB = {};             /*!< The note's secondary (end) time. +0x04 */
    short nNoteId = {};          /*!< The note identifier. +0x08 */
    short nStartTime = {};       /*!< The note's start time. +0x0a */
    short nPointCount = {};      /*!< The number of path points that follow. +0x0c */
    short reserved0e = {};       /*!< Padding before the aligned path-point pointer. +0x0e */
    short *pPathPoints = {};     /*!< The allocated path-point array. +0x10 */
    signed char nKind = {};      /*!< The note kind. +0x18 */
    signed char nSide = {};      /*!< The play side. +0x19 */
    signed char nHoldKind = {};  /*!< The hold-note kind. +0x1a */
    signed char reserved1b = {}; /*!< Reserved. +0x1b */
    short aTargetCoords[4] = {}; /*!< The four target coordinates. +0x1c */
    unsigned int nFlags = {};    /*!< The note flag bits; bit 3 heads a long note. +0x24 */
    /** @brief Read from the stream but never unpacked into the note record. +0x28 */
    signed char nField28 = {};
    /** @brief Read from the stream but never unpacked into the note record. +0x29 */
    signed char nField29 = {};
    /** @brief Read from the stream but never unpacked into the note record. +0x2a */
    short nField2a = {};
    int nType = {};           /*!< The note type; an on-disk 2 is remapped to 0. +0x2c */
    short nChainLink = {};    /*!< Chain-link sentinel (0xffff when unset). +0x30 */
    short nChainPartner = {}; /*!< Chain-partner sentinel (0xffff when unset). +0x32 */
    int nField34 = {};        /*!< Filled with the chain payload's high word. +0x34 */
    int nChainExtra = {};     /*!< Extra chain payload read only when the flag bit is set. +0x38 */
};

/**
 * @brief One RBFF tempo/speed-change event as stored in the chart stream (36 bytes).
 */
struct RbffTempoEvent {
    /** @brief The raw 36-byte event payload, copied verbatim by the reader. */
    unsigned char aData[36] = {};
};

/**
 * @brief One RBFF chart sub-record (a slide/header entry) read from the stream: three shorts and two
 * ints, with four trailing reserved bytes.
 */
struct RbffChartHeaderRecord {
    unsigned short nField0 = {}; /*!< The first of the record's three leading shorts. +0x00 */
    unsigned short nField2 = {}; /*!< The second of the record's three leading shorts. +0x02 */
    unsigned short nField4 = {}; /*!< The third of the record's three leading shorts. +0x04 */
    /** @brief Two bytes of padding before the first int. +0x06 */
    unsigned short reserved6 = {};
    int nValueA = {}; /*!< The first of the record's two trailing ints. +0x08 */
    int nValueB = {}; /*!< The second of the record's two trailing ints. +0x0c */
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
