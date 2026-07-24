/**
 * @file
 * The 3D polygon-mesh draw node, @c ne::C_DRAW_POLYGON_3D.
 */

#pragma once

#include "neRender.h"

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
     * @brief Store a vertex index into the mesh's index buffer and mark it dirty.
     * @param nIndex The position in the index buffer.
     * @param wValue The vertex index to store.
     * @ghidraAddress 0x29890
     */
    void SetIndex(int nIndex, unsigned short wValue);

private:
    // +0xd8..+0x117: the base C_RENDER tail and the mesh's vertex/colour/UV array pointers and
    // counts, whose individual fields are still being worked out.
    unsigned char m_aReservedD8[0x40] = {}; // +0xd8
    int m_nIndexCount = {};                 // +0x118: the number of entries in the index buffer.
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
