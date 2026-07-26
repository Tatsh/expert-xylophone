/**
 * @file
 * The play-colour gauge-parts layer, @c PlayColorLayer.
 */

#pragma once

#include "linear_tween.h"
#include "playfieldlayerbase.h"

namespace ne {
class C_TEXTURE;
class C_SPRITE_INSTANCING;
} // namespace ne

/**
 * @brief The play-colour gauge-parts layer.
 *
 * A process-wide singleton, built on first access, deriving from @c PlayFieldLayerBase. It owns one
 * atlas and two sprite instancers, drawn beneath the shared background layer, that present the
 * gauge-part graphics. The class carries no RTTI (it is non-polymorphic), so the name is inferred
 * from its singleton getter rather than confirmed from the runtime metadata. The trailing @c // +0xNN
 * comments document the original 32-bit offsets for reference only.
 */
class PlayColorLayer : public PlayFieldLayerBase {
public:
    // The number of gauge-part sprite instancers the layer builds.
    static constexpr int kBatchCount = 2;
    // The number of part groups whose sprites the layer emits.
    static constexpr int kPartGroupCount = 10;

    /**
     * @brief The process-wide play-colour layer, created on first use.
     * @return The shared layer.
     * @ghidraAddress 0x8350c
     */
    static PlayColorLayer *shared();

    /**
     * @brief Begins the gauge shrink/empty animation, easing the gauge to empty over @p flDuration
     * (snapping to empty and marking the colour dirty when the duration is non-positive).
     * @param flDuration The animation duration.
     * @ghidraAddress 0x8394c
     */
    void StartShrinkAnimation(float flDuration);

    /**
     * @brief Begins the gauge grow/fill animation, easing the gauge to full over @p flDuration from
     * @p flFromValue (snapping to full and marking the colour dirty when the duration is
     * non-positive). Shares the shrink channel and its from-value scratch.
     * @param flDuration The animation duration.
     * @param flFromValue The animation's cached start value.
     * @ghidraAddress 0x83918
     */
    void StartGaugeGrowAnimation(float flDuration, float flFromValue);

    /**
     * @brief Sets the gauge fill/brightness directly (clamped to @c [0, 1] and mapped to the fill
     * brightness range), marking the colour dirty.
     * @param flLevel The normalised fill level.
     * @ghidraAddress 0x83978
     */
    void SetGaugeFillLevel(float flLevel);

    /**
     * @brief Lazily builds the two gauge-part sprite batches and populates them with the gm_parts1
     * part sprites (attaching each batch under the background layer's render object, making it
     * visible, binding the atlas, sizing it to its part count, and flagging additive blend), then
     * emitting each part group's sprites.
     *
     * Guarded so the batches are built only once.
     * @ghidraAddress 0x8355c
     */
    void BuildGaugePartsSpriteBatches();

    /**
     * @brief Emit one gauge-part sprite into a batch slot: writes its position, source rect, UV
     * rect, scale, rotation, and colour from the part tables and advances the batch's used count.
     *
     * Drops the sprite when the batch's slot pool is full.
     * @param flPosX The sprite's X position.
     * @param flPosY The sprite's Y position.
     * @param flScaleX The sprite's X scale.
     * @param flScaleY The sprite's Y scale.
     * @param flRotation The sprite's rotation.
     * @param nBatchIndex The batch to emit into (0 or 1).
     * @param nPartIndex The part group (0 through 9).
     * @param nAlpha The sprite's alpha.
     * @ghidraAddress 0x83684
     */
    void EmitGaugePartSprite(float flPosX,
                             float flPosY,
                             float flScaleX,
                             float flScaleY,
                             float flRotation,
                             unsigned int nBatchIndex,
                             unsigned int nPartIndex,
                             unsigned int nAlpha);

    /**
     * @brief Sets the play-colour value (a theme-indexed colour selector).
     * @param nValue The colour value.
     * @ghidraAddress 0x83c90
     */
    void SetPlayColorValue(int nValue);

private:
    /**
     * @brief Constructs the layer, chaining the base constructor, seeding its transform scales, and
     * accumulating each batch's per-group capacities.
     * @ghidraAddress 0x83460
     */
    PlayColorLayer();

    ne::C_TEXTURE *m_pTexture = {}; // +0x08: the gm_parts1 atlas.
    ne::C_SPRITE_INSTANCING *m_apSprites[kBatchCount] =
        {};                                     // +0x10: the per-batch sprite instancers.
    int m_aBatchBaseIndex[kBatchCount] = {};    // +0x20: unused per-batch base index.
    int m_aBatchCapacity[kBatchCount] = {};     // +0x28: each batch's sprite capacity.
    int m_aPartBaseIndex[kPartGroupCount] = {}; // +0x30: each part group's base index.
    unsigned char m_aReserved58[0x18] = {};     // +0x58: further state, still being worked out.
    bool m_bBuilt = {};                         // +0x70: set once the batches are built.
    bool m_bGaugeColorDirty = {}; // +0x71: set when a gauge animation snaps or the fill is set.
    // +0x72..+0x73 is alignment padding before the shrink-animation block.
    unsigned char m_aPad72[2] = {}; // +0x72
    float m_flAnimFrom = {};        // +0x74: the shrink/grow animation's cached from-value.
    LinearTween m_shrinkChannel;    // +0x78: the shared gauge shrink/grow channel.
    // +0x8c..+0x8f: further animation state, still being worked out.
    unsigned char m_aReserved8c[4] = {}; // +0x8c
    float m_flGaugeBrightness = {};      // +0x90: the gauge fill brightness, seeded to 1 (full).
    int m_nPlayColorValue = {};          // +0x94: the theme-indexed play-colour value.
    float m_flScaleY = {};               // +0x98: a scale the constructor seeds to 1.
    float m_flScaleZ = {};               // +0x9c: a scale the constructor seeds to 1.
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
