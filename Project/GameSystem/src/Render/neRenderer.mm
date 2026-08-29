#include "neRenderer.h"

#include <cmath>
#include <cstring>

#import "matrixmath.h"
#include "neGLES.h"
#import "neRenderer.h"
#import "s_vector2.h"
#import "s_vector3.h"
#import "vectormath.h"

ne::Viewport *g_pCurrentAppliedCamera = nullptr; // @ghidraAddress 0x3cff00
ne::Viewport *g_pCurrentProjection = nullptr;    // @ghidraAddress 0x3cff08
ne::Viewport *g_pActiveViewCamera = nullptr;     // @ghidraAddress 0x3cff10
ne::CameraNode *g_pCurrentModelNode = nullptr;   // @ghidraAddress 0x3cff18

/** @ghidraAddress 0x2991c */
ne::Viewport::Viewport(
    float flWidth, float flHeight, int nViewX, int nViewY, int nViewW, int nViewH) {
    // The binary sets the projection to identity first; MakeOrthoMatrix overwrites it entirely.
    m_nRefCount = 1;
    m_nViewX = nViewX;
    m_nViewY = nViewY;
    m_nViewW = nViewW;
    m_nViewH = nViewH;
    MakeOrthoMatrix(flWidth, flHeight, 0.0f, 1.0f, m_mProjection);
}

/** @ghidraAddress 0x299c4 */
ne::Viewport::Viewport(float flFovY,
                       float flAspect,
                       float flNear,
                       float flFar,
                       int nViewX,
                       int nViewY,
                       int nViewW,
                       int nViewH) {
    m_nRefCount = 1;
    m_nViewX = nViewX;
    m_nViewY = nViewY;
    m_nViewW = nViewW;
    m_nViewH = nViewH;
    m_flFovY = flFovY;
    m_flAspect = flAspect;
    MakePerspectiveMatrix(flFovY, flAspect, flNear, flFar, m_mProjection);
}

/** @ghidraAddress 0x2991c */
ne::Viewport *CreateOrthoViewport(
    float width, float height, int x, int y, int viewportWidth, int viewportHeight) {
    return new ne::Viewport(width, height, x, y, viewportWidth, viewportHeight);
}

/** @ghidraAddress 0x299c4 */
ne::Viewport *CreatePerspectiveViewport(float fovY,
                                        float aspect,
                                        float nearZ,
                                        float farZ,
                                        int x,
                                        int y,
                                        int viewportWidth,
                                        int viewportHeight) {
    return new ne::Viewport(fovY, aspect, nearZ, farZ, x, y, viewportWidth, viewportHeight);
}

/** @ghidraAddress 0x29900 */
void ne::Viewport::Release() {
    // The binary decrements the count before its now-redundant null check.
    const int nCount = ReleaseRef();
    if (nCount == 0) {
        delete this;
    }
}

/** @ghidraAddress 0x29a80 */
void ne::Viewport::ApplyToRenderer(neGLESRenderer *pRenderer) {
    constexpr int kMatrixModeProjection = 1;
    pRenderer->SetViewport(GetViewX(), GetViewY(), GetViewWidth(), GetViewHeight());
    pRenderer->SetMatrixMode(kMatrixModeProjection, GetProjectionMatrix());
}

/** @ghidraAddress 0x29e70 */
void SetCurrentCamera(neGLESRenderer *pRenderer, ne::Viewport *pCamera) {
    if (g_pCurrentAppliedCamera == pCamera) {
        return;
    }
    if (g_pCurrentAppliedCamera != nullptr) {
        g_pCurrentAppliedCamera->Release();
    }
    pCamera->AddRef();
    g_pCurrentAppliedCamera = pCamera;
    pCamera->ApplyToRenderer(pRenderer);
}

/** @ghidraAddress 0x29f1c */
void SetCurrentProjection(ne::Viewport *pViewport) {
    if (g_pCurrentProjection != pViewport) {
        if (g_pCurrentProjection != nullptr) {
            g_pCurrentProjection->Release();
        }
        pViewport->AddRef();
        g_pCurrentProjection = pViewport;
    }
}

/** @ghidraAddress 0x29f64 */
void SetActiveViewCamera(ne::Viewport *pViewport) {
    if (g_pActiveViewCamera != pViewport) {
        if (g_pActiveViewCamera != nullptr) {
            g_pActiveViewCamera->Release();
        }
        pViewport->AddRef();
        g_pActiveViewCamera = pViewport;
    }
}

/** @ghidraAddress 0x21ed4 */
ne::CameraNode::CameraNode() {
    m_nRefCount = 1;
    SetMatrixIdentity(m_mView);
    SetMatrixIdentity(m_mInverseView);
}

/** @ghidraAddress 0x21f74 */
ne::CameraNode::CameraNode(S_VECTOR3 *pEye, S_VECTOR3 *pTarget, S_VECTOR3 *pUp) : ne::CameraNode() {
    MakeLookAtMatrix(m_mView, pEye, pTarget, pUp);
    std::memcpy(m_mInverseView, m_mView, sizeof(m_mView));
    InvertMatrix4x4(m_mInverseView);
}

/** @ghidraAddress 0x21fe0 */
ne::CameraNode::CameraNode(const float *pViewMatrix) : ne::CameraNode() {
    std::memcpy(m_mView, pViewMatrix, sizeof(m_mView));
    std::memcpy(m_mInverseView, pViewMatrix, sizeof(m_mInverseView));
    InvertMatrix4x4(m_mInverseView);
}

/** @ghidraAddress 0x21f74 */
ne::CameraNode *CreateLookAtCamera(S_VECTOR3 *pEye, S_VECTOR3 *pTarget, S_VECTOR3 *pUp) {
    return new ne::CameraNode(pEye, pTarget, pUp);
}

/** @ghidraAddress 0x21fe0 */
ne::CameraNode *CreateCameraFromMatrix(float *pMatrix) {
    return new ne::CameraNode(pMatrix);
}

/** @ghidraAddress 0x21f58 */
void ne::CameraNode::Release() {
    // As with the viewport, the count is decremented before the now-redundant null check.
    const int nCount = ReleaseRef();
    if (nCount == 0) {
        delete this;
    }
}

/** @ghidraAddress 0x29fac */
void SetCurrentModelNode(ne::CameraNode *pCamera) {
    if (g_pCurrentModelNode != pCamera) {
        if (g_pCurrentModelNode != nullptr) {
            g_pCurrentModelNode->Release();
        }
        pCamera->AddRef();
        g_pCurrentModelNode = pCamera;
    }
}

/** @ghidraAddress 0x22058 */
void ne::CameraNode::TransformVector4(float *pVec4) {
    MultiplyVector4ByMatrixInPlace(pVec4, GetViewMatrix());
}

/** @ghidraAddress 0x29ff4 */
void ComputeScreenPickRay(const S_VECTOR2 *pScreen, S_VECTOR3 *pRayOrigin, S_VECTOR3 *pRayDir) {
    const float flTanHalfFov = static_cast<float>(std::tan(g_pActiveViewCamera->GetFovY() * 0.5f));
    S_VECTOR3 nearPoint;
    nearPoint.x =
        (pScreen->x - 0.5f + pScreen->x - 0.5f) * flTanHalfFov * g_pActiveViewCamera->GetAspect();
    nearPoint.y = (pScreen->y - 0.5f) * -2.0f * flTanHalfFov;
    nearPoint.z = -1.0f;

    float invViewMatrix[16];
    std::memcpy(invViewMatrix, g_pCurrentModelNode->GetInverseViewMatrix(), sizeof(invViewMatrix));
    pRayOrigin->x = 0.0f;
    pRayOrigin->y = 0.0f;
    pRayOrigin->z = 0.0f;
    TransformPointByMatrix(pRayOrigin, invViewMatrix);
    TransformPointByMatrix(&nearPoint, invViewMatrix);

    *pRayDir = nearPoint;
    SubtractVector3(pRayDir, pRayOrigin);
    NormalizeVector3(pRayDir);
}

/** @ghidraAddress 0x29abc */
void ne::Viewport::ProjectWorldToScreen(float *pVec4) {
    // The helper only reads its matrix argument, so dropping constness is safe.
    MultiplyVector4ByMatrixInPlace(pVec4, const_cast<float *>(GetProjectionMatrix()));
    // The Y axis is negated so the origin is top-left.
    const float x = pVec4[0];
    const float y = pVec4[1];
    const float w = pVec4[3];
    pVec4[0] = static_cast<float>(GetViewWidth()) * (x / w + 1.0f) * 0.5f;
    pVec4[1] = static_cast<float>(GetViewHeight()) * (y / w - 1.0f) * -0.5f;
}

/** @ghidraAddress 0x2a158 */
void ProjectWorldToScreenCurrent(float *pVec4) {
    g_pCurrentModelNode->TransformVector4(pVec4);
    g_pActiveViewCamera->ProjectWorldToScreen(pVec4);
}
