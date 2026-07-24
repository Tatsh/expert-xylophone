/**
 * @file
 * The Classic-theme full-combo layer, @c FullComboClassicLayer.
 */

#pragma once

#include "playfieldlayerbase.h"

namespace ne {
class C_TEXTURE;
class C_SPRITE_INSTANCING;
} // namespace ne

/**
 * @brief The Classic-theme full-combo layer.
 *
 * A process-wide singleton, built on first access, deriving from @c PlayFieldLayerBase. It owns one
 * atlas and three sprite instancers, drawn beneath the shared background layer, that present the
 * Classic full-combo effect. The class carries no RTTI (it is non-polymorphic), so the name is
 * inferred from its singleton getter rather than confirmed from the runtime metadata. The trailing
 * @c // +0xNN comments document the original 32-bit offsets for reference only.
 */
class FullComboClassicLayer : public PlayFieldLayerBase {
public:
    /**
     * @brief The process-wide Classic full-combo layer, created on first use.
     * @return The shared layer.
     * @ghidraAddress 0x10f2dc
     */
    static FullComboClassicLayer *shared();

    /**
     * @brief Lazily builds the layer's three background sprite instancers: loads the atlas and
     * creates each instancer (attaching it under the background layer's render object, making it
     * visible, binding the atlas, clearing its sprite count, flagging additive blend, and seeding
     * its two texture-environment parameters).
     *
     * Guarded so the sprites are built only once.
     * @ghidraAddress 0x10f32c
     */
    void InitializeBackgroundSprites();

    // The number of background sprite instancers the layer builds.
    static constexpr int kSpriteSlotCount = 3;

private:
    /**
     * @brief Constructs the layer, chaining the base constructor and zero-clearing its own state.
     * @ghidraAddress 0x10f280
     */
    FullComboClassicLayer();

    // A per-slot effect record the constructor zero-clears (its fields are still being worked out).
    struct EffectRecord {
        bool m_bFlag = {};             // +0x00
        unsigned char m_aPad1[3] = {}; // +0x01
        int m_nValue = {};             // +0x04
        bool m_bFlag2 = {};            // +0x08
        unsigned char m_aPad9[3] = {}; // +0x09
    };

    ne::C_TEXTURE *m_pTexture = {}; // +0x08: the gm_parts2 atlas.
    ne::C_SPRITE_INSTANCING *m_apSprites[kSpriteSlotCount] =
        {};                                     // +0x10: the per-slot sprite batches.
    int m_aSpriteCounts[kSpriteSlotCount] = {}; // +0x28: each slot's initial count.
    bool m_bBuilt = {};                         // +0x34: set once the sprites are built.
    // +0x35..+0x37 is alignment padding before the effect records.
    unsigned char m_aPad35[3] = {};                     // +0x35
    EffectRecord m_aEffects[kSpriteSlotCount - 1] = {}; // +0x38: two per-slot effect records.
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
