/**
 * @file
 * The Classic full-combo sprite-type descriptor table.
 */

#pragma once

/**
 * @brief One Classic full-combo sprite-type descriptor: the sprite's anchor and size, and the
 * UV-table index it samples.
 *
 * A 20-byte read-only record indexed by the sprite type (0 through 15); the batch the sprite draws
 * into is chosen separately by the object type, not this record. The trailing @c // +0xNN comments
 * document the byte offsets within the record.
 */
struct ClassicFullComboSpriteType {
    float flAnchorX = {};       /*!< The sprite anchor x. +0x00 */
    float flAnchorY = {};       /*!< The sprite anchor y. +0x04 */
    float flSizeW = {};         /*!< The sprite width. +0x08 */
    float flSizeH = {};         /*!< The sprite height. +0x0c */
    unsigned int nUvIndex = {}; /*!< The index into the shared sprite-UV table. +0x10 */
};

// The number of Classic full-combo sprite types, and the number of object types (each selecting a
// distinct sprite batch).
constexpr int kClassicFullComboSpriteTypeCount = 16;
constexpr int kClassicFullComboObjectTypeCount = 3;

// The Classic full-combo sprite-type descriptor table (@ghidraAddress 0x302bf8): read-only ROM data.
extern const ClassicFullComboSpriteType
    g_aClassicFullComboSpriteTypes[kClassicFullComboSpriteTypeCount];

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
