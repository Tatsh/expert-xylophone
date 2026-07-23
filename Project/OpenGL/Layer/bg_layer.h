#pragma once

namespace ne {
class C_RENDER;
} // namespace ne

/**
 * @brief The engine's shared background layer.
 *
 * A single @c BgLayer owns the root render object that every screen's background sprites are
 * attached under. Only the accessor used to reach that root is recovered so far; the layer's own
 * fields have not yet been reconstructed.
 */
class BgLayer {
public:
    /**
     * @brief The root scene-graph node that background sprites are attached to.
     * @return The background layer's root render object.
     * @ghidraAddress 0x17278c
     */
    ne::C_RENDER *GetBackgroundRenderObject();
};

/**
 * @brief The process-wide background layer, created on first use.
 * @return The shared background layer.
 * @ghidraAddress 0x17203c
 */
BgLayer *GetBackgroundLayer();

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
