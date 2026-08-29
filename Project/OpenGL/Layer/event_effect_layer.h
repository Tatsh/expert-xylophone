/**
 * @file
 * The event-notification effect layer, @c EventEffectLayer.
 */

#pragma once

#include "playfieldlayerbase.h"
#include "s_vector2.h"

namespace ne {
class C_TEXTURE;
class C_SPRITE_INSTANCING_2D;
} // namespace ne

/**
 * The event-notification effect layer.
 *
 * A process-wide singleton, built on first access, deriving from @c PlayFieldLayerBase. It presents
 * the event-notification effect through a small root sprite instancer and a main instancer nested
 * beneath it. The class carries no RTTI (it is non-polymorphic), so the name is inferred from its
 * singleton getter rather than confirmed from the runtime metadata. The trailing @c // +0xNN
 * comments document the original 32-bit offsets for reference only.
 */
class EventEffectLayer : public PlayFieldLayerBase {
public:
    /**
     * The process-wide event-notification effect layer, created on first use.
     * @return The shared layer.
     * @ghidraAddress 0x1be49c
     */
    static EventEffectLayer *shared();

    /**
     * Lazily builds the event-effect sprites: loads the gm_event atlas, creates a
     * single-sprite root instancer registered in the global scene tree, and nests a six-sprite main
     * instancer beneath it bound to the atlas.
     *
     * Guarded so the sprites are built only once.
     * @ghidraAddress 0x1be504
     */
    void CreateEventEffectSprites();

    /** The capacity of the root sprite instancer. */
    static constexpr unsigned int kRootCapacity = 1;
    /** The capacity of the main sprite instancer. */
    static constexpr unsigned int kMainCapacity = 6;

    /**
     * Starts the event effect: arms the active and sound flags, resets the timer, and
     * captures the current pastel-bonus mode from the game system.
     * @ghidraAddress 0x1be594
     */
    void StartEffect();

    /**
     * Finishes the event effect by setting its timer to its full duration.
     * @param flDuration A duration slot the routine never reads; every caller passes zero.
     * @ghidraAddress 0x1be5cc
     */
    void FinishEffect(float flDuration);

    /**
     * Sets the full-screen background quad's colour and size in the root instancer.
     *
     * Sizes the single background sprite to the current viewport and sets its colour to opaque
     * black scaled by @p nAlpha (packed into the colour's high byte).
     * @param nAlpha The background alpha (0 through 255).
     * @ghidraAddress 0x1be9b4
     */
    void SetEventBackgroundQuad(int nAlpha);

    /**
     * Advances the event effect one frame and re-emits its animated sprites.
     *
     * Caches the viewport, clears the main instancer, and — while active — advances the effect
     * timer (deactivating and clearing the background once it runs out), plays the banner sound on
     * the first live frame, then fades the background quad and emits the centred banner, the three
     * curve-swept side icons, and a mode-dependent extra sprite, all driven by the timer curves.
     * @param flDeltaTime The frame delta.
     * @ghidraAddress 0x1be5dc
     */
    void Update(float flDeltaTime);

    /**
     * Appends one event sprite to the main instancer at a world position, at the given scale
     * and alpha.
     *
     * A no-op when the main instancer is full. The sprite's anchor, size, and atlas frame come from
     * the shared event-sprite descriptor table (indexed by @p uDescIdx); in portrait the anchor and
     * size are halved. Its scale is taken directly from @p flScaleX and @p flScaleY, and it is
     * drawn opaque white at @p iAlpha.
     * @param uDescIdx The event-sprite descriptor index.
     * @param position The sprite's world position.
     * @param iAlpha The sprite alpha (0 through 255).
     * @param flScaleX The sprite's X scale.
     * @param flScaleY The sprite's Y scale.
     * @ghidraAddress 0x1bea48
     */
    void EmitEventSprite(unsigned int uDescIdx,
                         const S_VECTOR2 &position,
                         int iAlpha,
                         float flScaleX,
                         float flScaleY);

    /**
     * Whether the event effect is currently playing.
     * @return @c true while the event effect is playing.
     */
    bool IsEffectActive() const {
        return m_bActive;
    }

private:
    ne::C_TEXTURE *m_pTexture = {};                 // +0x08: the gm_event atlas.
    ne::C_SPRITE_INSTANCING_2D *m_pMainSprite = {}; // +0x10
    ne::C_SPRITE_INSTANCING_2D *m_pRootSprite = {}; // +0x18
    int m_nSpriteCount = {};                        // +0x20: for the main instancer.
    bool m_bBuilt = {};                             // +0x24
    // unsigned char m_aReserved25[3] = {}; // +0x25
    float m_flViewportWidth = {};  // +0x28
    float m_flViewportHeight = {}; // +0x2c
    bool m_bActive = {};           // +0x30
    // unsigned char m_aReserved31[3] = {}; // +0x31
    float m_flTimer = {};   // +0x34: in frames.
    int m_nMode = {};       // +0x38: the getter zero-clears it.
    bool m_bSoundFlag = {}; // +0x3c: the getter zero-clears it.
    // unsigned char m_aReserved3d[3] = {}; // +0x3d: pads to the 0x40-byte allocation.
};
