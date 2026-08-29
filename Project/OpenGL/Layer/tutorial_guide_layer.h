/**
 * @file
 * The tutorial-guide layer, @c TutorialGuideLayer.
 */

#pragma once

#include "keyframe_step_table.h"
#include "playfieldlayerbase.h"

namespace ne {
class C_TEXTURE;
class C_SPRITE_INSTANCING_2D;
} // namespace ne

/**
 * The tutorial-guide layer.
 *
 * A process-wide singleton, built on first access, deriving from @c PlayFieldLayerBase. It presents
 * the tap-tutorial guide: a 20-sprite instancer plus a set of hard-coded keyframe timings and two
 * per-step coordinate grids, laid out so the guide sweeps a row of taps across the play field. The
 * class carries no RTTI (it is non-polymorphic), so the name is inferred from its singleton getter
 * rather than confirmed from the runtime metadata. The trailing @c // +0xNN comments document the
 * original 32-bit offsets for reference only.
 */
class TutorialGuideLayer : public PlayFieldLayerBase {
public:
    /** The number of keyframe steps in the guide sweep. */
    static constexpr int kKeyframeCount = 9;
    /** The number of grid rows filled per keyframe. */
    static constexpr int kGridRows = 4;
    /** The number of grid entries per row. */
    static constexpr int kGridColumns = 6;
    /** The sprite-instancer capacity the guide builds. */
    static constexpr unsigned int kSpriteCapacity = 0x14;

    /**
     * A keyframe step: the guide sweeps its taps from a start X to an end X over one step.
     */
    struct Keyframe {
        float flStartX = {}; /*!< The sweep's start X. +0x00 */
        float flEndX = {};   /*!< The sweep's end X. +0x04 */
        int nStep = {};      /*!< The step index. +0x08 */
    };

    /**
     * One coordinate-grid entry: an X position and an enable weight.
     *
     * The binary copies the second field as raw 32 bits, and every value in the shipped offset
     * tables is the float 0.0 or 1.0.
     */
    struct CoordEntry {
        float flX = {};      /*!< The entry's X position. +0x00 */
        float flWeight = {}; /*!< The entry's enable weight, 0.0 or 1.0. +0x04 */
    };

    /**
     * The process-wide tutorial-guide layer, created on first use.
     * @return The shared layer.
     * @ghidraAddress 0x10b3b0
     */
    static TutorialGuideLayer *shared();

    /**
     * Releases and destroys the process-wide tutorial-guide layer, if it exists.
     * @ghidraAddress 0x10b400
     */
    static void destroyShared();

    /**
     * Lazily builds the guide's sprite and its keyframe and coordinate tables.
     *
     * Loads the tutorial atlas, creates the 20-sprite instancer (registered in the global scene
     * tree, made visible, and bound to the atlas), then seeds the nine keyframe timings and the
     * frame-index and coordinate tables and fills the two per-step coordinate grids by adding each
     * keyframe's base X to the shared per-column offset tables. Guarded so the tables are built
     * only once (but the transient visibility byte is always cleared first).
     * @ghidraAddress 0x10b44c
     */
    void BuildTutorialGuideSpriteTable();

    /**
     * Hides the guide, clearing its active flag.
     * @param flDuration A duration slot the routine never reads; every caller passes zero.
     * @ghidraAddress 0x10b734
     */
    void Stop(float flDuration);

    /**
     * Puts the guide into its fade-in state.
     * @ghidraAddress 0x10b73c
     */
    void StartFadeIn();

    /**
     * Begins showing the guide: activates it, resets the animation clock, and advances the
     * game system's tutorial phase to the guide-active phase.
     * @ghidraAddress 0x10b70c
     */
    void Start();

    /**
     * Resets the guide to its idle fade-out state: sets the fade state to hidden, clears the
     * game system's tutorial phase, and resets the timer.
     * @ghidraAddress 0x10b748
     */
    void Reset();

    /**
     * Tears the guide down: releases its atlas, flags its sprite instancer for deferred
     * deletion, and clears the built guard.
     * @ghidraAddress 0x10b350
     */
    void Release();

    /**
     * The per-frame update dispatcher.
     *
     * On the phone (non-pad) it first refreshes the portrait flag from the game system's current
     * viewport dimensions. It then branches on the fade state: an active state (low byte non-zero)
     * animates the finger sprites; an idle state below the hidden threshold does nothing; and the
     * hidden/fade-out state advances the tutorial state machine and renders the result overlay.
     * @param flDeltaTime The frame's elapsed time, in seconds.
     * @ghidraAddress 0x10b778
     */
    void Update(float flDeltaTime);

private:
    /**
     * Advances and draws the animated tutorial finger sprites for the frame.
     * @param flDeltaTime The frame's elapsed time, in seconds.
     * @ghidraAddress 0x10b828
     */
    void AnimateFingerSprites(float flDeltaTime);

    /**
     * Advances the tutorial fade-out state machine.
     * @param flDeltaTime The frame's elapsed time, in seconds.
     * @ghidraAddress 0x10c430
     */
    void AdvanceStateMachine(float flDeltaTime);

    /**
     * Renders the tutorial result overlay during the fade-out phase.
     * @param flDeltaTime The frame's elapsed time, in seconds.
     * @ghidraAddress 0x10c5f8
     */
    void RenderResultOverlay(float flDeltaTime);

    /**
     * Constructs the layer, chaining the base constructor and zero-clearing its own state
     * (the texture, sprite, counts, flags, animation clock, and coordinate table).
     * @ghidraAddress 0x10b308
     */
    TutorialGuideLayer();

    /**
     * Looks up a keyframe step table by time, returning the value of the range that contains
     * it.
     *
     * The table is a flat array of three-float groups `{rangeStart, rangeEnd, value}`, where each
     * group's end equals the next group's start. The value is returned as its raw 32-bit
     * representation (the binary returns it in an integer register); callers reinterpret it as
     * needed.
     * @param flTime The query time.
     * @param pTable The keyframe table, three floats per group.
     * @param nEntries The number of groups.
     * @return The matching group's raw 32-bit value, or @c kKeyframeStepNoMatch when out of range.
     * @ghidraAddress 0x10cd34
     */
    static unsigned int KeyframeStepTableLookup(float flTime, const float *pTable, int nEntries);

    /**
     * Emits one guide sprite of a given kind into the instancer, if its pool is not full.
     *
     * Looks up the sprite kind's descriptor (target anchor, size, and UV-table index) and its UV
     * rectangle, optionally re-derives the Y position from the gauge coordinate when the guide is
     * in its gauge-anchored mode, then writes the sprite's position, anchor, size, UV rectangle,
     * scale, and colour and advances the instancer's sprite count. On the phone (non-pad), sprite
     * kinds above the tap-glyph range draw at half size. Silently drops the sprite when the pool is
     * full.
     * @param flSizeX The sprite's X scale.
     * @param flSizeY The sprite's Y scale.
     * @param nSpriteKind The sprite-kind descriptor index.
     * @param pPosition The sprite's world position (its Y may be re-derived in gauge mode).
     * @param nAlpha The sprite alpha.
     * @ghidraAddress 0x10cda4
     */
    void EmitTutorialSpriteSlot(
        float flSizeX, float flSizeY, unsigned int nSpriteKind, float *pPosition, int nAlpha);

    unsigned char m_aReserved08[8] =
        {};                         // +0x08: transient state; the low byte is cleared each call.
    ne::C_TEXTURE *m_pTexture = {}; // +0x10: the gm_tutorial atlas.
    ne::C_SPRITE_INSTANCING_2D *m_pSprite = {}; // +0x18
    int m_nSpriteCount = {};                    // +0x20
    bool m_bBuilt = {};                         // +0x24
    bool m_bPortrait = {};                      // +0x25: width <= height.
    // +0x26..+0x27 is alignment padding before the cached gauge coordinates.
    // unsigned char m_aPad26[2] = {}; // +0x26
    float m_flGaugeX = {}; // +0x28: the viewport width.
    float m_flGaugeY = {}; // +0x2c: the viewport height.
    bool m_bActive = {};   // +0x30
    // +0x31..+0x33 is alignment padding before the animation clock.
    // unsigned char m_aPad31[3] = {}; // +0x31
    float m_flClock = {};      // +0x34
    float m_flStateTimer = {}; // +0x38
    short m_nFadeState = {};   // +0x3c: 1 = fading in.
    // unsigned char m_aReserved3e[2] = {};        // +0x3e: alignment before the keyframe table.
    Keyframe m_aKeyframes[kKeyframeCount] = {}; // +0x40
    int m_aStepGlyphKinds[kKeyframeCount] = {}; // +0xac: values 14 through 22.
    float m_aCoords[8] = {};                    // +0xd0: four coordinate pairs.
    CoordEntry m_aGridA[kKeyframeCount][kGridRows][kGridColumns] = {}; // +0xf0: from the table at
                                                                       // 0x301f98.
    CoordEntry m_aGridB[kKeyframeCount][kGridRows][kGridColumns] = {}; // +0x7b0: from the table at
                                                                       // 0x302058.
};
