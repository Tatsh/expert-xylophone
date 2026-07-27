/**
 * @file
 * The parts-based title-screen scene layer, @c TitleLimelightScene.
 */

#pragma once

#include "base_scene.h"

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
 * member offsets for reference only; the spans whose roles are still being worked out are reserved to
 * preserve the object layout.
 * @ghidraAddress TitleLimelightScene (engine layer, 0x628 bytes)
 */
namespace rb {

class TitleLimelightScene : public BaseScene {
public:
    // The number of cached title textures and the number of part sprite instancers the layer builds.
    static constexpr int kTextureCount = 3;
    static constexpr int kSpriteSlotCount = 0x53;

    /**
     * @brief Constructs the layer: chains the UI-layer base, installs the title dispatch table, and
     * zero-clears the presentation state (seeding the fade value to 1.0 and the trailing index to -1).
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
     * State 0 loads the title resources and starts the BGM, state 1 waits for the start music, state
     * 2 renders and animates the title parts, and state 3 finishes and opens the music list.
     * @ghidraAddress 0x152f84
     */
    void OnFrame(void *pFrameArg) override;

private:
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
     * @brief State 2: renders and animates the title parts for the frame.
     * @param pFrameArg The per-frame argument forwarded from the task callback (a frame-delta count).
     * @ghidraAddress 0x1531fc
     */
    void RenderFrame(void *pFrameArg);

    /**
     * @brief State 3: finishes the title screen and opens the music list.
     * @ghidraAddress 0x154288
     */
    void FinishAndOpenList();

    unsigned char m_aReserved4b[1] = {};             // +0x4b
    int m_nState = {};                               // +0x4c: the dispatch state.
    int m_nFadeTimer = {};                           // +0x50: the fade/ready timer.
    int m_nReadyDelay = {};                          // +0x54: the start ready delay.
    ne::C_TEXTURE *m_apTextures[kTextureCount] = {}; // +0x58: the three title textures.
    ne::C_SPRITE_INSTANCING_2D *m_apSprites[kSpriteSlotCount] =
        {};                                    // +0x70: the part sprite instancers.
    int m_aSpriteCount[kSpriteSlotCount] = {}; // +0x308: each instancer's live sprite count.
    // +0x454..+0x59f: further per-part presentation state, still being worked out.
    unsigned char m_aReserved454[0x14c] = {}; // +0x454
    float m_flFadeStart = {};                 // +0x5a0: the fade curve's start value.
    float m_flFadeEnd = {};                   // +0x5a4: the fade curve's end value.
    float m_flFadeDuration = {};              // +0x5a8: the fade curve's duration, in milliseconds.
    float m_flFadeElapsed = {};               // +0x5ac: the fade curve's elapsed time.
    unsigned char m_aReserved5b0[4] = {};     // +0x5b0: the fade start delay.
    float m_flFadeValue = {};                 // +0x5b4: the current fade value (seeded to 1.0).
    unsigned char m_aReserved5b8[0xc] = {};   // +0x5b8: trailing presentation state.
    int m_nTrailingIndex = {};               // +0x5c4: a per-slot index (-1 when none is selected).
    unsigned char m_aReserved5c8[0x60] = {}; // +0x5c8: trailing presentation state.
};

} // namespace rb

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
