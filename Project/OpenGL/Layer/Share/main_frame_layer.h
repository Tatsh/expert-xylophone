/**
 * @file
 * The play-field main-frame layer, @c MainFrameLayer.
 */

#pragma once

#include "linear_tween.h"
#include "playfieldlayerbase.h"

namespace ne {
class C_TEXTURE;
class C_SPRITE_INSTANCING_2D;
} // namespace ne

/**
 * @brief The play-field main-frame layer (the frame graphics around the note field).
 *
 * A process-wide singleton, built on first access, deriving from @c PlayFieldLayerBase. It owns the
 * frame's sprite instancers and a fade channel that animates the frame's alpha in and out. The class
 * carries no RTTI (it is non-polymorphic), so the name is inferred from its singleton getter rather
 * than confirmed from the runtime metadata. Only the fields the reconstructed methods touch are
 * modelled; the trailing @c // +0xNN comments document the original 32-bit offsets for reference
 * only. The remaining layer state (the sprite instancers, layout tables, and 3D vertices the build
 * and render paths use) is still being worked out and kept as reserved storage.
 */
class MainFrameLayer : public PlayFieldLayerBase {
public:
    /**
     * @brief The process-wide main-frame layer, created on first use.
     * @return The shared layer.
     * @ghidraAddress 0x17b5d4
     */
    static MainFrameLayer *shared();

    /**
     * @brief Begins the frame fade-in, easing the frame alpha to fully opaque (255) over
     * @p flDuration (snapping to opaque and marking the fade done when the duration is non-positive).
     * @param flDuration The fade duration.
     * @ghidraAddress 0x17c670
     */
    void StartFadeIn(float flDuration);

    /**
     * @brief Begins the frame fade-out, easing the frame alpha to zero over @p flDuration (snapping
     * to zero and marking the fade done when the duration is non-positive).
     * @param flDuration The fade duration.
     * @ghidraAddress 0x17c6a0
     */
    void StartFadeOut(float flDuration);

    /**
     * @brief Shows or hides the main frame sprite. A no-op when the sprite has not been built.
     * @param bEnabled @c true to show the frame, @c false to hide it.
     * @ghidraAddress 0x17c9a8
     */
    void SetMainFrameEnabled(bool bEnabled);

    /**
     * @brief Sets the frame type, rebuilding the frame sprites when it changes.
     *
     * A no-op when the type is unchanged; otherwise it records the new type, clears the built flag,
     * and rebuilds the frame sprites.
     * @param nType The frame type.
     * @ghidraAddress 0x17c4c0
     */
    void SetFrameType(int nType);

    /**
     * @brief Sets the frame marker and difficulty, refreshing the overlay layout when either
     * changes.
     *
     * Builds the sprites first if they are not yet built, records the new marker and difficulty, and
     * re-lays-out the overlay only when one of them actually changed.
     * @param nMarker The frame marker.
     * @param nDifficulty The difficulty index shown on the frame.
     * @ghidraAddress 0x17c4dc
     */
    void SetMarker(int nMarker, int nDifficulty);

    /**
     * @brief Rebuilds the full frame geometry: the marker/difficulty overlay layout and the 3D frame
     * vertices.
     * @ghidraAddress 0x17c864
     */
    void BuildGeometry();

    /**
     * @brief Binds a texture to the frame mesh's sprite instancer and recomputes the mesh UV offsets
     * and scale from the texture's dimensions.
     *
     * With a null texture the mesh is left unchanged (only the instancer's texture is cleared).
     * @param pTexture The frame texture, or null to clear it.
     * @ghidraAddress 0x17c55c
     */
    void SetMainFrameTexture(ne::C_TEXTURE *pTexture);

private:
    /**
     * @brief Rebuilds the frame's 3D vertex mesh. Reconstruction pending.
     * @ghidraAddress 0x17c16c
     */
    void Build3dVertices();

    /**
     * @brief (Re)builds the frame sprites for the current frame type. Reconstruction pending.
     * @ghidraAddress 0x17b654
     */
    void BuildSprites();

    /**
     * @brief Re-lays-out the frame's marker/difficulty overlay sprites. Reconstruction pending.
     * @ghidraAddress 0x17bd50
     */
    void SetOverlayLayout();

    /**
     * @brief Constructs the layer, chaining the base constructor and seeding its default layout
     * fields. The binary inlines this into @c shared (0x17b5d4).
     */
    MainFrameLayer();

    // +0x08..+0x27: the frame's other sprite instancers and layout state, still being worked out.
    unsigned char m_aReserved08[0x20] = {};         // +0x08
    ne::C_SPRITE_INSTANCING_2D *m_pMainSprite = {}; // +0x28: the main frame sprite instancer.
    // +0x30..+0x3f: further layout state, still being worked out.
    unsigned char m_aReserved30[0x10] = {};        // +0x30
    ne::C_SPRITE_INSTANCING_2D *m_pFrameMesh = {}; // +0x40: the frame mesh sprite instancer whose
                                                   //        first slot carries the frame texture.
    int m_nFrameType = {};  // +0x48: the frame type, seeded to 0x20 and set by
                            //        SetMainFrameType (which rebuilds on change).
    int m_nDifficulty = {}; // +0x4c: the difficulty index shown on the frame.
    int m_nMarker = {};     // +0x50: the frame marker, seeded to 5.
    bool m_bReady = {};     // +0x54: cleared when the frame type changes (rebuild flag).
    unsigned char m_aReserved55[3] = {}; // +0x55
    LinearTween m_fadeChannel;           // +0x58: the frame alpha fade channel.
    bool m_bFadeDone = {};               // +0x6c: set when the fade snaps to its endpoint.
    // +0x6d..+0x77: the remaining layer state, still being worked out.
    unsigned char m_aReserved6d[0xb] = {}; // +0x6d
};

// code: language=Objective-C++
// kate: hl Objective-C++;
// vim: set ft=objcpp :
