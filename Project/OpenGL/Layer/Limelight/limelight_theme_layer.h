/**
 * @file
 * The Limelight-theme layer, @c LimelightThemeLayer.
 */

#pragma once

#include "linear_tween.h"
#include "playfieldlayerbase.h"

namespace ne {
class C_TEXTURE;
class C_SPRITE_INSTANCING;
} // namespace ne

/**
 * @brief The Limelight-theme layer.
 *
 * A process-wide singleton, built on first access, deriving from @c PlayFieldLayerBase. It owns the
 * three full-combo atlases and four sprite instancers, drawn beneath the shared background layer,
 * that present the Limelight full-combo effect. The class carries no RTTI (it is non-polymorphic),
 * so the name is inferred from its singleton getter rather than confirmed from the runtime metadata.
 * The trailing @c // +0xNN comments document the original 32-bit offsets for reference only.
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
     * creates the four sprite instancers (attaching each under the background layer's render object,
     * making it visible, binding its atlas for the textured slots, seeding its sprite count, and
     * flagging additive blend on the last slot).
     *
     * Guarded so the sprites are built only once.
     * @ghidraAddress 0x120718
     */
    void InitFullComboLayerTextures();

    // The number of full-combo sprite instancers the layer builds.
    static constexpr int kSpriteSlotCount = 4;
    // The number of player sides the result grade display tracks.
    static constexpr int kSideCount = 2;

    /**
     * @brief Initialises the result grade display: seeds the reveal channel, parks the reveal clock,
     * arms the display, fills the per-side grade values, and picks the reveal duration.
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
     * @ghidraAddress 0x120a74
     */
    void AdvanceGradeChannel(float flDeltaTime);

    /**
     * @brief Seeds the per-side grade values from the active score tracker's play records.
     * @ghidraAddress 0x1208c4
     */
    void InitializeGradeValuesFromTracker();

private:
    /**
     * @brief Constructs the layer, chaining the base constructor and zero-clearing its own state.
     * @ghidraAddress 0x120630
     */
    LimelightThemeLayer();

    float m_flWidth = {};                 // +0x08: the layer's layout width (384).
    float m_flHeight = {};                // +0x0c: the layer's layout height (680).
    ne::C_TEXTURE *m_pPartsTexture = {};  // +0x10: the gm_parts2 atlas.
    ne::C_TEXTURE *m_pEffectTexture = {}; // +0x18: the ti_parts_eff atlas.
    ne::C_TEXTURE *m_pWinTexture = {};    // +0x20: the gm_win atlas.
    ne::C_SPRITE_INSTANCING *m_apSprites[kSpriteSlotCount] =
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
    int m_aGradeValues[kSideCount] = {}; // +0x88: the per-side grade value from the play record.
    float m_flGradeRevealDuration = {};  // +0x90: the reveal clock's threshold (3000 or 5000).
    // +0x94..+0x97: the remaining layer state, still being worked out.
    unsigned char m_aReserved94[4] = {}; // +0x94
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
