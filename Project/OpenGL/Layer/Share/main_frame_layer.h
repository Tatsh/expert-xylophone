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
class C_DRAW_POLYGON_2D;
class C_DRAW_POLYGON_3D;
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

    /**
     * @brief Selects which of the layer's two sprite instancers @c EmitMainFrameSprite fills.
     */
    enum MainFrameInstancer {
        MainFrameInstancerOverlay = 0, /*!< The marker/difficulty overlay sprite batch. */
        MainFrameInstancerFrame = 1,   /*!< The single-slot 3D frame-mesh batch. */
    };

    /**
     * @brief Appends one sprite to one of the layer's two instancers, at the given world position.
     *
     * A no-op when the instancer index is out of range, the sprite kind is out of range, or the
     * target instancer is already full. The overlay instancer takes its size, anchor, and UV atlas
     * frame from the shared overlay-layout table (indexed by @p nSpriteKind); the frame-mesh
     * instancer takes only the position. Either way the sprite is drawn white with its alpha taken
     * from the frame fade channel, and the instancer's active-sprite count is bumped.
     * @param nInstancerIndex Which instancer to append to (@c MainFrameInstancer).
     * @param nSpriteKind The overlay-layout table index (also the source of the UV frame).
     * @param flX The sprite's world-position X.
     * @param flY The sprite's world-position Y.
     * @ghidraAddress 0x17c888
     */
    void EmitMainFrameSprite(unsigned int nInstancerIndex,
                             unsigned int nSpriteKind,
                             float flX,
                             float flY);

    /**
     * @brief (Re)builds the frame's meshes and sprite instancers for the current frame type.
     *
     * Resolves the frame type (substituting the game system's when the layer still holds the default
     * sentinel), releases and reloads the frame and overlay atlases, then creates any of the three
     * meshes and two instancers that do not exist yet: the marker's eight-vertex ring, the border's
     * sixteen-vertex textured strip, and the overlay's twenty-four-vertex strip parented to the
     * border. Every vertex is seeded at the origin with its atlas UV and a cleared alpha, and both
     * instancers are left empty. Finally it lays the overlay out, rebuilds the 3D vertices, and marks
     * the layer ready.
     * @ghidraAddress 0x17b654
     */
    void BuildSprites();

    /**
     * @brief Advances the frame layer by one frame, refreshing its geometry and fade alpha.
     *
     * Re-lays-out the overlay and rebuilds the 3D border whenever the viewport has changed size,
     * then advances the fade channel toward its end. On the frame the fade moves — or the frame a
     * snapped fade latches — the fade alpha is pushed into the 3D border's vertices, the 2D overlay
     * mesh's vertices, and every live sprite slot, and the marker mesh is hidden once the alpha has
     * fallen to the invisibility epsilon.
     * @param flDelta The elapsed frame count.
     * @ghidraAddress 0x17c6c8
     */
    void Process(float flDelta);

private:
    /**
     * @brief Rebuilds the positions of both 3D meshes from the current sheet metrics.
     *
     * Lays the border mesh out as a picture frame of four quads — a bottom band, a top band, and a
     * left and right strip spanning between them — around the sheet's outer rectangle, then lays
     * the marker ring out as four corner pairs that each join a far-off outer vertex to the sheet
     * corner beside it, so the ring covers everything outside the sheet.
     * @ghidraAddress 0x17c16c
     */
    void Build3dVertices();

    /**
     * @brief Re-lays-out the frame's border mesh and its marker/difficulty overlay sprites.
     *
     * Positions the frame mesh's 24 vertices as two theme-independent horizontal bands (a short
     * centre tab and the full-width bottom strip) sized to the current viewport width, clears both
     * overlay instancers, then emits the two top labels, the marker label, the difficulty label, and
     * the centred frame-mesh marker. The current player theme selects which label and marker sprites
     * are emitted.
     * @ghidraAddress 0x17bd50
     */
    void SetOverlayLayout();

    /**
     * @brief Constructs the layer, chaining the base constructor and seeding its default layout
     * fields. The binary inlines this into @c shared (0x17b5d4).
     */
    MainFrameLayer();

    // +0x08: the frame atlas for the current frame type; +0x10 the shared gm_parts2 overlay atlas.
    // BuildSprites releases and reloads both.
    ne::C_TEXTURE *m_pFrameTexture = {};
    ne::C_TEXTURE *m_pOverlayTexture = {};
    // +0x18: the frame border's 16-vertex 3D mesh, whose vertices Build3dVertices lays out and whose
    // per-vertex alpha follows the fade channel.
    ne::C_DRAW_POLYGON_3D *m_pFrameMesh3d = {};
    // +0x20: the marker's 8-vertex 3D mesh. Its visibility follows the fade alpha: it is hidden once
    // the alpha falls to the invisibility epsilon.
    ne::C_DRAW_POLYGON_3D *m_pMarkerMesh3d = {};
    // +0x28: the frame's 2D polygon mesh (a C_RENDER, so SetMainFrameEnabled toggles its visibility;
    // SetMainFrameOverlayLayout fills its 24 vertices through C_DRAW_POLYGON_2D::SetPos).
    ne::C_DRAW_POLYGON_2D *m_pFrameMesh2d = {};
    // +0x30..+0x37: further layout state, still being worked out.
    unsigned char m_aReserved30[8] = {}; // +0x30
    // +0x38, +0x40: the two instancers EmitMainFrameSprite fills, indexed by MainFrameInstancer.
    // [MainFrameInstancerFrame] is the frame mesh whose first slot carries the frame texture.
    ne::C_SPRITE_INSTANCING_2D *m_apInstancers[2] = {};
    int m_nFrameType = {};  // +0x48: the frame type, seeded to 0x20 and set by
                            //        SetMainFrameType (which rebuilds on change).
    int m_nDifficulty = {}; // +0x4c: the difficulty index shown on the frame.
    int m_nMarker = {};     // +0x50: the frame marker, seeded to 5.
    bool m_bReady = {};     // +0x54: cleared when the frame type changes (rebuild flag).
    unsigned char m_aReserved55[3] = {}; // +0x55
    LinearTween m_fadeChannel;           // +0x58: the frame alpha fade channel.
    bool m_bFadeDone = {};               // +0x6c: set when the fade snaps to its endpoint.
    unsigned char m_aReserved6d[3] = {}; // +0x6d
    // +0x70, +0x74: the viewport size the current layout and 3D mesh were built for; the per-frame
    // step rebuilds both when the viewport changes.
    float m_flLayoutWidth = {};
    float m_flLayoutHeight = {};
};

// code: language=Objective-C++
// kate: hl Objective-C++;
// vim: set ft=objcpp :
