/**
 * @file
 * The shared sprite UV atlas table, indexed by a sprite's atlas-frame number.
 */

#pragma once

/**
 * @brief One record of the shared sprite UV atlas: a quad's UV origin and UV size.
 *
 * The engine's sprite layers index this table by an atlas-frame number to obtain the texture
 * coordinates of a glyph or part within the shared @c gm_parts atlas. The 16-byte stride matches the
 * binary's layout. This is read-only data embedded in the binary.
 */
struct SpriteUvEntry {
    float flOriginU = {}; // +0x00: the U coordinate of the quad's top-left corner.
    float flOriginV = {}; // +0x04: the V coordinate of the quad's top-left corner.
    float flSizeU = {};   // +0x08: the U span added to the origin for the quad's far corner.
    float flSizeV = {};   // +0x0c: the V span added to the origin for the quad's far corner.
};

// The shared sprite UV atlas the layout records index by atlas-frame number.
extern const SpriteUvEntry g_aSpriteUvTable[]; // @ghidraAddress 0x2efcc8

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
