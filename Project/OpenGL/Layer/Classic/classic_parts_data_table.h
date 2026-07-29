/**
 * @file
 * The Classic result-window parts-data tables.
 */

#pragma once

#include "../Colette/phone_anchor_table.h"
#include "../Limelight/limelight_parts_data_table.h"
#include "parts_data_table.h"
#include "s_vector2.h"

// The number of records in the Classic result-window phone parts table (the static one), and the
// upper bound the device-selecting accessor uses for both tables.
constexpr int kClassicPhonePartsRecordCount = 126;
constexpr int kClassicPartsRecordBound = 240;

// The Classic phone parts table: static read-only data embedded in the binary.
extern const PartsDataRecord
    g_aClassicPartsPhone[kClassicPhonePartsRecordCount]; // @ghidraAddress 0x303580

// The Classic pad parts table, zero-initialised in the binary's @c __common segment and filled at
// runtime; the device-selecting accessor uses it on the pad.
extern PartsDataRecord g_aClassicPartsPad[kClassicPartsRecordBound]; // @ghidraAddress 0x3d6650

// The number of records in each Classic phone-layout position and separator table.
constexpr int kClassicPositionRecordCount = 82;
constexpr int kClassicSeparatorRecordCount = 46;

// The Classic phone-layout position tables, zero-initialised in the binary's @c __common segment
// and filled at runtime; the layer's orientation flag selects between them.
extern PhoneAnchorRecord
    g_aClassicPositionPhoneLandscape[kClassicPositionRecordCount]; // @ghidraAddress 0x3d84c0
extern PhoneAnchorRecord
    g_aClassicPositionPhonePortrait[kClassicPositionRecordCount]; // @ghidraAddress 0x3d80e8

// The shared UV-palette table the Classic result window indexes by a parts record's UV-palette
// index; distinct from the Limelight palette. Its length is not referenced by the code.
extern const UvPaletteEntry g_aClassicUvPalette[]; // @ghidraAddress 0x2f1b28

// The glyph UV-palette table the Classic glyph dispatcher indexes by a glyph record's UV-palette
// index (distinct from the part UV palette). Its length is not referenced by the code.
extern const UvPaletteEntry g_aClassicGlyphUvPalette[]; // @ghidraAddress 0x2f4dc8

/**
 * @brief One Classic phone-layout rectangle record: an anchored position, a carried secondary
 * coordinate, and the anchor mode that offsets the position relative to the play-field viewport.
 *
 * Used by the separator, position-by-state, and centre-position accessors. Only the leading
 * coordinate is viewport-anchored; the secondary coordinate (@c flWidth / @c flHeight, names
 * inferred from the separator-bar usage) is copied through verbatim. The tables are zero-initialised
 * in the binary's @c __common segment and filled at runtime. The trailing @c // +0xNN comments
 * document the original member offsets for reference only.
 */
struct PhoneLayoutRecord {
    float flX = {};       /*!< The base X coordinate (viewport-anchored). +0x00 */
    float flY = {};       /*!< The base Y coordinate (viewport-anchored). +0x04 */
    float flWidth = {};   /*!< The carried secondary X coordinate or width. +0x08 */
    float flHeight = {};  /*!< The carried secondary Y coordinate or height. +0x0c */
    int nAnchorMode = {}; /*!< The viewport-relative anchor mode (0 through 8). +0x10 */
};

// One anchored phone-layout rectangle, as returned by the position and centre accessors: the leading
// coordinate after viewport anchoring, plus the record's carried secondary coordinate.
struct PhoneLayoutRect {
    float flX = {};      /*!< The anchored X coordinate. +0x00 */
    float flY = {};      /*!< The anchored Y coordinate. +0x04 */
    float flWidth = {};  /*!< The carried secondary X coordinate or width. +0x08 */
    float flHeight = {}; /*!< The carried secondary Y coordinate or height. +0x0c */
};

// The Classic pad parts anchor table: one {x, y} anchor per parts slot, zero-initialised in the
// binary's @c __common segment and filled at runtime alongside the parts table itself.
constexpr int kClassicPartsAnchorRecordCount = 131;
// @ghidraAddress 0x3d7cd0
extern S_VECTOR2 g_aClassicPartsAnchorPad[kClassicPartsAnchorRecordCount];

// The Classic ribbon-trail vertex storage, zero-initialised in the binary's @c __common segment and
// filled at runtime by the layout initialiser. The layer constructor hands each trail one of the
// four starts listed in the pointer table at 0x3cf458; those starts are 0xa0 apart, so each trail
// owns 20 slots and uses the leading @c kTrailVertexCount of them. The flat extent runs to
// 0x3dd2f8, where the layer singleton pointer begins.
constexpr int kTrailVertexStride = 20;
constexpr int kTrailVertexTotal = 79;
// @ghidraAddress 0x3dd080
extern S_VECTOR2 g_aClassicTrailVertices[kTrailVertexTotal];

// The per-trail vertex counts the constructor reads alongside those starts; every entry is 19.
// @ghidraAddress 0x304190
extern const int g_aClassicTrailVertexCounts[];

// The Classic phone-layout separator tables, zero-initialised in the binary's @c __common segment
// and filled at runtime; the portrait flag selects between them.
extern PhoneLayoutRecord
    g_aClassicSeparatorPhonePortrait[kClassicSeparatorRecordCount]; // @ghidraAddress 0x3d88a0
extern PhoneLayoutRecord
    g_aClassicSeparatorPhoneLandscape[kClassicSeparatorRecordCount]; // @ghidraAddress 0x3d8c40

// The Classic phone-layout position-by-state tables: the state table is used on the iPad, otherwise
// the landscape or portrait table (selected by the orientation flag).
// Zero-initialised in the binary's @c __common segment and filled at runtime; the record count is
// not bounds-checked by the accessor.
extern PhoneLayoutRecord g_aClassicPositionPhoneState[];          // @ghidraAddress 0x3d8fd8
extern PhoneLayoutRecord g_aClassicPositionPhoneStatePortrait[];  // @ghidraAddress 0x3d9030
extern PhoneLayoutRecord g_aClassicPositionPhoneStateLandscape[]; // @ghidraAddress 0x3d9080

// The single Classic phone-layout centre-position records (16-byte, no anchor mode): the state
// record, and the portrait and landscape records (selected by the orientation flag when the state
// flag is clear). Zero-initialised in the binary's @c __common segment and filled at runtime.
extern PhoneLayoutRect g_ClassicCenterPositionPhoneState;     // @ghidraAddress 0x3d90d0
extern PhoneLayoutRect g_ClassicCenterPositionPhonePortrait;  // @ghidraAddress 0x3d90e0
extern PhoneLayoutRect g_ClassicCenterPositionPhoneLandscape; // @ghidraAddress 0x3d90f0

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
