/**
 * @file
 * The Limelight-theme background-effect layer, @c LimelightEffectLayer.
 */

#pragma once

#include "playfieldlayerbase.h"

struct S_VECTOR2;

namespace ne {
class C_TEXTURE;
class C_SPRITE_INSTANCING_2D;
} // namespace ne

/**
 * @brief The Limelight-theme background-effect layer.
 *
 * A process-wide singleton, built on first access, deriving from @c PlayFieldLayerBase. It owns the
 * two background-effect atlases and the two sprite instancers that draw them under the shared
 * background layer's render object. The class carries no RTTI (it is non-polymorphic), so the name
 * is inferred from its singleton getter rather than confirmed from the runtime metadata. The
 * trailing @c // +0xNN comments document the original 32-bit offsets for reference only.
 */
class LimelightEffectLayer : public PlayFieldLayerBase {
public:
    /**
     * @brief The process-wide Limelight effect layer, created on first use.
     * @return The shared layer.
     * @ghidraAddress 0x11ffcc
     */
    static LimelightEffectLayer *shared();

    /**
     * @brief Lazily builds the layer's background sprites: loads the two atlases, creates the two
     * sprite instancers (attaching each under the background layer's render object, making it
     * visible, binding its texture, seeding its sprite count, and flagging additive blend where the
     * slot table requests it).
     *
     * Guarded so the sprites are built only once.
     * @ghidraAddress 0x12001c
     */
    void InitializeBackgroundSprites();

    // The number of background sprite instancers the layer builds.
    static constexpr int kSpriteSlotCount = 2;

    /**
     * @brief Activates the effect and resets its frame counter.
     * @ghidraAddress 0x120118
     */
    void SetActiveAndResetCounter();

    /**
     * @brief Deactivates the effect.
     * @param flDuration A duration slot the routine never reads; every caller passes zero.
     * @ghidraAddress 0x120128
     */
    void SetInactive(float flDuration);

    /** @brief Whether the effect's intro animation is still active. */
    bool IsActive() const {
        return m_bActive;
    }

    /**
     * @brief Advances and redraws the Limelight full-combo effect for the frame.
     *
     * Caches the viewport size, clears both slot counts, and, while the effect is active, advances
     * its clock (deactivating past the end threshold), then emits the twelve base glyph sprites
     * (each animated by a scale and a position curve) and, once the clock passes the curve-phase
     * start, the curve-animated glyph sprites.
     * @param flDeltaTime The frame's elapsed time.
     * @ghidraAddress 0x120130
     */
    void UpdateEffect(float flDeltaTime);

private:
    /**
     * @brief Emits the twenty-eight curve-animated glyph sprites for the frame.
     *
     * Each slot chains four curve lookups (the output of each threading into the next as the query
     * value) to derive an animated position, then emits that glyph's sprite.
     * @param flClock The animation clock fed into the first curve lookup.
     * @ghidraAddress 0x120328
     */
    void EmitCurveAnimatedSprites(float flClock);

    /**
     * @brief Emits one Limelight effect glyph of kind @p nSpriteKind at @p pPosition.
     *
     * Looks the kind up in the effect sprite-layout table (which supplies the target sprite group,
     * fixed anchor and quad size, and atlas-frame index), resolves the group to an instancer slot
     * and the atlas frame to a UV rectangle (from the shared atlas table for the higher kinds, or
     * the title-part table otherwise), and appends the sprite into that slot's batch (dropping it
     * when the batch is full). The position is adjusted in place by the cached viewport size: laid
     * out full-size and only shifted vertically on an iPad, or halved and re-centred on the phone.
     * The sprite takes the caller's @p flScaleX and @p flScaleY, no rotation, and a white tint at
     * @p nAlpha.
     * @param nSpriteKind The effect glyph kind, indexing the layout table.
     * @param pPosition The sprite's base position, adjusted in place by the viewport size.
     * @param nAlpha The sprite's alpha, in @c [0, 255].
     * @param flScaleX The sprite's horizontal scale.
     * @param flScaleY The sprite's vertical scale.
     * @ghidraAddress 0x120434
     */
    void EmitSpriteSlot(unsigned int nSpriteKind,
                        S_VECTOR2 *pPosition,
                        unsigned int nAlpha,
                        float flScaleX,
                        float flScaleY);

    /**
     * @brief Constructs the layer, chaining the base constructor and zero-clearing its own state.
     * @ghidraAddress 0x11ff84
     */
    LimelightEffectLayer();

    ne::C_TEXTURE *m_pBackgroundTexture = {}; // +0x08: the gm_parts2 atlas.
    ne::C_TEXTURE *m_pEffectTexture = {};     // +0x10: the ti_parts_eff atlas.
    ne::C_SPRITE_INSTANCING_2D *m_apSprites[kSpriteSlotCount] =
        {};                                     // +0x18: the per-slot sprite batches.
    int m_aSpriteCounts[kSpriteSlotCount] = {}; // +0x28: each slot's initial count.
    bool m_bSpritesBuilt = {};                  // +0x30: set once the sprites are built.
    // +0x31..+0x33 is alignment padding before the trailing state.
    // unsigned char m_aPad31[3]; // +0x31 (alignment padding, compiler-inserted)
    float m_flCachedViewportWidth = {};  // +0x34: the last-seen viewport width.
    float m_flCachedViewportHeight = {}; // +0x38: the last-seen viewport height.
    bool m_bActive = {};                 // +0x3c: whether the effect is active.
    // unsigned char m_aPad3d[3]; // +0x3d (alignment padding, compiler-inserted)
    float m_flClock = {}; // +0x40: the effect animation clock, reset on activation.
    // unsigned char m_aReserved44[4] = {}; // +0x44
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
