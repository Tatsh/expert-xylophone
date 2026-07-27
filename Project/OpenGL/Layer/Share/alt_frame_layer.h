/**
 * @file
 * The alternate play-field frame layer, @c AltFrameLayer.
 */

#pragma once

#include "linear_tween.h"
#include "playfieldlayerbase.h"

namespace ne {
class C_TEXTURE;
class C_SPRITE_INSTANCING;
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

    // The number of frame sprite batches the layer builds.
    static constexpr int kSpriteSlotCount = 3;

private:
    /**
     * @brief (Re)builds the frame sprite batches for the current frame type. Reconstruction pending.
     * @ghidraAddress 0x17a548
     */
    void BuildSprites();

    /**
     * @brief Rebuilds the frame's marker overlay sprites. Reconstruction pending.
     * @ghidraAddress 0x17a9d8
     */
    void RenderMarkers();

    /**
     * @brief Constructs the layer: seeds the default frame type (32) and mode (5), and clears the
     * sprite batches, counts, and fade channel.
     * @ghidraAddress 0x17a4a4
     */
    AltFrameLayer();

    ne::C_TEXTURE *m_pTexture = {};         // +0x08: the frame atlas.
    unsigned char m_aReserved10[0x10] = {}; // +0x10: further texture/handle state.
    ne::C_SPRITE_INSTANCING *m_apSprites[kSpriteSlotCount] = {}; // +0x20: the frame sprite batches.
    int m_aSpriteCounts[kSpriteSlotCount] = {}; // +0x38: each batch's initial sprite count.
    int m_nFrameType = {};                      // +0x44: the frame type (default 32).
    int m_nFrameMode = {};                      // +0x48: the frame mode/kind (default 5).
    bool m_bReady = {};                         // +0x4c: cleared when the frame type changes.
    unsigned char m_aReserved4d[3] = {};        // +0x4d
    LinearTween m_fadeChannel;                  // +0x50: the frame fade channel.
    bool m_bFadeDone = {};                      // +0x64: set when the fade snaps to its endpoint.
    unsigned char m_aReserved65[0x1b] = {};     // +0x65: trailing state to the 0x80-byte size.
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
