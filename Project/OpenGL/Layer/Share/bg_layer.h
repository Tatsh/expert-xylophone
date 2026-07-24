/**
 * @file
 * The engine's shared background layer.
 */

#pragma once

#include "playfieldlayerbase.h"

namespace ne {
class C_RENDER;
class C_SPRITE_INSTANCING;
class C_TEXTURE;
} // namespace ne

/**
 * @brief The engine's shared background layer.
 *
 * A single @c BgLayer owns a small scene-graph subtree that draws the play-field background: a root
 * container node, a background-image batch beneath it, and, for the theme modes that use one, a
 * clear-effect overlay batch beneath that. The subtree is built lazily on first access, after which
 * two linear fade tweens (the main fade and the clear-effect fade), scaled by the configured
 * brightness, drive the batches' per-frame alpha. Trailing @c // +0xNN comments document the
 * original 32-bit member offsets for reference only; the object is always reached through named
 * fields.
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
     *
     * Loads the selected background texture (and the clear-effect overlay texture for the theme
     * modes that use one), builds the root container node and the background batches, and sizes
     * each batch's sprite to fill the screen from its bound texture. Runs once; a no-op thereafter.
     * @ghidraAddress 0x1720c4
     */
    void InitializeBackgroundLayer();

    /**
     * @brief Begin fading the background in towards full opacity.
     *
     * Re-centres the background batches, then seeds the main fade tween from the current value
     * towards 1. A non-positive duration snaps to full opacity immediately.
     * @param flDuration The fade duration in frames.
     * @ghidraAddress 0x1727fc
     */
    void StartBackgroundFadeIn(float flDuration);

    /**
     * @brief Begin fading the background out towards fully transparent.
     *
     * Seeds the main fade tween from the current value towards 0. A non-positive duration snaps to
     * transparent immediately.
     * @param flDuration The fade duration in frames.
     * @ghidraAddress 0x172914
     */
    void StartBackgroundFadeOut(float flDuration);

    /**
     * @brief Set the background brightness and mark its colours for re-application.
     * @param flBrightness The brightness applied to the background sprite colours.
     * @ghidraAddress 0x17293c
     */
    void SetBackgroundBrightness(float flBrightness);

    /**
     * @brief Advance the background layer's fades for the frame and apply the sprite colours.
     * @param flFrameDelta The elapsed frame time, in frames.
     * @ghidraAddress 0x17294c
     */
    void ProcessBackgroundLayer(float flFrameDelta);

    /**
     * @brief Sets whether the clear-effect overlay is active: when the state changes, starts the
     * clear-effect fade and records the new state.
     * @param bActive Whether the gauge has reached the clear threshold.
     */
    void SetClearEffectActive(bool bActive) {
        if (bActive != m_bClearEffectActive) {
            m_flClearEffectDuration = kClearEffectFadeDuration;
            m_flClearEffectElapsed = 0.0f;
            m_bColorDirty = true;
        }
        m_bClearEffectActive = bActive;
    }

private:
    // The "no background selected" sentinel the factory stamps into m_nBackgroundId; while it is set,
    // no background texture is loaded.
    static constexpr int kNoBackground = 0x1d;

    // The clear-effect fade duration used when the clear-effect overlay is toggled.
    static constexpr float kClearEffectFadeDuration = 1000.0f;

    // Re-centre the built background batches on the play-field's full-height layout Y.
    void RecenterBackgroundSprites();

    ne::C_SPRITE_INSTANCING *m_pRootSprite = {};       // +0x08: root container node.
    ne::C_TEXTURE *m_pBackgroundTexture = {};          // +0x10: the background image texture.
    ne::C_TEXTURE *m_pClearEffectTexture = {};         // +0x18: the clear-effect overlay texture.
    ne::C_SPRITE_INSTANCING *m_pBackgroundBatch = {};  // +0x20: draws the background image.
    ne::C_SPRITE_INSTANCING *m_pClearEffectBatch = {}; // +0x28: draws the clear-effect overlay.
    int m_nSpriteCapacity = {};  // +0x30: sprite capacity and count of the background batches.
    bool m_bBuilt = {};          // +0x34: whether the subtree has been built.
    int m_nBackgroundId = {};    // +0x38: selected background (index into the texture-name table).
    float m_flFadeCurrent = {};  // +0x3c: the main fade's current value (0 to 1).
    float m_flFadeFrom = {};     // +0x40: the main fade's start value.
    float m_flFadeTo = {};       // +0x44: the main fade's target value.
    float m_flAnimTime = {};     // +0x48: free-running animation clock, advanced every frame.
    float m_flFadeDuration = {}; // +0x4c: the main fade's duration, in frames.
    float m_flFadeElapsed = {};  // +0x50: the main fade's elapsed time, in frames.
    float m_flBrightness = {};   // +0x54: brightness applied to the sprite colours.
    bool m_bColorDirty = {};     // +0x58: set when a tween advances, cleared after colours applied.
    bool m_bClearEffectActive = {}; // +0x59: whether the clear-effect fade drives the overlay.
    // +0x5a..+0x5b is alignment padding before the clear-effect fade floats.
    float m_flClearEffectCurrent = {};  // +0x5c: the clear-effect fade's current value (0 to 1).
    float m_flClearEffectDuration = {}; // +0x60: the clear-effect fade's duration, in frames.
    float m_flClearEffectElapsed = {};  // +0x64: the clear-effect fade's elapsed time, in frames.
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
