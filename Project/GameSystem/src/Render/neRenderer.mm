#include "neRenderer.h"

#include <cstring>

#import "neEngineBridge.h"

// The reference-counted projection and view-camera slots the render path reads each frame.
ne_Viewport *g_pCurrentAppliedCamera = nullptr; // @ghidraAddress 0x3cff00
ne_Viewport *g_pCurrentProjection = nullptr;    // @ghidraAddress 0x3cff08
ne_Viewport *g_pActiveViewCamera = nullptr;     // @ghidraAddress 0x3cff10
ne_CameraNode *g_pCurrentModelNode = nullptr;   // @ghidraAddress 0x3cff18

/** @ghidraAddress 0x2991c */
ne_Viewport::ne_Viewport(
    float flWidth, float flHeight, int nViewX, int nViewY, int nViewW, int nViewH) {
    // The binary redundantly sets the projection matrix to identity first; MakeOrthoMatrix overwrites
    // it entirely. The field of view and aspect stay zero for an ortho viewport.
    m_nRefCount = 1;
    m_nViewX = nViewX;
    m_nViewY = nViewY;
    m_nViewW = nViewW;
    m_nViewH = nViewH;
    MakeOrthoMatrix(flWidth, flHeight, 0.0f, 1.0f, m_mProjection);
}

/** @ghidraAddress 0x299c4 */
ne_Viewport::ne_Viewport(float flFovY,
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
ne_Viewport *CreateOrthoViewport(
    float width, float height, int x, int y, int viewportWidth, int viewportHeight) {
    return new ne_Viewport(width, height, x, y, viewportWidth, viewportHeight);
}

/** @ghidraAddress 0x299c4 */
ne_Viewport *CreatePerspectiveViewport(float fovY,
                                       float aspect,
                                       float nearZ,
                                       float farZ,
                                       int x,
                                       int y,
                                       int viewportWidth,
                                       int viewportHeight) {
    return new ne_Viewport(fovY, aspect, nearZ, farZ, x, y, viewportWidth, viewportHeight);
}

/** @ghidraAddress 0x29900 */
void ReleaseViewportCamera(ne_Viewport *pViewport) {
    // The binary decrements the count before its now-redundant null check, so this runs on a live
    // viewport; the viewport is destroyed once the last reference is dropped.
    const int nCount = pViewport->ReleaseRef();
    if (pViewport != nullptr && nCount == 0) {
        delete pViewport;
    }
}

/** @ghidraAddress 0x29e70 */
void SetCurrentCamera(neGLESRenderer *pRenderer, ne_Viewport *pCamera) {
    if (g_pCurrentAppliedCamera == pCamera) {
        return;
    }
    if (g_pCurrentAppliedCamera != nullptr) {
        ReleaseViewportCamera(g_pCurrentAppliedCamera);
    }
    pCamera->AddRef();
    g_pCurrentAppliedCamera = pCamera;
    ApplyCameraToRenderer(pCamera, pRenderer);
}

/** @ghidraAddress 0x29f1c */
void SetCurrentProjection(ne_Viewport *pViewport) {
    if (g_pCurrentProjection != pViewport) {
        if (g_pCurrentProjection != nullptr) {
            ReleaseViewportCamera(g_pCurrentProjection);
        }
        pViewport->AddRef();
        g_pCurrentProjection = pViewport;
    }
}

/** @ghidraAddress 0x29f64 */
void SetActiveViewCamera(ne_Viewport *pViewport) {
    if (g_pActiveViewCamera != pViewport) {
        if (g_pActiveViewCamera != nullptr) {
            ReleaseViewportCamera(g_pActiveViewCamera);
        }
        pViewport->AddRef();
        g_pActiveViewCamera = pViewport;
    }
}

/** @ghidraAddress 0x21ed4 */
ne_CameraNode::ne_CameraNode() {
    m_nRefCount = 1;
    // The binary writes the identity rows inline; SetMatrixIdentity is the de-inlined equivalent.
    SetMatrixIdentity(m_mView);
    SetMatrixIdentity(m_mInverseView);
}

/** @ghidraAddress 0x21f74 */
ne_CameraNode::ne_CameraNode(S_VECTOR3 *pEye, S_VECTOR3 *pTarget, S_VECTOR3 *pUp)
    : ne_CameraNode() {
    // Build the view matrix, then derive the inverse-view (camera-to-world) matrix by inverting a
    // copy of it.
    MakeLookAtMatrix(m_mView, pEye, pTarget, pUp);
    std::memcpy(m_mInverseView, m_mView, sizeof(m_mView));
    InvertMatrix4x4(m_mInverseView);
}

/** @ghidraAddress 0x21fe0 */
ne_CameraNode::ne_CameraNode(const float *pViewMatrix) : ne_CameraNode() {
    // The supplied matrix becomes the view matrix; its inverse becomes the inverse-view matrix.
    std::memcpy(m_mView, pViewMatrix, sizeof(m_mView));
    std::memcpy(m_mInverseView, pViewMatrix, sizeof(m_mInverseView));
    InvertMatrix4x4(m_mInverseView);
}

/** @ghidraAddress 0x21f74 */
ne_CameraNode *CreateLookAtCamera(S_VECTOR3 *pEye, S_VECTOR3 *pTarget, S_VECTOR3 *pUp) {
    return new ne_CameraNode(pEye, pTarget, pUp);
}

/** @ghidraAddress 0x21fe0 */
ne_CameraNode *CreateCameraFromMatrix(float *pMatrix) {
    return new ne_CameraNode(pMatrix);
}

/** @ghidraAddress 0x21f58 */
void ReleaseCameraNode(ne_CameraNode *pCamera) {
    // As with the viewport, the count is decremented before the now-redundant null check.
    const int nCount = pCamera->ReleaseRef();
    if (pCamera != nullptr && nCount == 0) {
        delete pCamera;
    }
}

/** @ghidraAddress 0x29fac */
void SetCurrentModelNode(ne_CameraNode *pCamera) {
    if (g_pCurrentModelNode != pCamera) {
        if (g_pCurrentModelNode != nullptr) {
            ReleaseCameraNode(g_pCurrentModelNode);
        }
        pCamera->AddRef();
        g_pCurrentModelNode = pCamera;
    }
}

/** @ghidraAddress 0x22058 */
void TransformVector4ByCamera(ne_CameraNode *pCamera, float *pVec4) {
    MultiplyVector4ByMatrixInPlace(pVec4, pCamera->GetViewMatrix());
}
