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

// The Limelight colour-marker outline: four rounded-corner paths of nineteen points each, laid out
// on a twenty-point stride so indices 19, 39, and 59 are never written. Each path takes eighteen
// points from a run of 16-byte pool copies (two points per copy, from 0x2fe560, 0x2fe5f0, 0x2fe680,
// and 0x2fe710) and its nineteenth from a register pair, which is why a naive nineteen-point read
// of the pool overruns into the next path. The fourth path's nineteenth point lands at 0x3de000,
// which is @c g_LimelightColorMarkerOrigin, so the array itself covers indices 0 through 77.
// Zero-initialised in the binary's @c __common segment and filled at runtime.
constexpr int kLimelightColorMarkerPointCount = 78;
// @ghidraAddress 0x3ddd90
extern S_VECTOR2 g_aLimelightColorMarkerPoints[kLimelightColorMarkerPointCount];
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
