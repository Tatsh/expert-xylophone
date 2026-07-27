/**
 * @file
 * The slide-note sprite-type layout table.
 */

#pragma once

/**
 * @brief One slide-note sprite-type layout entry: the batch it draws into, its anchor and size, and
 * the UV-table index it samples.
 *
 * A 24-byte read-only record indexed by the sprite type (0 through 15). The trailing @c // +0xNN
 * comments document the byte offsets within the entry.
 */
struct SlideNoteSpriteType {
    unsigned int nBatchIndex = {}; // +0x00: the sprite batch (0 through 2) this type draws into.
    float flAnchorX = {};          // +0x04: the sprite anchor x.
    float flAnchorY = {};          // +0x08: the sprite anchor y.
    float flSizeW = {};            // +0x0c: the sprite width.
    float flSizeH = {};            // +0x10: the sprite height (used by the head/tail types).
    unsigned int nUvIndex = {};    // +0x14: the index into the shared sprite-UV table.
};

// The number of slide-note sprite types, and the type index at or above which the caller-supplied
// height and unit y-scale are used instead of the table's height.
constexpr int kSlideNoteSpriteTypeCount = 16;
constexpr int kSlideNoteGlowTypeBase = 0xf;

// The slide-note sprite-type layout table (@ghidraAddress 0x2fee38): read-only ROM data.
extern const SlideNoteSpriteType g_aSlideNoteSpriteTypes[kSlideNoteSpriteTypeCount];

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
