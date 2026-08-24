/**
 * @file
 * The Limelight result-window parts-data tables and the shared UV-palette table.
 */

#pragma once

#include "../Classic/classic_parts_data_table.h"
#include "parts_data_table.h"
#include "s_vector2.h"

// The maximum number of records the Limelight parts accessor will index (the accessor asserts the
// index is below this bound).
constexpr int kLimelightPartsRecordBound = 255;

// The Limelight result-window parts tables; the pad-versus-phone device kind selects between them.
// The pad table is zero storage in the binary's @c __common segment, seeded at runtime. The phone
// table is not: it is baked read-only data in @c __TEXT,__const and is never written. Only its
// first 142 records exist in the binary, ending at 0x308a40; the accessor's 255 bound is the pad
// table's length, so a phone index at or above 142 over-reads adjacent constant data.
extern PartsDataRecord g_aLimelightPartsPad[kLimelightPartsRecordBound]; // @ghidraAddress 0x3d9100
extern PartsDataRecord
    g_aLimelightPartsPhone[kLimelightPartsRecordBound]; // @ghidraAddress 0x307cf0

// The Limelight phone parts anchor table: one {x, y} anchor per parts slot, zero-initialised in the
// binary's @c __common segment and filled at runtime alongside the phone parts table. Its 8-byte
// stride and count run exactly up to the first phone-layout anchor table.
constexpr int kLimelightPartsAnchorRecordCount = 133;
// @ghidraAddress 0x3da8e8
extern S_VECTOR2 g_aLimelightPartsAnchorPhone[kLimelightPartsAnchorRecordCount];

// The Limelight colour-marker rectangles and their origin, zero-initialised in the binary's
// @c __common segment and filled at runtime. Same shape as the Classic pair: the record count and
// four-float shape are proven by the initialiser's writes, but the individual coordinates' roles
// are not yet recovered, so they carry the shared rectangle field names.
constexpr int kLimelightColorMarkerRectCount = 39;
// @ghidraAddress 0x3ddd90
extern PhoneLayoutRect g_aLimelightColorMarkerRects[kLimelightColorMarkerRectCount];
extern S_VECTOR2 g_LimelightColorMarkerOrigin; // @ghidraAddress 0x3de000

/**
 * @brief One entry of the shared UV-palette table: the texture-coordinate rectangle a part draws
 * from.
 *
 * A part descriptor's @c nUvPaletteIndex selects an entry; the emitter reads its UV origin and UV
 * size to place the sprite's texture rectangle. Each entry is sixteen bytes.
 */
struct UvPaletteEntry {
    float flU = {};        /*!< The U texture coordinate of the rectangle's origin. +0x00 */
    float flV = {};        /*!< The V texture coordinate of the rectangle's origin. +0x04 */
    float flUvWidth = {};  /*!< The U extent of the rectangle. +0x08 */
    float flUvHeight = {}; /*!< The V extent of the rectangle. +0x0c */
};

// The shared UV-palette table indexed by a parts record's UV-palette index. Its length is not
// referenced by the code, so it is declared without a bound.
extern const UvPaletteEntry g_aUvPalette[]; // @ghidraAddress 0x2f2a28

// The Limelight glyph UV-palette table the pad-glyph emitter indexes by a parts record's UV-palette
// index; distinct from the shared part palette above. Read-only ROM data in the binary; its length
// is not referenced by the code.
extern const UvPaletteEntry g_aLimelightGlyphUvPalette[]; // @ghidraAddress 0x2f55a8

// The number of glyph records the pad-glyph emitter will index (the emitter ignores part ids at or
// above this bound).
constexpr int kLimelightPadGlyphRecordBound = 142;

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
