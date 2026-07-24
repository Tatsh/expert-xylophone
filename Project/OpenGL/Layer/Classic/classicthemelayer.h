/**
 * @file
 * The Classic-theme play-field background layer.
 */

#pragma once

#include "playfieldlayerbase.h"

namespace ne {
class C_TEXTURE;
class C_SPRITE_INSTANCING;
} // namespace ne

/**
 * @brief The Classic-theme play-field background layer.
 *
 * Owns the three background sprite batches for the Classic theme and the shared texture they draw
 * from, building them lazily into the background scene graph on first use. The trailing @c // +0xNN
 * comments document the original 32-bit offsets for reference only; state is reached through named
 * members, never through those offsets.
 */
class ClassicThemeLayer : public PlayFieldLayerBase {
public:
    ClassicThemeLayer();

    /**
     * @brief Build the Classic-theme background sprite batches into the scene graph.
     *
     * On the first call it loads the shared background texture, creates the three world sprite
     * batches, attaches them under the background layer's root, seeds each batch's sprite count from
     * the layer, and makes them visible; the third batch is additively blended. Subsequent calls do
     * nothing.
     * @ghidraAddress 0x109f30
     */
    void InitializeBackgroundSceneNodes();

private:
    static constexpr int kBackgroundBatchCount = 3;

    ne::C_TEXTURE *m_pTexture = {};                                       // +0x08
    ne::C_SPRITE_INSTANCING *m_apSpriteBatch[kBackgroundBatchCount] = {}; // +0x10
    int m_anSpriteCount[kBackgroundBatchCount] = {};                      // +0x28
    bool m_fInitialized = {};                                             // +0x34
    // +0x35..+0x5f: layer state not yet recovered (a field count, flags, and pointers this routine
    // does not touch); kept as reserved storage rather than invented field names.
    unsigned char m_reserved35[43] = {};
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
