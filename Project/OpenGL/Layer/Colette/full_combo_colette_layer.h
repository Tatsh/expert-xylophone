/**
 * @file
 * The Colette-theme full-combo layer, @c FullComboColetteLayer.
 */

#pragma once

#include "playfieldlayerbase.h"

namespace ne {
class C_TEXTURE;
class C_SPRITE_INSTANCING;
} // namespace ne

/**
 * @brief The Colette-theme full-combo layer.
 *
 * A process-wide singleton, built on first access, deriving from @c PlayFieldLayerBase. It owns three
 * sprite instancers, drawn beneath the shared background layer, that present the Colette full-combo
 * effect (all three sharing the gm_parts2 atlas). The class carries no RTTI (it is non-polymorphic),
 * so the name is inferred from its singleton getter rather than confirmed from the runtime metadata.
 * The trailing @c // +0xNN comments document the original 32-bit offsets for reference only.
 */
class FullComboColetteLayer : public PlayFieldLayerBase {
public:
    /**
     * @brief The process-wide Colette full-combo layer, created on first use.
     * @return The shared layer.
     * @ghidraAddress 0x9b18c
     */
    static FullComboColetteLayer *shared();

    /**
     * @brief Lazily builds the layer's textures and sprites: loads the atlas into each of the three
     * texture fields and creates the three sprite instancers (attaching each under the background
     * layer's render object, making it visible, binding its atlas, clearing its sprite count,
     * flagging additive blend on the middle slot, and enabling its two texture-environment
     * parameters).
     *
     * Guarded so the sprites are built only once.
     * @ghidraAddress 0x9b1dc
     */
    void InitializeBackgroundSpriteLayers();

    // The number of full-combo sprite instancers the layer builds.
    static constexpr int kSpriteSlotCount = 3;

private:
    // A per-slot effect record the constructor zero-clears (its fields are still being worked out).
    struct EffectRecord {
        bool m_bFlag = {};             // +0x00
        unsigned char m_aPad1[3] = {}; // +0x01
        int m_nValue = {};             // +0x04
        bool m_bFlag2 = {};            // +0x08
        unsigned char m_aPad9[3] = {}; // +0x09
    };

    float m_flWidth = {};  // +0x08: the layer's layout width (384), seeded by the constructor.
    float m_flHeight = {}; // +0x0c: the layer's layout height, seeded by the constructor.
    ne::C_TEXTURE *m_pTexture0 = {}; // +0x10: the gm_parts2 atlas.
    ne::C_TEXTURE *m_pTexture1 = {}; // +0x18: a second gm_parts2 handle.
    ne::C_TEXTURE *m_pTexture2 = {}; // +0x20: a third gm_parts2 handle.
    ne::C_SPRITE_INSTANCING *m_apSprites[kSpriteSlotCount] =
        {};                                     // +0x28: the per-slot sprite batches.
    int m_aSpriteCounts[kSpriteSlotCount] = {}; // +0x40: each slot's initial count.
    bool m_bBuilt = {};                         // +0x4c: set once the sprites are built.
    // +0x4d..+0x4f is alignment padding before the effect records.
    unsigned char m_aPad4d[3] = {};                     // +0x4d
    EffectRecord m_aEffects[kSpriteSlotCount - 1] = {}; // +0x50: two per-slot effect records.
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
