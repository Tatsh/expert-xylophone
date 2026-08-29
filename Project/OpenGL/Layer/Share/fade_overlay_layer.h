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
 * The full-screen fade overlay: a black quad whose alpha animates between transparent and
 * opaque to fade the screen in and out.
 *
 * A process-wide singleton, built on first access, deriving from @c PlayFieldLayerBase. It owns one
 * sprite instancer that draws a single screen-sized quad, and a fade tween that drives the quad's
 * alpha. The class name is inferred (the binary carries no RTTI or embedded path for it).
 */
class FadeOverlayLayer : public PlayFieldLayerBase {
public:
    /**
     * The process-wide fade overlay layer, created on first use.
     * @return The shared layer.
     * @ghidraAddress 0x17f9c0
     */
    static FadeOverlayLayer *shared();

    /**
     * Lazily creates the overlay's sprite instancer on first use: creates a one-quad
     * instancer, registers it in the global scene tree, makes it visible, and seeds its order.
     * @ghidraAddress 0x17fa24
     */
    void EnsureInstancer();

    /**
     * Begins the fade-in animation, easing the overlay to fully opaque over @p flDuration.
     * @param flDuration The fade duration; a non-positive value snaps to opaque immediately.
     * @ghidraAddress 0x17fa78
     */
    void StartFadeIn(float flDuration);

    /**
     * Begins the fade-out animation, easing the overlay to transparent over @p flDuration.
     * @param flDuration The fade duration; a non-positive value snaps to transparent immediately.
     * @ghidraAddress 0x17faa0
     */
    void StartFadeOut(float flDuration);

    /**
     * Advances the fade tween by one frame and draws the full-screen quad at the current
     * alpha, scaled to the game-system viewport.
     * @param flDelta The elapsed frame time.
     * @ghidraAddress 0x17fac0
     */
    void Render(float flDelta);

    /**
     * The overlay's current fade alpha, in the unit interval.
     * @return The current fade alpha, in the unit interval.
     * @ghidraAddress 0x17fbf8
     */
    float GetCurrentAlpha() const {
        return m_flCurrentAlpha;
    }

private:
    /**
     * Emits one black full-screen quad into the instancer at the current slot: clears its
     * position and anchor, sets its size to @p size, sets its colour to black at @p nAlpha, and
     * bumps the slot count.
     * @param size The quad size (the viewport width and height).
     * @param nAlpha The quad's alpha byte.
     * @ghidraAddress 0x17fb6c
     */
    void EmitQuad(const S_VECTOR2 &size, unsigned int nAlpha);

    ne::C_SPRITE_INSTANCING_2D *m_pInstancer = {};
    int m_nSlotCount = {};
    bool m_bInstancerCreated = {};
    float m_flFadeStart = {};
    float m_flFadeTarget = {};
    float m_flFadeDuration = {}; // In frames.
    float m_flFadeElapsed = {};  // In frames.
    float m_flCurrentAlpha = {};
};

// code: language=Objective-C++
// kate: hl Objective-C++;
// vim: set ft=objcpp :
