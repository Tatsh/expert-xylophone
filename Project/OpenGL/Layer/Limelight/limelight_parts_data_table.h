/**
 * @file
 * The Limelight result-window parts-data tables and the shared UV-palette table.
 */

#pragma once

#include "parts_data_table.h"

// The maximum number of records the Limelight parts accessor will index (the accessor asserts the
// index is below this bound).
constexpr int kLimelightPartsRecordBound = 255;

// The Limelight result-window parts tables, zero-initialised in the binary's @c __common segment and
// filled at runtime; the pad-versus-phone device kind selects between them.
extern PartsDataRecord
    g_aLimelightPartsPhone[kLimelightPartsRecordBound];                  // @ghidraAddress 0x3d9100
extern PartsDataRecord g_aLimelightPartsPad[kLimelightPartsRecordBound]; // @ghidraAddress 0x307cf0

/**
 * @brief One entry of the shared UV-palette table: the texture-coordinate rectangle a part draws
 * from.
 *
 * A part descriptor's @c nUvPaletteIndex selects an entry; the emitter reads its UV origin and UV
 * size to place the sprite's texture rectangle. Each entry is sixteen bytes.
 */
struct UvPaletteEntry {
    float flU = {};        // +0x00: the U texture coordinate of the rectangle's origin.
    float flV = {};        // +0x04: the V texture coordinate of the rectangle's origin.
    float flUvWidth = {};  // +0x08: the U extent of the rectangle.
    float flUvHeight = {}; // +0x0c: the V extent of the rectangle.
};

// The shared UV-palette table indexed by a parts record's UV-palette index. Its length is not
// referenced by the code, so it is declared without a bound.
extern const UvPaletteEntry g_aUvPalette[]; // @ghidraAddress 0x2f2a28

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
