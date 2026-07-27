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
    unsigned int nBatchIndex = {}; // +0x00: the sprite batch (0 through 2) this type draws into.
    float flAnchorX = {};          // +0x04: the sprite anchor x.
    float flAnchorY = {};          // +0x08: the sprite anchor y.
    float flSizeW = {};            // +0x0c: the sprite width.
    float flSizeH = {};            // +0x10: the sprite height (used by the stretchable body types).
    unsigned int nUvIndex = {};    // +0x14: the index into the shared sprite-UV table.
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
