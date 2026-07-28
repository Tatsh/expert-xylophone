/**
 * @file
 * The Classic-theme play-field background layer.
 */

#pragma once

#include "linear_tween.h"
#include "playfieldlayerbase.h"
#include "s_vector2.h"

namespace ne {
class C_TEXTURE;
class C_SPRITE_INSTANCING_2D;
} // namespace ne

/**
 * @brief One Classic-theme sprite-kind transform record (a 20-byte entry): the sprite's anchor, its
 * size, and the atlas-frame index it draws from.
 */
struct ClassicThemeSpriteTransform {
    S_VECTOR2 anchor = {}; // +0x00: the sprite anchor offset.
    S_VECTOR2 size = {};   // +0x08: the sprite pixel size.
    int nUvIndex = {};     // +0x10: the atlas-frame index into the shared sprite UV table.
};

// The per-sprite-kind transform table, indexed by sprite kind. Read-only binary data.
extern const ClassicThemeSpriteTransform
    g_aClassicThemeSpriteTransforms[]; // @ghidraAddress 0x301c60

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
    /**
     * @brief The process-wide Classic-theme layer, created on first use.
     * @return The shared layer.
     * @ghidraAddress 0x109ee0
     */
    static ClassicThemeLayer *shared();

    /**
     * @brief Constructs the layer: chains the base constructor and clears the batch, count, texture,
     * and colour state, defaulting the colour index to one and the two trailing slots to four.
     * @ghidraAddress 0x109e68
     */
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

    /**
     * @brief Sets the theme colour index.
     * @param nColor The colour index.
     * @ghidraAddress 0x10a0a0
     */
    void SetColor(int nColor);

    /**
     * @brief Populates one sprite slot in a batch from the per-kind transform and UV tables.
     *
     * Positions the slot (offsetting Y by the play-field half-height), copies the sprite kind's
     * anchor and size, looks up its atlas UV, applies the given scale and rotation, and tints it
     * black on batch zero or white otherwise, then advances the batch's live slot count. A full
     * batch is left untouched.
     * @param nBatch The target batch (also selects the tint: batch zero is black).
     * @param nSpriteKind The sprite kind, indexing the transform table.
     * @param position The slot's screen position.
     * @param flScaleX The slot's X scale.
     * @param flScaleY The slot's Y scale.
     * @param flRotation The slot's rotation, in radians.
     * @param nAlpha The slot's colour alpha.
     * @ghidraAddress 0x10a644
     */
    void ConfigureSpriteSlot(int nBatch,
                             int nSpriteKind,
                             const S_VECTOR2 &position,
                             float flScaleX,
                             float flScaleY,
                             float flRotation,
                             int nAlpha);

    /**
     * @brief Initialises the theme-animation state, then seeds its per-side score values from the
     * score tracker.
     * @ghidraAddress 0x10a01c
     */
    void InitializeScoreGaugeState();

    /**
     * @brief Seeds the per-side score display values from the active score tracker's play records.
     * @ghidraAddress 0x10a044
     */
    void InitializeScoreValuesFromTracker();

    /**
     * @brief Starts the theme fade-in animation, easing the display value from its start to its end
     * over the given duration; a non-positive duration snaps it in immediately.
     * @param flDuration The animation duration.
     * @ghidraAddress 0x10a080
     */
    void StartGaugeValueFade(float flDuration);

    /**
     * @brief Advances the theme's eased-progress channel by @p flDelta.
     * @param flDelta The frame's elapsed time.
     * @ghidraAddress 0x10a5fc
     */
    void AdvanceEasedProgress(float flDelta);

private:
    static constexpr int kBackgroundBatchCount = 3;
    static constexpr int kScoreValueCount = 2;

    ne::C_TEXTURE *m_pTexture = {};                                          // +0x08
    ne::C_SPRITE_INSTANCING_2D *m_apSpriteBatch[kBackgroundBatchCount] = {}; // +0x10
    int m_anSpriteCount[kBackgroundBatchCount] = {};                         // +0x28
    bool m_fInitialized = {};                                                // +0x34
    // +0x35..+0x37 is alignment padding before the colour index.
    unsigned char m_aPad35[3] = {}; // +0x35
    int m_nColor = {};              // +0x38: the theme colour index (defaults to one).
    bool m_bAnimActive = {};        // +0x3c: whether the reveal-progress timer is still advancing.
    bool m_bAnimEnabled = {};       // +0x3d: whether the theme animation is running this frame.
    // +0x3e..+0x3f is alignment padding before the animation clock.
    unsigned char m_aPad3e[2] = {}; // +0x3e
    float m_flClock = {};           // +0x40: the theme animation clock, advanced each frame.
    // +0x44..+0x57: the eased reveal-progress channel; its current value scales the emitted sprites.
    LinearTween m_easeChannel;                 // +0x44
    int m_aScoreValues[kScoreValueCount] = {}; // +0x58: the per-side score display values.
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
