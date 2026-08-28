/**
 * @file
 * The shared sprite UV atlas table, indexed by a sprite's atlas-frame number.
 */

#pragma once

/**
 * @brief One record of the shared sprite UV atlas: a quad's UV origin and UV size.
 *
 * The engine's sprite layers index this table by an atlas-frame number to obtain the texture
 * coordinates of a glyph or part within the shared @c gm_parts atlas. The 16-byte stride matches
 * the binary's layout. This is read-only data embedded in the binary.
 */
struct SpriteUvEntry {
    float flOriginU = {}; /*!< The U coordinate of the quad's top-left corner. +0x00 */
    float flOriginV = {}; /*!< The V coordinate of the quad's top-left corner. +0x04 */
    float flSizeU = {};   /*!< The U span added to the origin for the far corner. +0x08 */
    float flSizeV = {};   /*!< The V span added to the origin for the far corner. +0x0c */
};

/**
 * @brief The shared sprite UV atlas the layout records index by atlas-frame number.
 * @ghidraAddress 0x2efcc8
 */
extern const SpriteUvEntry g_aSpriteUvTable[];
