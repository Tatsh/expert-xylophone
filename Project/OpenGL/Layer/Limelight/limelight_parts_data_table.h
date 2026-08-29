/**
 * @file
 * @brief The Limelight result-window parts-data tables and the shared UV-palette table.
 */

#pragma once

#include "../Classic/classic_parts_data_table.h"
#include "parts_data_table.h"
#include "s_vector2.h"

/**
 * @brief The maximum number of records the Limelight parts accessor will index.
 *
 * The accessor asserts the index is below this bound.
 */
constexpr int kLimelightPartsRecordBound = 255;

/**
 * @brief The Limelight result-window parts table used on the pad.
 *
 * The pad-versus-phone device kind selects between this table and @c g_aLimelightPartsPhone. The
 * pad table is zero storage in the binary's @c __common segment, seeded at runtime.
 * @ghidraAddress 0x3d9100
 */
extern PartsDataRecord g_aLimelightPartsPad[kLimelightPartsRecordBound];

/**
 * @brief The Limelight result-window parts table used on the phone.
 *
 * The pad-versus-phone device kind selects between this table and @c g_aLimelightPartsPad. Unlike
 * the pad table this one is not @c __common storage: it is baked read-only data in
 * @c __TEXT,__const and is never written. Only its first 142 records exist in the binary, ending
 * at 0x308a40; the accessor's 255 bound is the pad table's length, so a phone index at or above
 * 142 over-reads adjacent constant data.
 * @ghidraAddress 0x307cf0
 */
extern PartsDataRecord g_aLimelightPartsPhone[kLimelightPartsRecordBound];

/**
 * @brief The number of records in the Limelight phone parts anchor table.
 *
 * Its 8-byte stride and count run exactly up to the first phone-layout anchor table.
 */
constexpr int kLimelightPartsAnchorRecordCount = 133;

/**
 * @brief The Limelight phone parts anchor table: one {x, y} anchor per parts slot.
 *
 * Zero-initialised in the binary's @c __common segment and filled at runtime alongside the phone
 * parts table.
 * @ghidraAddress 0x3da8e8
 */
extern S_VECTOR2 g_aLimelightPartsAnchorPhone[kLimelightPartsAnchorRecordCount];

/**
 * @brief The number of points in the Limelight colour-marker outline.
 *
 * The outline is four rounded-corner paths of nineteen points each, laid out on a twenty-point
 * stride so indices 19, 39, and 59 are never written. The fourth path's nineteenth point lands at
 * 0x3de000, which is @c g_LimelightColorMarkerOrigin, so the array itself covers indices 0 through
 * 77.
 */
constexpr int kLimelightColorMarkerPointCount = 78;

/**
 * @brief The Limelight colour-marker outline points.
 *
 * Each path takes eighteen points from a run of 16-byte pool copies (two points per copy, from
 * 0x2fe560, 0x2fe5f0, 0x2fe680, and 0x2fe710) and its nineteenth from a register pair, which is
 * why a naive nineteen-point read of the pool overruns into the next path. Zero-initialised in the
 * binary's @c __common segment and filled at runtime.
 * @ghidraAddress 0x3ddd90
 */
extern S_VECTOR2 g_aLimelightColorMarkerPoints[kLimelightColorMarkerPointCount];

/**
 * @brief The origin the Limelight colour-marker outline is laid out about.
 *
 * It occupies the slot the fourth path's nineteenth point writes, immediately past the end of
 * @c g_aLimelightColorMarkerPoints.
 * @ghidraAddress 0x3de000
 */
extern S_VECTOR2 g_LimelightColorMarkerOrigin;

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

/**
 * @brief The shared UV-palette table indexed by a parts record's UV-palette index.
 *
 * Its length is not referenced by the code, so it is declared without a bound.
 * @ghidraAddress 0x2f2a28
 */
extern const UvPaletteEntry g_aUvPalette[];

/**
 * @brief The Limelight glyph UV-palette table the pad-glyph emitter indexes by a parts record's
 * UV-palette index.
 *
 * This is distinct from the shared part palette above. Read-only ROM data in the binary; its
 * length is not referenced by the code.
 * @ghidraAddress 0x2f55a8
 */
extern const UvPaletteEntry g_aLimelightGlyphUvPalette[];

/**
 * @brief The number of glyph records the pad-glyph emitter will index.
 *
 * The emitter ignores part ids at or above this bound.
 */
constexpr int kLimelightPadGlyphRecordBound = 142;
