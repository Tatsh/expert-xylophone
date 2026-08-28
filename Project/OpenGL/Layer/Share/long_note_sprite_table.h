/**
 * @file
 * The long-note sprite-type layout table.
 */

#pragma once

/**
 * @brief One long-note sprite-type layout entry: the batch it draws into, its anchor and size, and
 * the UV-table index it samples.
 *
 * A 24-byte read-only record indexed by the sprite type (0 through 35). The trailing @c // +0xNN
 * comments document the byte offsets within the entry.
 */
struct LongNoteSpriteType {
    /** The sprite batch (0 through 2) this type draws into. +0x00 */
    unsigned int nBatchIndex = {};
    float flAnchorX = {}; /*!< The sprite anchor x. +0x04 */
    float flAnchorY = {}; /*!< The sprite anchor y. +0x08 */
    float flSizeW = {};   /*!< The sprite width. +0x0c */
    float flSizeH = {};   /*!< The sprite height (used by the stretchable body types). +0x10 */
    unsigned int nUvIndex = {}; /*!< The index into the shared sprite-UV table. +0x14 */
};

/** @brief The number of long-note sprite types. */
constexpr int kLongNoteSpriteTypeCount = 36;

/**
 * @brief The exclusive upper bound of the first type range that takes its height from the layout
 * table (and scales both axes) rather than from the caller's length argument.
 */
constexpr int kLongNoteBodyBoundLow = 0x14;

/**
 * @brief The inclusive start of the second type range that takes its height from the layout table
 * (and scales both axes) rather than from the caller's length argument.
 */
constexpr int kLongNoteBodyRangeStart = 0x18;

/**
 * @brief The exclusive end of the second type range that takes its height from the layout table
 * (and scales both axes) rather than from the caller's length argument.
 */
constexpr int kLongNoteBodyRangeEnd = 0x22;

/**
 * @brief The long-note sprite-type layout table.
 *
 * Read-only ROM data.
 * @ghidraAddress 0x30dfa0
 */
extern const LongNoteSpriteType g_aLongNoteSpriteTypes[kLongNoteSpriteTypeCount];
