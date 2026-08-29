/**
 * @file
 * The RBFF chart-stream cursor and its header helpers.
 */

#pragma once

/**
 * A read cursor over an RBFF chart blob: the current position and bounds the parser advances
 * as it consumes records.
 *
 * A 16-byte record; the trailing @c // +0xNN comments document the byte offsets.
 */
struct RbffStreamCursor {
    int nField0 = {}; /*!< Cursor state (reset to zero on init). +0x00 */
    int nField4 = {}; /*!< Cursor state. +0x04 */
    int nField8 = {}; /*!< Cursor state. +0x08 */
    int nFieldC = {}; /*!< Cursor state. +0x0c */
};

/**
 * Zeroes an RBFF stream cursor to its initial state.
 * @param pCursor The cursor to reset.
 * @ghidraAddress 0x12e918
 */
void InitRbffStreamCursor(RbffStreamCursor *pCursor);

/**
 * Checks the four-byte @c 'RBFF' magic at the start of a chart blob.
 * @param pData The chart bytes.
 * @return @c true when the magic matches.
 * @ghidraAddress 0x12e92c
 */
bool CheckRbffMagic(const void *pData);
