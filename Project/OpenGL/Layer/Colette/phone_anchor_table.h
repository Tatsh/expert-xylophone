/**
 * @file
 * The phone-layout anchor-position record type and its runtime-filled tables.
 */

#pragma once

/**
 * One phone-layout anchor-position record: a base coordinate and the anchor mode that
 * offsets it relative to the play-field viewport.
 *
 * The record tables are zero-initialised in the binary's @c __common segment and filled at runtime
 * by the result-layout-table initialisers. The trailing @c +0xNN comments document the original
 * member offsets for reference only.
 */
struct PhoneAnchorRecord {
    float flX = {};       /*!< The base X coordinate. +0x00 */
    float flY = {};       /*!< The base Y coordinate. +0x04 */
    int nAnchorMode = {}; /*!< The viewport-relative anchor mode (0 through 8). +0x08 */
};

/** The number of records in each phone-layout anchor-position table. */
constexpr int kPhoneAnchorRecordCount = 168;

/**
 * The phone-layout anchor-position table used in portrait orientation.
 *
 * Zero-initialised in the binary's @c __common segment and filled at runtime by the
 * result-layout-table initialisers; the portrait flag selects between it and
 * @c g_aPhoneAnchorDefault.
 *
 * @ghidraAddress 0x3d4d50
 */
extern PhoneAnchorRecord g_aPhoneAnchorPortrait[kPhoneAnchorRecordCount];

/**
 * The default phone-layout anchor-position table, used outside portrait orientation.
 *
 * Zero-initialised in the binary's @c __common segment and filled at runtime by the
 * result-layout-table initialisers; the portrait flag selects between it and
 * @c g_aPhoneAnchorPortrait.
 *
 * @ghidraAddress 0x3d5530
 */
extern PhoneAnchorRecord g_aPhoneAnchorDefault[kPhoneAnchorRecordCount];
