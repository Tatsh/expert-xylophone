/**
 * @file
 * The Limelight-theme result-window layer, @c LimelightResultLayer.
 */

#pragma once

#include "playfieldlayerbase.h"

struct S_VECTOR2;
struct PartsDataRecord;

namespace ne {
class C_TEXTURE;
class C_SPRITE_INSTANCING;
} // namespace ne

/**
 * @brief The Limelight-theme result-window layer.
 *
 * A process-wide singleton, built on first access, deriving from @c PlayFieldLayerBase. It draws the
 * Limelight result panel through eight sprite instancers. The class carries no RTTI (it is
 * non-polymorphic), so the name is inferred from its singleton getter rather than confirmed from the
 * runtime metadata. Only the sprite-set fields used by @c InitializePhoneSpriteInstancers are modelled
 * so far; the remainder of the @c 0x170-byte layout is kept as a reserved span to preserve the
 * allocation size. The trailing @c // +0xNN comments document the original 32-bit offsets for
 * reference only.
 */
class LimelightResultLayer : public PlayFieldLayerBase {
public:
    /**
     * @brief The process-wide Limelight result-window layer, created on first use.
     * @return The shared layer.
     * @ghidraAddress 0x123d54
     */
    static LimelightResultLayer *shared();

    /**
     * @brief Lazily builds the eight result-window sprite instancers: loads the two atlases and
     * creates each instancer (registering it in the global scene tree, making it visible, binding
     * the edge slots' textures, and clearing its sprite count).
     *
     * Guarded so the sprites are built only once.
     * @ghidraAddress 0x123db0
     */
    void InitializePhoneSpriteInstancers();

    /**
     * @brief Returns the result-window parts descriptor at @p nIndex.
     *
     * Selects the pad or phone parts table by the current device kind.
     * @param nIndex The parts-record index (below @c 0xff).
     * @return The parts descriptor.
     * @ghidraAddress 0x123838
     */
    PartsDataRecord *GetPartsData(unsigned int nIndex) const;

    /**
     * @brief Emits one result-window part sprite by part id.
     *
     * Looks up the part's placement rectangle and UV-palette entry, then appends a quad to the
     * layer's shared instancer slot. Part id @c 0xff is a no-op used to skip optional parts. The
     * main pass draws at full alpha; the shadow pass draws the same quad at half intensity.
     * @param flRotation The sprite rotation, in radians.
     * @param flScaleX The sprite X scale.
     * @param flScaleY The sprite Y scale.
     * @param nSlot The instancer slot to append to.
     * @param nPartId The part id (below @c 0xff).
     * @param position The sprite's world position.
     * @param nAlpha The sprite's alpha.
     * @param bShadowPass Non-zero for the half-intensity shadow pass.
     * @ghidraAddress 0x126ab4
     */
    void EmitPartSprite(float flRotation,
                        float flScaleX,
                        float flScaleY,
                        unsigned int nSlot,
                        unsigned int nPartId,
                        const S_VECTOR2 &position,
                        unsigned int nAlpha,
                        int bShadowPass);

    // The number of sprite-instancer slots the layer builds.
    static constexpr int kSpriteSlotCount = 8;

private:
    // Appends one fully-specified quad to a slot's sprite instancer, if the slot exists and is not
    // full; the shared low-level emit behind all the part helpers.
    // @ghidraAddress 0x12ac64
    void AppendSpriteToSlot(const S_VECTOR2 &position,
                            const S_VECTOR2 &anchor,
                            const S_VECTOR2 &size,
                            const S_VECTOR2 &uvOrigin,
                            const S_VECTOR2 &uvSize,
                            float flRotation,
                            const S_VECTOR2 &scale,
                            unsigned int nSlot,
                            unsigned int nIntensity,
                            unsigned int nAlpha);
    // +0x08..+0x0f: descriptor state preceding the textures, still being worked out.
    unsigned char m_aReserved08[8] = {};      // +0x08
    ne::C_TEXTURE *m_pBackgroundTexture = {}; // +0x10: the selection-background atlas.
    ne::C_TEXTURE *m_pPartsTexture = {};      // +0x18: the result-parts atlas.
    ne::C_TEXTURE *m_pOverlayTexture = {};    // +0x20: the overlay atlas (left unset).
    ne::C_SPRITE_INSTANCING *m_apSprites[kSpriteSlotCount] =
        {};             // +0x28: the per-slot sprite batches.
    bool m_bBuilt = {}; // +0x68: set once the sprites are built.
    // +0x69..+0x6b is alignment padding before the default alpha.
    // unsigned char m_aPad69[3]; // +0x69 (alignment padding, compiler-inserted)
    int m_nDefaultAlpha = {}; // +0x6c: default alpha (255), cleared to 0 when the set is built.
    float m_flBaseScale = {}; // +0x70: a base scale the builder seeds (0.7).
    // +0x74..+0x16f: the remaining layer state, still being worked out, kept as a reserved span to
    // preserve the allocation size.
    unsigned char m_aReserved74[0xfc] = {}; // +0x74
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
