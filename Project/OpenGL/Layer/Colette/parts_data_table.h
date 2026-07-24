/**
 * @file
 * The result-window parts-data record type and its runtime-filled Colette tables.
 */

#pragma once

/**
 * @brief One result-window parts descriptor: a sprite's placement rectangle and the UV-palette
 * entry it draws from.
 *
 * The parts tables are zero-initialised in the binary's @c __common segment and filled at runtime.
 * The trailing @c // +0xNN comments document the original member offsets for reference only.
 */
struct PartsDataRecord {
    int nEnabled = {};        // +0x00: non-zero when the part is drawn.
    float flX = {};           // +0x04: the part's X placement offset.
    float flY = {};           // +0x08: the part's Y placement offset.
    float flWidth = {};       // +0x0c: the part's width, in pixels.
    float flHeight = {};      // +0x10: the part's height, in pixels.
    int nUvPaletteIndex = {}; // +0x14: index into the UV-palette table for the part's texture rect.
};

// The number of records in each Colette result-window parts table.
constexpr unsigned int kColettePartsRecordCount = 348;

// The Colette result-window parts tables, zero-initialised in the binary's @c __common segment and
// filled at runtime; the pad-versus-phone device kind selects between them.
extern PartsDataRecord g_aColettePartsPad[kColettePartsRecordCount];   // @ghidraAddress 0x3d0010
extern PartsDataRecord g_aColettePartsPhone[kColettePartsRecordCount]; // @ghidraAddress 0x3d20b0

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
