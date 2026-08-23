/**
 * @file
 * The Reflec gauge layer, @c ReflecGaugeLayer.
 */

#pragma once

#include "linear_tween.h"
#include "playfieldlayerbase.h"
#include "s_vector2.h"

namespace ne {
class C_TEXTURE;
class C_SPRITE_INSTANCING_2D;
} // namespace ne

/**
 * @brief The Reflec gauge layer (the gauge slider and score/combo digits).
 *
 * A process-wide singleton, built on first access, deriving from @c PlayFieldLayerBase. It owns one
 * atlas and four sprite instancers, drawn beneath the shared background layer, that present the
 * gauge slider and score digits, and holds the per-side gauge value the scoring path drives. The
 * class name and source path are taken from the binary's embedded @c reflec_gauge_layer.mm assert.
 * The trailing @c // +0xNN comments document the original 32-bit offsets for reference only.
 */
class ReflecGaugeLayer : public PlayFieldLayerBase {
public:
    /**
     * @brief Sets the gauge's display brightness from a unit-interval value, mapped by an affine
     * transform to @c [0.3, 1.0].
     * @param flValue The brightness input, in the range zero to one.
     * @ghidraAddress 0x18ad0c
     */
    void SetGaugeDisplayBrightness(float flValue);

    /**
     * @brief Adds a delta to a player colour's Reflec gauge value.
     * @param flDelta The amount to add.
     * @param pGauge The gauge layer.
     * @param nColor The player colour.
     * @ghidraAddress 0x18abfc
     */
    static void AddReflecGaugeValue(float flDelta, ReflecGaugeLayer *pGauge, int nColor);

    /**
     * @brief Subtracts a delta from a player's Reflec gauge value on the matching side.
     * @param flDelta The amount to subtract.
     * @param pGauge The gauge layer.
     * @param nPlayer The player id, compared against the current play side to pick the gauge side.
     * @ghidraAddress 0x18acb8
     */
    static void SubReflecGaugeValue(float flDelta, ReflecGaugeLayer *pGauge, int nPlayer);

    // The number of gauge/slider sprite instancers the layer builds.
    static constexpr int kBatchCount = 4;
    // The number of part groups whose capacities the constructor accumulates.
    static constexpr int kPartGroupCount = 6;
    // The number of player sides the gauge tracks.
    static constexpr int kSideCount = 2;

    /** @brief A gauge sprite descriptor (a 20-byte record): its anchor, its size, and atlas frame.
     */
    struct GaugeSpriteDescriptor {
        S_VECTOR2 anchor = {}; // +0x00: the sprite anchor offset.
        S_VECTOR2 size = {};   // +0x08: the sprite pixel size.
        int nAtlasFrame = {};  // +0x10: the atlas-frame number indexing the shared sprite UV table.
    };

    /**
     * @brief The process-wide Reflec gauge layer, created on first use.
     * @return The shared layer.
     * @ghidraAddress 0x18a88c
     */
    static ReflecGaugeLayer *shared();

    /**
     * @brief Lazily builds the four gauge/slider sprite batches: loads the gm_parts2 atlas and
     * creates each instancer (attaching it under the background layer's render object, making it
     * visible, binding the atlas, and clearing its frame index), flagging the third batch's vertex
     * flag.
     *
     * Guarded so the batches are built only once.
     * @ghidraAddress 0x18a8dc
     */
    void CreateGaugeSliderSprites();

    /**
     * @brief Advances the gauge bar's fill tween and rebuilds its cell sprites for the frame.
     *
     * Eases the fill value toward its target by @p flDelta, deriving the bar's fill ratio between
     * its two endpoints and marking it dirty. It then clears each batch's sprite count and, for
     * each of the two gauge halves, advances that side's animated display value toward its gauge
     * value at the per-half rate, clamps the cell count to @c [0, 5], and re-emits the base, icon,
     * value, and (in the alternate mode) label cell sprites at the resulting fill.
     * @param flDelta The per-frame time delta.
     * @ghidraAddress 0x18ad94
     */
    void UpdateGaugeBar(float flDelta);

    /**
     * @brief Returns the gauge value for the given player colour.
     *
     * Maps the colour to a side (matching the current play side) and reads that side's value.
     * @param nColor The player colour (0 or 1).
     * @ghidraAddress 0x18ab18
     */
    float GetValue(int nColor) const;
    /**
     * @brief Returns the opposing side's gauge value for the given player colour.
     *
     * Maps the colour to the side that does not match the current play side and reads that side's
     * value.
     * @param nColor The player colour (0 or 1).
     * @ghidraAddress 0x18ac38
     */
    float GetAnotherValue(int nColor) const;
    /**
     * @brief Sets the gauge value for the given player colour.
     *
     * Maps the colour to a side and stores the quantised, clamped value there.
     * @param flValue The requested value.
     * @param nColor The player colour (0 or 1).
     * @ghidraAddress 0x18a9d8
     */
    void SetValue(float flValue, int nColor);

    /**
     * @brief Reads a side's stored gauge value directly.
     * @param nSide The player side (0 or 1).
     * @ghidraAddress 0x18ab98
     */
    float GetValueBySide(unsigned int nSide) const;
    /**
     * @brief Stores a side's gauge value, quantised to the gauge step and clamped to the gauge
     * range (capping at the maximum unless the full-just-reflec flag is set).
     * @param flValue The requested value.
     * @param nSide The player side (0 or 1).
     * @ghidraAddress 0x18aa68
     */
    void SetValueBySide(float flValue, unsigned int nSide);

    /**
     * @brief Sets the gauge style (the sprite-layout variant), taken from the user's gauge-style
     * setting.
     * @param nStyle The gauge style.
     * @ghidraAddress 0x18ad2c
     */
    void SetGaugeStyle(int nStyle);
    /**
     * @brief Sets the mirror/side flag, which drives the gauge sprite's horizontal flip.
     * @param nSide The mirror/side flag.
     * @ghidraAddress 0x18ad34
     */
    void SetMirrorSide(int nSide);

    /**
     * @brief Begins the gauge fade-in, easing the gauge to fully opaque over @p flDuration
     * (snapping to opaque and marking the fade done when the duration is non-positive).
     * @param flDuration The fade duration.
     * @ghidraAddress 0x18ad3c
     */
    void StartFadeIn(float flDuration);

    /**
     * @brief Begins the gauge fade-out, easing the gauge to transparent over @p flDuration
     * (snapping to transparent and marking the fade done when the duration is non-positive).
     * @param flDuration The fade duration.
     * @ghidraAddress 0x18ad6c
     */
    void StartFadeOut(float flDuration);

    /**
     * @brief Resets both sides' gauge state, seeding the value to five in the full-just-reflec
     * challenge mode and to zero otherwise.
     * @ghidraAddress 0x18a988
     */
    void ResetSideGauges();

    /**
     * @brief Emits the gauge base/frame sprite (kind 0) into a batch.
     *
     * Selects the sprite descriptor and atlas frame by orientation and gauge mode. The batch is
     * always the first one; the caller's argument is the player side.
     * @param nSide The player side, selecting the position and rotation.
     * @param nAlpha The sprite tint alpha.
     * @ghidraAddress 0x18b034
     */
    void EmitBaseSprite(unsigned int nSide, int nAlpha);

    /**
     * @brief Emits a gauge label sprite (kind 2) into the label batch.
     * @param nSide The player side.
     * @param nLabelIndex The label index.
     * @param nAlpha The sprite tint alpha.
     * @ghidraAddress 0x18b2cc
     */
    void EmitLabelSprite(unsigned int nSide, int nLabelIndex, int nAlpha);

    /**
     * @brief Emits a gauge icon sprite (batch 3) from the orientation-specific icon table.
     * @param nSide The player side.
     * @param nIconIndex The icon index into the icon descriptor table.
     * @param nAlpha The sprite tint alpha.
     * @ghidraAddress 0x18b0dc
     */
    void EmitIconSprite(unsigned int nSide, int nIconIndex, int nAlpha);

private:
    /**
     * @brief Constructs the layer, chaining the base constructor, seeding its transform scales, and
     * accumulating each batch's per-group capacities.
     * @ghidraAddress 0x18a7d0
     */
    ReflecGaugeLayer();

    /** @brief One player side's gauge state: its target value and its animated display value. */
    struct SideGauge {
        float flValue = {};        // +0x00: the side's gauge value (the scoring target).
        float flDisplayValue = {}; // +0x04: the per-frame animated cell-fill value chasing flValue.
    };

    /**
     * @brief Emits one gauge quad into a batch at a side- and mode-selected screen position, with
     * an explicit texture rectangle.
     *
     * The caller resolves the quad's texture rectangle (the value renderer scales it to draw a
     * partially-filled digit cell); this places the quad's anchor and size from the descriptor and
     * its UV from @p uvOrigin and @p uvSize.
     * @param descriptor The sprite anchor and size (its atlas-frame field is unused here).
     * @param nBatch The target sprite batch.
     * @param nSide The player side, selecting the position and rotation.
     * @param nAlpha The sprite tint alpha.
     * @param uvOrigin The quad's UV origin.
     * @param uvSize The quad's UV size.
     * @ghidraAddress 0x18b380
     */
    void EmitGaugeSprite(const GaugeSpriteDescriptor &descriptor,
                         unsigned int nBatch,
                         unsigned int nSide,
                         int nAlpha,
                         const S_VECTOR2 &uvOrigin,
                         const S_VECTOR2 &uvSize);

    /**
     * @brief Emits one gauge value/digit quad, scaled to draw a partially-filled digit cell.
     *
     * Selects the digit descriptor by orientation, gauge mode, player side (inverted for the non-1P
     * side), and digit index, scales the cell's width and its UV width by @p flScale, and emits it
     * through @c EmitGaugeSprite into the value batch.
     * @param flScale The horizontal fill fraction (scales the cell width and its UV width).
     * @param nSide The player side.
     * @param nDigit The digit/value cell index.
     * @param nAlpha The sprite tint alpha.
     * @ghidraAddress 0x18b174
     */
    void EmitGaugeValueSprite(float flScale, unsigned int nSide, int nDigit, int nAlpha);

    ne::C_TEXTURE *m_pTexture = {}; // +0x08: the gm_parts2 atlas.
    ne::C_SPRITE_INSTANCING_2D *m_apSprites[kBatchCount] =
        {};                                     // +0x10: the per-batch sprite instancers.
    int m_aBatchCapacity[kBatchCount] = {};     // +0x30: each batch's sprite capacity.
    int m_aPartBaseIndex[kPartGroupCount] = {}; // +0x40: each part group's base index.
    bool m_bBuilt = {};                         // +0x58: set once the batches are built.
    // +0x59..+0x5f: further state, still being worked out.
    // unsigned char m_aReserved59[7] = {}; // +0x59
    LinearTween m_fadeChannel; // +0x60: the gauge fade channel.
    bool m_bFadeDone = {};     // +0x74: set when the fade snaps to its endpoint.
    // +0x75..+0x77 is alignment padding before the scales.
    // unsigned char m_aPad75[3]; // +0x75 (alignment padding, compiler-inserted)
    float m_aScales[2] = {};             // +0x78: two scales the constructor seeds to 1.
    float m_flDisplayBrightness = {};    // +0x80: the gauge display brightness (value mapped to
                                         //        [0.3, 1.0]).
    SideGauge m_aSides[kSideCount] = {}; // +0x84: the per-side gauge state (stride 8).
    int m_nGaugeStyle = {};              // +0x94: the gauge style / sprite-layout variant.
    int m_nMirrorSide = {};              // +0x98: the mirror/side flag (drives sprite X-flip).
    // unsigned char m_aReserved9c[4] = {}; // +0x9c: trailing layer state.
};

// code: language=Objective-C++
// kate: hl Objective-C++;
// vim: set ft=objcpp :
