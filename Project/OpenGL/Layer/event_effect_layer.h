/**
 * @file
 * The event-notification effect layer, @c EventEffectLayer.
 */

#pragma once

#include "playfieldlayerbase.h"

namespace ne {
class C_TEXTURE;
class C_SPRITE_INSTANCING;
} // namespace ne

/**
 * @brief The event-notification effect layer.
 *
 * A process-wide singleton, built on first access, deriving from @c PlayFieldLayerBase. It presents
 * the event-notification effect through a small root sprite instancer and a main instancer nested
 * beneath it. The class carries no RTTI (it is non-polymorphic), so the name is inferred from its
 * singleton getter rather than confirmed from the runtime metadata. The trailing @c // +0xNN comments
 * document the original 32-bit offsets for reference only.
 */
class EventEffectLayer : public PlayFieldLayerBase {
public:
    /**
     * @brief The process-wide event-notification effect layer, created on first use.
     * @return The shared layer.
     * @ghidraAddress 0x1be49c
     */
    static EventEffectLayer *shared();

    /**
     * @brief Lazily builds the event-effect sprites: loads the gm_event atlas, creates a
     * single-sprite root instancer registered in the global scene tree, and nests a six-sprite main
     * instancer beneath it bound to the atlas.
     *
     * Guarded so the sprites are built only once.
     * @ghidraAddress 0x1be504
     */
    void CreateEventEffectSprites();

    // The capacity of the root and main sprite instancers.
    static constexpr unsigned int kRootCapacity = 1;
    static constexpr unsigned int kMainCapacity = 6;

private:
    ne::C_TEXTURE *m_pTexture = {};              // +0x08: the gm_event atlas.
    ne::C_SPRITE_INSTANCING *m_pMainSprite = {}; // +0x10: the six-sprite main instancer.
    ne::C_SPRITE_INSTANCING *m_pRootSprite = {}; // +0x18: the single-sprite root instancer.
    int m_nSpriteCount = {}; // +0x20: the main instancer's initial sprite count.
    bool m_bBuilt = {};      // +0x24: set once the sprites are built.
    // +0x25..+0x33 is further layer state (still being worked out) preceding the timer.
    unsigned char m_aReserved25[0xf] = {}; // +0x25
    int m_nTimer = {};                     // +0x34: an animation timer the getter zero-clears.
    int m_nMode = {};                      // +0x38: a mode field the getter zero-clears.
    bool m_bSoundFlag = {};                // +0x3c: a sound flag the getter zero-clears.
    unsigned char m_aReserved3d[3] = {};   // +0x3d: padding to the 0x40-byte allocation size.
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
