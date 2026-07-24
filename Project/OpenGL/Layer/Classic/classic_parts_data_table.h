/**
 * @file
 * The Classic result-window parts-data tables.
 */

#pragma once

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

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
