/**
 * @file
 * The alternate play-field frame layer, @c AltFrameLayer.
 */

#pragma once

#include "linear_tween.h"
#include "playfieldlayerbase.h"

namespace ne {
class C_TEXTURE;
class C_SPRITE_INSTANCING_2D;
} // namespace ne

/**
 * @brief The alternate-frame layer, drawn in place of the main frame for the alt (event/wide) mode.
 *
 * A process-wide singleton, built on first access, deriving from @c PlayFieldLayerBase. It owns the
 * frame sprite batches and a fade channel. The trailing @c // +0xNN comments document the original
 * 32-bit offsets for reference only; the class carries no RTTI, so the name is inferred from its
 * @c GetAltFrameLayer / @c SetAltFrame* accessors.
 */
class AltFrameLayer : public PlayFieldLayerBase {
public:
    /**
     * @brief The process-wide alternate-frame layer, created on first use.
     * @return The shared layer.
     * @ghidraAddress 0x17a4f8
     */
    static AltFrameLayer *shared();

    /**
     * @brief Rebuilds the frame markers, then begins the frame fade-in, easing to opaque (255) over
     * @p flDuration (snapping and marking the fade done when the duration is non-positive).
     * @param flDuration The fade duration.
     * @ghidraAddress 0x17b054
     */
    void StartFadeIn(float flDuration);

    /**
     * @brief Begins the frame fade-out, easing to transparent over @p flDuration (snapping and
     * marking the fade done when the duration is non-positive).
     * @param flDuration The fade duration.
     * @ghidraAddress 0x17b0ac
     */
    void StartFadeOut(float flDuration);

    /**
     * @brief Sets the frame type, rebuilding the frame sprites when it changes.
     *
     * A no-op when the type is unchanged; otherwise it records the new type, clears the built flag,
     * and rebuilds the frame sprites.
     * @param nType The frame type.
     * @ghidraAddress 0x17aba8
     */
    void SetFrameType(int nType);

    /**
     * @brief Advances the frame fade one frame and applies the faded alpha to every sprite slot.
     *
     * When ready, advances the fade channel toward its end value, writes the eased alpha to each
     * live slot of the three batches, and keeps the two overlay batches visible.
     * @param flDelta The frame delta.
     * @ghidraAddress 0x17b0d4
     */
    void Process(float flDelta);

    /**
     * @brief Binds a texture to the frame's mesh sprite instancer and recomputes its UV offsets and
     * scale from the texture's dimensions.
     *
     * With a null texture, every slot's UV origin, size, tex-size, and centre are zeroed instead.
     * @param pTexture The frame texture, or null to clear it.
     * @ghidraAddress 0x17aecc
     */
    void SetAltFrameTexture(ne::C_TEXTURE *pTexture);

    /**
     * @brief Records the frame mode and re-emits the active lane's highlight sprite.
     *
     * Stores @p nMode, then writes the first slot of the highlight's sprite batch: it takes the
     * position, rotation, and scale from the active lane's marker layout (the base Y offset by the
     * play-field half-height), and the anchor, pixel size, and atlas rectangle from the
     * mode-selected highlight descriptor. The lane-count tier (chosen by the frame type) selects
     * the marker and descriptor tables; the descriptor's batch selects the sprite instancer, and
     * the mesh batch draws from the frame type's alt-frame mesh UV atlas while the overlay batches
     * draw from the shared atlas. The highlight is always drawn opaque white.
     * @param nMode The frame mode (the active lane's highlight selector).
     * @ghidraAddress 0x17abc4
     */
    void SetFrameMode(int nMode);

    /**
     * @brief (Re)builds the frame sprite batches for the current frame type.
     *
     * A no-op once the layer is ready. Otherwise it resolves the frame type (substituting the game
     * system's when the layer still holds the default sentinel), picks the active lane and each
     * batch's capacity from the lane-count tier, loads the frame and shared parts atlases, creates
     * and registers any batch that does not exist yet, then emits every marker's sprite: position,
     * anchor, size, atlas rectangle, rotation, scale, and tint. Finally it marks the layer ready.
     * @ghidraAddress 0x17a548
     */
    void BuildSprites();

    // The number of frame sprite batches the layer builds.
    static constexpr int kSpriteSlotCount = 3;

private:
    /**
     * @brief Re-places every marker sprite for the current frame type.
     *
     * Walks the lane-count tier's marker layout table and rewrites each sprite's position (the base
     * Y offset by the play-field half-height), leaving the anchor, size, atlas rectangle, and tint
     * that @c BuildSprites established.
     * @ghidraAddress 0x17a9d8
     */
    void RenderMarkers();

    /**
     * @brief Constructs the layer: seeds the default frame type (32) and mode (5), and clears the
     * sprite batches, counts, and fade channel.
     * @ghidraAddress 0x17a4a4
     */
    AltFrameLayer();

    // The number of textures the layer binds across its batches: the frame atlas and the shared
    // parts atlas.
    static constexpr int kTextureSlotCount = 2;

    // unsigned char m_aReserved08[8] = {}; // +0x08: untouched by the constructor and never read.
    ne::C_TEXTURE *m_apTextures[kTextureSlotCount] =
        {}; // +0x10: the frame atlas and the shared parts atlas.
    ne::C_SPRITE_INSTANCING_2D *m_apSprites[kSpriteSlotCount] =
        {};                                     // +0x20: the frame sprite batches.
    int m_aSpriteCounts[kSpriteSlotCount] = {}; // +0x38: each batch's initial sprite count.
    int m_nFrameType = {};                      // +0x44: the frame type (default 32).
    int m_nFrameMode = {};                      // +0x48: the frame mode/kind (default 5).
    bool m_bReady = {};                         // +0x4c: cleared when the frame type changes.
    // unsigned char m_aReserved4d[3] = {};        // +0x4d
    LinearTween m_fadeChannel; // +0x50: the frame fade channel.
    bool m_bFadeDone = {};     // +0x64: set when the fade snaps to its endpoint.
    // unsigned char m_aReserved65[3] = {};        // +0x65
    int m_nActiveLane = {};  // +0x68: the highlighted (active) lane marker index.
    int m_nMarkerCount = {}; // +0x6c: the number of markers this frame draws.
    int m_anBatchCapacity[kSpriteSlotCount] =
        {}; // +0x70: each batch's sprite capacity and draw count.
    // unsigned char m_aReserved7c[4] = {}; // +0x7c: trailing state to the 0x80-byte size.
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
