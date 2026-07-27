/**
 * @file
 * The binary-resident part-layout tables for the parts-based title screen, @c TitleLimelightScene.
 */

#pragma once

/**
 * @brief One title-part layout record: the cached-texture index the part binds and its placement
 * rectangle. A 24-byte record; @c TitleLimelightScene::LoadResources reads the texture index to bind
 * each part instancer's texture.
 */
struct TitlePartLayoutRecord {
    int nTextureIndex; // +0x00: the cached-texture index the part binds, doubling as its render-type
                       // selector (0 background, 1 lettered part, 3 logo); an index of 4 or 5 binds
                       // no texture.
    float flPosX;      // +0x04: the part's X position.
    float flPosY;      // +0x08: the part's Y position.
    float flWidth;     // +0x0c: the part's width.
    float flHeight;    // +0x10: the part's height.
    int nUvIndex;      // +0x14: the index into the part's UV-rectangle table.
};

/**
 * @brief The default-device part-layout table (0x53 records).
 * @ghidraAddress 0x309d48
 */
extern const TitlePartLayoutRecord g_aTitle2PartLayoutDefault[];

/**
 * @brief The alt-frame (iPad) part-layout table (0x53 records).
 * @ghidraAddress 0x309580
 */
extern const TitlePartLayoutRecord g_aTitle2PartLayoutAltFrame[];

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
