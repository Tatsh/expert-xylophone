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
    float flAnchorX = {};       // +0x00: the sprite anchor x.
    float flAnchorY = {};       // +0x04: the sprite anchor y.
    float flSizeW = {};         // +0x08: the sprite width.
    float flSizeH = {};         // +0x0c: the sprite height.
    unsigned int nUvIndex = {}; // +0x10: the index into the shared sprite-UV table.
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
