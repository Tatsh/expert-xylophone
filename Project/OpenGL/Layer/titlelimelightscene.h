/**
 * @file
 * The parts-based title-screen scene layer, @c TitleLimelightScene.
 */

#pragma once

#include "basescene.h"

struct S_VECTOR2;

namespace ne {
class C_TEXTURE;
class C_SPRITE_INSTANCING_2D;
} // namespace ne

/**
 * @brief The parts-based title-screen scene layer used for the themes other than 0 (Classic) and 2
 * (Colette).
 *
 * A @c rb::BaseScene-derived per-frame task created by @c CreateTitleLayerForTheme's fall-through
 * branch. Its per-frame callback is a small state machine (@c DispatchTitleScreen2State): load the
 * title resources and start the BGM, wait for the start music, render and animate the parts, then
 * finish and open the music list. It is a larger (0x628-byte) layer than @c rb::TitleClassicScene,
 * drawing the title from many part sprites. The trailing @c // +0xNN comments document the original
 * member offsets for reference only; the spans whose roles are still being worked out are reserved
 * to preserve the object layout.
 * @ghidraAddress TitleLimelightScene (engine layer, 0x628 bytes)
 */
namespace rb {

class TitleLimelightScene : public BaseScene {
public:
    // The number of cached title textures and the number of part sprite instancers the layer
    // builds.
    static constexpr int kTextureCount = 3;
    static constexpr int kSpriteSlotCount = 0x53;
    // The number of interactive-part touch hit-rectangles the part emitter records.
    static constexpr int kHitRectCount = 5;

    /** @brief One interactive part's touch hit-rectangle, in screen space. */
    struct HitRect {
        float x = {};      // +0x00: the rectangle's left edge.
        float y = {};      // +0x04: the rectangle's top edge.
        float width = {};  // +0x08: the rectangle's width.
        float height = {}; // +0x0c: the rectangle's height.
    };

    /**
     * @brief Constructs the layer: chains the UI-layer base, installs the title dispatch table, and
     * zero-clears the presentation state (seeding the fade value to 1.0 and the trailing index to
     * -1).
     * @ghidraAddress 0x152de8
     */
    TitleLimelightScene();

    /**
     * @brief Destroys the layer: releases its cached textures and part sprite instancers, then runs
     * the task-node base destructor.
     *
     * The binary emits a non-deleting destructor body (@c 0x152e90) and a deleting variant
     * (@c 0x152f4c) that runs it then frees the object; both are this destructor.
     * @ghidraAddress 0x152e90
     * @ghidraAddress 0x152f4c
     */
    ~TitleLimelightScene() override;

    /**
     * @brief The per-frame task callback: dispatches on the layer state.
     *
     * State 0 loads the title resources and starts the BGM, state 1 waits for the start music,
     * state 2 renders and animates the title parts, and state 3 finishes and opens the music list.
     * @ghidraAddress 0x152f84
     */
    void OnFrame(int nElapsedMs) override;

private:
    /**
     * @brief Emits one title part sprite into its instancer slot, positioned and sized by kind.
     *
     * A no-op for an out-of-range kind or a full instancer. Kind 0 is the background: it binds the
     * instancer's texture and fills a full-texture quad. Every other kind reads the per-kind part
     * layout (the alt table when the alt flag at +0x49 is set, otherwise the main table) for its
     * anchor mode, position, size, and atlas frame — the atlas frame indexing one of three UV
     * tables by the layout's anchor mode. The interactive kinds (0x2b, 0x32, 0x34, 0x3e, 0x50)
     * additionally record their screen rectangle into the layer's hit-rect fields for the touch
     * tests. The sprite is tinted by the intro-fade complement (1 - the fade value) scaled by the
     * caller's alpha.
     * @param nKind The part kind, also the instancer index.
     * @param nColorAlpha The caller's alpha.
     * @param flTransformX The part's base transform X.
     * @param flTransformY The part's base transform Y.
     * @param flSize The part's uniform scale.
     * @param flRotation The part's rotation, in radians.
     * @ghidraAddress 0x1543fc
     */
    void RenderPartsElement(unsigned int nKind,
                            unsigned int nColorAlpha,
                            float flTransformX,
                            float flTransformY,
                            float flSize,
                            float flRotation);

    /**
     * @brief Emits the title screen's star-field particle burst for the given animation time.
     *
     * For each of the 35 burst particles it samples the particle's Y-position, alpha, and scale
     * animation curves at @p flTime, doubles the scale while the hidden-code flag is set, and emits
     * the particle (as part kind index + 5) at its fixed X column and sampled Y, scale, and alpha
     * through @c RenderPartsElement.
     * @param flTime The title animation time the curves are sampled at.
     * @ghidraAddress 0x15484c
     */
    void RenderParticleBurst(float flTime);

    /**
     * @brief Releases the cached textures and flags each owned part sprite instancer for the scene
     * walker to delete.
     * @ghidraAddress 0x152edc
     */
    void ReleaseResources();

    /**
     * @brief State 0: loads the title textures and part sprite instancers and starts the title BGM.
     * @ghidraAddress 0x152fc8
     */
    void LoadResources();

    /**
     * @brief State 1: waits for the start music, then advances to the render state.
     * @ghidraAddress 0x153190
     */
    void StartMusic();

    /**
     * @brief State 2: renders and animates the title parts for the frame, and reads the touches.
     *
     * Advances the animation clock (wrapping it back to the end of the intro), clears every part
     * instancer, and emits the whole title in program order: the backdrop, the rotated lead part,
     * the row of ten, the two groups of four, the singles, the ring of fifteen, the stacked trio,
     * the four sweeping parts, the three particle-burst windows, and the corner button with its own
     * one-second pulse. It then hit-tests a fresh touch against the five rectangles the part
     * emitter records -- start, shot-sound audition, the two hidden-code buttons, and the voice cue
     * -- and reads a tracked touch's net travel as a hidden-code flick. Taking the start prompt
     * seeds the leave fade; once that fade completes the layer advances to the finish state.
     * @param nElapsedMs The frame delta, in milliseconds, forwarded from the task callback.
     * @ghidraAddress 0x1531fc
     */
    void RenderFrame(int nElapsedMs);

    /**
     * @brief State 3: finishes the title screen and opens the music list.
     * @ghidraAddress 0x154288
     */
    void FinishAndOpenList();

    /**
     * @brief Advances the fade curve one frame toward its target value.
     *
     * While the elapsed time is below the duration, accumulates the frame delta and, once past the
     * start delay, sets the fade value by linearly interpolating from the start to the end value
     * over the remaining span. Past the duration, snaps the fade value to the end.
     * @param nDeltaFrames The elapsed frame count.
     * @ghidraAddress 0x154380
     */
    void AdvanceFadeValue(int nDeltaFrames);

    /**
     * @brief Advances the title screen's hidden-code input sequence by one flick or button.
     *
     * The sequence is the Konami code -- up, up, down, down, left, right, left, right, B, A -- and
     * each input only advances the state when it is the one the sequence expects next; anything
     * else either leaves the state alone or, for the two openers, restarts it. The final A fires
     * the secret sound effect, latches the hidden-code flag, and rewinds the animation clock.
     * @param nSwipeEvent The input: a flick direction, or one of the two buttons.
     * @ghidraAddress 0x1549b8
     */
    void AdvanceSwipeState(int nSwipeEvent);

    // The base's trailing bool ends at +0x4a, so +0x4b is the natural alignment padding before the
    // dispatch state.
    int m_nState = {};                               // +0x4c: the dispatch state.
    int m_nAnimationTime = {};                       // +0x50: the title animation clock, in
                                                     // milliseconds; wraps back to the end of the
                                                     // intro once it passes the loop end.
    int m_nReadyDelay = {};                          // +0x54: the start ready delay.
    ne::C_TEXTURE *m_apTextures[kTextureCount] = {}; // +0x58: the three title textures.
    ne::C_SPRITE_INSTANCING_2D *m_apSprites[kSpriteSlotCount] =
        {};                                    // +0x70: the part sprite instancers.
    int m_aSpriteCount[kSpriteSlotCount] = {}; // +0x308: each instancer's seed sprite count.
    // +0x454: a third per-slot array the constructor zeroes in the same loop as the instancer
    // pointers and the seed sprite counts. No routine in the class reads or writes it -- the
    // constructor's zeroing loop is its only access anywhere in the reconstructed cluster -- so its
    // role is recorded as unknown rather than guessed.
    int m_aSpriteSlotState[kSpriteSlotCount] = {}; // +0x454
    float m_flFadeStart = {};                      // +0x5a0: the fade curve's start value.
    float m_flFadeEnd = {};                        // +0x5a4: the fade curve's end value.
    float m_flFadeDuration = {};   // +0x5a8: the fade curve's duration, in milliseconds.
    float m_flFadeElapsed = {};    // +0x5ac: the fade curve's elapsed time.
    float m_flFadeStartDelay = {}; // +0x5b0: the delay before the fade curve begins.
    float m_flFadeValue = {};      // +0x5b4: the current fade value (seeded to 1.0).
    bool m_bLeaving = {};          // +0x5b8: set once the start prompt is taken; the frame then
                                   // stops accepting touches and only waits for the fade.
    // +0x5b9..+0x5bb is the natural alignment padding after the leaving flag.
    int m_nUnusedCounter = {};        // +0x5bc: zeroed by the constructor and never read or written
                                      // again anywhere in the class.
    float m_flCornerButtonClock = {}; // +0x5c0: the corner button's own one-second pulse clock,
                                      // advanced six times as fast while leaving.
    int m_nTrackedTouchId = {}; // +0x5c4: the touch being tracked for a flick (-1 when none is).
    int m_nSwipeState = {};     // +0x5c8: the hidden-code (Konami) input sequence's progress.
    bool m_bSecretActive = {};  // +0x5cc: the hidden-code flag; doubles the burst scale.
    // +0x5cd..+0x5cf is the natural alignment padding before the cached viewport size.
    float m_flViewportWidth = {};  // +0x5d0: the viewport width cached each frame; the part emitter
                                   // halves it into the part layout's screen X origin.
    float m_flViewportHeight = {}; // +0x5d4: the viewport height, used the same way.
    // +0x5d8: the five touch hit-rectangles the part emitter records for the interactive parts,
    // read by the title touch tests. Each is {x, y, width, height}.
    HitRect m_aHitRects[kHitRectCount] = {}; // +0x5d8
};

} // namespace rb

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
