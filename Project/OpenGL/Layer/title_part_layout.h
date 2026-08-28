/**
 * @file
 * The binary-resident part-layout tables for the parts-based title screen, @c TitleLimelightScene.
 */

#pragma once

#include "sprite_uv_table.h"

/**
 * @brief One title-part layout record: the cached-texture index the part binds and its placement
 * rectangle. A 24-byte record; @c TitleLimelightScene::LoadResources reads the texture index to
 * bind each part instancer's texture.
 */
struct TitlePartLayoutRecord {
    /**
     * @brief The cached-texture index the part binds, doubling as its render-type selector
     * (0 background, 1 lettered part, 3 logo); an index of 4 or 5 binds no texture. +0x00
     */
    int nTextureIndex;
    float flPosX;   /*!< The part's X position. +0x04 */
    float flPosY;   /*!< The part's Y position. +0x08 */
    float flWidth;  /*!< The part's width. +0x0c */
    float flHeight; /*!< The part's height. +0x10 */
    int nUvIndex;   /*!< The index into the part's UV-rectangle table. +0x14 */
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

/**
 * @brief The lettered/logo parts' UV atlas for the default device (45 records). A part indexes this
 * (through its layout record's UV index) when its anchor mode is one and the alt flag is clear.
 * @ghidraAddress 0x2f7638
 */
extern const SpriteUvEntry g_aTitle2PartUvMain[];

/**
 * @brief The lettered/logo parts' UV atlas for the alt-frame (iPad) device (45 records). A part
 * indexes this when its anchor mode is one and the alt flag is set.
 * @ghidraAddress 0x2f7368
 */
extern const SpriteUvEntry g_aTitle2PartUvAlt[];
