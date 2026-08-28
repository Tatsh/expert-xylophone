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

/** @brief The number of records in each non-phone anchor-box table. */
constexpr int kAnchorBoxRecordCount = 4;

/**
 * @brief The non-phone anchor-box table used on the pad.
 *
 * Zero-initialised in the binary's @c __common segment and filled at runtime by
 * @c InitializeResultLayoutTables. The pad flag selects this table; otherwise the orientation flag
 * selects @c g_aAnchorBoxPortrait or @c g_aAnchorBoxDefault.
 *
 * @ghidraAddress 0x3d6530
 */
extern AnchorBoxRecord g_aAnchorBoxPad[kAnchorBoxRecordCount];

/**
 * @brief The non-phone anchor-box table used off the pad in portrait orientation.
 *
 * Zero-initialised in the binary's @c __common segment and filled at runtime by
 * @c InitializeResultLayoutTables. The orientation flag selects it once the pad flag is clear.
 *
 * @ghidraAddress 0x3d6580
 */
extern AnchorBoxRecord g_aAnchorBoxPortrait[kAnchorBoxRecordCount];

/**
 * @brief The default non-phone anchor-box table, used off the pad outside portrait orientation.
 *
 * Zero-initialised in the binary's @c __common segment and filled at runtime by
 * @c InitializeResultLayoutTables. It is the fallback once the pad flag and the orientation flag
 * are both clear.
 *
 * @ghidraAddress 0x3d65d0
 */
extern AnchorBoxRecord g_aAnchorBoxDefault[kAnchorBoxRecordCount];

/** @brief The number of records in each Colette phone-layout separator table. */
constexpr int kColetteSeparatorRecordCount = 52;

/**
 * @brief The Colette phone-layout separator table used in the default orientation.
 *
 * A 0x14-stride @c PhoneLayoutRecord table, zero-initialised in the binary's @c __common segment
 * and filled at runtime; the orientation flag selects between it and
 * @c g_aColetteSeparatorPhonePortrait. Together the two fill the span between the phone anchor
 * tables and the anchor boxes exactly.
 *
 * @ghidraAddress 0x3d5d10
 */
extern PhoneLayoutRecord g_aColetteSeparatorPhoneDefault[kColetteSeparatorRecordCount];

/**
 * @brief The Colette phone-layout separator table used in portrait orientation.
 *
 * A 0x14-stride @c PhoneLayoutRecord table, zero-initialised in the binary's @c __common segment
 * and filled at runtime; the orientation flag selects between it and
 * @c g_aColetteSeparatorPhoneDefault. Together the two fill the span between the phone anchor
 * tables and the anchor boxes exactly.
 *
 * @ghidraAddress 0x3d6120
 */
extern PhoneLayoutRecord g_aColetteSeparatorPhonePortrait[kColetteSeparatorRecordCount];

/**
 * @brief The number of points in the Colette colour-marker outline array.
 *
 * Four rounded-corner outline paths of nineteen points each on a twenty-point stride, so indices
 * 19, 39, and 59 are never written. Each path takes eighteen points from a run of 16-byte pool
 * copies and its nineteenth from a register pair; the fourth path's nineteenth lands at 0x3dc590,
 * which is @c g_ColetteColorMarkerOrigin, so the array covers indices 0 through 77.
 */
constexpr int kColetteColorMarkerPointCount = 78;

/**
 * @brief The Colette colour-marker outline points.
 *
 * Zero-initialised in the binary's @c __common segment and filled at runtime. The same shape as
 * the Limelight pair.
 *
 * @ghidraAddress 0x3dc320
 */
extern S_VECTOR2 g_aColetteColorMarkerPoints[kColetteColorMarkerPointCount];

/**
 * @brief The origin of the Colette colour marker.
 *
 * Zero-initialised in the binary's @c __common segment and filled at runtime, in the slot directly
 * after the outline points. The same shape as the Limelight pair.
 *
 * @ghidraAddress 0x3dc590
 */
extern S_VECTOR2 g_ColetteColorMarkerOrigin;
