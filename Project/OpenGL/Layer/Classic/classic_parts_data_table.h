/**
 * @file
 * The Classic result-window parts-data tables.
 */

#pragma once

#include "../Colette/phone_anchor_table.h"
#include "../Limelight/limelight_parts_data_table.h"
#include "parts_data_table.h"

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

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
