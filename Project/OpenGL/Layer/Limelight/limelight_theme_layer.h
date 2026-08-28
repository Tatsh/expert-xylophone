/**
 * @file
 * The Limelight-theme layer, @c LimelightThemeLayer.
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
 * @brief The Limelight-theme layer.
 *
 * A process-wide singleton, built on first access, deriving from @c PlayFieldLayerBase. It owns the
 * three full-combo atlases and four sprite instancers, drawn beneath the shared background layer,
 * that present the Limelight full-combo effect. The class carries no RTTI (it is non-polymorphic),
 * so the name is inferred from its singleton getter rather than confirmed from the runtime
 * metadata. The trailing @c // +0xNN comments document the original 32-bit offsets for reference
 * only.
 */
class LimelightThemeLayer : public PlayFieldLayerBase {
public:
    /**
     * @brief The process-wide Limelight-theme layer, created on first use.
     * @return The shared layer.
     * @ghidraAddress 0x1206c8
     */
    static LimelightThemeLayer *shared();

    /**
     * @brief Lazily builds the full-combo layer's textures and sprites: loads the three atlases and
     * creates the four sprite instancers (attaching each under the background layer's render
     * object, making it visible, binding its atlas for the textured slots, seeding its sprite
     * count, and flagging additive blend on the last slot).
     *
     * Guarded so the sprites are built only once.
     * @ghidraAddress 0x120718
     */
    void InitFullComboLayerTextures();

    /** @brief The number of full-combo sprite instancers the layer builds. */
    static constexpr int kSpriteSlotCount = 4;
    /** @brief The number of player sides the result grade display tracks. */
    static constexpr int kSideCount = 2;

    /**
     * @brief Initialises the result grade display: seeds the reveal channel, parks the reveal
     * clock, arms the display, fills the per-side grade values, and picks the reveal duration.
     * @ghidraAddress 0x120844
     */
    void InitializeGradeDisplayState();

    /**
     * @brief Begins animating the grade-gauge reveal channel from its current value down to zero
     * over @p flDuration (snapping straight to zero when the duration is non-positive).
     * @param flDuration The animation duration.
     * @ghidraAddress 0x120900
     */
    void StartGradeAnimation(float flDuration);

    /**
     * @brief Advances the result grade-gauge reveal channel by @p flDeltaTime.
     * @param flDeltaTime The frame's elapsed time.
     * @ghidraAddress 0x120a74
     */
    void AdvanceGradeChannel(float flDeltaTime);

    /**
     * @brief Seeds the per-side grade values from the active score tracker's play records.
     * @ghidraAddress 0x1208c4
     */
    void InitializeGradeValuesFromTracker();

    /**
     * @brief Advances and redraws the result grade/achievement-rate display for the frame.
     *
     * Caches the viewport size, advances the reveal channel, and, when the display is enabled, runs
     * the reveal clock and emits the base grade sprite faded in by the reveal, then per side (the
     * first only when single-side) draws the grade meter for a zero grade and either the high-rank
     * badge (rank below AA) or the rank glyphs. Finally publishes each slot's count to its
     * instancer.
     * @param flDeltaTime The frame's elapsed time.
     * @ghidraAddress 0x120920
     */
    void UpdateGradeDisplay(float flDeltaTime);

    /**
     * @brief Whether the result grade display is drawing (the theme intro has finished animating).
     * @return @c true once the grade display is visible.
     */
    bool IsGradeVisible() const {
        return m_bGradeVisible;
    }

    /**
     * @brief Sets the side count the grade display runs with.
     * @param nSideCount The side count (one runs the display single-side).
     */
    void SetSideCount(int nSideCount) {
        m_nSideCount = nSideCount;
    }

private:
    /**
     * @brief Emits one grade-display sprite of kind @p nSpriteKind.
     *
     * Looks the kind up in the grade sprite-layout table (which supplies the target sprite group,
     * fixed anchor and quad size, and atlas-frame index), resolves the group to an instancer slot
     * and the atlas frame to a UV rectangle (from the shared atlas table for a glyph/part kind, or
     * the title-part table otherwise), and appends the sprite into that slot's batch (dropping it
     * when the batch is full). The sprite takes the caller's @p flScaleX, @p flScaleY, and
     * @p flRotation, is positioned at @p pPosition offset down by half the full-height layout
     * coordinate, and is tinted black for the backdrop kind or white for every glyph/part, both at
     * the caller's @p nAlpha.
     * @param flScaleX The sprite's horizontal scale.
     * @param flScaleY The sprite's vertical scale.
     * @param flRotation The sprite's rotation, in radians.
     * @param nSpriteKind The grade sprite kind, indexing the layout table.
     * @param pPosition The sprite's world position (before the vertical centre offset).
     * @param nAlpha The sprite's alpha, in @c [0, 255].
     * @ghidraAddress 0x120abc
     */
    void EmitGradeSpriteSlot(float flScaleX,
                             float flScaleY,
                             float flRotation,
                             unsigned int nSpriteKind,
                             const S_VECTOR2 *pPosition,
                             unsigned int nAlpha);

    /**
     * @brief Draws one side's animated achievement-rate meter needle.
     *
     * Runs only once the reveal clock passes the meter's start threshold. The first frame past the
     * threshold triggers the achievement-rate fanfare (playing themed sound effect 10 once). It
     * lazily seeds the shared needle-frame UV table, maps the reveal clock to one of the thirty
     * needle frames (clamped), and emits that frame's meter sprite for the side at full alpha,
     * fading to transparent once the clock passes the meter's fade threshold.
     * @param nSide The player side.
     * @ghidraAddress 0x120ca0
     */
    void RenderGradeMeterSprite(unsigned int nSide);

    /**
     * @brief Draws one side's animated achievement-rate digit strip (the rank AA-and-above path).
     *
     * Once the reveal clock passes the digit reveal threshold it first draws the achievement-rate
     * percentage digits. It then animates each of the seven strip glyphs in with its own scale,
     * alpha, and horizontal-position curves, sampled at the reveal clock, positioning each glyph
     * relative to the layer's layout origin. In single-side mode the far side is mirrored a
     * half-turn across the field and the near side is nudged down; each glyph is emitted at the
     * sampled scale, with alpha faded by the reveal channel.
     * @param nSide The player side.
     * @ghidraAddress 0x120e50
     */
    void RenderGradeRankGlyphs(int nSide);

    /**
     * @brief Draws one side's animated high-rank badge glyph strip (the rank-below-AA path).
     *
     * Animates each of the seven badge glyphs in with its own alpha and vertical-position curves
     * sampled at the reveal clock, placing each at a fixed horizontal base relative to the layout
     * origin. As with the rank glyphs, single-side mode nudges the near side down and mirrors the
     * far side a half-turn across the field. Each glyph is emitted at unit scale with alpha faded
     * by the reveal channel.
     * @param nSide The player side.
     * @ghidraAddress 0x1214ec
     */
    void RenderGradeHighRankBadge(int nSide);

    /**
     * @brief Emits one side's achievement-rate meter needle sprite at the given frame UV and alpha.
     *
     * Appends into the additive meter batch (dropping the sprite when the batch is full). The
     * needle is placed at a fixed horizontal position relative to the layout origin, at a per-side
     * vertical position that differs between iPad and phone, offset down by half the full-height
     * layout coordinate. On iPad in single-side mode the near side is repositioned and mirrored a
     * half-turn. The sprite draws at the fixed meter anchor, size, and UV size, at unit scale,
     * tinted white at the caller's alpha.
     * @param nSide The player side.
     * @param pUvOrigin The needle frame's UV origin.
     * @param nAlpha The sprite's alpha, in @c [0, 255].
     * @ghidraAddress 0x121bb8
     */
    void EmitGradeMeterSlot(unsigned int nSide, const S_VECTOR2 *pUvOrigin, unsigned int nAlpha);

    /**
     * @brief Draws one side's animated achievement-rate percentage digit strip.
     *
     * Animates each of the thirty-five digit-strip glyphs in with its own scale, alpha, and
     * vertical-position curves sampled at the digit clock, placing each at a fixed horizontal base
     * relative to the layout origin. As with the rank glyphs, single-side mode nudges the near side
     * down and mirrors the far side a half-turn across the field. Each glyph is emitted at the
     * sampled scale with the sampled alpha (the reveal channel is not applied here).
     * @param flClock The digit animation clock (the reveal clock shifted by the digit reveal
     * offset).
     * @param nSide The player side.
     * @ghidraAddress 0x121e14
     */
    void RenderGradeArDigits(float flClock, unsigned int nSide);

    /**
     * @brief Constructs the layer, chaining the base constructor and zero-clearing its own state.
     * @ghidraAddress 0x120630
     */
    LimelightThemeLayer();

    // +0x08 and +0x0c are the layer's layout size (384 x 680); the grade strip also reads them as
    // the layout origin it positions the animated glyphs relative to.
    float m_flWidth = {};                 // +0x08: the layer's layout width (384).
    float m_flHeight = {};                // +0x0c: the layer's layout height (680).
    ne::C_TEXTURE *m_pPartsTexture = {};  // +0x10: the gm_parts2 atlas.
    ne::C_TEXTURE *m_pEffectTexture = {}; // +0x18: the ti_parts_eff atlas.
    ne::C_TEXTURE *m_pWinTexture = {};    // +0x20: the gm_win atlas.
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
    float m_flCachedViewportWidth = {};  // +0x80: the last-seen viewport width.
    float m_flCachedViewportHeight = {}; // +0x84: the last-seen viewport height.
    int m_aGradeValues[kSideCount] = {}; // +0x88: the per-side grade value from the play record.
    float m_flGradeRevealDuration = {};  // +0x90: the reveal clock's threshold (3000 or 5000).
    // +0x94..+0x97: the remaining layer state, still being worked out.
    // unsigned char m_aReserved94[4] = {}; // +0x94
};
