/**
 * @file
 * The non-phone anchor-box record type and its runtime-filled tables.
 */

#pragma once

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
    float flX = {};       // +0x00: the base X coordinate.
    float flY = {};       // +0x04: the base Y coordinate.
    float flWidth = {};   // +0x08: the carried box width (or secondary X).
    float flHeight = {};  // +0x0c: the carried box height (or secondary Y).
    int nAnchorMode = {}; // +0x10: the viewport-relative anchor mode (0 through 8).
};

// The number of records in each non-phone anchor-box table.
constexpr int kAnchorBoxRecordCount = 4;

// The three non-phone anchor-box tables, zero-initialised in the binary's @c __common segment and
// filled at runtime by @c InitializeResultLayoutTables. The pad flag selects the pad table; otherwise
// the orientation flag selects the portrait or default table.
extern AnchorBoxRecord g_aAnchorBoxPad[kAnchorBoxRecordCount];      // @ghidraAddress 0x3d6530
extern AnchorBoxRecord g_aAnchorBoxPortrait[kAnchorBoxRecordCount]; // @ghidraAddress 0x3d6580
extern AnchorBoxRecord g_aAnchorBoxDefault[kAnchorBoxRecordCount];  // @ghidraAddress 0x3d65d0

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
