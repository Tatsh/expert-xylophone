/**
 * @file
 * The theme-marker layer, @c ThemaMarkerLayer.
 */

#pragma once

#include "linear_tween.h"
#include "playfieldlayerbase.h"

namespace ne {
class C_TEXTURE;
class C_SPRITE_INSTANCING_2D;
} // namespace ne

/**
 * @brief The theme-marker layer (the row of marker graphics along the play field).
 *
 * A process-wide singleton, built on first access, deriving from @c PlayFieldLayerBase. It owns one
 * atlas and two sprite instancers (a 2D and a 3D batch) beneath the shared background layer, laying
 * out a set of marker groups whose count depends on the selected theme. The class carries no RTTI
 * (it is non-polymorphic), so the name is inferred from its singleton getter rather than confirmed
 * from the runtime metadata. The trailing @c // +0xNN comments document the original 32-bit offsets
 * for reference only.
 */
class ThemaMarkerLayer : public PlayFieldLayerBase {
public:
    // The number of sprite instancers the layer owns (a 2D batch and a 3D batch).
    static constexpr int kBatchCount = 2;
    // The number of marker-group layout entries in the shared tables.
    static constexpr int kMarkerLayoutCount = 6;

    /**
     * @brief The process-wide theme-marker layer, created on first use.
     * @return The shared layer.
     * @ghidraAddress 0x17fccc
     */
    static ThemaMarkerLayer *shared();

    /**
     * @brief Lazily builds the theme-marker sprites: picks the marker count from the theme, loads the
     * gm_parts1 atlas, creates the two sprite instancers (attaching each under the background
     * layer's render object, making it visible, and binding the atlas), and emits each marker
     * group's sprites from the shared layout and UV tables.
     *
     * Guarded so the sprites are built only once.
     * @ghidraAddress 0x17ff50
     */
    void LoadThemaMarkerSprites();

    /**
     * @brief Re-applies the current theme to the already-built markers: refreshes the theme, reselects
     * the marker count, reloads and re-binds the atlas to both batches, and re-emits every marker
     * group's geometry.
     *
     * Unlike @c LoadThemaMarkerSprites this does not create the batches; it refreshes an existing
     * layer after a theme change.
     * @ghidraAddress 0x17fd1c
     */
    void SetupMarkers();

    /**
     * @brief Begins the marker fade-out: resets the active marker index and eases the markers to
     * transparent over @p flDuration (snapping to transparent and marking the colour dirty when the
     * duration is non-positive).
     * @param flDuration The fade duration.
     * @ghidraAddress 0x180438
     */
    void StartFadeOut(float flDuration);

    /**
     * @brief Begins the marker fade-in, selecting the active marker value: eases the markers to
     * opaque over @p flDuration (snapping to opaque and marking the colour dirty when the duration is
     * non-positive) and resets the effect timer.
     * @param flDuration The fade duration.
     * @param flMarker The active marker value to store.
     * @ghidraAddress 0x180400
     */
    void StartFadeIn(float flDuration, float flMarker);

    /**
     * @brief Sets the low-gauge danger/warning intensity (clamped to @c [0, 1] and mapped to the
     * warning brightness range), marking the colour dirty.
     * @param flLevel The normalised danger level.
     * @ghidraAddress 0x180464
     */
    void SetDangerLevel(float flLevel);

    /**
     * @brief Rebuilds and emits the marker frame's sprites for the current active marker.
     * @ghidraAddress 0x1801d4
     */
    void RenderThemaMarkerFrame();

private:
    /**
     * @brief Constructs the layer, chaining the base constructor, seeding its scales, and computing
     * each batch's capacity and each marker group's base sprite index from the shared tables.
     * @ghidraAddress 0x17fc00
     */
    ThemaMarkerLayer();

    ne::C_TEXTURE *m_pTexture = {}; // +0x08: the gm_parts1 atlas.
    ne::C_SPRITE_INSTANCING_2D *m_apSprites[kBatchCount] =
        {};                                          // +0x10: the 2D and 3D sprite batches.
    int m_aBatchBaseIndex[kBatchCount] = {};         // +0x20: unused per-batch base index.
    int m_aBatchCapacity[kBatchCount] = {};          // +0x28: each batch's sprite capacity.
    int m_aMarkerBaseIndex[kMarkerLayoutCount] = {}; // +0x30: each marker group's base index.
    bool m_bBuilt = {};                              // +0x48: set once the sprites are built.
    bool m_bFadeColorDirty = {};                     // +0x49: set when the fade snaps or advances.
    // +0x4a..+0x4b is alignment padding before the active-marker value.
    unsigned char m_aPad4a[2] = {};      // +0x4a
    float m_flActiveMarker = {};         // +0x4c: the active marker value the fade-in selects.
    LinearTween m_fadeChannel;           // +0x50: the marker fade channel.
    float m_flScaleX = {};               // +0x64: a scale the constructor seeds to 1.
    float m_flScaleY = {};               // +0x68: a scale the constructor seeds to 1.
    int m_nEffectTimer = {};             // +0x6c: the fade-in effect timer, reset by StartFadeIn.
    float m_aTransform[6] = {};          // +0x70: a six-float transform block seeded from a table.
    int m_nReserved88 = {};              // +0x88: an int the constructor zero-clears.
    float m_flDangerBrightness = {};     // +0x8c: the low-gauge danger/warning brightness.
    int m_nMarkerCount = {};             // +0x90: the active marker count (6 for theme 0, else 4).
    unsigned char m_aReserved94[4] = {}; // +0x94: padding to the 0x98-byte allocation size.
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
