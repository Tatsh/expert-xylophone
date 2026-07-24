/**
 * @file
 * The 2D polygon-mesh "trail" (ribbon), @c Polygon2dTrail.
 */

#pragma once

struct S_VECTOR2;

namespace ne {
class C_DRAW_POLYGON_2D;
} // namespace ne

/**
 * @brief A polygon-mesh trail (a ribbon strip that follows a moving point).
 *
 * Holds the strip's vertex list, its cached total length, and the mesh node that draws it. The
 * trailing @c // +0xNN comments document the original member offsets for reference only. The vertex
 * list and count are populated by the owner (a sprite-set state block) before @c Init runs.
 */
class Polygon2dTrail {
public:
    /**
     * @brief Builds the trail's mesh: creates the polygon-mesh node, registers it, seeds every
     * vertex to the strip's first point (white, zero alpha), and caches the strip's total length.
     * @ghidraAddress 0x11c744
     */
    void Init();

private:
    // +0x00..+0x08: descriptor state preceding the cached length, still being worked out.
    unsigned char m_aReserved00[0xc] = {}; // +0x00
    float m_flTotalLength = {};            // +0x0c: the cached total length of the strip.
    // +0x10..+0x17: further descriptor state still being worked out.
    unsigned char m_aReserved10[8] = {}; // +0x10
    int m_nVertexCount = {};             // +0x18: the number of strip vertices.
    // +0x1c..+0x1f is padding before the vertex array pointer.
    unsigned char m_aReserved1c[4] = {}; // +0x1c
    S_VECTOR2 *m_pVertices = {};         // +0x20: the strip vertex positions.
    ne::C_DRAW_POLYGON_2D *m_pMesh = {}; // +0x28: the mesh node that draws the strip.
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
