/**
 * @file
 * The play-colour gauge-parts layer, @c PlayColorLayer.
 */

#pragma once

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
    // +0x71..+0x73 is alignment padding before the transform block.
    // unsigned char m_aPad71[3]; // +0x71 (alignment padding, compiler-inserted)
    float m_aTransform[9] = {}; // +0x74: a transform block the constructor seeds (scales to 1).
    unsigned char m_aReserved98[8] = {}; // +0x98: padding to the 0xa0-byte allocation size.
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
