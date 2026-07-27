/**
 * @file
 * The full-screen fade overlay layer, @c FadeOverlayLayer.
 */

#pragma once

#include "playfieldlayerbase.h"
#include "s_vector2.h"

namespace ne {
class C_SPRITE_INSTANCING_2D;
} // namespace ne

/**
 * @brief The full-screen fade overlay: a black quad whose alpha animates between transparent and
 * opaque to fade the screen in and out.
 *
 * A process-wide singleton, built on first access, deriving from @c PlayFieldLayerBase. It owns one
 * sprite instancer that draws a single screen-sized quad, and a fade tween that drives the quad's
 * alpha. The class name is inferred (the binary carries no RTTI or embedded path for it). The
 * trailing @c // +0xNN comments document the original 32-bit offsets for reference only.
 */
class FadeOverlayLayer : public PlayFieldLayerBase {
public:
    /**
     * @brief The process-wide fade overlay layer, created on first use.
     * @return The shared layer.
     * @ghidraAddress 0x17f9c0
     */
    static FadeOverlayLayer *shared();

    /**
     * @brief Lazily creates the overlay's sprite instancer on first use: creates a one-quad
     * instancer, registers it in the global scene tree, makes it visible, and seeds its order.
     * @ghidraAddress 0x17fa24
     */
    void EnsureInstancer();

    /**
     * @brief Begins the fade-in animation, easing the overlay to fully opaque over @p flDuration.
     * @param flDuration The fade duration; a non-positive value snaps to opaque immediately.
     * @ghidraAddress 0x17fa78
     */
    void StartFadeIn(float flDuration);

    /**
     * @brief Begins the fade-out animation, easing the overlay to transparent over @p flDuration.
     * @param flDuration The fade duration; a non-positive value snaps to transparent immediately.
     * @ghidraAddress 0x17faa0
     */
    void StartFadeOut(float flDuration);

    /**
     * @brief Advances the fade tween by one frame and draws the full-screen quad at the current
     * alpha, scaled to the game-system viewport.
     * @param flDelta The elapsed frame time.
     * @ghidraAddress 0x17fac0
     */
    void Render(float flDelta);

    /**
     * @brief The overlay's current fade alpha, in the unit interval.
     * @ghidraAddress 0x17fbf8
     */
    float GetCurrentAlpha() const {
        return m_flCurrentAlpha;
    }

private:
    /**
     * @brief Emits one black full-screen quad into the instancer at the current slot: clears its
     * position and anchor, sets its size to @p size, sets its colour to black at @p nAlpha, and
     * bumps the slot count.
     * @param size The quad size (the viewport width and height).
     * @param nAlpha The quad's alpha byte.
     * @ghidraAddress 0x17fb6c
     */
    void EmitQuad(const S_VECTOR2 &size, unsigned int nAlpha);

    ne::C_SPRITE_INSTANCING_2D *m_pInstancer = {}; // +0x08: the one-quad sprite instancer.
    int m_nSlotCount = {};                         // +0x10: the slots emitted this frame.
    bool m_bInstancerCreated = {};                 // +0x14: set once the instancer exists.
    // +0x15..+0x17 is alignment padding before the tween block.
    float m_flFadeStart = {};    // +0x18: the alpha the current tween starts from.
    float m_flFadeTarget = {};   // +0x1c: the alpha the current tween ends at.
    float m_flFadeDuration = {}; // +0x20: the current tween's duration, in frames.
    float m_flFadeElapsed = {};  // +0x24: the current tween's elapsed time, in frames.
    float m_flCurrentAlpha = {}; // +0x28: the overlay's current alpha.
};

// code: language=Objective-C++
// kate: hl Objective-C++;
// vim: set ft=objcpp :
