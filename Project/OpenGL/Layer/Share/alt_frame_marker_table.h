/**
 * @file
 * The alternate play-field frame's lane-marker layout tables, seeded at load time and read by the
 * alt-frame layer's build and render passes.
 */

#pragma once

#include "sprite_uv_table.h"

/**
 * @brief One alt-frame lane-marker layout record: the sprite-kind row it draws from and its base
 * placement.
 *
 * The base Y is seeded relative to the play-field layout centre split; the render pass offsets it
 * by the screen height each frame. The 24-byte stride matches the binary's layout.
 */
struct AltFrameMarkerLayout {
    /** The sprite-kind row (indexes the alt-frame sprite-kind table). +0x00 */
    int nSpriteKind = {};
    float flX = {};        /*!< The marker's base X. +0x04 */
    float flY = {};        /*!< The marker's base Y (relative to the layout centre split). +0x08 */
    float flRotation = {}; /*!< The marker's rotation, in radians. +0x0c */
    float flScaleX = {};   /*!< The marker's X scale. +0x10 */
    float flScaleY = {};   /*!< The marker's Y scale. +0x14 */
};

/** @brief The number of records in the low-tier marker layout table. */
constexpr int kAltFrameMarkerCount4 = 10;
/** @brief The number of records in the mid-tier marker layout table. */
constexpr int kAltFrameMarkerCount6 = 14;
/** @brief The number of records in the high-tier marker layout table. */
constexpr int kAltFrameMarkerCount9 = 12;

/**
 * @brief The low-tier alt-frame marker layout table.
 *
 * One of the three tables selected by the frame's lane count (the low, mid, and high difficulty
 * tiers). Seeded once at load by the layout-table constructor.
 * @ghidraAddress 0x3dbec8
 */
extern AltFrameMarkerLayout g_aAltFrameMarker4[kAltFrameMarkerCount4];

/**
 * @brief The mid-tier alt-frame marker layout table.
 *
 * One of the three tables selected by the frame's lane count (the low, mid, and high difficulty
 * tiers). Seeded once at load by the layout-table constructor.
 * @ghidraAddress 0x3dbfb8
 */
extern AltFrameMarkerLayout g_aAltFrameMarker6[kAltFrameMarkerCount6];

/**
 * @brief The high-tier alt-frame marker layout table.
 *
 * One of the three tables selected by the frame's lane count (the low, mid, and high difficulty
 * tiers). Seeded once at load by the layout-table constructor.
 * @ghidraAddress 0x3dc108
 */
extern AltFrameMarkerLayout g_aAltFrameMarker9[kAltFrameMarkerCount9];

/**
 * @brief One alt-frame sprite descriptor: which sprite batch it belongs to, its anchor and pixel
 * size, and the UV atlas frame it draws from.
 *
 * Static read-only data embedded in the binary. Each marker's sprite-kind row indexes one of the
 * descriptor tables (paired with the layout tables above by difficulty tier). The 24-byte stride
 * matches the binary's layout.
 */
struct AltFrameSpriteDescriptor {
    int nBatch = {}; /*!< The sprite batch (instancer) index this descriptor draws into. +0x00 */
    float flAnchorX = {};   /*!< The sprite anchor X. +0x04 */
    float flAnchorY = {};   /*!< The sprite anchor Y. +0x08 */
    float flSizeX = {};     /*!< The sprite pixel width. +0x0c */
    float flSizeY = {};     /*!< The sprite pixel height. +0x10 */
    int nUvFrameIndex = {}; /*!< The UV atlas-frame index. +0x14 */
};

/** @brief The number of descriptor records in the low-tier sprite-descriptor table. */
constexpr int kAltFrameDescriptorCount4 = 10;
/** @brief The number of descriptor records in the mid-tier sprite-descriptor table. */
constexpr int kAltFrameDescriptorCount6 = 12;
/** @brief The number of descriptor records in the high-tier sprite-descriptor table. */
constexpr int kAltFrameDescriptorCount9 = 15;

/**
 * @brief The low-tier alt-frame sprite-descriptor table.
 *
 * One of the three tables selected by the frame's lane count. Read-only ROM data in the binary.
 * @ghidraAddress 0x30ca98
 */
extern const AltFrameSpriteDescriptor g_aAltFrameDescriptor4[kAltFrameDescriptorCount4];

/**
 * @brief The mid-tier alt-frame sprite-descriptor table.
 *
 * One of the three tables selected by the frame's lane count. Read-only ROM data in the binary.
 * @ghidraAddress 0x30cb88
 */
extern const AltFrameSpriteDescriptor g_aAltFrameDescriptor6[kAltFrameDescriptorCount6];

/**
 * @brief The high-tier alt-frame sprite-descriptor table.
 *
 * One of the three tables selected by the frame's lane count. Read-only ROM data in the binary.
 * @ghidraAddress 0x30cca8
 */
extern const AltFrameSpriteDescriptor g_aAltFrameDescriptor9[kAltFrameDescriptorCount9];

/** @brief The number of records in the mid-lane-count alt-frame mesh UV atlas. */
constexpr int kAltFrameMeshUvCountMid = 7;
/** @brief The number of records in the high-lane-count alt-frame mesh UV atlas. */
constexpr int kAltFrameMeshUvCountHigh = 10;

/**
 * @brief The mid-lane-count alt-frame mesh (batch-0) UV atlas.
 *
 * Holds the texture rectangles for the frame-mesh sprite quad, indexed by the active marker's
 * descriptor UV-frame index. This variant is selected for frame types up to twelve, and
 * @c g_aAltFrameMeshUvHigh above that. The batch-1 and batch-2 overlay sprites instead index the
 * shared @c g_aSpriteUvTable. Read-only ROM data.
 * @ghidraAddress 0x2f19d8
 */
extern const SpriteUvEntry g_aAltFrameMeshUvMid[kAltFrameMeshUvCountMid];

/**
 * @brief The high-lane-count alt-frame mesh (batch-0) UV atlas.
 *
 * Holds the texture rectangles for the frame-mesh sprite quad, indexed by the active marker's
 * descriptor UV-frame index. This variant is selected for frame types above twelve, and
 * @c g_aAltFrameMeshUvMid at or below that. The batch-1 and batch-2 overlay sprites instead index
 * the shared @c g_aSpriteUvTable. Read-only ROM data.
 * @ghidraAddress 0x2f1a48
 */
extern const SpriteUvEntry g_aAltFrameMeshUvHigh[kAltFrameMeshUvCountHigh];
