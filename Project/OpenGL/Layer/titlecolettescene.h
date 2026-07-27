/**
 * @file
 * The theme-2 (Colette) parts-based title-screen scene, @c rb::TitleColetteScene.
 */

#pragma once

#include "basescene.h"
#include "s_vector2.h"

#ifdef __OBJC__
@class SePlayer;
#else
typedef struct objc_object SePlayer;
#endif

namespace ne {
class C_TEXTURE;
class C_SPRITE_INSTANCING_2D;
} // namespace ne

namespace rb {

/**
 * @brief The theme-2 (Colette) title-screen scene: the campaign parts-based title shown before the
 * music list.
 *
 * A @c rb::BaseScene-derived per-frame task created by @c CreateTitleLayerForTheme for theme 2. Its
 * per-frame callback is a small state machine (@c OnFrame): load the campaign textures, part
 * sprites, title BGM, and theme sound-effect player; start the BGM; scroll and animate the parts and
 * handle input; then finish and open the music list. It is the largest title scene (0x898 bytes),
 * drawing the title from 104 part sprites plus a campaign-portrait layer. The Ghidra name
 * @c TitleScreenLayer for this class is a misnomer; its RTTI type_info is @c rb::TitleColetteScene.
 * The trailing @c // +0xNN comments document the original member offsets for reference only; the
 * spans whose roles are still being worked out are reserved to preserve the object layout.
 * @ghidraAddress TitleColetteScene (engine scene, 0x898 bytes)
 */
class TitleColetteScene : public BaseScene {
public:
    // The number of cached title textures and the number of part sprite instancers the scene builds.
    static constexpr int kTextureCount = 4;
    static constexpr int kSpriteSlotCount = 0x68;
    // The number of part anchor positions in the ring the title arranges its parts around.
    static constexpr int kPartAnchorCount = 12;

    /**
     * @brief Constructs the scene: chains the scene base, installs the title dispatch table, and
     * zero-clears the presentation state (seeding the fade base to 1.0, the trailing index to -1,
     * the tint to opaque white, and copying the part-layout table into the per-sprite state).
     * @ghidraAddress 0x572e4
     */
    TitleColetteScene();

    /**
     * @brief Destroys the scene: releases its cached textures, part sprites, and sound-effect player,
     * then runs the task-node base destructor.
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
     * @ghidraAddress 0x57514
     */
    void OnFrame(void *pFrameArg) override;

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
     * @param pFrameArg The per-frame argument forwarded from the task callback (a frame-delta count).
     * @ghidraAddress 0x57ad8
     */
    void RunMainLoop(void *pFrameArg);

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

    unsigned char m_aReserved4b[1] = {}; // +0x4b
    int m_nState = {};                   // +0x4c: the dispatch state.
    unsigned char m_aReserved50[4] = {}; // +0x50
    int m_nFadeTimer = {};               // +0x54: the fade/scroll timer, reset on load.
    int m_nReadyDelay = {};              // +0x58: the start ready-delay timer (seeded to 0x708).
    int m_nScrollTimer = {};             // +0x5c: a second scroll timer, reset on load.
    unsigned char m_aReserved60[8] = {}; // +0x60
    ne::C_TEXTURE *m_apTextures[kTextureCount] = {}; // +0x68: bg, parts, parts_eff, and campaign.
    ne::C_SPRITE_INSTANCING_2D *m_apSprites[kSpriteSlotCount] = {}; // +0x88: the 104 part sprites.
    int m_aSpriteCount[kSpriteSlotCount] = {}; // +0x3c8: each instancer's seeded sprite count.
    // +0x568..+0x707: further per-sprite presentation state, still being worked out.
    unsigned char m_aReserved568[0x1a0] = {}; // +0x568
    float m_aFadeTransform[4] = {};           // +0x708: the fade transform (copied from the base).
    unsigned char m_aReserved718[4] = {};     // +0x718
    float m_flFadeBase = {};                  // +0x71c: the fully-shown fade level (seeded to 1.0).
    unsigned char m_aReserved720[0xc] = {};   // +0x720
    int m_nTrailingIndex = {};               // +0x72c: a per-slot index (-1 when none is selected).
    unsigned char m_aReserved730[0x11] = {}; // +0x730
    bool m_bSeTriggered = {};                // +0x741: whether the title sound effect has fired.
    // +0x742..+0x7cb is trailing presentation state whose roles are still being worked out.
    unsigned char m_aReserved742[0x8a] = {};        // +0x742
    S_VECTOR2 m_aPartAnchor[kPartAnchorCount] = {}; // +0x7cc: the ring of part anchor positions,
    // copied from the campaign anchor table at set-up.
    // +0x82c..+0x88f is further trailing state.
    unsigned char m_aReserved82c[0x64] = {}; // +0x82c
    SePlayer *m_pSePlayer = {};              // +0x890: the theme sound-effect player.
};

/**
 * @brief The 104-entry per-sprite part-layout table selecting each part's texture and z-order.
 *
 * Two variants live in the binary's read-only data: the default table and the alternate (iPad)
 * table. A layout entry's texture index of 5 marks a sprite that binds no texture.
 * @ghidraAddress 0x2f8f80
 * @ghidraAddress 0x2f85c0
 */
extern const unsigned int g_aTitleCampaignLayoutDefault[];
extern const unsigned int g_aTitleCampaignLayoutAltFrame[];

/**
 * @brief The ring of twelve part anchor positions the title arranges its campaign parts around.
 *
 * Copied into the scene's @c m_aPartAnchor at construction.
 * @ghidraAddress 0x2fc2c0
 */
extern const S_VECTOR2 g_aTitleCampaignPartAnchor[];

} // namespace rb

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
