/**
 * @file
 * The alternate play-field frame's lane-marker layout tables, seeded at load time and read by the
 * alt-frame layer's build and render passes.
 */

#pragma once

/**
 * @brief One alt-frame lane-marker layout record: the sprite-kind row it draws from and its base
 * placement.
 *
 * The base Y is seeded relative to the play-field layout centre split; the render pass offsets it by
 * the screen height each frame. The 24-byte stride matches the binary's layout.
 */
struct AltFrameMarkerLayout {
    int nSpriteKind = {};  // +0x00: the sprite-kind row (indexes the alt-frame sprite-kind table).
    float flX = {};        // +0x04: the marker's base X.
    float flY = {};        // +0x08: the marker's base Y (relative to the layout centre split).
    float flRotation = {}; // +0x0c: the marker's rotation, in radians.
    float flScaleX = {};   // +0x10: the marker's X scale.
    float flScaleY = {};   // +0x14: the marker's Y scale.
};

// The number of records in each difficulty's marker layout table.
constexpr int kAltFrameMarkerCount4 = 10;
constexpr int kAltFrameMarkerCount6 = 14;
constexpr int kAltFrameMarkerCount9 = 12;

// The three alt-frame marker layout tables, selected by the frame's lane count (the low, mid, and
// high difficulty tiers). Seeded once at load by the layout-table constructor. The trailing @c // ...
// addresses document the binary globals.
extern AltFrameMarkerLayout g_aAltFrameMarker4[kAltFrameMarkerCount4]; // @ghidraAddress 0x3dbec8
extern AltFrameMarkerLayout g_aAltFrameMarker6[kAltFrameMarkerCount6]; // @ghidraAddress 0x3dbfb8
extern AltFrameMarkerLayout g_aAltFrameMarker9[kAltFrameMarkerCount9]; // @ghidraAddress 0x3dc108

/**
 * @brief One alt-frame sprite descriptor: which sprite batch it belongs to, its anchor and pixel
 * size, and the UV atlas frame it draws from.
 *
 * Static read-only data embedded in the binary. Each marker's sprite-kind row indexes one of the
 * descriptor tables (paired with the layout tables above by difficulty tier). The 24-byte stride
 * matches the binary's layout.
 */
struct AltFrameSpriteDescriptor {
    int nBatch = {};        // +0x00: the sprite batch (instancer) index this descriptor draws into.
    float flAnchorX = {};   // +0x04: the sprite anchor X.
    float flAnchorY = {};   // +0x08: the sprite anchor Y.
    float flSizeX = {};     // +0x0c: the sprite pixel width.
    float flSizeY = {};     // +0x10: the sprite pixel height.
    int nUvFrameIndex = {}; // +0x14: the UV atlas-frame index.
};

// The number of descriptor records in each difficulty's sprite-descriptor table.
constexpr int kAltFrameDescriptorCount4 = 10;
constexpr int kAltFrameDescriptorCount6 = 12;
constexpr int kAltFrameDescriptorCount9 = 15;

// The three alt-frame sprite-descriptor tables, selected by the frame's lane count. Read-only ROM
// data in the binary.
extern const AltFrameSpriteDescriptor
    g_aAltFrameDescriptor4[kAltFrameDescriptorCount4]; // @ghidraAddress 0x30ca98
extern const AltFrameSpriteDescriptor
    g_aAltFrameDescriptor6[kAltFrameDescriptorCount6]; // @ghidraAddress 0x30cb88
extern const AltFrameSpriteDescriptor
    g_aAltFrameDescriptor9[kAltFrameDescriptorCount9]; // @ghidraAddress 0x30cca8

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
