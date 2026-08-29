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
 * A polygon-mesh trail (a ribbon strip that follows a moving point).
 *
 * Holds the strip's vertex list, its cached total length, and the mesh node that draws it. The
 * trailing @c // +0xNN comments document the original member offsets for reference only. The vertex
 * list and count are populated by the owner (a sprite-set state block) before @c Init runs.
 */
class Polygon2dTrail {
public:
    /**
     * Constructs a trail over a caller-owned vertex buffer, clearing its derived state.
     *
     * Records the strip's vertex count and the buffer that holds its points, and zeroes the cached
     * length and the mesh pointer; @c Init later builds the mesh from them. The binary inlines this
     * into the owner's constructor (the four Classic result-window trails), seeding the count and
     * buffer from static tables.
     * @param nVertexCount The number of strip vertices.
     * @param pVertices The caller-owned vertex buffer.
     */
    Polygon2dTrail(int nVertexCount, S_VECTOR2 *pVertices);

    /**
     * Builds the trail's mesh: creates the polygon-mesh node, registers it, seeds every
     * vertex to the strip's first point (white, zero alpha), and caches the strip's total length.
     * @ghidraAddress 0x11c744
     */
    void Init();

    /**
     * Advances the trail's visible head along the strip by one frame's worth of travel.
     *
     * Adds @p flDeltaTime to the reveal progress (finishing and deactivating once it passes the
     * reveal length, or waiting while it is still negative), then walks the strip's segments from
     * the head by the per-frame step, snapping crossed vertices onto their path points and
     * interpolating the partially-reached vertex, writing each moved vertex to the mesh in opaque
     * white.
     * @param nDeltaTime The elapsed frame time.
     * @ghidraAddress 0x11c3e0
     */
    void Update(int nDeltaTime);

    /**
     * Begins the trail's reveal animation over @p nDuration, after a @p nStartOffset delay.
     *
     * Activates the trail, seeds the reveal progress to @c -nStartOffset (so the reveal begins once
     * the progress climbs back to zero) and the reveal length to @p nDuration, resets the head-walk
     * state, and clears every mesh vertex back to the strip's first point in transparent white.
     * @param nDuration The reveal duration.
     * @param nStartOffset The delay before the reveal begins.
     * @ghidraAddress 0x11c868
     */
    void Start(int nDuration, int nStartOffset);

    /**
     * Resets the trail to its idle, hidden state.
     *
     * Deactivates the trail and clears every mesh vertex back to the strip's first point in
     * transparent white, leaving no visible ribbon.
     * @ghidraAddress 0x11c8ec
     */
    void Reset();

    /**
     * Hides the trail's mesh node without disturbing its vertices (clears the mesh's visible
     * flag). Used by the owner's idle per-frame path.
     */
    void HideMesh();

private:
    // Clears every mesh vertex back to the strip's first point in transparent white (the shared
    // hidden state used by Start and Reset).
    void ClearMeshVertices();

    bool m_bActive = {}; // +0x00: whether the trail is animating.
    // +0x01..+0x03 is alignment padding before the progress value.
    // unsigned char m_aPad01[3] = {}; // +0x01
    float m_flProgress = {};       // +0x04: the elapsed reveal progress, driven by Update.
    float m_flRevealLength = {};   // +0x08: the reveal's total travel length (the progress bound).
    float m_flTotalLength = {};    // +0x0c: the cached geometric length of the strip (sum of
                                   //        segment lengths), computed by Init.
    int m_nHeadIndex = {};         // +0x10: the index of the strip's current head vertex.
    float m_flReachRemainder = {}; // +0x14: the reach carried between segments while advancing.
    int m_nVertexCount = {};       // +0x18: the number of strip vertices.
    // +0x1c..+0x1f is padding before the vertex array pointer.
    // unsigned char m_aPad1c[4] = {};      // +0x1c
    S_VECTOR2 *m_pVertices = {};         // +0x20: the strip vertex positions.
    ne::C_DRAW_POLYGON_2D *m_pMesh = {}; // +0x28: the mesh node that draws the strip.
};
