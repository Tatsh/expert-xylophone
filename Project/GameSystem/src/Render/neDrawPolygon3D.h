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
    };

private:
    unsigned int m_nVertexFormat = {}; // +0xd8: the vertex-format attribute bit-set.
    int m_nVertexCount = {};           // +0xdc: the number of vertices.
    int m_nVertexStride = {};          // +0xe0: the interleaved byte stride between vertices.
    int m_nPositionOffset = {};        // +0xe4: the position byte offset within a vertex.
    int m_nUvOffset = {};              // +0xe8: the texcoord byte offset within a vertex.
    // +0xec..+0xfc: further mesh state still being worked out.
    unsigned char m_aReservedEc[0x11] = {}; // +0xec
    bool m_bVertexDirty = {};               // +0xfd: set when a vertex attribute is modified.
    bool m_bColorDirty = {};                // +0xfe: set when a vertex colour is modified.
    // +0xff..+0x107 is padding before the array pointers.
    unsigned char m_aPadFf[9] = {}; // +0xff
    void *m_pVertexArray = {};      // +0x108: the interleaved vertex-attribute array.
    S_RGBA *m_pColorArray = {};     // +0x110: the per-vertex RGBA colour array.
    int m_nIndexCount = {};         // +0x118: the number of entries in the index buffer.
    // +0x11c..+0x120: further mesh state still being worked out.
    unsigned char m_aReserved11c[5] = {}; // +0x11c
    bool m_bIndexDirty = {};              // +0x121: set when the index buffer is modified.
    // +0x122..+0x127 is alignment padding before the index-array pointer.
    unsigned char m_aPad122[6] = {};    // +0x122
    unsigned short *m_pIndexArray = {}; // +0x128: the 16-bit index buffer.
    // +0x130..+0x17b: remaining mesh state still being worked out.
    unsigned char m_aReserved130[0x4c] = {}; // +0x130
};

} // namespace ne

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
