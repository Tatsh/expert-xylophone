/**
 * @file
 * The Colette-theme result-window layer, @c ResultWindowColetteLayer.
 */

#pragma once

#include "playfieldlayerbase.h"

struct S_VECTOR2;
struct PartsDataRecord;

namespace ne {
class C_SPRITE_INSTANCING;
class C_TEXTURE;
} // namespace ne

/**
 * @brief The Colette-theme result-window layer.
 *
 * Draws the phone-layout result panel (score, rank, rate, per-side stats, and bonus rows) as a bank
 * of eight sprite-instancer nodes over the play field. It is a process-wide singleton built on first
 * access and derives from @c PlayFieldLayerBase. The trailing @c // +0xNN comments document the
 * original 32-bit member offsets for reference only; state is reached through named fields. The
 * fields between the recovered members whose roles are still being worked out are grouped into
 * reserved spans sized to preserve the binary's object layout.
 */
class ResultWindowColetteLayer : public PlayFieldLayerBase {
public:
    // The number of sprite-instancer slots the result window draws with.
    static constexpr int kSlotCount = 8;

    /**
     * @brief The process-wide Colette result-window layer, created on first use.
     * @return The shared layer.
     * @ghidraAddress 0x73edc
     */
    static ResultWindowColetteLayer *shared();

    /**
     * @brief Builds the eight result-window sprite instancers on first use.
     *
     * Loads the selection-background and result-parts textures, creates one sprite instancer per
     * slot (from a per-slot capacity table), registers each as a global scene node, and binds a
     * texture to the parts and overlay slots. Runs once; a no-op thereafter.
     * @ghidraAddress 0x73f2c
     */
    void InitializeResultWindowSprites();

    /**
     * @brief Resolves a phone-layout anchor position by index, offset relative to the play field.
     *
     * Looks up a @c PhoneAnchorRecord from one of two runtime-filled tables (selected by the
     * portrait flag), copies its base coordinate into @p pOutPosition, then shifts it by the
     * play-field viewport's half or full width and height according to the record's anchor mode.
     * @param nIndex The position-record index (0 through 167).
     * @param pOutPosition Receives the resolved position.
     * @ghidraAddress 0x73b4c
     */
    void getPosition_Phone(int nIndex, S_VECTOR2 *pOutPosition) const;

    /**
     * @brief Returns a result-window parts descriptor by index.
     *
     * Selects the pad or phone parts table by the current device kind and returns the record at
     * @p nIndex.
     * @param nIndex The parts-record index (0 through 347).
     * @return The parts descriptor.
     * @ghidraAddress 0x73a44
     */
    PartsDataRecord *getPartsData(int nIndex) const;

private:
    /**
     * @brief Appends one sprite quad to a slot's sprite instancer.
     *
     * When the slot index is in range, the slot's instancer exists, and it is not already full,
     * writes the quad's position, anchor, size, UV origin, UV size, rotation, and scale into the
     * next free sprite, sets its colour from the intensity and alpha, and advances the instancer's
     * sprite count.
     * @param nSlot The slot index (0 through 7).
     * @param position The sprite's world position.
     * @param anchor The sprite's anchor (pivot) offset.
     * @param size The sprite's pixel size.
     * @param uvOrigin The sprite's UV origin.
     * @param uvSize The sprite's UV size.
     * @param flRotation The sprite's rotation, in radians.
     * @param scale The sprite's per-axis scale.
     * @param nIntensity The value written to each of the red, green, and blue channels.
     * @param nAlpha The alpha channel.
     * @ghidraAddress 0x7ac58
     */
    void appendSpriteToSlot(int nSlot,
                            const S_VECTOR2 &position,
                            const S_VECTOR2 &anchor,
                            const S_VECTOR2 &size,
                            const S_VECTOR2 &uvOrigin,
                            const S_VECTOR2 &uvSize,
                            float flRotation,
                            const S_VECTOR2 &scale,
                            unsigned int nIntensity,
                            unsigned int nAlpha);

    // +0x08..+0x0f: presentation-transform state seeded by the constructor, whose individual fields
    // are still being worked out.
    unsigned char m_aReserved08[0x08] = {};   // +0x08
    ne::C_TEXTURE *m_pBackgroundTexture = {}; // +0x10: the selection-background texture.
    ne::C_TEXTURE *m_pPartsTexture = {};      // +0x18: the result-parts atlas texture, bound to the
                                              //        parts slot.
    ne::C_TEXTURE *m_pOverlayTexture = {};    // +0x20: the texture bound to the overlay slot; not
                                              //        set by the sprite builder.
    ne::C_SPRITE_INSTANCING *m_apSlots[kSlotCount] = {}; // +0x28: the eight sprite-instancer nodes.
    bool m_bBuilt = {};    // +0x68: whether the sprite instancers have been built.
    bool m_bPortrait = {}; // +0x69: selects the portrait anchor-position table.
    // +0x6a..+0x6b is alignment padding before the glyph-table base indices.
    unsigned char m_aPad6a[2] = {}; // +0x6a
    int m_nGlyphBaseA = {};         // +0x6c: glyph-table base index A (0x4e).
    int m_nGlyphBaseB = {};         // +0x70: glyph-table base index B (0x45).
    int m_nGlyphBaseC = {};         // +0x74: glyph-table base index C (0x3a).
    float m_flPartsScale = {};      // +0x78: the parts-sprite scale (1.0).
    // +0x7c..+0x17f: the panel's per-frame presentation state (page index, flick blend, handle,
    // per-side statistics, fade alphas, bonus values, and side colours) that the render pass reads;
    // the individual fields are still being worked out.
    unsigned char m_aReserved7c[0x104] = {}; // +0x7c
};

// code: language=Objective-C++
// kate: hl Objective-C++;
// vim: set ft=objcpp :
