/**
 * @file
 * The non-phone anchor-box record type and its runtime-filled tables.
 */

#pragma once

#include "../Classic/classic_parts_data_table.h"
#include "s_vector2.h"

/**
 * @brief One non-phone anchor-box record: a base rectangle and the anchor mode that offsets it
 * relative to the play-field viewport.
 *
 * The 20-byte counterpart of @c PhoneAnchorRecord used by the non-phone position accessor. The
 * leading four floats are the rectangle the accessor copies out (an x/y/w/h box); the trailing int
 * is the viewport-relative anchor mode. The tables are zero-initialised in the binary's @c __common
 * segment and filled at runtime by the result-layout-table initialisers. The trailing @c // +0xNN
 * comments document the original member offsets for reference only.
 */
struct AnchorBoxRecord {
    float flX = {};       /*!< The base X coordinate. +0x00 */
    float flY = {};       /*!< The base Y coordinate. +0x04 */
    float flWidth = {};   /*!< The carried box width (or secondary X). +0x08 */
    float flHeight = {};  /*!< The carried box height (or secondary Y). +0x0c */
    int nAnchorMode = {}; /*!< The viewport-relative anchor mode (0 through 8). +0x10 */
};

// The number of records in each non-phone anchor-box table.
constexpr int kAnchorBoxRecordCount = 4;

// The three non-phone anchor-box tables, zero-initialised in the binary's @c __common segment and
// filled at runtime by @c InitializeResultLayoutTables. The pad flag selects the pad table;
// otherwise the orientation flag selects the portrait or default table.
extern AnchorBoxRecord g_aAnchorBoxPad[kAnchorBoxRecordCount];      // @ghidraAddress 0x3d6530
extern AnchorBoxRecord g_aAnchorBoxPortrait[kAnchorBoxRecordCount]; // @ghidraAddress 0x3d6580
extern AnchorBoxRecord g_aAnchorBoxDefault[kAnchorBoxRecordCount];  // @ghidraAddress 0x3d65d0

// The number of records in each Colette phone-layout separator table.
constexpr int kColetteSeparatorRecordCount = 52;

// The Colette phone-layout separator tables (0x14-stride PhoneLayoutRecord), zero-initialised in
// the binary's @c __common segment and filled at runtime; the orientation flag selects between
// them.
// They fill the span between the phone anchor tables and the anchor boxes exactly.
// @ghidraAddress 0x3d5d10
extern PhoneLayoutRecord g_aColetteSeparatorPhoneDefault[kColetteSeparatorRecordCount];
// @ghidraAddress 0x3d6120
extern PhoneLayoutRecord g_aColetteSeparatorPhonePortrait[kColetteSeparatorRecordCount];

// The Colette colour-marker outline and its origin, zero-initialised in the binary's @c __common
// segment and filled at runtime. The same shape as the Limelight pair.
// Four rounded-corner outline paths of nineteen points each on a twenty-point stride, so indices
// 19, 39, and 59 are never written. Each path takes eighteen points from a run of 16-byte pool
// copies and its nineteenth from a register pair; the fourth path's nineteenth lands at 0x3dc590,
// which is @c g_ColetteColorMarkerOrigin, so the array covers indices 0 through 77.
constexpr int kColetteColorMarkerPointCount = 78;
// @ghidraAddress 0x3dc320
extern S_VECTOR2 g_aColetteColorMarkerPoints[kColetteColorMarkerPointCount];
extern S_VECTOR2 g_ColetteColorMarkerOrigin; // @ghidraAddress 0x3dc590

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
