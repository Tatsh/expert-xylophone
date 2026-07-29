/**
 * @file
 * The Limelight-theme full-combo layer, @c FullComboLimelightLayer.
 */

#pragma once

#include "playfieldlayerbase.h"

struct S_VECTOR2;

namespace ne {
class C_TEXTURE;
class C_SPRITE_INSTANCING_2D;
} // namespace ne

/**
 * @brief The Limelight-theme full-combo layer.
 *
 * A process-wide singleton, built on first access, deriving from @c PlayFieldLayerBase. It owns the
 * three full-combo atlases and three sprite instancers, drawn beneath the shared background layer,
 * that present the Limelight full-combo effect. The class carries no RTTI (it is non-polymorphic),
 * so the name is inferred from its singleton getter rather than confirmed from the runtime metadata.
 * The trailing @c // +0xNN comments document the original 32-bit offsets for reference only.
 */
class FullComboLimelightLayer : public PlayFieldLayerBase {
public:
    /**
     * @brief The process-wide Limelight full-combo layer, created on first use.
     * @return The shared layer.
     * @ghidraAddress 0x1228e4
     */
    static FullComboLimelightLayer *shared();

    /**
     * @brief Constructs the layer: chains the base-layer constructor and seeds the layout size,
     * leaving the texture, sprite, count, and effect state zero-cleared.
     * @ghidraAddress 0x122870
     */
    FullComboLimelightLayer();

    /**
     * @brief Lazily builds the layer's textures and sprites: loads the three atlases and creates the
     * three sprite instancers (attaching each under the background layer's render object, making it
     * visible, binding its mapped atlas, clearing its sprite count, flagging additive blend on the
     * middle slot, and enabling its two texture-environment parameters).
     *
     * Guarded so the sprites are built only once.
     * @ghidraAddress 0x122934
     */
    void LoadTexturesAndBatchesForLimelightLayer();

    /**
     * @brief Activates the full-combo effect for a player colour.
     * @param nColor The player colour (0 or 1).
     * @ghidraAddress 0x122a44
     */
    void CreateFullComboLimelight(unsigned int nColor);

    /**
     * @brief Clears every player colour's full-combo effect active flag.
     * @ghidraAddress 0x122abc
     */
    void ClearEffectFlags();

    /**
     * @brief Whether any player colour's full-combo effect is currently active.
     * @return @c true when at least one effect record's active flag is set.
     * @ghidraAddress 0x122ad8
     */
    bool IsAnyEffectActive() const;

    /**
     * @brief Advances every active full-combo effect by one frame and emits its sprites.
     * Reconstruction pending.
     * @param flDelta The elapsed frame count.
     * @ghidraAddress 0x122b08
     */
    void Update(float flDelta);

    // The number of full-combo sprite instancers the layer builds.
    static constexpr int kSpriteSlotCount = 3;
    // The number of player colours with a full-combo effect record.
    static constexpr int kColorCount = 2;

private:
    /**
     * @brief Emits one full-combo quad of the given type into its sprite batch, if capacity remains.
     *
     * Looks up the type's descriptor (its batch selector, anchor, pixel size, and atlas frame). The
     * selector both chooses one of the layer's three sprite batches and selects the atlas the quad's
     * UV rectangle comes from: batch 0 draws from the Limelight title-part atlas, the others from the
     * shared sprite atlas. While that batch is below its capacity, it writes the quad — the caller's
     * position, the descriptor's anchor and size, the atlas UV rectangle, the caller's scale and
     * rotation, and opaque white at the caller's alpha — then bumps that batch's slot count.
     * @param nType The sprite type (0 through 0x49).
     * @param pPosition The quad's screen position.
     * @param nAlpha The quad's alpha.
     * @param flScaleX The quad's X scale.
     * @param flScaleY The quad's Y scale.
     * @param flRotation The quad's rotation, in radians.
     * @ghidraAddress 0x123658
     */
    void CreateSprite(int nType,
                      const S_VECTOR2 *pPosition,
                      int nAlpha,
                      float flScaleX,
                      float flScaleY,
                      float flRotation);

    // A per-colour full-combo effect record.
    struct EffectRecord {
        bool m_bActive = {}; // +0x00: whether the effect is playing.
        // unsigned char m_aPad1[3]; // +0x01 (alignment padding, compiler-inserted)
        int m_nTimer = {};  // +0x04: the effect animation timer.
        bool m_bFlag2 = {}; // +0x08: a secondary state flag, cleared on activation.
        // unsigned char m_aPad9[3]; // +0x09 (alignment padding, compiler-inserted)
    };

    float m_flWidth = {};  // +0x08: the layer's layout width (384), seeded by the constructor.
    float m_flHeight = {}; // +0x0c: the layer's layout height (1098), seeded by the constructor.
    ne::C_TEXTURE *m_pEffectTexture = {}; // +0x10: the ti_parts_eff atlas.
    ne::C_TEXTURE *m_pPartsTexture = {};  // +0x18: the gm_parts2 atlas.
    ne::C_TEXTURE *m_pPartsTexture2 = {}; // +0x20: a second gm_parts2 handle.
    ne::C_SPRITE_INSTANCING_2D *m_apSprites[kSpriteSlotCount] =
        {};                                     // +0x28: the per-slot sprite batches.
    int m_aSpriteCounts[kSpriteSlotCount] = {}; // +0x40: each slot's initial count.
    bool m_bBuilt = {};                         // +0x4c: set once the sprites are built.
    // +0x4d..+0x4f is alignment padding before the effect records.
    // unsigned char m_aPad4d[3]; // +0x4d (alignment padding, compiler-inserted)
    EffectRecord m_aEffects[kColorCount] = {}; // +0x50: one effect record per player colour.
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
