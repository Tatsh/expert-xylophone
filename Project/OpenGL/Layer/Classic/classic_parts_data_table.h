/**
 * @file
 * The Classic result-window parts-data tables.
 */

#pragma once

#include "../Colette/phone_anchor_table.h"
#include "../Limelight/limelight_parts_data_table.h"
#include "parts_data_table.h"
#include "s_vector2.h"

/**
 * @brief The number of records in the Classic result-window phone parts table (the static one).
 */
constexpr int kClassicPhonePartsRecordCount = 126;
/**
 * @brief The upper bound the device-selecting accessor uses for both Classic parts tables.
 */
constexpr int kClassicPartsRecordBound = 240;

/**
 * @brief The Classic phone parts table: static read-only data embedded in the binary.
 * @ghidraAddress 0x303580
 */
extern const PartsDataRecord g_aClassicPartsPhone[kClassicPhonePartsRecordCount];

/**
 * @brief The Classic pad parts table, which the device-selecting accessor uses on the pad.
 *
 * Zero-initialised in the binary's @c __common segment and filled at runtime.
 * @ghidraAddress 0x3d6650
 */
extern PartsDataRecord g_aClassicPartsPad[kClassicPartsRecordBound];

/** @brief The number of records in each Classic phone-layout position table. */
constexpr int kClassicPositionRecordCount = 82;
/** @brief The number of records in each Classic phone-layout separator table. */
constexpr int kClassicSeparatorRecordCount = 46;

/**
 * @brief The Classic phone-layout position table for landscape orientation.
 *
 * Zero-initialised in the binary's @c __common segment and filled at runtime; the layer's
 * orientation flag selects between the landscape and portrait tables.
 * @ghidraAddress 0x3d84c0
 */
extern PhoneAnchorRecord g_aClassicPositionPhoneLandscape[kClassicPositionRecordCount];
/**
 * @brief The Classic phone-layout position table for portrait orientation.
 *
 * Zero-initialised in the binary's @c __common segment and filled at runtime; the layer's
 * orientation flag selects between the landscape and portrait tables.
 * @ghidraAddress 0x3d80e8
 */
extern PhoneAnchorRecord g_aClassicPositionPhonePortrait[kClassicPositionRecordCount];

/**
 * @brief The shared UV-palette table the Classic result window indexes by a parts record's
 * UV-palette index.
 *
 * Distinct from the Limelight palette. Its length is not referenced by the code.
 * @ghidraAddress 0x2f1b28
 */
extern const UvPaletteEntry g_aClassicUvPalette[];

/**
 * @brief The glyph UV-palette table the Classic glyph dispatcher indexes by a glyph record's
 * UV-palette index.
 *
 * Distinct from the part UV palette. Its length is not referenced by the code.
 * @ghidraAddress 0x2f4dc8
 */
extern const UvPaletteEntry g_aClassicGlyphUvPalette[];

/**
 * @brief One Classic phone-layout rectangle record: an anchored position, a carried secondary
 * coordinate, and the anchor mode that offsets the position relative to the play-field viewport.
 *
 * Used by the separator, position-by-state, and centre-position accessors. Only the leading
 * coordinate is viewport-anchored; the secondary coordinate (@c flWidth / @c flHeight, names
 * inferred from the separator-bar usage) is copied through verbatim. The tables are
 * zero-initialised in the binary's @c __common segment and filled at runtime. The @c +0xNN notes
 * on each member document the original 32-bit offsets for reference only.
 */
struct PhoneLayoutRecord {
    float flX = {};       /*!< The base X coordinate (viewport-anchored). +0x00 */
    float flY = {};       /*!< The base Y coordinate (viewport-anchored). +0x04 */
    float flWidth = {};   /*!< The carried secondary X coordinate or width. +0x08 */
    float flHeight = {};  /*!< The carried secondary Y coordinate or height. +0x0c */
    int nAnchorMode = {}; /*!< The viewport-relative anchor mode (0 through 8). +0x10 */
};

/**
 * @brief One anchored phone-layout rectangle, as returned by the position and centre accessors.
 *
 * Holds the leading coordinate after viewport anchoring, plus the record's carried secondary
 * coordinate. The @c +0xNN notes on each member document the original 32-bit offsets for reference
 * only.
 */
struct PhoneLayoutRect {
    float flX = {};      /*!< The anchored X coordinate. +0x00 */
    float flY = {};      /*!< The anchored Y coordinate. +0x04 */
    float flWidth = {};  /*!< The carried secondary X coordinate or width. +0x08 */
    float flHeight = {}; /*!< The carried secondary Y coordinate or height. +0x0c */
};

/** @brief The number of records in the Classic pad parts anchor table. */
constexpr int kClassicPartsAnchorRecordCount = 131;
/**
 * @brief The Classic pad parts anchor table: one {x, y} anchor per parts slot.
 *
 * Zero-initialised in the binary's @c __common segment and filled at runtime alongside the parts
 * table itself.
 * @ghidraAddress 0x3d7cd0
 */
extern S_VECTOR2 g_aClassicPartsAnchorPad[kClassicPartsAnchorRecordCount];

/** @brief The number of vertex slots each Classic ribbon trail owns. */
constexpr int kTrailVertexStride = 20;
/** @brief The total number of vertex slots in the Classic ribbon-trail storage. */
constexpr int kTrailVertexTotal = 79;
/**
 * @brief The Classic ribbon-trail vertex storage.
 *
 * Zero-initialised in the binary's @c __common segment and filled at runtime by the layout
 * initialiser. The layer constructor hands each trail one of the four starts listed in the pointer
 * table at 0x3cf458; those starts are 0xa0 apart, so each trail owns 20 slots and uses the leading
 * @c kTrailVertexCount of them. The flat extent runs to 0x3dd2f8, where the layer singleton
 * pointer begins.
 * @ghidraAddress 0x3dd080
 */
extern S_VECTOR2 g_aClassicTrailVertices[kTrailVertexTotal];

/**
 * @brief The per-trail vertex counts the constructor reads alongside those starts.
 *
 * Every entry is 19.
 * @ghidraAddress 0x304190
 */
extern const int g_aClassicTrailVertexCounts[];

/**
 * @brief The Classic phone-layout separator table for portrait orientation.
 *
 * Zero-initialised in the binary's @c __common segment and filled at runtime; the portrait flag
 * selects between the portrait and landscape tables.
 * @ghidraAddress 0x3d88a0
 */
extern PhoneLayoutRecord g_aClassicSeparatorPhonePortrait[kClassicSeparatorRecordCount];
/**
 * @brief The Classic phone-layout separator table for landscape orientation.
 *
 * Zero-initialised in the binary's @c __common segment and filled at runtime; the portrait flag
 * selects between the portrait and landscape tables.
 * @ghidraAddress 0x3d8c40
 */
extern PhoneLayoutRecord g_aClassicSeparatorPhoneLandscape[kClassicSeparatorRecordCount];

/**
 * @brief The Classic phone-layout position-by-state table, used on the iPad.
 *
 * Zero-initialised in the binary's @c __common segment and filled at runtime; the record count is
 * not bounds-checked by the accessor.
 * @ghidraAddress 0x3d8fd8
 */
extern PhoneLayoutRecord g_aClassicPositionPhoneState[];
/**
 * @brief The Classic phone-layout position-by-state table for portrait orientation.
 *
 * Used instead of the state table off the iPad, selected by the orientation flag. Zero-initialised
 * in the binary's @c __common segment and filled at runtime; the record count is not
 * bounds-checked by the accessor.
 * @ghidraAddress 0x3d9030
 */
extern PhoneLayoutRecord g_aClassicPositionPhoneStatePortrait[];
/**
 * @brief The Classic phone-layout position-by-state table for landscape orientation.
 *
 * Used instead of the state table off the iPad, selected by the orientation flag. Zero-initialised
 * in the binary's @c __common segment and filled at runtime; the record count is not
 * bounds-checked by the accessor.
 * @ghidraAddress 0x3d9080
 */
extern PhoneLayoutRecord g_aClassicPositionPhoneStateLandscape[];

/**
 * @brief The single Classic phone-layout centre-position record for the state case (16-byte, no
 * anchor mode).
 *
 * Zero-initialised in the binary's @c __common segment and filled at runtime.
 * @ghidraAddress 0x3d90d0
 */
extern PhoneLayoutRect g_ClassicCenterPositionPhoneState;
/**
 * @brief The single Classic phone-layout centre-position record for portrait orientation (16-byte,
 * no anchor mode).
 *
 * Selected by the orientation flag when the state flag is clear. Zero-initialised in the binary's
 * @c __common segment and filled at runtime.
 * @ghidraAddress 0x3d90e0
 */
extern PhoneLayoutRect g_ClassicCenterPositionPhonePortrait;
/**
 * @brief The single Classic phone-layout centre-position record for landscape orientation
 * (16-byte, no anchor mode).
 *
 * Selected by the orientation flag when the state flag is clear. Zero-initialised in the binary's
 * @c __common segment and filled at runtime.
 * @ghidraAddress 0x3d90f0
 */
extern PhoneLayoutRect g_ClassicCenterPositionPhoneLandscape;
