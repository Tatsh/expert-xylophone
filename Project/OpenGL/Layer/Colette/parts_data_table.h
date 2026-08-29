/**
 * @file
 * The result-window parts-data record type and its runtime-filled Colette tables.
 */

#pragma once

/**
 * One result-window parts descriptor: a sprite's placement rectangle and the UV-palette
 * entry it draws from.
 *
 * The parts tables are zero-initialised in the binary's @c __common segment and filled at runtime.
 * The @c +0xNN notes on each member document the original 32-bit offsets for reference only.
 */
struct PartsDataRecord {
    int nEnabled = {};   /*!< Non-zero when the part is drawn. +0x00 */
    float flX = {};      /*!< The part's X placement offset. +0x04 */
    float flY = {};      /*!< The part's Y placement offset. +0x08 */
    float flWidth = {};  /*!< The part's width, in pixels. +0x0c */
    float flHeight = {}; /*!< The part's height, in pixels. +0x10 */
    /** Index into the UV-palette table for the part's texture rect. +0x14 */
    int nUvPaletteIndex = {};
};

/**
 * The number of pad records in the Colette result-window parts tables.
 *
 * The device-selecting accessor bounds both tables at this pad count.
 */
constexpr int kColettePartsRecordCount = 348;

/**
 * The number of phone records in the Colette result-window parts tables.
 *
 * This is the larger of the two counts; the phone-only accessor bounds at it.
 */
constexpr int kColettePhonePartsRecordCount = 400;

/**
 * The Colette result-window parts table used on the pad.
 *
 * Zero-initialised in the binary's @c __common segment and filled at runtime; the pad-versus-phone
 * device kind selects between this table and @c g_aColettePartsPhone.
 *
 * @ghidraAddress 0x3d0010
 */
extern PartsDataRecord g_aColettePartsPad[kColettePartsRecordCount];

/**
 * The Colette result-window parts table used on the phone.
 *
 * Zero-initialised in the binary's @c __common segment and filled at runtime; the pad-versus-phone
 * device kind selects between this table and @c g_aColettePartsPad.
 *
 * @ghidraAddress 0x3d20b0
 */
extern PartsDataRecord g_aColettePartsPhone[kColettePhonePartsRecordCount];
