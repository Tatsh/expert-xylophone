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
 * the name is inferred from its singleton getter rather than confirmed from the runtime metadata.
 * It shares its layout with @c LimelightThemeLayer. The trailing @c // +0xNN comments document the
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

    /**
     * @brief Advances the grade/full-combo reveal channel by @p flDelta.
     * @param flDelta The frame's elapsed time.
     * @ghidraAddress 0x18795c
     */
    void AdvanceFadeInterp(float flDelta);

    /**
     * @brief Whether the result grade display is drawing (the theme intro has finished animating).
     * @return @c true once the grade display is visible.
     */
    bool IsGradeVisible() const {
        return m_bGradeVisible;
    }

    /**
     * @brief Advances and re-emits the full-combo result-grade effect for the frame.
     *
     * Caches the viewport size, clears the sprite batches, and advances the reveal channel. While
     * the reveal is armed it advances the reveal clock (clearing the clock-active flag once it
     * passes the threshold), emits the base backdrop sprite at an alpha eased from the reveal
     * clock, and for each drawn player side (the first side only when the two-side gauge is on)
     * emits the rank medals (for a fresh best rank, at the player's colour), then the cleared-rank
     * result sprites (a clear that is not a challenge) or the miss sprites otherwise. Finally it
     * publishes each batch's sprite count.
     * @param flDelta The frame's elapsed time.
     * @ghidraAddress 0x18776c
     */
    void Update(float flDelta);

    /**
     * @brief Sets the side count the grade display runs with.
     * @param nSideCount The side count (one runs the display single-side).
     */
    void SetSideCount(int nSideCount) {
        m_nSideCount = nSideCount;
    }

private:
    /**
     * @brief Emits one full-combo quad into its sprite batch, if that batch still has a free slot.
     *
     * Resolves the sprite slot's descriptor (its batch kind, anchor, pixel size, and atlas frame),
     * maps the batch kind to one of the layer's four instancers, and — while that instancer is
     * below its capacity — writes the quad there: the caller's position offset down by half the
     * play-field height, the descriptor's anchor and size, the shared atlas UV rectangle, the
     * caller's scale and rotation, and a tint that is black for the drop-shadow slot and white
     * otherwise, at the caller's alpha. Then it bumps that batch's slot count.
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
     * @brief Emits the six curve-animated "miss"/lower-rank full-combo sprites plus their banner
     * for one player side.
     *
     * Lays out the six sprites along a fixed row of X columns at a shared base Y (the layout height
     * below the reference line), each sized and rotated by its own animation curve sampled at the
     * grade-reveal clock, then emits a final banner sprite. On a single-player display the second
     * side is shifted down and the first side is mirrored (its X negated, its Y reflected, and its
     * sprites turned a half-turn). Each sprite's alpha is its rotation/alpha curve value scaled by
     * the reveal channel and the opaque range.
     * @param nSide The player side (0 or 1).
     * @ghidraAddress 0x187ea4
     */
    void EmitFcMissSprites(int nSide);

    /**
     * @brief Emits the seven curve-animated rank-medal sprites for one player side.
     *
     * Only runs while the grade-reveal clock is inside the medals' window; on the first such frame
     * it plays the reveal sound once. Each of the seven medals is placed at its fixed column and
     * base Y (offset by its own curve), sized and rotated and faded by its animation curves sampled
     * at the windowed clock, and emitted through EmitFcSprite. The single-player mirror/shift
     * layout applies as in the miss burst. Two medals draw only for a matching colour variant; the
     * rest always draw.
     * @param nSide The player side (0 or 1).
     * @param nColorVariant The colour variant selecting which of the two conditional medals draws.
     * @ghidraAddress 0x187b44
     */
    void EmitFcRankSprites(int nSide, int nColorVariant);

    /**
     * @brief Emits the nine curve-animated result/high-rank full-combo sprites for one player side.
     *
     * Each of the nine sprites is placed at its fixed X column with its Y driven by a per-sprite
     * position curve (built once with the layout height folded in), and sized and faded by its own
     * scale and alpha curves sampled at the grade-reveal clock. The single-player mirror/shift
     * layout matches the miss and rank bursts; in multiplayer the position curve drives the Y
     * directly.
     * @param nSide The player side (0 or 1).
     * @ghidraAddress 0x188114
     */
    void EmitFcResultSprites(int nSide);

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
    LinearTween m_gradeChannel;          // +0x6c: the result grade-gauge reveal channel.
    float m_flViewportWidth = {};        // +0x80: the cached viewport width (refreshed each frame).
    float m_flViewportHeight = {};       // +0x84: the cached viewport height.
    int m_aGradeValues[kSideCount] = {}; // +0x88: the per-side best-rank flag from the play record.
    float m_flGradeRevealDuration = {};  // +0x90: the reveal clock's threshold (3000 or 5000).
    // +0x94..+0x97: the remaining layer state, still being worked out.
    unsigned char m_aReserved94[4] = {}; // +0x94
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
