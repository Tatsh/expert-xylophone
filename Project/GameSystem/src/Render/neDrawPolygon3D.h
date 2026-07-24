/**
 * @file
 * The 3D polygon-mesh draw node, @c ne::C_DRAW_POLYGON_3D.
 */

#pragma once

#include "neDrawPolygon2D.h"
#include "neRender.h"

struct S_VECTOR2;
struct S_VECTOR3;

namespace ne {

class C_TEXTURE;

/**
 * @brief A 3D polygon-mesh draw node (RTTI @c ne::C_DRAW_POLYGON_3D).
 *
 * Draws an indexed 3D triangle mesh: per-vertex position, colour, and UV arrays plus a 16-bit index
 * buffer. It is a @c C_RENDER, so it lives in the scene graph. The trailing @c // +0xNN comments
 * document the original offsets for reference only; state is reached through the accessors, never
 * through those offsets. Only the members touched by the reconstructed methods are named so far; the
 * rest of the 0x17c-byte object is a reserved span preserving the binary's allocation size.
 */
class C_DRAW_POLYGON_3D : public C_RENDER {
public:
    /**
     * @brief Constructs a 3D polygon-mesh node with the given draw mode, vertex format, vertex and
     * index counts, ownership flags, and draw colour.
     *
     * Records the configuration and initialises the per-vertex attribute offsets to their unset
     * sentinels; @c AllocateBuffers derives the real offsets and allocates the buffers.
     * @param nDrawMode The primitive draw mode.
     * @param nVertexCount The number of vertices.
     * @param nVertexFormat The vertex-format attribute bit-set.
     * @param bVertexBufferExternal Whether the vertex buffer is externally owned.
     * @param nIndexCount The number of index-buffer entries.
     * @param bIndexBufferExternal Whether the index buffer is externally owned.
     * @ghidraAddress 0x285e8
     */
    C_DRAW_POLYGON_3D(unsigned int nDrawMode,
                      unsigned int nVertexCount,
                      unsigned int nVertexFormat,
                      unsigned char bVertexBufferExternal,
                      unsigned int nIndexCount,
                      unsigned char bIndexBufferExternal);

    /**
     * @brief Set a mesh vertex's 3D position, if the mesh carries a position attribute.
     *
     * The position is taken by value (its three components arrive in the floating-point argument
     * registers).
     * @param nIndex The vertex index.
     * @param position The vertex position.
     * @ghidraAddress 0x29638
     */
    void SetPos(int nIndex, S_VECTOR3 position);

    /**
     * @brief Set a mesh vertex's RGBA colour, if the mesh carries a colour attribute.
     * @param nIndex The vertex index.
     * @param nRed The red component.
     * @param nGreen The green component.
     * @param nBlue The blue component.
     * @param nAlpha The alpha component.
     * @ghidraAddress 0x29788
     */
    void SetRGBA(int nIndex,
                 unsigned char nRed,
                 unsigned char nGreen,
                 unsigned char nBlue,
                 unsigned char nAlpha);

    /**
     * @brief Set only the alpha of a mesh vertex's colour, if the mesh carries a colour attribute.
     * @param nIndex The vertex index.
     * @param nAlpha The alpha component.
     * @ghidraAddress 0x29810
     */
    void SetAlpha(int nIndex, unsigned char nAlpha);

    /**
     * @brief Set a mesh vertex's UV coordinates, if the mesh carries a texcoord attribute.
     *
     * The U and V are stored as 16-bit fixed point, with V flipped (1 - v), at the vertex's UV
     * offset within the interleaved buffer.
     * @param nIndex The vertex index.
     * @param flU The U coordinate.
     * @param flV The V coordinate.
     * @ghidraAddress 0x296cc
     */
    void SetUV(int nIndex, float flU, float flV);

    /**
     * @brief Set a mesh vertex's UV coordinates from a vector pointer, forwarding to @c SetUV.
     * @param nIndex The vertex index.
     * @param pUv The UV coordinates.
     * @ghidraAddress 0x296c4
     */
    void SetUvFromVec(int nIndex, const S_VECTOR2 *pUv);

    /**
     * @brief Assign the mesh's texture, updating reference counts.
     *
     * Releases the previously held texture and retains @p pTexture.
     * @param pTexture The texture to assign, or @c nullptr to clear it.
     * @ghidraAddress 0x29558
     */
    void SetTexture(C_TEXTURE *pTexture);

    /**
     * @brief Store one texture-environment parameter.
     * @param nIndex The parameter slot.
     * @param nValue The parameter value.
     * @ghidraAddress 0x2959c
     */
    void SetTexEnvParam(int nIndex, int nValue);

    /**
     * @brief Store a vertex index into the mesh's index buffer and mark it dirty.
     * @param nIndex The position in the index buffer.
     * @param wValue The vertex index to store.
     * @ghidraAddress 0x29890
     */
    void SetIndex(int nIndex, unsigned short wValue);

    // The vertex-format attribute bits tested before writing a vertex attribute.
    enum VertexFormatFlag {
        kVertexHasPosition = 1 << 0, // The mesh carries per-vertex positions.
        kVertexHasTexcoord = 1 << 1, // The mesh carries per-vertex texture coordinates.
        kVertexHasColor = 1 << 2,    // The mesh carries per-vertex colours.
        kVertexHasSkin = 7 << 3,     // The mesh carries per-vertex bone weights and indices.
    };

    /**
     * @brief Allocates the interleaved vertex buffer, the index buffer, and (for a skinned mesh) the
     * per-bone arrays, deriving the per-attribute offsets and stride from the vertex format.
     *
     * Also generates the GL vertex and index buffer objects unless the caller owns them, marking the
     * mesh's vertex and index data dirty so the first draw uploads them.
     * @ghidraAddress 0x287e8
     */
    void AllocateBuffers();

    /**
     * @brief Draws the mesh (the @c C_RENDER vtable render slot).
     *
     * Builds the model matrix from the node's translation, Z rotation, and uniform scale, composes
     * it under the parent's world matrix and then the current model node's view matrix (the step
     * that distinguishes the 3D path from the 2D one), then uploads the (possibly
     * colour-premultiplied) vertex and index data and issues the indexed draw. A skinned mesh
     * additionally loads one palette matrix per bone. Meshes with fewer than one triangle's worth
     * of indices are skipped.
     * @ghidraAddress 0x28964
     */
    void Render() override;

private:
    // Applies the mesh's per-bone translation/rotation/scale palette matrices (the shared skinning
    // path), one per supported vertex unit.
    void LoadBoneMatrices(neGLESRenderer *pRenderer);
    // Premultiplies each vertex colour in the interleaved buffer by its own alpha (the binary's
    // dirty-colour fixup), reading the packed source colours from the colour array.
    void PremultiplyVertexColors();
    // The first derived member sits at +0xd4, in the polymorphic base's tail padding.
    unsigned int m_nDrawMode = {};     // +0xd4: the primitive draw mode.
    unsigned int m_nVertexFormat = {}; // +0xd8: the vertex-format attribute bit-set.
    int m_nVertexCount = {};           // +0xdc: the number of vertices.
    int m_nVertexStride = {};          // +0xe0: the interleaved byte stride between vertices.
    int m_nPositionOffset = {};        // +0xe4: the position byte offset within a vertex.
    int m_nUvOffset = {};           // +0xe8: the texcoord (format bit 1) byte offset in a vertex.
    int m_nColorOffset = {};        // +0xec: the colour (format bit 2) byte offset in a vertex.
    int m_nMatrixWeightOffset = {}; // +0xf0: the bone-weight byte offset within a vertex.
    int m_nMatrixIndexOffset = {};  // +0xf4: the bone-index byte offset within a vertex.
    int m_nBoneComponentCount = {}; // +0xf8: the number of bone components per vertex.
    bool m_bVertexBufferExternal = {}; // +0xfc: whether the vertex buffer is externally owned.
    bool m_bVertexDirty = {};          // +0xfd: set when a vertex attribute is modified.
    bool m_bColorDirty = {};           // +0xfe: set when a vertex colour is modified.
    // +0xff is alignment padding before the vertex VBO handle.
    unsigned char m_aPadFf[1] = {};  // +0xff
    unsigned int m_dwVertexVbo = {}; // +0x100: the vertex-buffer GL handle.
    // +0x104 is alignment padding before the vertex-buffer pointer.
    unsigned char m_aPad104[4] = {}; // +0x104
    void *m_pVertexArray = {};       // +0x108: the interleaved vertex-attribute buffer.
    S_RGBA *m_pColorArray = {};      // +0x110: the per-vertex colour array (a.k.a. texcoord slot).
    int m_nIndexCount = {};          // +0x118: the number of entries in the index buffer.
    unsigned int m_nDrawIndexCount = {}; // +0x11c: the element count passed to the indexed draw.
    bool m_bIndexBufferExternal = {};    // +0x120: whether the index buffer is externally owned.
    bool m_bIndexDirty = {};             // +0x121: set when the index buffer is modified.
    // +0x122 is alignment padding before the index VBO handle.
    unsigned char m_aPad122[2] = {};    // +0x122
    unsigned int m_dwIndexVbo = {};     // +0x124: the index-buffer GL handle.
    unsigned short *m_pIndexArray = {}; // +0x128: the 16-bit index buffer.
    float m_flTranslateX = {};          // +0x130: the model translation X.
    float m_flTranslateY = {};          // +0x134: the model translation Y.
    float m_flTranslateZ = {};          // +0x138: the model translation Z.
    float m_flRotationZ = {};           // +0x13c: the model rotation about Z.
    float m_flScale = {};               // +0x140: the uniform model scale.
    // +0x144..+0x147 is alignment padding before the per-bone array pointers.
    unsigned char m_aPad144[4] = {}; // +0x144
    void *m_pBoneTranslate = {};     // +0x148: the per-bone translation array.
    void *m_pBoneRotation = {};      // +0x150: the per-bone rotation array.
    void *m_pBoneScale = {};         // +0x158: the per-bone scale array.
    C_TEXTURE *m_pTexture = {};      // +0x160: the retained texture.
    int m_aTexEnvParams[4] = {};     // +0x168: the texture-environment parameters.
    int m_nBlendMode = {};           // +0x178: the blend-mode identifier.
};

/**
 * @brief Allocates and initialises a 3D polygon-mesh node ready to be populated and drawn.
 * @param nDrawMode The primitive draw mode.
 * @param nVertexCount The number of vertices.
 * @param nVertexFormat The vertex-format attribute bit-set.
 * @param bVertexBufferExternal Whether the vertex buffer is externally owned.
 * @param nIndexCount The number of index-buffer entries.
 * @param bIndexBufferExternal Whether the index buffer is externally owned.
 * @return The new 3D polygon-mesh node.
 * @ghidraAddress 0x295a8
 */
C_DRAW_POLYGON_3D *CreatePolygon3dMesh(unsigned int nDrawMode,
                                       unsigned int nVertexCount,
                                       unsigned int nVertexFormat,
                                       unsigned char bVertexBufferExternal,
                                       unsigned int nIndexCount,
                                       unsigned char bIndexBufferExternal);

} // namespace ne

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
