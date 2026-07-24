#include "neRenderer.h"

#import "neEngineBridge.h"

// The reference-counted projection and view-camera slots the render path reads each frame.
ne_Viewport *g_pCurrentProjection = nullptr; // @ghidraAddress 0x3cff08
ne_Viewport *g_pActiveViewCamera = nullptr;  // @ghidraAddress 0x3cff10

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
