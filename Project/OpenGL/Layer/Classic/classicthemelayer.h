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
     * @brief Initialises the result-screen score-gauge display block, then seeds its per-side score
     * values from the score tracker.
     * @ghidraAddress 0x10a01c
     */
    void InitializeScoreGaugeState();

    /**
     * @brief Seeds the per-side score display values from the active score tracker's play records.
     * @ghidraAddress 0x10a044
     */
    void InitializeScoreValuesFromTracker();

    /**
     * @brief Starts the score-gauge value animation, ramping the gauge from its current target over
     * the given duration; a non-positive duration snaps the target to zero.
     * @param flDuration The animation duration.
     * @ghidraAddress 0x10a080
     */
    void StartGaugeValueFade(float flDuration);

private:
    static constexpr int kBackgroundBatchCount = 3;
    static constexpr int kScoreValueCount = 2;
    static constexpr int kScoreGaugeBlockCount = 4;

    ne::C_TEXTURE *m_pTexture = {};                                       // +0x08
    ne::C_SPRITE_INSTANCING *m_apSpriteBatch[kBackgroundBatchCount] = {}; // +0x10
    int m_anSpriteCount[kBackgroundBatchCount] = {};                      // +0x28
    bool m_fInitialized = {};                                             // +0x34
    // +0x35..+0x37 is alignment padding before the colour index.
    unsigned char m_aPad35[3] = {}; // +0x35
    int m_nColor = {};              // +0x38: the theme colour index (defaults to one).
    bool m_bFlag3c = {};            // +0x3c: a flag the constructor clears.
    bool m_bFlag3d = {};            // +0x3d: a flag the constructor clears.
    // +0x3e..+0x3f is alignment padding before the score-gauge block.
    unsigned char m_aPad3e[2] = {}; // +0x3e
    // +0x40..+0x4f: the score-gauge display block InitializeScoreGaugeState seeds (a start position
    // and two scales), cleared by the constructor.
    float m_aScoreGaugeBlock[kScoreGaugeBlockCount] = {}; // +0x40
    int m_nScoreGaugeState = {};     // +0x50: a state field InitializeScoreGaugeState clears.
    float m_flScoreGaugeTarget = {}; // +0x54: the gauge's full target (one).
    int m_aScoreValues[kScoreValueCount] = {}; // +0x58: the per-side score display values.
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
