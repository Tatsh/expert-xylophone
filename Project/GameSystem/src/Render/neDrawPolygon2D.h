/**
 * @file
 * The 2D polygon-mesh draw node, @c ne::C_DRAW_POLYGON_2D.
 */

#pragma once

#include "neRender.h"

namespace ne {

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
     * @brief Set a mesh vertex's position, if the mesh carries a position attribute.
     * @param nIndex The vertex index.
     * @param flX The vertex X position.
     * @param flY The vertex Y position.
     * @ghidraAddress 0x28328
     */
    void SetPos(int nIndex, float flX, float flY);

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
        kVertexHasColor = 1 << 2,    // The mesh carries per-vertex colours.
    };

private:
    unsigned int m_nVertexFormat = {}; // +0xd8: the vertex-format attribute bit-set.
    int m_nVertexCount = {};           // +0xdc: the number of vertices.
    int m_nVertexStride = {};          // +0xe0: the byte stride between vertices.
    int m_nPositionOffset = {};        // +0xe4: the byte offset of the position within a vertex.
    // +0xe8..+0xfc: further mesh state still being worked out.
    unsigned char m_aReservedE8[0x15] = {}; // +0xe8
    bool m_bVertexDirty = {};               // +0xfd: set when a vertex attribute is modified.
    bool m_bColorDirty = {};                // +0xfe: set when a vertex colour is modified.
    // +0xff..+0x107 is padding before the array pointers.
    unsigned char m_aPadFf[9] = {};    // +0xff
    void *m_pVertexArray = {};         // +0x108: the interleaved vertex-attribute array.
    unsigned char *m_pColorArray = {}; // +0x110: the per-vertex RGBA colour array (4 bytes each).
    int m_nIndexCount = {};            // +0x118: the number of entries in the index buffer.
    // +0x11c..+0x120: further mesh state still being worked out.
    unsigned char m_aReserved11c[5] = {}; // +0x11c
    bool m_bIndexDirty = {};              // +0x121: set when the index buffer is modified.
    // +0x122..+0x127 is alignment padding before the index-array pointer.
    unsigned char m_aPad122[6] = {};    // +0x122
    unsigned short *m_pIndexArray = {}; // +0x128: the 16-bit index buffer.
    // +0x130..+0x173: remaining mesh state still being worked out.
    unsigned char m_aReserved130[0x44] = {}; // +0x130
};

} // namespace ne

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
