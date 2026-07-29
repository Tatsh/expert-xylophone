/**
 * @file
 * The result-window parts-data record type and its runtime-filled Colette tables.
 */

#pragma once

/**
 * @brief One result-window parts descriptor: a sprite's placement rectangle and the UV-palette
 * entry it draws from.
 *
 * The parts tables are zero-initialised in the binary's @c __common segment and filled at runtime.
 * The trailing @c // +0xNN comments document the original member offsets for reference only.
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

// The number of pad records, and the (larger) number of phone records. The device-selecting
// accessor bounds both at the pad count, while the phone-only accessor bounds at the phone count.
constexpr int kColettePartsRecordCount = 348;
constexpr int kColettePhonePartsRecordCount = 400;

// The Colette result-window parts tables, zero-initialised in the binary's @c __common segment and
// filled at runtime; the pad-versus-phone device kind selects between them.
extern PartsDataRecord g_aColettePartsPad[kColettePartsRecordCount]; // @ghidraAddress 0x3d0010
extern PartsDataRecord
    g_aColettePartsPhone[kColettePhonePartsRecordCount]; // @ghidraAddress 0x3d20b0

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
