#include "neSpriteInstancing3D.h"

#include <cstring>

#include "matrixmath.h"
#include "neGLES.h"
#include "neRenderer.h"

namespace ne {

namespace {
// The world-space batch's linear-filter min/mag sampler parameters (@ghidraAddress 0x2eee00); the
// two wrap parameters are the same as the screen-space batch's and are left as seeded.
constexpr int kWorldTexMinFilter = 1;
constexpr int kWorldTexMagFilter = 1;

// The neIGLES blend factors, as in the screen-space batch: the source is always GL_ONE and the
// destination is GL_ONE_MINUS_SRC_ALPHA for a normal alpha blend or GL_ONE for an additive one.
constexpr int kBlendOne = 1;
constexpr int kBlendOneMinusSrcAlpha = 5;
} // namespace

/** @ghidraAddress 0x3097c */
C_SPRITE_INSTANCING_3D::C_SPRITE_INSTANCING_3D(unsigned int nCapacity)
    : C_SPRITE_INSTANCING_2D(nCapacity) {
    // The world-space constructor's only state difference from the screen-space one is the strb
    // wzr at +0x154; its texture parameters use the linear-filter min/mag pair at 0x2eee00 rather
    // than the screen batch's nearest-filter pair.
    m_bBatchFlag = false;
    SetTexParam(0, kWorldTexMinFilter);
    SetTexParam(1, kWorldTexMagFilter);
}

/** @ghidraAddress 0x30dc0 */
void C_SPRITE_INSTANCING_3D::Render() {
    neGLESRenderer *pRenderer = neGLESRenderer::GetShared();
    const int nMaxPerBatch = pRenderer->GetMaxPaletteMatrices();
    SetMatrixIdentity(GetLocalMatrix());

    // Count the live (non-transparent) sprites; bail if there are none.
    int nLiveCount = 0;
    for (int nSprite = 0; nSprite < m_nSpriteCount; ++nSprite) {
        if (GetColorAlpha(nSprite) != 0) {
            ++nLiveCount;
        }
    }
    if (nLiveCount == 0) {
        return;
    }

    // Bind the active view camera and copy the parent's world matrix into this node's, then reset
    // the render state and select the blend mode. The camera is the perspective one installed by
    // -[RBViewController UpdateProjection] through SetActiveViewCamera, read from the global at
    // 0x3cff10 by the ldr at 0x30e4c -- not the orthographic projection at 0x3cff08. Binding the
    // ortho here draws world-space geometry in raw world units against a top-left origin, which
    // put the play-field frame at half scale with its left half off screen.
    SetCurrentCamera(pRenderer, g_pActiveViewCamera);
    std::memcpy(GetWorldMatrix(), GetParent()->GetWorldMatrix(), sizeof(float) * 16);
    ResetRenderState(pRenderer);
    pRenderer->SetBlendFunc(kBlendOne, m_nBlendMode == 0 ? kBlendOneMinusSrcAlpha : kBlendOne);

    // The shared compose matrix is the current model node's camera (view) matrix multiplied by the
    // parent's world matrix, so every world-space sprite is placed in the camera's frame.
    float worldCamMatrix[16];
    std::memcpy(worldCamMatrix, g_pCurrentModelNode->GetViewMatrix(), sizeof(worldCamMatrix));
    MultiplyMatrixInPlace(worldCamMatrix, GetParent()->GetWorldMatrix());

    EmitMatrixSprites(pRenderer, nMaxPerBatch, worldCamMatrix);
}

} // namespace ne
