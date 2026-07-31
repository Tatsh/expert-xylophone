/**
 * @file
 * The world-space batched sprite draw node, @c ne::C_SPRITE_INSTANCING_3D.
 */

#pragma once

#include "neSpriteInstancing.h"

namespace ne {

/**
 * @brief A world-space batched sprite draw node (RTTI @c ne::C_SPRITE_INSTANCING_3D).
 *
 * The binary builds this from its own constructor (@c 0x3097c, the one
 * @c CreateWorldSpriteBatch calls) and installs a second vtable at @c 0x3594a0 whose render slot is
 * @c 0x30dc0, against the screen-space batch's @c 0x359450 and @c 0x2faa8. The two are distinct
 * classes, not one class with a mode flag: their @c type_info records name them
 * @c ne::C_SPRITE_INSTANCING_2D and @c ne::C_SPRITE_INSTANCING_3D.
 *
 * They hold identical state -- the same ten allocations and the same field stores, the world-space
 * constructor differing only by clearing the byte at @c +0x154 -- and differ only in how they draw:
 * this node composes every sprite against the current model node's camera matrix, so its sprite
 * coordinates are relative to the play-field centre, while the screen-space node draws against the
 * parent's world matrix alone under the top-left orthographic projection.
 *
 * @note In the binary the two derive from separate bases, @c ne::C_RENDER_2D and
 * @c ne::C_RENDER_3D, which this tree has not split out of its single @c C_RENDER yet. Deriving
 * this node from the screen-space one is therefore a deliberate simplification: it reproduces the
 * layout and the render-slot override exactly, but not the base hierarchy.
 *
 * That simplification is safe rather than merely convenient. Both bases name @c ne::C_RENDER as
 * their own base, and neither has an instantiated vtable anywhere in @c __const, so they are
 * intermediate classes that contribute no virtual behaviour of their own. Of the nine @c ne::
 * classes the binary carries type_info for, these two are the only ones this tree does not model,
 * so this node was the last collapsed class whose vtable difference could change what a draw does.
 */
class C_SPRITE_INSTANCING_3D : public C_SPRITE_INSTANCING_2D {
public:
    /**
     * @brief Constructs a world-space sprite batch that can draw up to @p nCapacity sprites.
     * @param nCapacity The maximum number of sprites the batch can draw.
     * @ghidraAddress 0x3097c
     */
    explicit C_SPRITE_INSTANCING_3D(unsigned int nCapacity);

    /**
     * @brief Draws every live sprite composed under the current model node's camera matrix.
     *
     * Every live sprite carries its own transform matrix through the palette-matrix slot, each
     * composed with the shared world*camera matrix (the current model node's view matrix times the
     * parent's world matrix). There is no axis-aligned fast path.
     * @ghidraAddress 0x30dc0
     */
    void Render() override;
};

} // namespace ne

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
