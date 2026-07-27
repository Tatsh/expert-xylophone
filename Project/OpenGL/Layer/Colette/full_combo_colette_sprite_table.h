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
    unsigned int nGroup = {};   // +0x00: the sprite batch group (1 or 2) this type draws into.
    float flAnchorX = {};       // +0x04: the sprite anchor x.
    float flAnchorY = {};       // +0x08: the sprite anchor y.
    float flSizeW = {};         // +0x0c: the sprite width.
    float flSizeH = {};         // +0x10: the sprite height.
    unsigned int nUvIndex = {}; // +0x14: the index into the shared sprite-UV table.
};

// The number of Colette full-combo sprite types.
constexpr int kColetteFullComboSpriteTypeCount = 103;

// The Colette full-combo sprite-type descriptor table (@ghidraAddress 0x3005f0): read-only ROM data.
extern const ColetteFullComboSpriteType
    g_aColetteFullComboSpriteTypes[kColetteFullComboSpriteTypeCount];

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
