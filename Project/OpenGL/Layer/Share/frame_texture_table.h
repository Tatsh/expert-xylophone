/**
 * @file
 * The play-field frame texture-name table, indexed by frame type.
 */

#pragma once

/**
 * The number of frame types the table names, one per unlockable frame skin.
 */
constexpr int kFrameTextureNameCount = 31;

/**
 * The frame texture-name table, indexed by the frame type.
 *
 * Read-only ROM data. The three theme families occupy contiguous runs: the classic frames are types
 * zero to six, the limelight frames seven to thirteen, and the colette frames fourteen to thirty.
 * The table is the leading half of a larger pointer array whose trailing half is the background
 * texture-name table at @c 0x3ce830 (see @c bg_layer.mm).
 * @ghidraAddress 0x3ce738
 */
extern const char *const g_aFrameTextureNames[kFrameTextureNameCount];
