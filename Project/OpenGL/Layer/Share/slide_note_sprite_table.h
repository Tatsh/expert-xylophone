/**
 * @file
 * The slide-note sprite-type layout table.
 */

#pragma once

/**
 * @brief One slide-note sprite-type layout entry: the batch it draws into, its anchor and size, and
 * the UV-table index it samples.
 *
 * A 24-byte read-only record indexed by the sprite type (0 through 15). The trailing @c // +0xNN
 * comments document the byte offsets within the entry.
 */
struct SlideNoteSpriteType {
    /** The sprite batch (0 through 2) this type draws into. +0x00 */
    unsigned int nBatchIndex = {};
    float flAnchorX = {};       /*!< The sprite anchor x. +0x04 */
    float flAnchorY = {};       /*!< The sprite anchor y. +0x08 */
    float flSizeW = {};         /*!< The sprite width. +0x0c */
    float flSizeH = {};         /*!< The sprite height (used by the head/tail types). +0x10 */
    unsigned int nUvIndex = {}; /*!< The index into the shared sprite-UV table. +0x14 */
};

/** @brief The number of slide-note sprite types. */
constexpr int kSlideNoteSpriteTypeCount = 16;

/**
 * @brief The type index at or above which the caller-supplied height and unit y-scale are used
 * instead of the table's height.
 */
constexpr int kSlideNoteGlowTypeBase = 0xf;

/**
 * @brief The slide-note sprite-type layout table.
 *
 * Read-only ROM data.
 * @ghidraAddress 0x2fee38
 */
extern const SlideNoteSpriteType g_aSlideNoteSpriteTypes[kSlideNoteSpriteTypeCount];

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
