/**
 * @file
 * @brief The theme-2 (Colette) parts-based title-screen scene, @c rb::TitleColetteScene.
 */

#pragma once

#include "basescene.h"
#include "s_vector2.h"
#include "s_vector3.h"
#include "sprite_uv_table.h"
#include "title_part_layout.h"

#ifdef __OBJC__
@class SePlayer;
#else
/** @brief The Objective-C sound-effect player, opaque to a pure C++ translation unit. */
typedef struct objc_object SePlayer;
#endif

namespace ne {
class C_TEXTURE;
class C_SPRITE_INSTANCING_2D;
} // namespace ne

namespace rb {

/**
 * @brief A title-part touch hit-box: the top-left corner and the extent, in layout coordinates.
 *
 * The emitter records one of these per touchable part; the main loop hit-tests a flick or tap
 * against @c x <= p <= x + width on each axis.
 */
struct TitleHitRect {
    float x = {};      /*!< The left edge. +0x00 */
    float y = {};      /*!< The top edge. +0x04 */
    float width = {};  /*!< The horizontal extent. +0x08 */
    float height = {}; /*!< The vertical extent. +0x0c */
};

/**
 * @brief The theme-2 (Colette) title-screen scene: the campaign parts-based title shown before the
 * music list.
 *
 * A @c rb::BaseScene-derived per-frame task created by @c CreateTitleLayerForTheme for theme 2. Its
 * per-frame callback is a small state machine (@c OnFrame): load the campaign textures, part
 * sprites, title BGM, and theme sound-effect player; start the BGM; scroll and animate the parts
 * and handle input; then finish and open the music list. It is the largest title scene (0x898
 * bytes), drawing the title from 104 part sprites plus a campaign-portrait layer. The Ghidra name
 * @c TitleScreenLayer for this class is a misnomer; its RTTI type_info is @c rb::TitleColetteScene.
 * The trailing @c // +0xNN comments document the original member offsets for reference only; the
 * spans whose roles are still being worked out are reserved to preserve the object layout.
 * Reconstructed type @c TitleColetteScene: engine scene, 0x898 bytes.
 */
class TitleColetteScene : public BaseScene {
public:
    /** @brief The number of cached title textures the scene builds. */
    static constexpr int kTextureCount = 4;
    /** @brief The number of part sprite instancers the scene builds. */
    static constexpr int kSpriteSlotCount = 0x68;
    /** @brief The number of part anchor positions in the ring the title arranges its parts around.
     */
    static constexpr int kPartAnchorCount = 12;
    /** @brief The number of touchable part hit-box rectangles the emitter records. */
    static constexpr int kHitBoxCount = 8;

    /**
     * @brief Constructs the scene: chains the scene base, installs the title dispatch table, and
     * zero-clears the presentation state (seeding the fade fully hidden and the tracked touch id to
     * -1, and copying the part anchor ring into the per-sprite state).
     * @ghidraAddress 0x572e4
     */
    TitleColetteScene();

    /**
     * @brief Destroys the scene: releases its cached textures, part sprites, and sound-effect
     * player, then runs the task-node base destructor.
     *
     * The binary emits a non-deleting destructor body (@c 0x574d8) and a deleting variant
     * (@c 0x574dc) that runs it then frees the object; both are this destructor.
     * @ghidraAddress 0x574d8
     * @ghidraAddress 0x574dc
     */
    ~TitleColetteScene() override;

    /**
     * @brief The per-frame task callback: dispatches on the scene state.
     *
     * State 0 loads the resources and sound-effect player, state 1 starts the title BGM, state 2
     * scrolls and animates the parts and handles input, and state 3 finishes and opens the music
     * list.
     * @param nElapsedMs The frame delta, in milliseconds, passed by the dispatcher.
     * @ghidraAddress 0x57514
     */
    void OnFrame(int nElapsedMs) override;

private:
    /**
     * @brief Releases the cached textures and part sprites and terminates the sound-effect player.
     *
     * Releases and nulls each cached texture, flags each owned part sprite for the scene walker to
     * delete, and terminates and nulls the sound-effect player.
     * @ghidraAddress 0x57440
     */
    void ReleaseResources();

    /**
     * @brief State 0: loads the campaign textures and part sprites, starts the title BGM, loads the
     * shot-sound and voice banks, arms the ready-delay timer, and creates the theme sound-effect
     * player.
     * @ghidraAddress 0x57558
     */
    void LoadResources();

    /**
     * @brief State 1: starts the title BGM and advances to the main loop.
     * @ghidraAddress 0x57a64
     */
    void StartMusic();

    /**
     * @brief State 2: scrolls and animates the title parts, handles touch, and drives transitions.
     * @param nElapsedMs The frame delta, in milliseconds, forwarded from the task callback.
     * @ghidraAddress 0x57ad8
     */
    void RunMainLoop(int nElapsedMs);

    /**
     * @brief The main loop's touch pass: tracks one touch, hit-tests the menu boxes on a fresh
     * touch, and classifies a flick into the hidden-gesture state machine on release.
     */
    void ProcessTitleTouch();

    /**
     * @brief Begins the corporate-logo exit: seeds the exit cross-fade, stops the BGM, plays the
     * exit sound, marks the scene exiting, and fades the corporate button in.
     */
    void BeginExit();

    /**
     * @brief Whether a point lies within a hit-box rectangle (corner to corner plus extent).
     * @param flX The point X.
     * @param flY The point Y.
     * @param box The hit-box rectangle.
     * @return @c true when the point is inside.
     */
    static bool IsInsideHitBox(float flX, float flY, const TitleHitRect &box);

    /**
     * @brief State 3: once the audio has fully started, tears down the scene and opens the music
     * list.
     * @ghidraAddress 0x58478
     */
    void FinishAndOpenList();

    /**
     * @brief Emits the title part sprites for the frame.
     * @ghidraAddress 0x5872c
     */
    void RenderSprites();

    /**
     * @brief Emits the campaign-portrait sprite layer for the frame.
     * @ghidraAddress 0x59474
     */
    void RenderCampaignPortrait();

    /**
     * @brief Emits one animated part sprite of a standard timeline window for the current clock.
     *
     * Positions the part from the swung particle table when the swing is active, otherwise from the
     * campaign anchor ring, curve-interpolates a uniform scale and an alpha (scaled to 0-255) from
     * the given keyframe tables, and appends the sprite at full white.
     * @param nPartId The part index to emit.
     * @param nPosIndex The index into the anchor and swing-particle tables.
     * @param pScaleTable The uniform-scale keyframe table.
     * @param nScaleKnots The scale table's knot count.
     * @param pAlphaTable The alpha keyframe table.
     * @param nAlphaKnots The alpha table's knot count.
     */
    void EmitAnimatedPart(unsigned int nPartId,
                          int nPosIndex,
                          const float *pScaleTable,
                          int nScaleKnots,
                          const float *pAlphaTable,
                          int nAlphaKnots);

    /**
     * @brief Emits one animated part sprite at an explicit position.
     *
     * The same shape as @c EmitAnimatedPart, except the position is given rather than taken from
     * the swing or anchor tables. Windows 5 and 7 read their positions from their own tables and
     * consult neither, so neither performs the swing selection.
     * @param nPartId The part index to emit.
     * @param position The part's position.
     * @param pScaleTable The uniform-scale keyframe table.
     * @param nScaleKnots The scale table's knot count.
     * @param pAlphaTable The alpha keyframe table.
     * @param nAlphaKnots The alpha table's knot count.
     */
    void EmitTablePositionedPart(unsigned int nPartId,
                                 const S_VECTOR2 &position,
                                 const float *pScaleTable,
                                 int nScaleKnots,
                                 const float *pAlphaTable,
                                 int nAlphaKnots);

    /**
     * @brief Emits one title part's sprite into its instancer slot and records its hit-box rect.
     *
     * Appends one quad to part @p nPartId's sprite instancer (doing nothing once the instancer is
     * full). The background part (id 0) fills the screen from its texture; the other parts take
     * their placement from the platform layout table and their UV rectangle from the type-specific
     * atlas table, recentring the landscape layout around the viewport. The colour is the passed
     * tint faded out by the scene's fade level, and the lettered/logo parts whose ids gate a touch
     * also store their anchor rectangle into the layer's hit-box table.
     * @param nPartId The part index (0 background; the lettered and logo part ids otherwise).
     * @param nAlpha The base alpha, scaled by the fade.
     * @param position The part centre position.
     * @param scale The part scale.
     * @param flRotation The part rotation, in radians.
     * @param color The tint (each channel 0 to 255, scaled by the fade).
     * @ghidraAddress 0x599e0
     */
    void EmitPartSprite(unsigned int nPartId,
                        unsigned int nAlpha,
                        const S_VECTOR2 &position,
                        const S_VECTOR2 &scale,
                        float flRotation,
                        const S_VECTOR3 &color);

    // Records a touchable part's hit-box (its draw position offset by the layout anchor, sized by
    // the layout extent) into the layer's hit-box table. The sound-effect part in the landscape
    // layout uses a nudged and grown rectangle. Parts without a hit-box are ignored.
    void RecordPartHitBox(unsigned int nPartId,
                          const S_VECTOR2 &drawPosition,
                          const TitlePartLayoutRecord &layout);

    /**
     * @brief Advances the flick-gesture state machine, toggling the swing direction when the main
     * sequence completes and the hidden Hinabita mode when the alternate sequence completes.
     * @param nInputCode The directional gesture id.
     * @return The played sound handle after the swing toggle, or @c 0 otherwise. (Only the caller's
     * completion call with @p nInputCode 4 uses the result; on the partial-step paths the binary
     * leaves its object pointer in the return register, which no caller reads.)
     * @ghidraAddress 0x597a8
     */
    unsigned int AdvanceGestureState(int nInputCode);

    /**
     * @brief Rotates a swing-particle rest position around the logo pivot by the current swing
     * phase and returns its screen X coordinate.
     * @param flBaseX The particle's rest X.
     * @param flBaseY The particle's rest Y.
     * @return The rotated screen X coordinate.
     * @ghidraAddress 0x58570
     */
    float ComputeSwingParticleX(float flBaseX, float flBaseY) const;

    /**
     * @brief The Y counterpart of @c ComputeSwingParticleX.
     * @param flBaseX The particle's rest X.
     * @param flBaseY The particle's rest Y.
     * @return The rotated screen Y coordinate.
     * @ghidraAddress 0x58610
     */
    float ComputeSwingParticleY(float flBaseX, float flBaseY) const;

    /**
     * @brief Advances the title cross-fade timer and updates the interpolated fade value.
     *
     * Accumulates the frame delta into the elapsed time; once it passes the start delay, the fade
     * value eases from its start to its end across the remaining duration (snapping to the end
     * value when the duration is zero or the timer has already completed).
     * @param nDeltaMs The elapsed time this frame, in milliseconds.
     * @ghidraAddress 0x586b0
     */
    void UpdateFadeProgress(int nDeltaMs);

    // unsigned char m_aReserved4b[1] = {}; // +0x4b
    int m_nState = {};        // +0x4c: the dispatch state.
    bool m_bAttractMode = {}; // +0x50: set once the idle timer reaches the attract cap.
    bool m_bSeReady = {};     // +0x51: set once the sound-effect timer passes its ready
                              //        threshold, arming the sound-effect hit-box.
    // unsigned char m_aReserved52[2] = {}; // +0x52
    int m_nIdleTimer = {};     // +0x54: the idle/attract timer, reset on load.
    int m_nReadyDelay = {};    // +0x58: the start ready-delay timer (seeded to 0x708).
    int m_nSeTimer = {};       // +0x5c: the sound-effect timer, reset on load.
    int m_nSeAccumulator = {}; // +0x60: accumulates while the sound-effect part is active.
    // unsigned char m_aReserved64[4] = {};             // +0x64
    ne::C_TEXTURE *m_apTextures[kTextureCount] = {}; // +0x68: bg, parts, parts_eff, and campaign.
    ne::C_SPRITE_INSTANCING_2D *m_apSprites[kSpriteSlotCount] = {}; // +0x88: the 104 part sprites.
    int m_aSpriteCount[kSpriteSlotCount] = {}; // +0x3c8: each instancer's seeded sprite count.
    // +0x568..+0x707: further per-sprite presentation state, still being worked out.
    // unsigned char m_aReserved568[0x1a0] = {}; // +0x568
    // +0x708: the title cross-fade block seeded at load: from, to, duration, elapsed, start-delay,
    // and the interpolated fade value the emitter consumes (as one minus the value, a reveal).
    float m_flFadeFrom = {};       // +0x708
    float m_flFadeTo = {};         // +0x70c
    float m_flFadeDuration = {};   // +0x710
    float m_flFadeElapsed = {};    // +0x714
    float m_flFadeStartDelay = {}; // +0x718
    float m_flFadeValue = {};      // +0x71c: seeded to 1.0 (fully hidden; reveal zero).
    bool m_bExiting = {};          // +0x720: set when the corporate-logo exit is running.
    // unsigned char m_aReserved721[7] = {}; // +0x721
    float m_flGlowPhase = {};      // +0x728: the cycling glow-pulse phase.
    int m_nActiveTouchId = {};     // +0x72c: the tracked touch id (-1 when none).
    int m_nGestureState = {};      // +0x730: the flick-gesture sequence state.
    bool m_bGestureTriggered = {}; // +0x734: latched when a flick sequence completes.
    // +0x735: the swing-direction toggle, also read as the "actively swinging" flag.
    bool m_bSwingToggle = {}; // +0x735
    // unsigned char m_aReserved736[2] = {}; // +0x736
    int m_nSwingDelta = {};    // +0x738: the resulting swing delta (+1 or -1).
    int m_nSwingPhase = {};    // +0x73c: the accumulated swing phase, in degrees.
    bool m_bHinabitaMode = {}; // +0x740: the hidden Hinabita campaign toggle.
    bool m_bSeTriggered = {};  // +0x741: whether the title sound effect has fired.
    // unsigned char m_aReserved742[2] = {}; // +0x742
    float m_flViewportWidth = {};  // +0x744: the viewport width, cached from the game system.
    float m_flViewportHeight = {}; // +0x748: the viewport height.
    // +0x74c: the eight part hit-box rectangles the emitter records for touch testing (the
    // corporate logo, the lettered parts, and the sound-effect part).
    TitleHitRect m_aHitBox[kHitBoxCount] = {};      // +0x74c
    S_VECTOR2 m_aPartAnchor[kPartAnchorCount] = {}; // +0x7cc: the ring of part anchor positions,
    // copied from the campaign anchor table at set-up.
    // +0x82c: each swing particle's animated position, rotated from its anchor by the swing phase.
    S_VECTOR2 m_aSwingParticle[kPartAnchorCount] = {}; // +0x82c
    // unsigned char m_aReserved88c[4] = {};              // +0x88c
    SePlayer *m_pSePlayer = {}; // +0x890: the theme sound-effect player.
};

/**
 * @brief The 104-record per-sprite part-layout table binding each part's texture and placement.
 *
 * Two variants live in the binary's read-only data: the default table and the alternate (iPad)
 * table. A record's texture index of 4 or 5 marks a part that binds no texture. @c LoadResources
 * reads the texture index; the placement fields and UV index are used when the parts are drawn.
 * @ghidraAddress 0x2f8f80
 */
extern const TitlePartLayoutRecord g_aTitleCampaignLayoutDefault[];
/** @ghidraAddress 0x2f85c0 */
extern const TitlePartLayoutRecord g_aTitleCampaignLayoutAltFrame[];

/**
 * @brief The part UV-rectangle tables, selected by a part's render type and the orientation.
 *
 * The default table serves the background and any non-typed part; the lettered-part (type 1) and
 * logo (type 3) parts each have a phone and an iPad table. The default table is declared at global
 * scope below, outside @c rb, because the Limelight layers index it from there.
 */
/** @ghidraAddress 0x2f7ef8 */
extern const SpriteUvEntry g_aTitlePartUvLetterPhone[];
/** @ghidraAddress 0x2f7b68 */
extern const SpriteUvEntry g_aTitlePartUvLetterPad[];
/** @ghidraAddress 0x2f82e8 */
extern const SpriteUvEntry g_aTitlePartUvLogoPhone[];
/** @ghidraAddress 0x2f8288 */
extern const SpriteUvEntry g_aTitlePartUvLogoPad[];

/**
 * @brief The ring of twelve part anchor positions the title arranges its campaign parts around.
 *
 * Copied into the scene's @c m_aPartAnchor at construction.
 * @ghidraAddress 0x2fc2c0
 */
extern const S_VECTOR2 g_aTitleCampaignPartAnchor[];

} // namespace rb

/**
 * @brief The default part UV-rectangle table, serving the background and any non-typed part.
 *
 * At global scope rather than in @c rb: the Limelight effect, theme, and full-combo layers index
 * it from outside that namespace, and the shared @c g_aScoreGaugeUvTable is scoped the same way.
 * @ghidraAddress 0x2f7908
 */
extern const SpriteUvEntry g_aTitlePartUvDefault[];
