#include "polygon2d_trail.h"

#include "neDrawPolygon2D.h"
#import "s_vector2.h"
#import "vectormath.h"

namespace {

// The vertex format of a trail mesh: per-vertex position and colour (bits 0 and 2).
constexpr unsigned int kTrailVertexFormat = 5;

// The trail mesh's primitive draw mode.
constexpr unsigned int kTrailDrawMode = 1;

// The opaque-white channel value each trail vertex starts at (its alpha starts at zero).
constexpr unsigned char kFullChannel = 0xff;

} // namespace

// The binary inlines this constructor into the owner's constructor (@ghidraAddress 0x115094, the
// Classic result-window layer), which new[]s each trail and seeds its vertex count and buffer from
// the static tables at 0x304190 (19 vertices) and 0x3cf458 (the per-trail vertex buffers).
Polygon2dTrail::Polygon2dTrail(int nVertexCount, S_VECTOR2 *pVertices)
    : m_nVertexCount(nVertexCount), m_pVertices(pVertices) {
}

/** @ghidraAddress 0x11c3e0 */
void Polygon2dTrail::Update(int nDeltaTime) {
    if (!m_bActive) {
        return;
    }

    // Advance the reveal progress. Once it passes the reveal length the trail is fully shown and
    // deactivates; while it is still negative the reveal has not begun.
    const float flDelta = static_cast<float>(nDeltaTime);
    m_flProgress += flDelta;
    if (m_flProgress > m_flRevealLength) {
        m_flProgress = m_flRevealLength;
        m_bActive = false;
    } else if (m_flProgress < 0.0f) {
        return;
    }

    if (m_nHeadIndex >= m_nVertexCount - 1) {
        return;
    }

    // The travel this frame, scaled from frame time by the strip's geometric length over its reveal
    // length. Walk segments from the head, snapping each fully-crossed vertex onto its path point,
    // until a segment is only partially reached.
    const float flStep = flDelta * (m_flTotalLength / m_flRevealLength);
    while (m_nHeadIndex < m_nVertexCount - 1) {
        S_VECTOR2 vSegment = m_pVertices[m_nHeadIndex + 1];
        SubtractVector2(&vSegment, &m_pVertices[m_nHeadIndex]);
        const float flSegmentLength = Vector2Length(&vSegment);
        const float flReach = flStep + m_flReachRemainder;

        if (flSegmentLength >= flReach) {
            // The reach stops inside this segment: interpolate the head point and fill every
            // trailing vertex with it, in opaque white.
            NormalizeVector2(&vSegment);
            ScaleVector2(&vSegment, flReach);
            AddVector2(&vSegment, &m_pVertices[m_nHeadIndex]);
            for (int nVertex = m_nHeadIndex + 1; nVertex < m_nVertexCount; ++nVertex) {
                m_pMesh->SetPosFromVec(nVertex, &vSegment);
                m_pMesh->SetRGBA(nVertex, kFullChannel, kFullChannel, kFullChannel, kFullChannel);
            }
            m_flReachRemainder += flStep;
            return;
        }

        // The reach crosses this vertex: snap it onto its path point, then carry the overshoot into
        // the next segment.
        ++m_nHeadIndex;
        m_pMesh->SetPosFromVec(m_nHeadIndex, &m_pVertices[m_nHeadIndex]);
        m_pMesh->SetRGBA(m_nHeadIndex, kFullChannel, kFullChannel, kFullChannel, kFullChannel);
        if (m_nHeadIndex >= m_nVertexCount - 1) {
            return;
        }
        m_flReachRemainder -= flSegmentLength;
    }
}

/** @ghidraAddress 0x11c744 */
void Polygon2dTrail::Init() {
    const int nVertexCount = m_nVertexCount;

    // Build the strip's mesh: one position-and-colour vertex per strip point, an owned vertex buffer,
    // and an index per vertex; register it in the global scene tree and make it visible.
    m_pMesh = ne::CreatePolygon2dMesh(kTrailDrawMode,
                                      static_cast<unsigned int>(nVertexCount),
                                      kTrailVertexFormat,
                                      1,
                                      static_cast<unsigned int>(nVertexCount),
                                      0);
    m_pMesh->RegisterGlobal();
    m_pMesh->SetVisible(true);

    // Seed every vertex: its index, an opaque-white colour at zero alpha, and the strip's first
    // point as the initial position.
    for (int nVertex = 0; nVertex < nVertexCount; ++nVertex) {
        m_pMesh->SetIndex(nVertex, static_cast<unsigned short>(nVertex));
        m_pMesh->SetRGBA(nVertex, kFullChannel, kFullChannel, kFullChannel, 0);
        m_pMesh->SetPosFromVec(nVertex, m_pVertices);
    }

    // Cache the strip's total length as the sum of its segment lengths.
    m_flTotalLength = 0.0f;
    for (int nSegment = 0; nSegment < nVertexCount - 1; ++nSegment) {
        S_VECTOR2 delta = m_pVertices[nSegment];
        SubtractVector2(&delta, &m_pVertices[nSegment + 1]);
        m_flTotalLength += Vector2Length(&delta);
    }
}
