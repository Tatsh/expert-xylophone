/**
 * @file
 * The phone-layout anchor-position record type and its runtime-filled tables.
 */

#pragma once

/**
 * @brief One phone-layout anchor-position record: a base coordinate and the anchor mode that offsets
 * it relative to the play-field viewport.
 *
 * The record tables are zero-initialised in the binary's @c __common segment and filled at runtime
 * by the result-layout-table initialisers. The trailing @c // +0xNN comments document the original
 * member offsets for reference only.
 */
struct PhoneAnchorRecord {
    float flX = {};       // +0x00: the base X coordinate.
    float flY = {};       // +0x04: the base Y coordinate.
    int nAnchorMode = {}; // +0x08: the viewport-relative anchor mode (0 through 8).
};

// The number of records in each phone-layout anchor-position table.
constexpr unsigned int kPhoneAnchorRecordCount = 168;

// The phone-layout anchor-position tables, zero-initialised in the binary's @c __common segment and
// filled at runtime by the result-layout-table initialisers; the portrait flag selects between them.
extern PhoneAnchorRecord g_aPhoneAnchorPortrait[kPhoneAnchorRecordCount]; // @ghidraAddress 0x3d4d50
extern PhoneAnchorRecord g_aPhoneAnchorDefault[kPhoneAnchorRecordCount];  // @ghidraAddress 0x3d5530

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
