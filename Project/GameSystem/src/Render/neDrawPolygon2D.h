/**
 * @file
 * The 2D polygon-mesh draw node, @c ne::C_DRAW_POLYGON_2D.
 */

#pragma once

#include "neRender.h"

struct S_VECTOR2;

namespace ne {

/**
 * @brief A packed 8-bit-per-channel RGBA colour, in memory order.
 */
struct S_RGBA {
    unsigned char nRed = {};   // +0x00
    unsigned char nGreen = {}; // +0x01
    unsigned char nBlue = {};  // +0x02
    unsigned char nAlpha = {}; // +0x03
};

/**
 * @brief A 2D polygon-mesh draw node (RTTI @c ne::C_DRAW_POLYGON_2D).
 *
 * Draws an indexed 2D triangle mesh: per-vertex position, colour, and UV arrays plus a 16-bit index
 * buffer, uploaded together. It is a @c C_RENDER, so it lives in the scene graph. The trailing
 * @c // +0xNN comments document the original 32-bit offsets for reference only; state is reached
 * through the accessors, never through those offsets. Only the members touched by the reconstructed
 * methods are named so far; the rest of the 0x174-byte object is a reserved span preserving the
 * binary's allocation size.
 */
class C_DRAW_POLYGON_2D : public C_RENDER {
public:
    /**
     * @brief Constructs a 2D polygon-mesh node with the given draw mode, vertex format, vertex and
     * index counts, ownership flags, and draw colour.
     *
     * Records the configuration and initialises the per-vertex attribute offsets to their unset
     * sentinels; @c AllocatePolygon2dMeshBuffers derives the real offsets and allocates the buffers.
     * @param nDrawMode The primitive draw mode.
     * @param nVertexCount The number of vertices.
     * @param nVertexFormat The vertex-format attribute bit-set.
     * @param bVertexBufferExternal Whether the vertex buffer is externally owned.
     * @param nIndexCount The number of index-buffer entries.
     * @param bIndexBufferExternal Whether the index buffer is externally owned.
     * @ghidraAddress 0x27374
     */
    C_DRAW_POLYGON_2D(unsigned int nDrawMode,
                      unsigned int nVertexCount,
                      unsigned int nVertexFormat,
                      unsigned char bVertexBufferExternal,
                      unsigned int nIndexCount,
                      unsigned char bIndexBufferExternal);

    /**
     * @brief Set a mesh vertex's position, if the mesh carries a position attribute.
     *
     * The position is taken by value (its two components arrive in the floating-point argument
     * registers), so this is interchangeable with the pointer-taking @c SetPosFromVec wrapper.
     * @param nIndex The vertex index.
     * @param position The vertex position.
     * @ghidraAddress 0x28328
     */
    void SetPos(int nIndex, S_VECTOR2 position);

    /**
     * @brief Set a mesh vertex's position from a vector pointer, forwarding to @c SetPos.
     * @param nIndex The vertex index.
     * @param pPosition The vertex position.
     * @ghidraAddress 0x28320
     */
    void SetPosFromVec(int nIndex, const S_VECTOR2 *pPosition);

    /**
     * @brief Set a mesh vertex's RGBA colour, if the mesh carries a colour attribute.
     * @param nIndex The vertex index.
     * @param nRed The red component.
     * @param nGreen The green component.
     * @param nBlue The blue component.
     * @param nAlpha The alpha component.
     * @ghidraAddress 0x28470
     */
    void SetRGBA(int nIndex,
                 unsigned char nRed,
                 unsigned char nGreen,
                 unsigned char nBlue,
                 unsigned char nAlpha);

    /**
     * @brief Store a vertex index into the mesh's index buffer and mark it dirty.
     * @param nIndex The position in the index buffer.
     * @param wValue The vertex index to store.
     * @ghidraAddress 0x28578
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
     * @ghidraAddress 0x27568
     */
    void AllocateBuffers();

private:
    // The first derived member sits at +0xd4, in the polymorphic base's tail padding.
    unsigned int m_nDrawMode = {};     // +0xd4: the primitive draw mode.
    unsigned int m_nVertexFormat = {}; // +0xd8: the vertex-format attribute bit-set.
    int m_nVertexCount = {};           // +0xdc: the number of vertices.
    int m_nVertexStride = {};          // +0xe0: the interleaved byte stride between vertices.
    int m_nPositionOffset = {};        // +0xe4: the position byte offset within a vertex.
    int m_nTexcoordOffset = {};     // +0xe8: the texcoord (format bit 1) byte offset in a vertex.
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
    unsigned char m_aPad104[4] = {};  // +0x104
    void *m_pVertexArray = {};        // +0x108: the interleaved vertex-attribute buffer.
    S_RGBA *m_pColorArray = {};       // +0x110: the per-vertex colour array (a.k.a. texcoord slot).
    int m_nIndexCount = {};           // +0x118: the number of entries in the index buffer.
    unsigned int m_dwDrawColor = {};  // +0x11c: the mesh's flat draw colour.
    bool m_bIndexBufferExternal = {}; // +0x120: whether the index buffer is externally owned.
    bool m_bIndexDirty = {};          // +0x121: set when the index buffer is modified.
    // +0x122 is alignment padding before the index VBO handle.
    unsigned char m_aPad122[2] = {};    // +0x122
    unsigned int m_dwIndexVbo = {};     // +0x124: the index-buffer GL handle.
    unsigned short *m_pIndexArray = {}; // +0x128: the 16-bit index buffer.
    float m_flTranslateX = {};          // +0x130: the model translation X.
    float m_flTranslateY = {};          // +0x134: the model translation Y.
    float m_flRotationZ = {};           // +0x138: the model rotation about Z.
    float m_flScale = {};               // +0x13c: the uniform model scale.
    void *m_pBoneTranslate = {};        // +0x140: the per-bone translation array.
    void *m_pBoneRotation = {};         // +0x148: the per-bone rotation array.
    void *m_pBoneScale = {};            // +0x150: the per-bone scale array.
    void *m_pTexture = {};              // +0x158: the bound texture.
    int m_aTexParams[4] = {};           // +0x160: the texture-sampler parameters.
    int m_nBlendMode = {};              // +0x170: the blend-mode identifier.
};

/**
 * @brief Allocates and initialises a 2D polygon-mesh node ready to be populated and drawn.
 * @param nDrawMode The primitive draw mode.
 * @param nVertexCount The number of vertices.
 * @param nVertexFormat The vertex-format attribute bit-set.
 * @param bVertexBufferExternal Whether the vertex buffer is externally owned.
 * @param nIndexCount The number of index-buffer entries.
 * @param bIndexBufferExternal Whether the index buffer is externally owned.
 * @return The new 2D polygon-mesh node.
 * @ghidraAddress 0x28290
 */
C_DRAW_POLYGON_2D *CreatePolygon2dMesh(unsigned int nDrawMode,
                                       unsigned int nVertexCount,
                                       unsigned int nVertexFormat,
                                       unsigned char bVertexBufferExternal,
                                       unsigned int nIndexCount,
                                       unsigned char bIndexBufferExternal);

} // namespace ne

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
