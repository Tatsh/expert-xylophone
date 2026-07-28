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

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
