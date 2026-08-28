/**
 * @file
 * The result-window bonus colour palette shared by the Colette result renderers.
 */

#pragma once

/**
 * @brief One result-bonus colour: a red, green, and blue channel, each in @c [0, 255] as a float.
 */
struct ResultBonusColor {
    float flRed = {};   /*!< The red channel. +0x00 */
    float flGreen = {}; /*!< The green channel. +0x04 */
    float flBlue = {};  /*!< The blue channel. +0x08 */
};

/**
 * @brief The number of colours in the result-bonus palette.
 *
 * The table ends where the per-slot instancer capacity table begins at 0x2fe854, which fixes the
 * count at eleven: seven named tints followed by black, a mid grey, a light grey, and white.
 */
constexpr int kResultBonusColorCount = 11;

/**
 * @brief The result-bonus colour palette, indexed by a bonus/colour index.
 *
 * Read-only ROM data in the binary.
 *
 * @ghidraAddress 0x2fe7d0
 */
extern const ResultBonusColor g_aResultBonusColor[kResultBonusColorCount];

/** @brief The palette entries the result renderers select by index. */
enum ResultBonusColorIndex {
    kResultBonusColorAmber = 0,     /*!< 231, 174, 0. */
    kResultBonusColorOrange = 1,    /*!< 255, 120, 20. */
    kResultBonusColorBlue = 2,      /*!< 34, 149, 238. */
    kResultBonusColorGreen = 3,     /*!< 34, 150, 31. */
    kResultBonusColorPurple = 4,    /*!< 180, 94, 191. */
    kResultBonusColorTaupe = 5,     /*!< 115, 101, 85. */
    kResultBonusColorMagenta = 6,   /*!< 252, 86, 244. */
    kResultBonusColorBlack = 7,     /*!< 0, 0, 0. */
    kResultBonusColorMidGray = 8,   /*!< 128, 128, 128. */
    kResultBonusColorLightGray = 9, /*!< 192, 192, 192. */
    kResultBonusColorWhite = 10,    /*!< 255, 255, 255. */
};
