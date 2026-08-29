#include "neSpriteInstancing3D.h"

#include <cstring>

#include "matrixmath.h"
#include "neGLES.h"
#include "neRenderer.h"

namespace ne {

namespace {
// @ghidraAddress 0x2eee00
constexpr int kWorldTexMinFilter = 1;
constexpr int kWorldTexMagFilter = 1;

// The neIGLES blend factors, GL_ONE and GL_ONE_MINUS_SRC_ALPHA.
constexpr int kBlendOne = 1;
constexpr int kBlendOneMinusSrcAlpha = 5;
} // namespace

/** @ghidraAddress 0x3097c */
C_SPRITE_INSTANCING_3D::C_SPRITE_INSTANCING_3D(unsigned int nCapacity)
    : C_SPRITE_INSTANCING_2D(nCapacity) {
    m_bBatchFlag = false;
    SetTexParam(0, kWorldTexMinFilter);
    SetTexParam(1, kWorldTexMagFilter);
}

/** @ghidraAddress 0x30dc0 */
void C_SPRITE_INSTANCING_3D::Render() {
    DebugSnapshot();
    neGLESRenderer *pRenderer = neGLESRenderer::GetShared();
    const int nMaxPerBatch = pRenderer->GetMaxPaletteMatrices();
    SetMatrixIdentity(GetLocalMatrix());

    int nLiveCount = 0;
    for (int nSprite = 0; nSprite < m_nSpriteCount; ++nSprite) {
        if (GetColorAlpha(nSprite) != 0) {
            ++nLiveCount;
        }
    }
    if (nLiveCount == 0) {
        return;
    }

    // The perspective camera, not the orthographic projection, which would draw world-space
    // geometry at half scale against a top-left origin. @ghidraAddress 0x30e4c
    SetCurrentCamera(pRenderer, g_pActiveViewCamera);
    std::memcpy(GetWorldMatrix(), GetParent()->GetWorldMatrix(), sizeof(float) * 16);
    ResetRenderState(pRenderer);
    pRenderer->SetBlendFunc(kBlendOne, m_nBlendMode == 0 ? kBlendOneMinusSrcAlpha : kBlendOne);

    float worldCamMatrix[16];
    std::memcpy(worldCamMatrix, g_pCurrentModelNode->GetViewMatrix(), sizeof(worldCamMatrix));
    MultiplyMatrixInPlace(worldCamMatrix, GetParent()->GetWorldMatrix());

    EmitMatrixSprites(pRenderer, nMaxPerBatch, worldCamMatrix);
}

} // namespace ne
