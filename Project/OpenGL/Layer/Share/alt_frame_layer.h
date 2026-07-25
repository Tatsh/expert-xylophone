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
     * @brief Begins the frame fade-out, easing to transparent over @p flDuration (snapping and
     * marking the fade done when the duration is non-positive).
     * @param flDuration The fade duration.
     * @ghidraAddress 0x17b0ac
     */
    void StartFadeOut(float flDuration);

    // The number of frame sprite batches the layer builds.
    static constexpr int kSpriteSlotCount = 3;

private:
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
