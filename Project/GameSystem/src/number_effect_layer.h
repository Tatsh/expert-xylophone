#pragma once

//
//  number_effect_layer.h
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458. @ghidraAddress values are relative to
//  the program image base.
//

#include "linear_tween.h"
#include "playfieldlayerbase.h"
#include "s_vector2.h"

namespace ne {
class C_SPRITE_INSTANCING_2D;
class C_TEXTURE;
} // namespace ne

/**
 * @brief The number-effect layer: a @c PlayFieldLayerBase-derived layer that draws the play-field
 * number glyphs through four gm_parts2 sprite instancers, with a fade channel and a brightness.
 * @ghidraAddress NumberEffectLayer (engine layer, 0x78 bytes)
 */
class NumberEffectLayer : public PlayFieldLayerBase {
public:
    // The number of sprite instancers the layer builds.
    static constexpr int kBatchCount = 4;
    // The number of words in the side-dependent transform block.
    static constexpr int kTransformWordCount = 4;

    /**
     * @brief The process-wide number-effect layer, created on first use.
     * @ghidraAddress 0x189ce0
     */
    static NumberEffectLayer *shared();

    /**
     * @brief Destroys and frees the process-wide number-effect layer, if it exists.
     * @ghidraAddress 0x189d50
     */
    static void FreeInstance();

    /**
     * @brief Lazily builds the four gm_parts2 sprite instancers.
     *
     * Seeds the side-dependent transform block (mirrored on the left side), loads the atlas, creates
     * and registers each instancer under the background layer, and sets the wide-screen flag from
     * the viewport width. Guarded so it runs only once.
     * @ghidraAddress 0x189d9c
     */
    void CreateSpriteInstancers();

    /**
     * @brief Advances the fade channel by @p flDeltaTime and raises the active flag.
     * @ghidraAddress 0x189ef0
     */
    void AdvanceFadeInterp(float flDeltaTime);

    /**
     * @brief Starts a fade-in of the layer alpha to fully opaque over @p flDuration.
     *
     * The fade channel eases from the current alpha to 255; a non-positive duration snaps to opaque
     * and marks the fade done immediately.
     * @param flDuration The fade duration.
     * @ghidraAddress 0x189e98
     */
    void StartFadeIn(float flDuration);

    /**
     * @brief Starts a fade-out of the layer alpha to fully transparent over @p flDuration.
     *
     * The fade channel eases from the current alpha to 0; a non-positive duration snaps to
     * transparent and marks the fade done immediately.
     * @param flDuration The fade duration.
     * @ghidraAddress 0x189ec8
     */
    void StartFadeOut(float flDuration);

    /**
     * @brief Sets the layer brightness, clamped to the range [0, 1].
     * @param flValue The brightness value.
     * @ghidraAddress 0x18a7a8
     */
    void SetBrightness(float flValue);

    /**
     * @brief Computes an element's screen-space anchor position for the current device layout.
     *
     * The portrait (pad) layout uses its own base-offset table; the landscape (phone) layout picks
     * the wide-variant row. It copies the element's base offset, then applies a per-element
     * viewport-relative gravity adjustment. The layout is chosen by the inherited is-pad flag.
     * @param nElement The element index.
     * @param pOut The output position.
     * @ghidraAddress 0x18a2d4
     */
    void ComputeAnchorPos(unsigned int nElement, S_VECTOR2 *pOut) const;

private:
    /**
     * @brief Emits one number-glyph sprite into a batch.
     *
     * Selects the element descriptor from the portrait or landscape layout table by the inherited
     * is-pad flag, looks up its atlas UV rectangle, and writes the next free slot of batch
     * @p nBatch with the descriptor's anchor and size, the caller's position, that UV rectangle, and
     * a solid @p nColour tint at the layer's current fade alpha. A no-op when the batch is full.
     * @param flX The sprite's x position.
     * @param flY The sprite's y position.
     * @param nBatch The target sprite batch (0 through 3).
     * @param nDescIndex The element descriptor index (0 through 3).
     * @param nColour The sprite's red, green, and blue channel value.
     * @ghidraAddress 0x18a674
     */
    void EmitNumberSprite(
        float flX, float flY, unsigned int nBatch, unsigned int nDescIndex, unsigned int nColour);

    /**
     * @brief The per-frame update: re-anchors on a viewport change, advances the fade, processes the
     * brightness-slider touch, and emits the track, knob, and brightness-fill sprites.
     *
     * On the landscape layout it emits the track element (and its wide-variant extension), then the
     * knob element (half alpha while held), and finally the brightness-fill element plus a second
     * sprite offset along the track vector by the current brightness.
     * @param flDeltaTime The frame's elapsed time.
     * @ghidraAddress 0x18a4ac
     */
    void Update(float flDeltaTime);

    /**
     * @brief Handles the brightness-slider touch for the frame.
     * @ghidraAddress 0x189f40
     */
    void ProcessBrightnessSliderTouch();

    // Constructs the layer through the base constructor; every field is zero-initialised. The binary
    // inlines this into the singleton getter rather than emitting a separate constructor.
    NumberEffectLayer() = default;

    /**
     * @brief Destroys the layer: releases the atlas and requests deletion of the four instancers.
     * @ghidraAddress 0x189c70
     */
    ~NumberEffectLayer();

    // +0x00..+0x07: the inherited PlayFieldLayerBase fields (is-pad, hardware type, theme).
    ne::C_TEXTURE *m_pTexture = {};                            // +0x08: the gm_parts2 atlas.
    ne::C_SPRITE_INSTANCING_2D *m_apSprites[kBatchCount] = {}; // +0x10: the four sprite instancers.
    LinearTween m_fadeChannel;           // +0x30 (five floats, ending at +0x44)
    bool m_bFadeActive = {};             // +0x44 raised once the channel advances a frame
    unsigned char m_aReserved45[3] = {}; // +0x45
    float m_flCachedViewportWidth = {};  // +0x48: the last-seen viewport width (re-anchor trigger).
    float m_flCachedViewportHeight = {}; // +0x4c: the last-seen viewport height.
    bool m_bWideScreen = {};             // +0x50: set when the viewport is wider than the split.
    unsigned char m_aReserved54[8] = {}; // +0x54
    bool m_bSliderHeld = {};             // +0x5c: set while the brightness slider is being dragged.
    unsigned char m_aReserved5d[3] = {}; // +0x5d
    float m_flBrightness = {};           // +0x60: the layer brightness (0 to 1).
    bool m_bBuilt = {};                  // +0x64: set once the instancers are built.
    unsigned char m_aReserved65[3] = {}; // +0x65
    // +0x68: the side-dependent transform block seeded when the instancers are built.
    float m_aTransform[kTransformWordCount] = {};
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
