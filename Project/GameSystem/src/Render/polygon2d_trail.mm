#include "polygon2d_trail.h"

#include "neDrawPolygon2D.h"
#import "neEngineBridge.h"

namespace {

// The vertex format of a trail mesh: per-vertex position and colour (bits 0 and 2).
constexpr unsigned int kTrailVertexFormat = 5;

// The trail mesh's primitive draw mode.
constexpr unsigned int kTrailDrawMode = 1;

// The opaque-white channel value each trail vertex starts at (its alpha starts at zero).
constexpr unsigned char kFullChannel = 0xff;

} // namespace

/** @ghidraAddress 0x11c744 */
void InitPolygon2dTrail(Polygon2dTrail *pTrail) {
    const int nVertexCount = pTrail->m_nVertexCount;

    // Build the strip's mesh: one position-and-colour vertex per strip point, an owned vertex buffer,
    // and an index per vertex; register it in the global scene tree and make it visible.
    pTrail->m_pMesh = ne::CreatePolygon2dMesh(kTrailDrawMode,
                                              static_cast<unsigned int>(nVertexCount),
                                              kTrailVertexFormat,
                                              1,
                                              static_cast<unsigned int>(nVertexCount),
                                              0);
    pTrail->m_pMesh->RegisterGlobal();
    pTrail->m_pMesh->SetVisible(true);

    // Seed every vertex: its index, an opaque-white colour at zero alpha, and the strip's first
    // point as the initial position.
    for (int nVertex = 0; nVertex < nVertexCount; ++nVertex) {
        pTrail->m_pMesh->SetIndex(nVertex, static_cast<unsigned short>(nVertex));
        pTrail->m_pMesh->SetRGBA(nVertex, kFullChannel, kFullChannel, kFullChannel, 0);
        pTrail->m_pMesh->SetPosFromVec(nVertex, pTrail->m_pVertices);
    }

    // Cache the strip's total length as the sum of its segment lengths.
    pTrail->m_flTotalLength = 0.0f;
    for (int nSegment = 0; nSegment < nVertexCount - 1; ++nSegment) {
        S_VECTOR2 delta = pTrail->m_pVertices[nSegment];
        SubtractVector2(&delta, &pTrail->m_pVertices[nSegment + 1]);
        pTrail->m_flTotalLength += Vector2Length(&delta);
    }
}
