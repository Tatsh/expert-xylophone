/**
 * @file
 * The engine's shared background layer.
 */

#pragma once

#include "playfieldlayerbase.h"

namespace ne {
class C_RENDER;
} // namespace ne

/**
 * @brief The engine's shared background layer.
 *
 * A single @c BgLayer owns the root render node that every screen's background, HUD, and effect
 * layers attach their sprites under. The root is built lazily on first access. Trailing
 * @c // +0xNN comments document the original 32-bit offsets for reference only; most of the layer's
 * own state has not yet been recovered and is kept as named reserved storage.
 */
class BgLayer : public PlayFieldLayerBase {
public:
    /**
     * @brief The process-wide background layer, created on first use.
     * @return The shared background layer.
     * @ghidraAddress 0x17203c
     */
    static BgLayer *GetBackgroundLayer();

    /**
     * @brief The root scene-graph node background sprites are attached to, building the layer on
     * first access.
     * @return The background layer's root render node.
     * @ghidraAddress 0x17278c
     */
    ne::C_RENDER *GetBackgroundRenderObject();

    /**
     * @brief Build the background layer's root node and content.
     * @ghidraAddress 0x1720c4
     */
    void InitializeBackgroundLayer();

private:
    // The layer-kind identifier the factory stamps into a background layer.
    static constexpr int kBackgroundLayerKind = 0x1d;

    ne::C_RENDER *m_pRootSprite = {};    // +0x08
    unsigned char m_reserved10[32] = {}; // +0x10: layer state not yet recovered.
    int m_nField30 = {};                 // +0x30: initialised to 1 by the factory.
    bool m_fBuilt = {};                  // +0x34
    int m_nLayerKind = {};               // +0x38
    unsigned char m_reserved3c[44] = {}; // +0x3c: layer state not yet recovered.
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
