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
