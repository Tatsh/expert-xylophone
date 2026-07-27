/**
 * @file
 * The theme-2 (Colette) parts-based title-screen scene, @c rb::TitleColetteScene.
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
    float x = {};      // +0x00: the left edge.
    float y = {};      // +0x04: the top edge.
    float width = {};  // +0x08: the horizontal extent.
    float height = {}; // +0x0c: the vertical extent.
};

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
    // The number of floats in the fade transform seeded at load.
    static constexpr int kFadeTransformCount = 5;
    // The number of touchable part hit-box rectangles the emitter records.
    static constexpr int kHitBoxCount = 8;

    /**
     * @brief Constructs the scene: chains the scene base, installs the title dispatch table, and
     * zero-clears the presentation state (seeding the fade base to 1.0 and the trailing index to -1,
     * and copying the part anchor ring into the per-sprite state).
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

    /**
     * @brief Emits one title part's sprite into its instancer slot and records its hit-box rect.
     *
     * Appends one quad to part @p nPartId's sprite instancer (doing nothing once the instancer is
     * full). The background part (id 0) fills the screen from its texture; the other parts take their
     * placement from the platform layout table and their UV rectangle from the type-specific atlas
     * table, recentring the landscape layout around the viewport. The colour is the passed tint faded
     * out by the scene's fade level, and the lettered/logo parts whose ids gate a touch also store
     * their anchor rectangle into the layer's hit-box table.
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

    // Records a touchable part's hit-box (its draw position offset by the layout anchor, sized by the
    // layout extent) into the layer's hit-box table. The sound-effect part in the landscape layout
    // uses a nudged and grown rectangle. Parts without a hit-box are ignored.
    void RecordPartHitBox(unsigned int nPartId,
                          const S_VECTOR2 &drawPosition,
                          const TitlePartLayoutRecord &layout);

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
    // +0x708: the fade transform seeded at load: the fade base followed by a fixed drop-in offset
    // (element 2 is 300, the rest zero).
    float m_aFadeTransform[kFadeTransformCount] = {}; // +0x708
    float m_flFadeBase = {};                 // +0x71c: the fully-shown fade level (seeded to 1.0).
    unsigned char m_aReserved720[0xc] = {};  // +0x720
    int m_nTrailingIndex = {};               // +0x72c: a per-slot index (-1 when none is selected).
    unsigned char m_aReserved730[0x11] = {}; // +0x730
    bool m_bSeTriggered = {};                // +0x741: whether the title sound effect has fired.
    unsigned char m_aReserved742[2] = {};    // +0x742
    float m_flViewportWidth = {};  // +0x744: the viewport width, cached from the game system.
    float m_flViewportHeight = {}; // +0x748: the viewport height.
    // +0x74c: the eight part hit-box rectangles the emitter records for touch testing (the corporate
    // logo, the lettered parts, and the sound-effect part).
    TitleHitRect m_aHitBox[kHitBoxCount] = {};      // +0x74c
    S_VECTOR2 m_aPartAnchor[kPartAnchorCount] = {}; // +0x7cc: the ring of part anchor positions,
    // copied from the campaign anchor table at set-up.
    // +0x82c..+0x88f is further trailing state.
    unsigned char m_aReserved82c[0x64] = {}; // +0x82c
    SePlayer *m_pSePlayer = {};              // +0x890: the theme sound-effect player.
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
 * logo (type 3) parts each have a phone and an iPad table.
 * @ghidraAddress 0x2f7908
 */
extern const SpriteUvEntry g_aTitlePartUvDefault[];
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

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
