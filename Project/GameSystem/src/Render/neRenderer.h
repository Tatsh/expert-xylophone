/**
 * @file
 * The reference-counted projection viewport and camera node, @c ne::Viewport and
 * @c ne::CameraNode, and the render-camera installation and factory helpers.
 */

#pragma once

class neGLESRenderer;
struct S_VECTOR2;
struct S_VECTOR3;

namespace ne {

/**
 * @brief A reference-counted projection viewport: a 4x4 projection matrix and a GL viewport
 * rectangle.
 *
 * Built by @c CreateOrthoViewport or @c CreatePerspectiveViewport and shared by reference count;
 * @c ReleaseViewportCamera drops a reference and destroys the viewport at zero. The trailing
 * @c // +0xNN comments document the original 32-bit member offsets for reference only.
 * @ghidraAddress ne::Viewport (engine class, refcount at +0x0)
 */
class Viewport {
public:
    /**
     * @brief Constructs an orthographic viewport with a zero-to-one depth ortho projection.
     * @param flWidth The orthographic width.
     * @param flHeight The orthographic height.
     * @param nViewX The GL viewport x origin.
     * @param nViewY The GL viewport y origin.
     * @param nViewW The GL viewport width.
     * @param nViewH The GL viewport height.
     * @ghidraAddress 0x2991c
     */
    Viewport(float flWidth, float flHeight, int nViewX, int nViewY, int nViewW, int nViewH);
    /**
     * @brief Constructs a perspective viewport.
     * @param flFovY The vertical field of view, in radians.
     * @param flAspect The aspect ratio.
     * @param flNear The near clip plane.
     * @param flFar The far clip plane.
     * @param nViewX The GL viewport x origin.
     * @param nViewY The GL viewport y origin.
     * @param nViewW The GL viewport width.
     * @param nViewH The GL viewport height.
     * @ghidraAddress 0x299c4
     */
    Viewport(float flFovY,
             float flAspect,
             float flNear,
             float flFar,
             int nViewX,
             int nViewY,
             int nViewW,
             int nViewH);

    /**
     * @brief Add a reference to the viewport.
     */
    void AddRef() {
        ++m_nRefCount;
    }
    /**
     * @brief Remove a reference from the viewport.
     * @return The reference count after the decrement.
     */
    int ReleaseRef() {
        return --m_nRefCount;
    }

    /**
     * @brief The column-major 4x4 projection matrix.
     */
    const float *GetProjectionMatrix() const {
        return m_mProjection;
    }
    /**
     * @brief The vertical field of view, in radians (zero for an orthographic viewport).
     */
    float GetFovY() const {
        return m_flFovY;
    }
    /**
     * @brief The perspective aspect ratio (zero for an orthographic viewport).
     */
    float GetAspect() const {
        return m_flAspect;
    }
    /**
     * @brief The GL viewport x origin.
     */
    int GetViewX() const {
        return m_nViewX;
    }
    /**
     * @brief The GL viewport y origin.
     */
    int GetViewY() const {
        return m_nViewY;
    }
    /**
     * @brief The GL viewport width.
     */
    int GetViewWidth() const {
        return m_nViewW;
    }
    /**
     * @brief The GL viewport height.
     */
    int GetViewHeight() const {
        return m_nViewH;
    }

private:
    int m_nRefCount = {}; // +0x00
    // +0x04..+0x0f is alignment padding placing the projection matrix on a 16-byte boundary for the
    // vector stores that fill it.
    alignas(16) float m_mProjection[16] = {}; // +0x10
    float m_flFovY = {};                      // +0x50: perspective field of view (zero for ortho).
    float m_flAspect = {};                    // +0x54: perspective aspect ratio (zero for ortho).
    int m_nViewX = {};                        // +0x58
    int m_nViewY = {};                        // +0x5c
    int m_nViewW = {};                        // +0x60
    int m_nViewH = {};                        // +0x64
    // +0x68..+0x6f is tail padding to the 0x70-byte object size.
};

/**
 * @brief A reference-counted camera node: a view matrix and its inverse (camera-to-world).
 *
 * Built by @c CreateLookAtCamera or @c CreateCameraFromMatrix and installed as the current model
 * node through @c SetCurrentModelNode. Storing both the view and its inverse lets the projection
 * helpers transform points in either direction without recomputing. The trailing @c // +0xNN
 * comments document the original 32-bit member offsets for reference only.
 * @ghidraAddress ne::CameraNode (engine class, refcount at +0x0)
 */
class CameraNode {
public:
    /**
     * @brief Constructs a camera node with identity view and inverse-view matrices.
     * @ghidraAddress 0x21ed4
     */
    CameraNode();
    /**
     * @brief Constructs a camera node whose view matrix looks from @p pEye towards @p pTarget.
     * @param pEye The camera position.
     * @param pTarget The look-at target.
     * @param pUp The up direction.
     * @ghidraAddress 0x21f74
     */
    CameraNode(S_VECTOR3 *pEye, S_VECTOR3 *pTarget, S_VECTOR3 *pUp);
    /**
     * @brief Constructs a camera node whose view matrix is taken from @p pViewMatrix.
     * @param pViewMatrix A column-major 4x4 view matrix.
     * @ghidraAddress 0x21fe0
     */
    explicit CameraNode(const float *pViewMatrix);

    /**
     * @brief Add a reference to the camera node.
     */
    void AddRef() {
        ++m_nRefCount;
    }
    /**
     * @brief Remove a reference from the camera node.
     * @return The reference count after the decrement.
     */
    int ReleaseRef() {
        return --m_nRefCount;
    }

    /**
     * @brief The column-major 4x4 view (world-to-camera) matrix.
     */
    float *GetViewMatrix() {
        return m_mView;
    }
    /**
     * @brief The column-major 4x4 inverse-view (camera-to-world) matrix.
     */
    const float *GetInverseViewMatrix() const {
        return m_mInverseView;
    }

private:
    int m_nRefCount = {}; // +0x00
    // +0x04..+0x0f is alignment padding placing the view matrix on a 16-byte boundary.
    alignas(16) float m_mView[16] = {}; // +0x10
    float m_mInverseView[16] = {};      // +0x50
};

} // namespace ne

/**
 * @brief The current projection viewport, retained by @c SetCurrentProjection.
 * @ghidraAddress 0x3cff08
 */
extern ne::Viewport *g_pCurrentProjection;
/**
 * @brief The active view-camera viewport, retained by @c SetActiveViewCamera.
 * @ghidraAddress 0x3cff10
 */
extern ne::Viewport *g_pActiveViewCamera;
/**
 * @brief The current model/world camera node, retained by @c SetCurrentModelNode.
 * @ghidraAddress 0x3cff18
 */
extern ne::CameraNode *g_pCurrentModelNode;

/**
 * @brief Installs a camera as the current one and applies it to the renderer.
 *
 * When the camera differs from the current one, releases the previous camera, retains the new one,
 * stores it, and pushes its viewport and projection matrix to the renderer.
 * @param pRenderer The renderer to apply the camera to.
 * @param pCamera The camera to install.
 * @ghidraAddress 0x29e70
 */
void SetCurrentCamera(neGLESRenderer *pRenderer, ne::Viewport *pCamera);
/**
 * @brief Pushes a camera's viewport rectangle and projection matrix to the renderer.
 * @param pCamera The camera whose viewport and projection are applied.
 * @param pRenderer The renderer to apply them to.
 * @ghidraAddress 0x29a80
 */
void ApplyCameraToRenderer(ne::Viewport *pCamera, neGLESRenderer *pRenderer);
/**
 * @brief Installs the given viewport as the current projection (retaining it and releasing the
 *        previous one).
 * @ghidraAddress 0x29f1c
 */
void SetCurrentProjection(ne::Viewport *pViewport);
/**
 * @brief Installs the given viewport as the active view camera (retaining it and releasing the
 *        previous one).
 * @ghidraAddress 0x29f64
 */
void SetActiveViewCamera(ne::Viewport *pViewport);
/**
 * @brief Installs the given camera node as the current model/world node (retaining it and releasing
 *        the previous one).
 * @ghidraAddress 0x29fac
 */
void SetCurrentModelNode(ne::CameraNode *pCamera);
/**
 * @brief Releases a viewport created by one of the viewport constructors (decrements its
 *        reference count and destroys it at zero).
 * @ghidraAddress 0x29900
 */
void ReleaseViewportCamera(ne::Viewport *pViewport);
/**
 * @brief Creates an orthographic viewport for the given view rectangle.
 * @ghidraAddress 0x2991c
 */
ne::Viewport *
CreateOrthoViewport(float width, float height, int x, int y, int viewportWidth, int viewportHeight);
/**
 * @brief Creates a perspective viewport for the given field of view and view rectangle.
 * @ghidraAddress 0x299c4
 */
ne::Viewport *CreatePerspectiveViewport(float fovY,
                                        float aspect,
                                        float nearZ,
                                        float farZ,
                                        int x,
                                        int y,
                                        int viewportWidth,
                                        int viewportHeight);
/**
 * @brief Creates a camera node from a 4x4 view matrix.
 * @ghidraAddress 0x21fe0
 */
ne::CameraNode *CreateCameraFromMatrix(float *pMatrix);
/**
 * @brief Creates a look-at camera node from an eye, a target, and an up vector.
 * @ghidraAddress 0x21f74
 */
ne::CameraNode *CreateLookAtCamera(S_VECTOR3 *pEye, S_VECTOR3 *pTarget, S_VECTOR3 *pUp);
/**
 * @brief Releases a camera node created by one of the camera-node constructors (decrements its
 *        reference count and destroys it at zero).
 * @ghidraAddress 0x21f58
 */
void ReleaseCameraNode(ne::CameraNode *pCamera);
/**
 * @brief Transforms a 4-vector in place by a camera node's view matrix.
 * @ghidraAddress 0x22058
 */
void TransformVector4ByCamera(ne::CameraNode *pCamera, float *pVec4);

/**
 * @brief Computes a world-space picking ray from a normalised screen point (a perspective
 *        unprojection through the current active-view camera and model node).
 *
 * Builds a near-plane point from the screen coordinates using @c tan(fovY/2) of the active-view
 * camera (@c g_pActiveViewCamera), transforms the ray origin and near point into world space by the
 * current model node's inverse-view matrix (@c g_pCurrentModelNode), and returns the origin and the
 * normalised direction from origin to near point.
 * @param pScreen The normalised screen coordinates (x, y in the unit square).
 * @param pRayOrigin Receives the world-space ray origin (the camera position).
 * @param pRayDir Receives the normalised world-space ray direction.
 * @ghidraAddress 0x29ff4
 */
void ComputeScreenPickRay(const S_VECTOR2 *pScreen, S_VECTOR3 *pRayOrigin, S_VECTOR3 *pRayDir);

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
