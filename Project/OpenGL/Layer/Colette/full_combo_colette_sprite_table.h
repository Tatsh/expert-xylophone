/**
 * @file
 * The Colette full-combo sprite-type descriptor table.
 */

#pragma once

/**
 * @brief One Colette full-combo sprite-type descriptor: the batch group it draws into, its anchor
 * and size, and the UV-table index it samples.
 *
 * A 24-byte read-only record indexed by the sprite type (0 through 102). The trailing @c // +0xNN
 * comments document the byte offsets within the record.
 */
struct ColetteFullComboSpriteType {
    unsigned int nGroup = {};   /*!< The sprite batch group (1 or 2) this type draws into. +0x00 */
    float flAnchorX = {};       /*!< The sprite anchor x. +0x04 */
    float flAnchorY = {};       /*!< The sprite anchor y. +0x08 */
    float flSizeW = {};         /*!< The sprite width. +0x0c */
    float flSizeH = {};         /*!< The sprite height. +0x10 */
    unsigned int nUvIndex = {}; /*!< The index into the shared sprite-UV table. +0x14 */
};

/** @brief The number of Colette full-combo sprite types. */
constexpr int kColetteFullComboSpriteTypeCount = 103;

/**
 * @brief The Colette full-combo sprite-type descriptor table, indexed by the sprite type.
 *
 * Read-only ROM data in the binary.
 *
 * @ghidraAddress 0x3005f0
 */
extern const ColetteFullComboSpriteType
    g_aColetteFullComboSpriteTypes[kColetteFullComboSpriteTypeCount];

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
