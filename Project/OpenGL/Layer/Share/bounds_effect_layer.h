/**
 * @file
 * The play-field bounds effect layer, @c BoundsEffectLayer.
 */

#pragma once

#include "playfieldlayerbase.h"

struct S_VECTOR2;

namespace ne {
class C_TEXTURE;
class C_SPRITE_INSTANCING_2D;
} // namespace ne

/**
 * @brief The play-field bounds (edge) effect layer.
 *
 * A process-wide singleton, built on first access, deriving from @c PlayFieldLayerBase. The class
 * carries no RTTI, so the name is inferred from its @c GetBoundsEffectLayer / @c SetBoundsEffect*
 * accessors. Only the fields the reconstructed methods touch are modelled; the rest of the
 * 0x310-byte object is reserved. The trailing @c // +0xNN comments document the original offsets
 * for reference.
 * @ghidraAddress BoundsEffectLayer (engine effect layer, 0x310 bytes)
 */
class BoundsEffectLayer : public PlayFieldLayerBase {
public:
    // The number of player-colour effect banks and the records per bank.
    static constexpr int kBankCount = 2;
    static constexpr int kRecordsPerBank = 23;

    /**
     * @brief The process-wide bounds-effect layer, created on first use.
     * @return The shared layer.
     * @ghidraAddress 0x17528c
     */
    static BoundsEffectLayer *shared();

    /**
     * @brief Builds the effect sprite batch and binds the style's atlas on first use.
     *
     * Reads the user's bounds-effect style, loads the matching atlas, creates the 0x5c-capacity
     * world sprite batch, attaches it under the background layer, makes it visible, and flags
     * additive blend. Guarded so it runs only once.
     * @ghidraAddress 0x1752dc
     */
    void InitializeSprites();

    /**
     * @brief Refreshes the theme, re-reads the bounds-effect style, and rebinds the matching atlas.
     * @ghidraAddress 0x1753e4
     */
    void SetStyle();

    /**
     * @brief Spawns a bounds effect for a colour bank at a screen position.
     *
     * Builds the sprite batch on first use, then claims the first inactive record in the colour's
     * bank and fills its reset timer and position. A full bank drops the effect.
     * @param nColor The player colour bank (0 or 1).
     * @param flPosX The effect's screen x.
     * @param flPosY The effect's screen y.
     * @ghidraAddress 0x1754cc
     */
    void CreateBoundsEffect(unsigned int nColor, float flPosX, float flPosY);

    /**
     * @brief Advances every live bounds effect one frame and re-emits the batch's sprites.
     *
     * Clears the batch's sprite count, then for each colour bank walks its records: a live record
     * advances its timer by @p flDelta and deactivates once the timer passes its lifetime;
     * otherwise, when that bank's lane-light alpha is non-zero, it maps the timer to an animation
     * frame and appends the effect sprite (from the bank's UV-frame row, drawn at the lane-light
     * alpha) as long as the frame is within the style's frame count. Finally publishes the batch's
     * sprite count into the instancer's order field.
     * @param flDelta The frame delta, in frame-time.
     * @ghidraAddress 0x17559c
     */
    void Process(float flDelta);

    /**
     * @brief Sets the effect size from the user's bounds-effect-size setting.
     * @param flSize The effect size.
     * @ghidraAddress 0x1754c4
     */
    void SetEffectSize(float flSize);

    /**
     * @brief Sets one lane's bounds-light alpha byte (the flash intensity for that lane's edge).
     * @param flValue The alpha value, truncated to a byte (callers pass the on/off endpoints).
     * @param nLane The lane: 1 selects the first lane's alpha, anything else the second.
     * @ghidraAddress 0x1754a8
     */
    void SetLaneLightFlag(float flValue, int nLane);

private:
    /**
     * @brief Appends one bounds-effect sprite to the batch.
     *
     * Writes the next sprite slot with a fixed 84-point anchor and 168-point size, the caller's
     * position and animation-frame UV origin, the fixed bounds cell UV size, the layer's current
     * effect scale on both axes, and opaque white modulated by @p nAlpha. The sprite is flipped a
     * half-turn when its x is negative (mirrored onto the left bound). Advances the sprite count;
     * the caller guards against overflow.
     * @param pPosition The sprite's screen position.
     * @param pUvOrigin The animation-frame UV origin.
     * @param nAlpha The sprite alpha.
     * @ghidraAddress 0x1758f0
     */
    void SetBoundsEffectSprite(const S_VECTOR2 *pPosition, const S_VECTOR2 *pUvOrigin, int nAlpha);

    /**
     * @brief Constructs the layer: chains the base constructor, clears the per-lane effect state,
     * and seeds both lane-light alphas fully on (0xff) and the effect size to one.
     * @ghidraAddress 0x175210
     */
    BoundsEffectLayer();

    /** @brief One pooled bounds-effect record (16 bytes): its active flag, timer, and position. */
    struct EffectRecord {
        bool bActive = {};                 // +0x00: whether the record holds a live effect.
        unsigned char aReserved01[3] = {}; // +0x01
        float flTimer = {};                // +0x04: the effect's animation timer, in frame-time.
        float flPosX = {};                 // +0x08: the effect's screen x.
        float flPosY = {};                 // +0x0c: the effect's screen y.
    };

    ne::C_TEXTURE *m_pTexture = {};             // +0x08: the bound effect atlas.
    ne::C_SPRITE_INSTANCING_2D *m_pSprite = {}; // +0x10: the effect sprite instancer.
    int m_nSpriteCount = {};                    // +0x18: the batch's live sprite count.
    int m_nCapacity = {};                       // +0x1c: the sprite-batch capacity.
    bool m_bLoaded = {};                        // +0x20: set once the sprite batch is built.
    unsigned char m_aReserved21[3] = {};        // +0x21
    // +0x24: the two per-colour effect banks (each kRecordsPerBank records, stride 0x170 per bank).
    EffectRecord m_aEffects[kBankCount][kRecordsPerBank] = {};
    unsigned char m_nLaneLightAlpha0 =
        {}; // +0x304: the first lane's bounds-light alpha (0 hides the
            //         lane's effects, 0xff shows them fully).
    unsigned char m_nLaneLightAlpha1 = {}; // +0x305: the second lane's bounds-light alpha.
    unsigned char m_aReserved306[2] = {};  // +0x306
    float m_flEffectSize = {};             // +0x308: the user's effect size.
    int m_nStyle = {};                     // +0x30c: the bounds-effect style (0/1/2).
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
