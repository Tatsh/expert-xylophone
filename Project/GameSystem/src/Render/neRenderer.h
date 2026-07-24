/**
 * @file
 * The reference-counted projection viewport, @c ne_Viewport.
 */

#pragma once

struct S_VECTOR3;

/**
 * @brief A reference-counted projection viewport: a 4x4 projection matrix and a GL viewport
 * rectangle.
 *
 * Built by @c CreateOrthoViewport or @c CreatePerspectiveViewport and shared by reference count;
 * @c ReleaseViewportCamera drops a reference and destroys the viewport at zero. The trailing
 * @c // +0xNN comments document the original 32-bit member offsets for reference only.
 */
class ne_Viewport {
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
    ne_Viewport(float flWidth, float flHeight, int nViewX, int nViewY, int nViewW, int nViewH);
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
    ne_Viewport(float flFovY,
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
 * @brief The current projection viewport, retained by @c SetCurrentProjection.
 * @ghidraAddress 0x3cff08
 */
extern ne_Viewport *g_pCurrentProjection;
/**
 * @brief The active view-camera viewport, retained by @c SetActiveViewCamera.
 * @ghidraAddress 0x3cff10
 */
extern ne_Viewport *g_pActiveViewCamera;

/**
 * @brief A reference-counted camera node: a view matrix and its inverse (camera-to-world).
 *
 * Built by @c CreateLookAtCamera or @c CreateCameraFromMatrix and installed as the current model
 * node through @c SetCurrentModelNode. Storing both the view and its inverse lets the projection
 * helpers transform points in either direction without recomputing. The trailing @c // +0xNN
 * comments document the original 32-bit member offsets for reference only.
 */
class ne_CameraNode {
public:
    /**
     * @brief Constructs a camera node with identity view and inverse-view matrices.
     * @ghidraAddress 0x21ed4
     */
    ne_CameraNode();
    /**
     * @brief Constructs a camera node whose view matrix looks from @p pEye towards @p pTarget.
     * @param pEye The camera position.
     * @param pTarget The look-at target.
     * @param pUp The up direction.
     * @ghidraAddress 0x21f74
     */
    ne_CameraNode(S_VECTOR3 *pEye, S_VECTOR3 *pTarget, S_VECTOR3 *pUp);
    /**
     * @brief Constructs a camera node whose view matrix is taken from @p pViewMatrix.
     * @param pViewMatrix A column-major 4x4 view matrix.
     * @ghidraAddress 0x21fe0
     */
    explicit ne_CameraNode(const float *pViewMatrix);

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

/**
 * @brief The current model/world camera node, retained by @c SetCurrentModelNode.
 * @ghidraAddress 0x3cff18
 */
extern ne_CameraNode *g_pCurrentModelNode;

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
