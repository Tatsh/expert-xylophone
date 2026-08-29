/**
 * @file
 * The 3D polygon-mesh draw node, @c ne::C_DRAW_POLYGON_3D.
 */

#pragma once

#include "neDrawPolygon2D.h"
#include "neRender.h"

class neGLESRenderer;
struct S_VECTOR2;
struct S_VECTOR3;

namespace ne {

class C_TEXTURE;

/**
 * A 3D polygon-mesh draw node (RTTI @c ne::C_DRAW_POLYGON_3D).
 *
 * Draws an indexed 3D triangle mesh: per-vertex position, colour, and UV arrays plus a 16-bit index
 * buffer. It is a @c C_RENDER, so it lives in the scene graph. The trailing @c // +0xNN comments
 * document the original offsets for reference only; state is reached through the accessors, never
 * through those offsets. Only the members touched by the reconstructed methods are named so far;
 * the rest of the 0x17c-byte object is a reserved span preserving the binary's allocation size.
 */
class C_DRAW_POLYGON_3D : public C_RENDER {
public:
    /**
     * Constructs a 3D polygon-mesh node with the given draw mode, vertex format, vertex and
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
                      bool bVertexBufferExternal,
                      unsigned int nIndexCount,
                      bool bIndexBufferExternal);

    /**
     * Destroys the mesh: releases the bound texture, frees the vertex, colour, index, and
     * per-bone arrays, deletes the GL vertex and index buffer objects it owns, and chains the base
     * render-node destructor.
     * @ghidraAddress 0x286c0
     */
    ~C_DRAW_POLYGON_3D() override;

    /**
     * Set a mesh vertex's 3D position, if the mesh carries a position attribute.
     *
     * The position is taken by value (its three components arrive in the floating-point argument
     * registers).
     * @param nIndex The vertex index.
     * @param position The vertex position.
     * @ghidraAddress 0x29638
     */
    void SetPos(int nIndex, S_VECTOR3 position);

    /**
     * Set a mesh vertex's RGBA colour, if the mesh carries a colour attribute.
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
     * Set only the alpha of a mesh vertex's colour, if the mesh carries a colour attribute.
     * @param nIndex The vertex index.
     * @param nAlpha The alpha component.
     * @ghidraAddress 0x29810
     */
    void SetAlpha(int nIndex, unsigned char nAlpha);

    /**
     * Set a mesh vertex's UV coordinates, if the mesh carries a texcoord attribute.
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
     * Set a mesh vertex's UV coordinates from a vector pointer, forwarding to @c SetUV.
     * @param nIndex The vertex index.
     * @param pUv The UV coordinates.
     * @ghidraAddress 0x296c4
     */
    void SetUvFromVec(int nIndex, const S_VECTOR2 *pUv);

    /**
     * Assign the mesh's texture, updating reference counts.
     *
     * Releases the previously held texture and retains @p pTexture.
     * @param pTexture The texture to assign, or @c nullptr to clear it.
     * @ghidraAddress 0x29558
     */
    void SetTexture(C_TEXTURE *pTexture);

    /**
     * Store one texture-environment parameter.
     * @param nIndex The parameter slot.
     * @param nValue The parameter value.
     * @ghidraAddress 0x2959c
     */
    void SetTexEnvParam(int nIndex, int nValue);

    /**
     * Store a vertex index into the mesh's index buffer and mark it dirty.
     * @param nIndex The position in the index buffer.
     * @param wValue The vertex index to store.
     * @ghidraAddress 0x29890
     */
    void SetIndex(int nIndex, unsigned short wValue);

    /** The vertex-format attribute bits tested before writing a vertex attribute. */
    enum VertexFormatFlag {
        kVertexHasPosition = 1 << 0, /*!< The mesh carries per-vertex positions. */
        kVertexHasTexcoord = 1 << 1, /*!< The mesh carries per-vertex texture coordinates. */
        kVertexHasColor = 1 << 2,    /*!< The mesh carries per-vertex colours. */
        kVertexHasSkin = 7 << 3,     /*!< The mesh carries per-vertex bone weights and indices. */
    };

    /**
     * Allocates the interleaved vertex buffer, the index buffer, and (for a skinned mesh)
     * the per-bone arrays, deriving the per-attribute offsets and stride from the vertex format.
     *
     * Also generates the GL vertex and index buffer objects unless the caller owns them, marking
     * the mesh's vertex and index data dirty so the first draw uploads them.
     * @ghidraAddress 0x287e8
     */
    void AllocateBuffers();

    /**
     * Draws the mesh (the @c C_RENDER vtable render slot).
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
    void LoadBoneMatrices(neGLESRenderer *pRenderer);
    void PremultiplyVertexColors();
    unsigned int m_nDrawMode = {};     // +0xd4
    unsigned int m_nVertexFormat = {}; // +0xd8
    int m_nVertexCount = {};           // +0xdc
    int m_nVertexStride = {};          // +0xe0
    int m_nPositionOffset = {};        // +0xe4
    int m_nUvOffset = {};              // +0xe8: format bit 1.
    int m_nColorOffset = {};           // +0xec: format bit 2.
    int m_nMatrixWeightOffset = {};    // +0xf0
    int m_nMatrixIndexOffset = {};     // +0xf4
    int m_nBoneComponentCount = {};    // +0xf8
    bool m_bVertexBufferExternal = {}; // +0xfc
    bool m_bVertexDirty = {};          // +0xfd
    bool m_bColorDirty = {};           // +0xfe
    // unsigned char m_aPadFf[1] = {};  // +0xff
    unsigned int m_dwVertexVbo = {}; // +0x100
    // unsigned char m_aPad104[4] = {}; // +0x104
    void *m_pVertexArray = {};           // +0x108: interleaved attributes.
    S_RGBA *m_pColorArray = {};          // +0x110: also the texcoord slot.
    int m_nIndexCount = {};              // +0x118
    unsigned int m_nDrawIndexCount = {}; // +0x11c: the count passed to the indexed draw.
    bool m_bIndexBufferExternal = {};    // +0x120
    bool m_bIndexDirty = {};             // +0x121
    // unsigned char m_aPad122[2] = {};    // +0x122
    unsigned int m_dwIndexVbo = {};     // +0x124
    unsigned short *m_pIndexArray = {}; // +0x128
    float m_flTranslateX = {};          // +0x130
    float m_flTranslateY = {};          // +0x134
    float m_flTranslateZ = {};          // +0x138
    float m_flRotationZ = {};           // +0x13c
    float m_flScale = {};               // +0x140
    // unsigned char m_aPad144[4] = {}; // +0x144..+0x147
    void *m_pBoneTranslate = {}; // +0x148
    void *m_pBoneRotation = {};  // +0x150
    void *m_pBoneScale = {};     // +0x158
    C_TEXTURE *m_pTexture = {};  // +0x160: retained.
    int m_aTexEnvParams[4] = {}; // +0x168
    int m_nBlendMode = {};       // +0x178
};

/**
 * Allocates and initialises a 3D polygon-mesh node ready to be populated and drawn.
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
                                       bool bVertexBufferExternal,
                                       unsigned int nIndexCount,
                                       bool bIndexBufferExternal);

} // namespace ne
