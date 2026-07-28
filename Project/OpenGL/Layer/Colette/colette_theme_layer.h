/**
 * @file
 * The Colette-theme layer, @c ColetteThemeLayer.
 */

#pragma once

#include "linear_tween.h"
#include "playfieldlayerbase.h"

struct S_VECTOR2;

namespace ne {
class C_TEXTURE;
class C_SPRITE_INSTANCING_2D;
} // namespace ne

/**
 * @brief The Colette-theme layer.
 *
 * A process-wide singleton, built on first access, deriving from @c PlayFieldLayerBase. It owns the
 * three full-combo atlases and four sprite instancers, drawn beneath the shared background layer,
 * that present the Colette full-combo effect. The class carries no RTTI (it is non-polymorphic), so
 * the name is inferred from its singleton getter rather than confirmed from the runtime metadata. It
 * shares its layout with @c LimelightThemeLayer. The trailing @c // +0xNN comments document the
 * original 32-bit offsets for reference only.
 */
class ColetteThemeLayer : public PlayFieldLayerBase {
public:
    /**
     * @brief The process-wide Colette-theme layer, created on first use.
     * @return The shared layer.
     * @ghidraAddress 0x18751c
     */
    static ColetteThemeLayer *shared();

    /**
     * @brief Lazily builds the full-combo effect sprites: loads the three atlases and creates the
     * four sprite instancers (attaching each under the background layer's render object, making it
     * visible, binding its atlas for the textured slots, seeding its sprite count, and flagging
     * additive blend on the last slot).
     *
     * Guarded so the sprites are built only once.
     * @ghidraAddress 0x18756c
     */
    void CreateFcEffectSprites();

    // The number of full-combo sprite instancers the layer builds.
    static constexpr int kSpriteSlotCount = 4;
    // The number of player sides the result grade display tracks.
    static constexpr int kSideCount = 2;

    /**
     * @brief Resets the result grade display: seeds the reveal channel, parks the reveal clock,
     * arms the display, loads the per-side best-rank flags, and picks the reveal duration.
     * @ghidraAddress 0x187690
     */
    void ResetGradeDisplayState();

    /**
     * @brief Loads the per-side best-rank flags from the active score tracker's play records.
     * @ghidraAddress 0x187710
     */
    void LoadBestRankFlags();

    /**
     * @brief Begins the result grade channel's fade-out, easing it to zero over @p flDuration and
     *        snapping to zero immediately when the duration is non-positive.
     * @param flDuration The fade duration.
     * @ghidraAddress 0x18774c
     */
    void StartFadeOut(float flDuration);

private:
    /**
     * @brief Emits one full-combo quad into its sprite batch, if that batch still has a free slot.
     *
     * Resolves the sprite slot's descriptor (its batch kind, anchor, pixel size, and atlas frame),
     * maps the batch kind to one of the layer's four instancers, and — while that instancer is below
     * its capacity — writes the quad there: the caller's position offset down by half the play-field
     * height, the descriptor's anchor and size, the shared atlas UV rectangle, the caller's scale and
     * rotation, and a tint that is black for the drop-shadow slot and white otherwise, at the caller's
     * alpha. Then it bumps that batch's slot count.
     * @param flScaleX The quad's X scale.
     * @param flScaleY The quad's Y scale.
     * @param flRotation The quad's rotation, in radians.
     * @param nSpriteSlot The sprite-slot descriptor index.
     * @param pPosition The quad's base screen position (x, y).
     * @param nAlpha The quad's alpha.
     * @ghidraAddress 0x1879a4
     */
    void EmitFcSprite(float flScaleX,
                      float flScaleY,
                      float flRotation,
                      unsigned int nSpriteSlot,
                      const S_VECTOR2 *pPosition,
                      int nAlpha);

    /**
     * @brief Constructs the layer, chaining the base constructor and seeding its own state.
     * @ghidraAddress 0x187484
     */
    ColetteThemeLayer();

    float m_flWidth = {};                 // +0x08: the layer's layout width (384).
    float m_flHeight = {};                // +0x0c: the layer's layout height (680).
    ne::C_TEXTURE *m_pPartsTexture = {};  // +0x10: the gm_parts2 atlas.
    ne::C_TEXTURE *m_pEffectTexture = {}; // +0x18: the ti_parts_eff atlas.
    ne::C_TEXTURE *m_pPartsTexture2 = {}; // +0x20: a second gm_parts2 handle.
    ne::C_SPRITE_INSTANCING_2D *m_apSprites[kSpriteSlotCount] =
        {};                                     // +0x28: the per-slot sprite batches.
    int m_aSpriteCounts[kSpriteSlotCount] = {}; // +0x48: each slot's initial count.
    bool m_bBuilt = {};                         // +0x58: set once the sprites are built.
    // +0x59..+0x5b is alignment padding before the trailing state.
    // unsigned char m_aPad59[3]; // +0x59 (alignment padding, compiler-inserted)
    int m_nSideCount = {}; // +0x5c: seeded to 1; the grade display runs single-side when this is 1.
    bool m_bGradeVisible = {};     // +0x60: whether the result grade display draws.
    bool m_bGradeClockActive = {}; // +0x61: whether the reveal clock is advancing.
    // +0x62..+0x63 is alignment padding before the reveal clock.
    float m_flGradeRevealClock = {}; // +0x64: the reveal clock, counting up to the threshold.
    bool m_bGradeArmed = {};         // +0x68: raised once the grade display is initialised.
    // +0x69..+0x6b is alignment padding before the reveal channel.
    LinearTween m_gradeChannel; // +0x6c: the result grade-gauge reveal channel.
    // +0x80..+0x87: the cached viewport size, still being worked out.
    unsigned char m_aReserved80[8] = {}; // +0x80
    int m_aGradeValues[kSideCount] = {}; // +0x88: the per-side best-rank flag from the play record.
    float m_flGradeRevealDuration = {};  // +0x90: the reveal clock's threshold (3000 or 5000).
    // +0x94..+0x97: the remaining layer state, still being worked out.
    unsigned char m_aReserved94[4] = {}; // +0x94
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
