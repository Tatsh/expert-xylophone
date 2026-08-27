/**
 * @file
 * The pause-gauge play-field layer, @c PauseGaugeLayer.
 */

#pragma once

#include "basescene.h"
#include "s_vector2.h"

namespace ne {
class C_SPRITE_INSTANCING_2D;
class C_TEXTURE;
} // namespace ne

/**
 * @brief One pause-gauge rectangle size: the width and height of a lane's gauge hit rectangle.
 */
struct PauseGaugeRectSize {
    int nWidth = {};  /*!< The rectangle width. +0x00 */
    int nHeight = {}; /*!< The rectangle height. +0x04 */
};

/**
 * @brief One pause-gauge sprite layout record: the sprite's anchor, size, and UV-table index.
 *
 * A 28-byte read-only record; the emitter reads the anchor, size, and UV index from it. The
 * trailing
 * @c // +0xNN comments document the byte offsets.
 */
struct PauseGaugeSpriteLayout {
    float flOffsetX = {}; /*!< The menu-item x offset from the viewport centre. +0x00 */
    float flOffsetY = {}; /*!< The menu-item y offset from the viewport centre. +0x04 */
    float flAnchorX = {}; /*!< The sprite anchor x. +0x08 */
    float flAnchorY = {}; /*!< The sprite anchor y. +0x0c */
    float flSizeW = {};   /*!< The sprite size width. +0x10 */
    float flSizeH = {};   /*!< The sprite size height. +0x14 */
    int nUvIndex = {};    /*!< The index into the UV table. +0x18 */
};

/**
 * @brief One lane's pause-gauge geometry: the gauge-rectangle centre and its dimmed-lane flag.
 *
 * The trailing @c // +0xNN comments document the byte offsets within the 16-byte per-lane entry.
 */
struct PauseGaugeLaneGeometry {
    float flCenterX = {}; /*!< The gauge rectangle's centre x. +0x00 */
    float flCenterY = {}; /*!< The gauge rectangle's centre y. +0x04 */
    // unsigned char aReserved08[4] = {}; /*!< Further per-lane state, not yet identified. +0x08 */
    bool bDimmed = {}; /*!< Whether the lane's gauge is drawn dimmed. +0x0c */
    // unsigned char aReserved0d[3] = {}; /*!< Trailing padding to the 16-byte entry. +0x0d */
};

/**
 * @brief The pause-gauge layer: the per-lane gauge shown while the game is paused.
 *
 * A @c rb::BaseScene subclass registered as a per-frame task. It owns two sprite instancers and a
 * parts texture, and charges a per-lane gauge while the game is held paused. The trailing
 * @c // +0xNN comments document the original member offsets for reference only.
 */
class PauseGaugeLayer : public rb::BaseScene {
public:
    /** @brief The per-lane gauge geometry record the layer stores one of per lane. */
    using LaneGeometry = PauseGaugeLaneGeometry;

    /** @brief The number of sprite slots: a gauge slot and a parts slot. */
    static constexpr int kSlotCount = 2;
    /** @brief The number of lane-slot ids. */
    static constexpr int kLaneSlotCount = 13;
    /** @brief The number of lanes the gauge draws a rectangle for. */
    static constexpr int kLaneCount = 3;

    /**
     * @brief Constructs the pause-gauge layer: chains the UI-layer base, installs the task dispatch
     * table, clears the state and charging flag, seeds the active-lane mask, distributes the
     * per-lane sprite-slot ids from the lane-group table, and loads the sprites.
     * @ghidraAddress 0x1508b4
     */
    PauseGaugeLayer();

    /**
     * @brief Destroys the layer: releases the parts atlas and flags each owned sprite instancer for
     * the scene walker to delete.
     *
     * The binary emits a non-deleting destructor body (@c 0x150a7c) and a deleting variant
     * (@c 0x150b00) that runs it then frees the object; both are this destructor.
     * @ghidraAddress 0x150a7c
     * @ghidraAddress 0x150b00
     */
    ~PauseGaugeLayer() override;

    /**
     * @brief Marks the gauge as charging on first entry, playing the charge-start sound effect.
     *
     * A no-op when it is already charging.
     * @ghidraAddress 0x150e58
     */
    void SetCharging();

    /**
     * @brief Clears the charging flag, returning the gauge to its unpaused state.
     * @ghidraAddress 0x150e84
     */
    void ClearCharging();

    /**
     * @brief Hit-tests a point against a lane's pause-gauge rectangle.
     *
     * The rectangle is centred on the lane's geometry centre, sized from the per-device size table
     * (the iPad uses the variant table, otherwise the default), with the width and
     * height applied as round-toward-zero half-extents.
     * @param flX The point x.
     * @param flY The point y.
     * @param nLaneIndex The lane to test.
     * @return @c true when the point lies within the lane's gauge rectangle.
     * @ghidraAddress 0x1512fc
     */
    bool CheckPointInRect(float flX, float flY, unsigned int nLaneIndex) const;

    /**
     * @brief Emits the pause-gauge sprites for one lane (0 to 2).
     *
     * The dimmed lanes draw at half alpha; on the main frame with a non-Colette theme the gauge is
     * drawn as a left arrow, a right arrow, and a centre element, otherwise as a single sprite. The
     * Limelight and Colette themes additionally dim the 2P lane when no pastel bonus is active.
     * @param nLaneIndex The lane to render.
     * @ghidraAddress 0x151000
     */
    void RenderForLane(unsigned int nLaneIndex);

    /**
     * @brief Opens the pause menu when the gauge is fully charged.
     *
     * Resets each instancer's sprite count, and when the gauge has charged, resets the menu
     * selection state, clears the per-lane selection flags, and runs the pause-scene show step.
     * @ghidraAddress 0x150ba8
     */
    void ShowPauseMenu();

    /**
     * @brief The pause-menu Exit action: leaves the song and returns to the menu.
     *
     * The Limelight and Colette themes refuse to exit while a pastel-bonus (two-player) session is
     * active; otherwise the active scene enters its pause-exit state and the confirm sound plays.
     * @ghidraAddress 0x1513c4
     */
    void HandleExit();

    /**
     * @brief The pause-menu Resume action: resumes play when a scene is active and plays the
     * confirm sound effect.
     * @ghidraAddress 0x15139c
     */
    static void HandleResume();

    /**
     * @brief The pause-menu Retry/Release action: transitions the active scene into its
     * music-release state and plays the confirm sound effect.
     * @ghidraAddress 0x151434
     */
    static void HandleMusicRelease();

    /**
     * @brief The pause-scene per-frame show step: lays out the menu items, updates the touch-drag
     * selection, and re-emits the gauge sprites.
     *
     * A large touch-driven routine; declared here so ShowPauseMenu can run it. Reconstruction
     * pending. The class's embedded @c __FILE__ is @c OpenGL/Scene/pause_scene.mm.
     * @ghidraAddress 0x150bfc
     */
    void ExecShow();

    /**
     * @brief The pause-scene state-machine step: dispatches on the layer state.
     *
     * State 0 loads the sprites, state 1 opens the pause menu, state 2 runs the per-frame show
     * step, and state 3 flags the layer dead so the next dispatch destroys it.
     *
     * This is the class's per-frame task callback: it occupies the task node's virtual slot in the
     * binary's vtable, so the listener dispatch runs the state machine every frame. It ignores the
     * frame delta.
     * @param nElapsedMs The frame delta, in milliseconds, which this override ignores.
     * @ghidraAddress 0x150b38
     */
    void OnFrame(int nElapsedMs) override;

private:
    /**
     * @brief Loads the pause-gauge parts atlas and builds one sprite instancer per slot for the
     * current theme.
     * @ghidraAddress 0x150994
     */
    void LoadSprites();

    /**
     * @brief Emits one gauge sprite into the next free slot of its lane's instancer.
     *
     * Reads the sprite's anchor, size, and UV from the layout and UV tables (the size for slot 0
     * comes from the game-system viewport instead), and writes the position, colour, and horizontal
     * flip through the instancer. A no-op when the slot index is out of range or the instancer is
     * full.
     * @param flFlip The horizontal flip/scale factor.
     * @param nSlotIndex The layout-table slot index (below 13).
     * @param position The sprite position.
     * @param nColorRgb The packed RGB colour (the same value fills all three channels).
     * @param nAlpha The sprite alpha.
     * @ghidraAddress 0x150e8c
     */
    void EmitSprite(float flFlip,
                    unsigned int nSlotIndex,
                    const S_VECTOR2 &position,
                    unsigned int nColorRgb,
                    unsigned int nAlpha);

    int m_nState = {};              // +0x4c: the layer's build/render state.
    ne::C_TEXTURE *m_pTexture = {}; // +0x50: the pause-gauge parts atlas.
    ne::C_SPRITE_INSTANCING_2D *m_apSprites[kSlotCount] =
        {};                                 // +0x58: the gauge and parts instancers.
    int m_aSlotCapacity[kSlotCount] = {};   // +0x68: each slot's sprite capacity.
    int m_aLaneSlotId[kLaneSlotCount] = {}; // +0x70: the per-lane sprite-slot index.
    bool m_bCharging = {};                  // +0xa4: whether the gauge is charging.
    int m_nSelectedTouchId = {}; // +0xa8: the id of the touch dragging a menu item (-1 when none).
    int m_nSelectedLane = {};    // +0xac: the selected menu lane (4 when none is selected).
    LaneGeometry m_aLaneGeometry[kLaneCount] = {}; // +0xb0: the per-lane gauge centre and flag.
    int m_nThema = {};                             // +0xe0: the cached UI theme.
};

/**
 * @brief The per-lane gauge rectangle sizes the iPad uses.
 *
 * Seeded at startup from the read-only source constants. Every other device uses
 * @c g_aPauseGaugeRectDefault instead.
 * @ghidraAddress 0x3dbe90
 */
extern PauseGaugeRectSize g_aPauseGaugeRectVariant[PauseGaugeLayer::kLaneCount];
/**
 * @brief The per-lane gauge rectangle sizes every device other than the iPad uses.
 *
 * Seeded at startup from the read-only source constants, alongside @c g_aPauseGaugeRectVariant.
 * @ghidraAddress 0x3dbeb0
 */
extern PauseGaugeRectSize g_aPauseGaugeRectDefault[PauseGaugeLayer::kLaneCount];

/**
 * @brief The default device's pause-gauge sprite layout table (up to 13 records).
 *
 * Read-only render configuration embedded in the binary.
 * @ghidraAddress 0x308fe0
 */
extern const PauseGaugeSpriteLayout g_aPauseGaugeLayoutDefault[];
/**
 * @brief The alt-frame device's pause-gauge sprite layout table (up to 13 records).
 *
 * Read-only render configuration embedded in the binary.
 * @ghidraAddress 0x308e74
 */
extern const PauseGaugeSpriteLayout g_aPauseGaugeLayoutAltFrame[];

/**
 * @brief Seeds the per-lane pause-gauge rectangle size tables (both device layouts) at startup.
 *
 * Run by dyld at image load through the binary's @c __mod_init_func table; nothing calls it by
 * name.
 *
 * @ghidraAddress 0x15145c
 */
void SeedPauseGaugeLayoutTable(void);

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
