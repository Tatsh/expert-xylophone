/**
 * @file
 * The theme-0 title-screen scene layer, @c TitleClassicScene.
 */

#pragma once

#include "base_scene.h"
#include "linear_tween.h"

namespace ne {
class C_TEXTURE;
class C_SPRITE_INSTANCING;
} // namespace ne

/**
 * @brief The theme-0 (Classic) title-screen scene layer: the animated title/logo screen shown before
 * the music list.
 *
 * A @c rb::BaseScene-derived per-frame task created by @c CreateTitleLayerForTheme for theme 0. Its
 * per-frame callback is a small state machine (@c DispatchTitleScreenState): load the title textures
 * and sprites and start the BGM, wait for the start music, render and animate the title, then finish
 * and open the music list. The Ghidra name @c ScoreGaugeLayer for its constructor is a misnomer; the
 * vtable's methods are all title-screen routines. This is a distinct, smaller (0x168-byte) class from
 * the interactive @c TitleScreenLayerClassic gesture layer. The trailing @c // +0xNN comments
 * document the original member offsets for reference only; the spans whose roles are still being
 * worked out are reserved to preserve the object layout.
 * @ghidraAddress TitleClassicScene (engine layer, 0x168 bytes)
 */
namespace rb {

class TitleClassicScene : public BaseScene {
public:
    // The number of cached title textures and the number of sprite instancers the layer builds.
    static constexpr int kTextureCount = 7;
    static constexpr int kSpriteSlotCount = 8;

    /**
     * @brief Constructs the layer: chains the UI-layer base, installs the title dispatch table, and
     * zero-clears the presentation state (seeding the fade base to 1.0 and the trailing index to -1).
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
     * State 0 loads the title resources and starts the BGM, state 1 waits for the start music, state
     * 2 renders and animates the title, and state 3 finishes and opens the music list.
     * @ghidraAddress 0x151678
     */
    void OnFrame(void *pFrameArg) override;

private:
    /**
     * @brief Releases the cached textures and flags each owned sprite instancer for the scene walker
     * to delete.
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
     * @param pFrameArg The per-frame argument forwarded from the task callback (a frame-delta count).
     * @ghidraAddress 0x151934
     */
    void RenderFrame(void *pFrameArg);

    /**
     * @brief State 3: finishes the title screen and opens the music list.
     * @ghidraAddress 0x152450
     */
    void FinishAndOpenList();

    unsigned char m_aReserved4b[1] = {};                         // +0x4b
    int m_nState = {};                                           // +0x4c: the dispatch state.
    int m_nFadeTimer = {};                                       // +0x50: the fade/ready timer.
    int m_nReadyDelay = {};                                      // +0x54: the start ready delay.
    ne::C_TEXTURE *m_apTextures[kTextureCount] = {};             // +0x58: the seven title textures.
    ne::C_SPRITE_INSTANCING *m_apSprites[kSpriteSlotCount] = {}; // +0x90: the sprite instancers.
    int m_aSpriteCount[kSpriteSlotCount] = {}; // +0xd0: each instancer's live sprite count.
    // +0xf0..+0x10f: further per-slot presentation state, still being worked out.
    unsigned char m_aReserved0f0[0x20] = {}; // +0xf0
    LinearTween m_fadeChannel;               // +0x110: the title fade tween.
    unsigned char m_aReserved124[0x38] = {}; // +0x124: trailing state.
    int m_nTrailingIndex = {};               // +0x15c: a per-slot index (-1 when
                                             //         none is selected).
    unsigned char m_aReserved160[0x08] = {}; // +0x160: trailing state.
};

} // namespace rb

/**
 * @brief The capacity (maximum sprite count) of each of the eight title-screen sprite instancers.
 * @ghidraAddress 0x309454
 */
extern const unsigned int g_aTitleSpriteCapacity[rb::TitleClassicScene::kSpriteSlotCount];

/**
 * @brief The cached-texture index each of the eight title-screen instancers binds (slot 7 binds none).
 * @ghidraAddress 0x309384
 */
extern const unsigned int g_aTitleSpriteTextureIndex[rb::TitleClassicScene::kSpriteSlotCount];

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
