/**
 * @file
 * The theme-0 title-screen scene layer, @c TitleClassicScene.
 */

#pragma once

#include "basescene.h"
#include "linear_tween.h"
#include "s_vector2.h"

namespace ne {
class C_TEXTURE;
class C_SPRITE_INSTANCING_2D;
} // namespace ne

/**
 * @brief The theme-0 (Classic) title-screen scene layer: the animated title/logo screen shown
 * before the music list.
 *
 * A @c rb::BaseScene-derived per-frame task created by @c CreateTitleLayerForTheme for theme 0. Its
 * per-frame callback is a small state machine (@c DispatchTitleScreenState): load the title
 * textures and sprites and start the BGM, wait for the start music, render and animate the title,
 * then finish and open the music list. The Ghidra name @c ScoreGaugeLayer for its constructor is a
 * misnomer; the vtable's methods are all title-screen routines. This is a distinct, smaller
 * (0x168-byte) class from the boot logo scene @c rb::LogoScene. The trailing @c
 * // +0xNN comments document the original member offsets for reference only; the spans whose roles
 * are still being worked out are reserved to preserve the object layout.
 * @ghidraAddress TitleClassicScene (engine layer, 0x168 bytes)
 */
namespace rb {

class TitleClassicScene : public BaseScene {
public:
    // The number of cached title textures and the number of sprite instancers the layer builds.
    static constexpr int kTextureCount = 7;
    static constexpr int kSpriteSlotCount = 8;
    // The number of scrolling star layers and counter-rotating rings the title animates.
    static constexpr int kStarLayerCount = 2;
    static constexpr int kRingCount = 2;

    /**
     * @brief Constructs the layer: chains the UI-layer base, installs the title dispatch table, and
     * zero-clears the presentation state (seeding the fade base to 1.0 and the trailing index to
     * -1).
     * @ghidraAddress 0x1514b4
     */
    TitleClassicScene();

    /**
     * @brief Destroys the layer: releases its cached textures and sprite instancers, then runs the
     * task-node base destructor.
     *
     * The binary emits a non-deleting destructor body (@c 0x151580) and a deleting variant
     * (@c 0x151640) that runs it then frees the object; both are this destructor.
     * @ghidraAddress 0x151580
     * @ghidraAddress 0x151640
     */
    ~TitleClassicScene() override;

    /**
     * @brief The per-frame task callback: dispatches on the layer state.
     *
     * State 0 loads the title resources and starts the BGM, state 1 waits for the start music,
     * state 2 renders and animates the title, and state 3 finishes and opens the music list.
     * @ghidraAddress 0x151678
     */
    void OnFrame(int nElapsedMs) override;

private:
    /**
     * @brief Releases the cached textures and flags each owned sprite instancer for the scene
     * walker to delete.
     * @ghidraAddress 0x1515cc
     */
    void ReleaseResources();

    /**
     * @brief State 0: loads the title textures and sprite instancers and starts the title BGM.
     * @ghidraAddress 0x1516bc
     */
    void LoadResources();

    /**
     * @brief State 1: waits for the start music, then advances to the render state.
     * @ghidraAddress 0x1518c8
     */
    void StartMusic();

    /**
     * @brief State 2: renders and animates the title screen for the frame.
     *
     * Clears the eight instancers, ticks the start-prompt, star, and ring clocks, emits the whole
     * title screen (background, start prompt, two scrolling star layers, two counter-rotating
     * rings, the logo, and the black fade overlay), then — once the start delay has elapsed — runs
     * the touch input pass: the start hit-box commits to the music list, the two secret hit-boxes
     * and the four-way swipe classifier drive the hidden sequence, and the remaining hit-box
     * auditions the shot sound.
     * @param nElapsedMs The frame delta, in milliseconds, forwarded from the task callback.
     * @ghidraAddress 0x151934
     */
    void RenderFrame(int nElapsedMs);

    /**
     * @brief State 3: finishes the title screen and opens the music list.
     * @ghidraAddress 0x152450
     */
    void FinishAndOpenList();

    /**
     * @brief Advances the title fade tween by @p nDeltaFrames.
     * @param nDeltaFrames The elapsed frames this tick.
     * @ghidraAddress 0x152548
     */
    void AdvanceFadeValue(int nDeltaFrames);

    /**
     * @brief Advances the hidden-swipe sequence on a directional swipe or secret-button tap, firing
     * the secret sound effect and latching the completion flag when the sequence completes.
     * @param iSwipeEvent The swipe or button event id.
     * @ghidraAddress 0x152cc8
     */
    void AdvanceSwipeState(int iSwipeEvent);

    /**
     * @brief Emits a full-texture quad (such as the background) into a title sprite instancer slot.
     *
     * Resolves the instancer for the sprite kind and, while it has room, derives the quad's anchor,
     * size, and UV span from the bound texture's image size, allocated size, and retina scale, then
     * writes the caller's position, size scale, rotation, and an opaque-white colour modulated by
     * the alpha, and bumps the slot count.
     * @param nSpriteKind The sprite kind (below 9), selecting the instancer.
     * @param nColorAlpha The quad's alpha.
     * @param position The quad's screen position.
     * @param flSize The uniform size scale.
     * @param flRotation The quad's rotation, in radians.
     * @ghidraAddress 0x152a90
     */
    void RenderTitleBackgroundFullQuad(unsigned int nSpriteKind,
                                       unsigned int nColorAlpha,
                                       S_VECTOR2 position,
                                       float flSize,
                                       float flRotation);

    /**
     * @brief Emits one title-screen sprite into its instancer slot.
     *
     * Sprite kind 0 draws a full-texture quad (as @c RenderTitleBackgroundFullQuad does). Kinds 1
     * through 8 take their anchor, size, and UV rectangle from the per-kind title layout table for
     * the current frame variant (the alt-frame table when the alt frame is active, otherwise the
     * main-frame table). Either way the caller's position, uniform size scale, rotation, and an
     * opaque-white colour modulated by the alpha are applied, and the slot count is bumped. A no-op
     * for an out-of-range kind or a full instancer.
     * @param nSpriteKind The sprite kind (0 through 8), selecting the instancer and layout.
     * @param nColorAlpha The sprite's alpha.
     * @param position The sprite's screen position.
     * @param flSize The uniform size scale.
     * @param flRotation The sprite's rotation, in radians.
     * @ghidraAddress 0x15259c
     */
    void EmitTitleSprite(unsigned int nSpriteKind,
                         unsigned int nColorAlpha,
                         S_VECTOR2 position,
                         float flSize,
                         float flRotation);

    /**
     * @brief Emits a plain coloured quad (no atlas lookup) into a title sprite instancer slot.
     *
     * Resolves the instancer for the quad kind and, while it has room, writes the caller's
     * position, size, and anchor with a solid grey-scale tint modulated by the alpha, then bumps
     * the slot count. A no-op for an out-of-range kind or a full instancer. The title screen uses
     * it for the untextured black overlay that fades the screen out.
     * @param nKind The colour-quad kind (0 through 8), selecting the instancer.
     * @param nColorRgb The quad's red, green, and blue channel value.
     * @param nAlpha The quad's alpha.
     * @param position The quad's screen position.
     * @param size The quad's size.
     * @param anchor The quad's anchor.
     * @ghidraAddress 0x152bfc
     */
    void EmitTitleColorQuad(unsigned int nKind,
                            unsigned int nColorRgb,
                            unsigned int nAlpha,
                            S_VECTOR2 position,
                            S_VECTOR2 size,
                            S_VECTOR2 anchor);

    // unsigned char m_aReserved4b[1] = {};             // +0x4b
    int m_nState = {};                               // +0x4c: the dispatch state.
    int m_nFadeTimer = {};                           // +0x50: the fade/ready timer.
    int m_nReadyDelay = {};                          // +0x54: the start ready delay.
    ne::C_TEXTURE *m_apTextures[kTextureCount] = {}; // +0x58: the seven title textures.
    ne::C_SPRITE_INSTANCING_2D *m_apSprites[kSpriteSlotCount] = {}; // +0x90: the sprite instancers.
    int m_aSpriteCount[kSpriteSlotCount] = {}; // +0xd0: each instancer's live sprite count.
    // +0xf0..+0x10f: further per-slot presentation state, still being worked out.
    // unsigned char m_aReserved0f0[0x20] = {}; // +0xf0
    LinearTween m_fadeChannel;      // +0x110: the title fade tween.
    float m_flStartDelayClock = {}; // +0x124: counts up until input is accepted.
    bool m_bLeaving = {};           // +0x128: latched once the player commits to starting.
    // unsigned char m_aReserved129[3] = {};    // +0x129
    float m_flPromptFadeClock = {};  // +0x12c: the start prompt's one-shot fade-in clock.
    float m_flPromptPulseClock = {}; // +0x130: the start prompt's repeating pulse clock.
    int m_anStarScrollClock[kStarLayerCount] = {};  // +0x134: each star layer's scroll clock.
    int m_anStarTwinkleClock[kStarLayerCount] = {}; // +0x13c: each star layer's twinkle clock.
    int m_anRingScaleClock[kRingCount] = {};        // +0x144: each ring's scale-sweep clock.
    int m_anRingSpinClock[kRingCount] = {};         // +0x14c: each ring's rotation clock.
    int m_anRingAlphaClock[kRingCount] = {};        // +0x154: each ring's alpha-curve clock.
    int m_nTrackedTouchId = {};  // +0x15c: the touch being followed for a swipe (-1 when none).
    int m_nSwipeState = {};      // +0x160: the hidden-swipe sequence step.
    bool m_bSwipeTriggered = {}; // +0x164: latched once the hidden sequence completes; also drives
                                 //         the five-times animation speed-up.
    // unsigned char m_aReserved165[3] = {}; // +0x165
};

} // namespace rb

/**
 * @brief The capacity (maximum sprite count) of each of the eight title-screen sprite instancers.
 * @ghidraAddress 0x309454
 */
extern const unsigned int g_aTitleSpriteCapacity[rb::TitleClassicScene::kSpriteSlotCount];

/**
 * @brief The cached-texture index each of the eight title-screen instancers binds (slot 7 binds
 * none).
 * @ghidraAddress 0x309384
 */
extern const unsigned int g_aTitleSpriteTextureIndex[rb::TitleClassicScene::kSpriteSlotCount];

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
