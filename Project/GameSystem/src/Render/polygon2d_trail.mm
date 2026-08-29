#include "polygon2d_trail.h"

#include "neDrawPolygon2D.h"
#import "s_vector2.h"
#import "vectormath.h"

namespace {

// Per-vertex position and colour, bits 0 and 2.
constexpr unsigned int kTrailVertexFormat = 5;

constexpr unsigned int kTrailDrawMode = 1;

constexpr unsigned char kFullChannel = 0xff;

} // namespace

// The binary inlines this constructor into the owner's constructor.
// @ghidraAddress 0x115094
Polygon2dTrail::Polygon2dTrail(int nVertexCount, S_VECTOR2 *pVertices)
    : m_nVertexCount(nVertexCount), m_pVertices(pVertices) {
}

/** @ghidraAddress 0x11c3e0 */
void Polygon2dTrail::Update(int nDeltaTime) {
    if (!m_bActive) {
        return;
    }

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

    const float flStep = flDelta * (m_flTotalLength / m_flRevealLength);
    while (m_nHeadIndex < m_nVertexCount - 1) {
        S_VECTOR2 vSegment = m_pVertices[m_nHeadIndex + 1];
        SubtractVector2(&vSegment, &m_pVertices[m_nHeadIndex]);
        const float flSegmentLength = Vector2Length(&vSegment);
        const float flReach = flStep + m_flReachRemainder;

        if (flSegmentLength >= flReach) {
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

        ++m_nHeadIndex;
        m_pMesh->SetPosFromVec(m_nHeadIndex, &m_pVertices[m_nHeadIndex]);
        m_pMesh->SetRGBA(m_nHeadIndex, kFullChannel, kFullChannel, kFullChannel, kFullChannel);
        if (m_nHeadIndex >= m_nVertexCount - 1) {
            return;
        }
        m_flReachRemainder -= flSegmentLength;
    }
}

/** @ghidraAddress 0x11c868 */
void Polygon2dTrail::Start(int nDuration, int nStartOffset) {
    m_bActive = true;
    // A negative starting progress delays the reveal until it climbs back to zero.
    m_flProgress = static_cast<float>(-nStartOffset);
    m_flRevealLength = static_cast<float>(nDuration);
    m_nHeadIndex = 0;
    m_flReachRemainder = 0.0f;
    ClearMeshVertices();
}

/** @ghidraAddress 0x11c8ec */
void Polygon2dTrail::Reset() {
    m_bActive = false;
    ClearMeshVertices();
}

void Polygon2dTrail::HideMesh() {
    m_pMesh->SetVisible(false);
}

void Polygon2dTrail::ClearMeshVertices() {
    for (int nVertex = 0; nVertex < m_nVertexCount; ++nVertex) {
        m_pMesh->SetRGBA(nVertex, kFullChannel, kFullChannel, kFullChannel, 0);
        m_pMesh->SetPosFromVec(nVertex, m_pVertices);
    }
}

/** @ghidraAddress 0x11c744 */
void Polygon2dTrail::Init() {
    const int nVertexCount = m_nVertexCount;

    m_pMesh = ne::CreatePolygon2dMesh(kTrailDrawMode,
                                      static_cast<unsigned int>(nVertexCount),
                                      kTrailVertexFormat,
                                      1,
                                      static_cast<unsigned int>(nVertexCount),
                                      0);
    m_pMesh->RegisterGlobal();
    m_pMesh->SetVisible(true);

    for (int nVertex = 0; nVertex < nVertexCount; ++nVertex) {
        m_pMesh->SetIndex(nVertex, static_cast<unsigned short>(nVertex));
        m_pMesh->SetRGBA(nVertex, kFullChannel, kFullChannel, kFullChannel, 0);
        m_pMesh->SetPosFromVec(nVertex, m_pVertices);
    }

    m_flTotalLength = 0.0f;
    for (int nSegment = 0; nSegment < nVertexCount - 1; ++nSegment) {
        S_VECTOR2 delta = m_pVertices[nSegment];
        SubtractVector2(&delta, &m_pVertices[nSegment + 1]);
        m_flTotalLength += Vector2Length(&delta);
    }
}
