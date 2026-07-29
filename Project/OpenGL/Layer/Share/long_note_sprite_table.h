/**
 * @file
 * The long-note sprite-type layout table.
 */

#pragma once

/**
 * @brief One long-note sprite-type layout entry: the batch it draws into, its anchor and size, and
 * the UV-table index it samples.
 *
 * A 24-byte read-only record indexed by the sprite type (0 through 35). The trailing @c // +0xNN
 * comments document the byte offsets within the entry.
 */
struct LongNoteSpriteType {
    /** The sprite batch (0 through 2) this type draws into. +0x00 */
    unsigned int nBatchIndex = {};
    float flAnchorX = {}; /*!< The sprite anchor x. +0x04 */
    float flAnchorY = {}; /*!< The sprite anchor y. +0x08 */
    float flSizeW = {};   /*!< The sprite width. +0x0c */
    float flSizeH = {};   /*!< The sprite height (used by the stretchable body types). +0x10 */
    unsigned int nUvIndex = {}; /*!< The index into the shared sprite-UV table. +0x14 */
};

// The number of long-note sprite types.
constexpr int kLongNoteSpriteTypeCount = 36;

// The type ranges that take their height from the layout table (and scale both axes) rather than
// from the caller's length argument: types below the first bound, and types in the second range.
constexpr int kLongNoteBodyBoundLow = 0x14;
constexpr int kLongNoteBodyRangeStart = 0x18;
constexpr int kLongNoteBodyRangeEnd = 0x22;

// The long-note sprite-type layout table (@ghidraAddress 0x30dfa0): read-only ROM data.
extern const LongNoteSpriteType g_aLongNoteSpriteTypes[kLongNoteSpriteTypeCount];

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
