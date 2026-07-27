/**
 * @file
 * The Colette-theme result-window layer, @c ResultWindowColetteLayer.
 */

#pragma once

#include "playfieldlayerbase.h"

struct S_VECTOR2;
struct PartsDataRecord;
struct PhoneLayoutRect;

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
     * @brief Starts the result panel's hide animation: keyframes each display animation channel from
     * its current shown value toward zero over @p flDuration (snapping immediately when
     * non-positive) and clears the panel-active flag.
     * @param flDuration The animation duration.
     * @ghidraAddress 0x74190
     */
    void StartHideTween(float flDuration);

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

    /**
     * @brief Returns a phone-layout parts descriptor by index.
     *
     * Always uses the phone parts table, regardless of device kind, and returns the record at
     * @p nIndex.
     * @param nIndex The parts-record index (0 through 399).
     * @return The parts descriptor.
     * @ghidraAddress 0x73adc
     */
    PartsDataRecord *getPartsData_Phone(int nIndex) const;

    /**
     * @brief Resolves the single phone-layout centre-position rectangle, offset by the viewport.
     *
     * Copies the state, portrait, or default centre record (selected by the is-pad flag and
     * orientation flags) to @p pOutRect. When the state flag is clear the leading coordinate is
     * shifted by half the viewport width and height.
     * @param pOutRect Receives the resolved rectangle.
     * @ghidraAddress 0x73e50
     */
    void getCenterPosition_Phone(PhoneLayoutRect *pOutRect) const;

    /**
     * @brief Advances the bonus voice-cue timer and fires the cue once past its threshold.
     *
     * When the cue is armed, the timer accumulates the frame delta; once it passes the threshold the
     * cue is disarmed and the themed bonus voice is loaded and played.
     * @param flDeltaTime The elapsed time since the last frame, in milliseconds.
     * @ghidraAddress 0x74238
     */
    void UpdateBonusSoundCueTimer(float flDeltaTime);

    /** @brief Stores the seven result-bonus display values computed at the end of a play. */
    void SetResultBonuses(float flClear,
                          float flMiss,
                          float flRank,
                          float flFirstPlay,
                          float flHotMusic,
                          float flEarlyPlay,
                          float flExperience) {
        m_flClearBonus = flClear;
        m_flMissBonus = flMiss;
        m_flRankBonus = flRank;
        m_flFirstPlayBonus = flFirstPlay;
        m_flHotMusicBonus = flHotMusic;
        m_flEarlyPlayBonus = flEarlyPlay;
        m_flExperienceBonus = flExperience;
    }

private:
    /**
     * @brief Binds a texture into a slot and refreshes every existing sprite's size and UV rect.
     *
     * Sets the slot's ref-counted bound texture to @p pTexture, then, for each sprite already in the
     * slot, resizes it to the texture image size over its scale factor, zeroes its UV origin, and
     * sets its UV size to the used region. Does nothing if the slot is empty or @p pTexture is null.
     * @param nSlot The slot index (0 through 7).
     * @param pTexture The texture to bind.
     * @ghidraAddress 0x74018
     */
    void applySpriteInstancerTexture(int nSlot, ne::C_TEXTURE *pTexture);

    /**
     * @brief Draws a slot's whole bound texture centred on a position (half-size anchor), tinted.
     *
     * Like @c renderSpriteInstanceScaled (full texture-scaled size), but anchors the quad at half
     * its size so it is centred on @p position. The alpha is @p nScale times the layer parts scale;
     * the colour channels reuse the layer's three glyph-base bytes as a tint. The binary does not
     * null-check the bound texture.
     * @param nSlot The slot index (0 through 7).
     * @param position The sprite's centre position.
     * @param nScale The scale units multiplied into the alpha.
     * @ghidraAddress 0x79e7c
     */
    void blitSpriteInstanceHalfScale(int nSlot, const S_VECTOR2 &position, unsigned int nScale);

    /**
     * @brief Draws a slot's whole bound texture scaled by the layer's parts scale, tinted.
     *
     * Reads the slot's bound texture, sizes the quad by the texture's own scale factor, derives its
     * UV size from the used image over allocated dimensions, and appends it through
     * @c appendSpriteToSlotRgba. The alpha is @p nScale times the layer's parts scale; the red,
     * green, and blue channels come from the layer's three glyph-base bytes (reused as a colour
     * tint). A no-op when the slot is out of range, empty, or unbound.
     * @param nSlot The slot index (0 through 7).
     * @param position The sprite's world position.
     * @param nScale The scale units multiplied into the alpha.
     * @ghidraAddress 0x76c1c
     */
    void renderSpriteInstanceScaled(int nSlot, const S_VECTOR2 &position, unsigned int nScale);

    /**
     * @brief Draws a slot's whole bound texture as one quad, at half the given extent.
     *
     * Reads the slot instancer's bound texture, derives its UV size from the used-image over
     * allocated dimensions, and appends a sprite at @p position anchored at half @p extent with a
     * size of @p extent, fully opaque at the given alpha.
     * @param nSlot The slot index (0 through 7).
     * @param position The sprite's world position.
     * @param extent The sprite's pixel size; its half is used as the anchor.
     * @param nAlpha The sprite's alpha.
     * @ghidraAddress 0x76b5c
     */
    void renderSpriteInstanceFromSlot(int nSlot,
                                      const S_VECTOR2 &position,
                                      const S_VECTOR2 &extent,
                                      unsigned int nAlpha);

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

    /**
     * @brief Appends one sprite quad to a slot's instancer with an explicit per-channel colour.
     *
     * Identical to @c appendSpriteToSlot but takes independent red, green, and blue channels rather
     * than a single intensity. When the slot is in range, its instancer exists, and it is not full,
     * writes the quad's position, anchor, size, UV origin, UV size, rotation, and scale into the next
     * free sprite, sets its colour from the four channels, and advances the sprite count.
     * @param nSlot The slot index (0 through 7).
     * @param nRed The red channel.
     * @param nGreen The green channel.
     * @param nBlue The blue channel.
     * @param nAlpha The alpha channel.
     * @param position The sprite's world position.
     * @param anchor The sprite's anchor (pivot) offset.
     * @param size The sprite's pixel size.
     * @param uvOrigin The sprite's UV origin.
     * @param uvSize The sprite's UV size.
     * @param flRotation The sprite's rotation, in radians.
     * @param scale The sprite's per-axis scale.
     * @ghidraAddress 0x7ada0
     */
    void appendSpriteToSlotRgba(int nSlot,
                                unsigned int nRed,
                                unsigned int nGreen,
                                unsigned int nBlue,
                                unsigned int nAlpha,
                                const S_VECTOR2 &position,
                                const S_VECTOR2 &anchor,
                                const S_VECTOR2 &size,
                                const S_VECTOR2 &uvOrigin,
                                const S_VECTOR2 &uvSize,
                                float flRotation,
                                const S_VECTOR2 &scale);

    /**
     * @brief Emits one glyph sprite at a resolved position index plus an offset, dimmable.
     *
     * Resolves the base position from the phone anchor table by @p nPositionIndex, adds @p offset,
     * looks up the glyph placement rectangle from the phone parts table by @p nCharCode and its
     * texture rectangle from the Colette glyph UV palette, then appends the quad to the slot with the
     * given rotation and scale. Character codes at or above the phone parts table count are ignored.
     * The main pass draws at full intensity, the shadow pass at half.
     * @param nSlot The slot index (0 through 7).
     * @param nCharCode The glyph character code (below the phone parts table count).
     * @param nPositionIndex The phone anchor-position index.
     * @param offset The offset added to the resolved position.
     * @param nAlpha The glyph alpha.
     * @param bShadowPass Whether this is the half-intensity shadow pass.
     * @param flRotation The glyph rotation, in radians.
     * @param flScaleX The glyph X scale.
     * @param flScaleY The glyph Y scale.
     * @ghidraAddress 0x7aa54
     */
    void RenderAnchoredGlyphWithAlpha(int nSlot,
                                      int nCharCode,
                                      int nPositionIndex,
                                      const S_VECTOR2 &offset,
                                      unsigned int nAlpha,
                                      bool bShadowPass,
                                      float flRotation,
                                      float flScaleX,
                                      float flScaleY);

    /**
     * @brief Emits one result-window part sprite by part id with a per-channel float colour.
     *
     * Looks up the part's placement rectangle by @p nPartId (device-selected parts table) and its
     * texture rectangle from the Colette part UV palette, then appends the quad through
     * @c appendSpriteToSlotRgba at @p position with the given rotation and scale. The three colour
     * channels arrive as floats and are truncated to byte channels. Part ids at or above the parts
     * table count are ignored.
     * @param nSlot The slot index (0 through 7).
     * @param nPartId The part id (below the parts table count).
     * @param position The sprite's world position.
     * @param nAlpha The sprite's alpha.
     * @param flRotation The sprite rotation, in radians.
     * @param flScaleX The sprite X scale.
     * @param flScaleY The sprite Y scale.
     * @param flRed The red channel (truncated to an integer).
     * @param flGreen The green channel (truncated to an integer).
     * @param flBlue The blue channel (truncated to an integer).
     * @ghidraAddress 0x769cc
     */
    void RenderPartSpriteByIndex(int nSlot,
                                 int nPartId,
                                 const S_VECTOR2 &position,
                                 unsigned int nAlpha,
                                 float flRotation,
                                 float flScaleX,
                                 float flScaleY,
                                 float flRed,
                                 float flGreen,
                                 float flBlue);

    /**
     * @brief Emits one result-window part sprite by part id, dimmable.
     *
     * Looks up the part's placement rectangle by @p nPartId (device-selected parts table) and its
     * texture rectangle from the Colette part UV palette, then appends the quad to the slot at
     * @p position with the given rotation and scale. Part ids at or above the parts table count are
     * ignored. The main pass draws at full intensity, the shadow pass at half.
     * @param nSlot The slot index (0 through 7).
     * @param nPartId The part id (below the parts table count).
     * @param position The sprite's world position.
     * @param nAlpha The sprite's alpha.
     * @param bShadowPass Whether this is the half-intensity shadow pass.
     * @param flRotation The sprite rotation, in radians.
     * @param flScaleX The sprite X scale.
     * @param flScaleY The sprite Y scale.
     * @ghidraAddress 0x76a98
     */
    void RenderPartSpriteWithAlpha(int nSlot,
                                   int nPartId,
                                   const S_VECTOR2 &position,
                                   unsigned int nAlpha,
                                   bool bShadowPass,
                                   float flRotation,
                                   float flScaleX,
                                   float flScaleY);

    /**
     * @brief Emits one glyph sprite from the phone parts table by part id, dimmable.
     *
     * Looks up the glyph's placement rectangle from the phone parts table indexed by @p nPartId and
     * its texture rectangle from the Colette glyph UV palette, then appends the quad to the slot at
     * @p position with the given rotation and scale. Part ids at or above the phone parts table count
     * are ignored. The main pass draws at full intensity, the dimmed pass at half.
     * @param nSlot The slot index (0 through 7).
     * @param nPartId The glyph part id (below the phone parts table count).
     * @param position The glyph's world position.
     * @param nAlpha The glyph alpha.
     * @param bDimmed Whether this is the half-intensity dimmed pass.
     * @param flRotation The glyph rotation, in radians.
     * @param flScaleX The glyph X scale.
     * @param flScaleY The glyph Y scale.
     * @ghidraAddress 0x79df0
     */
    void RenderDimmableGlyphFromTable(int nSlot,
                                      int nPartId,
                                      const S_VECTOR2 &position,
                                      unsigned int nAlpha,
                                      bool bDimmed,
                                      float flRotation,
                                      float flScaleX,
                                      float flScaleY);

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
    // +0x7c..+0x143: the panel's per-frame presentation state (page index, flick blend, handle,
    // per-side statistics, fade alphas, bonus values, and side colours) that the render pass reads;
    // the individual fields are still being worked out.
    unsigned char m_aReserved7c[0xc8] = {}; // +0x7c
    bool m_bBonusCueArmed = {};             // +0x144: whether the bonus voice cue is still pending.
    // +0x145..+0x147 is alignment padding before the bonus-cue timer.
    unsigned char m_aPad145[3] = {}; // +0x145
    float m_flBonusCueTimer = {};    // +0x148: time accumulated toward the bonus voice cue.
    // +0x14c..+0x157: further presentation state, still being worked out.
    unsigned char m_aReserved14c[0xc] = {}; // +0x14c
    // +0x158..+0x173: the seven result-bonus display values, computed by
    // PlayTask::ComputeResultBonusesAndExperience.
    float m_flClearBonus = {};     // +0x158: the clear bonus.
    float m_flMissBonus = {};      // +0x15c: the miss (full-combo/miss1/miss2) bonus.
    float m_flRankBonus = {};      // +0x160: the rank (B/A/AA/AAA/AAAP) bonus.
    float m_flFirstPlayBonus = {}; // +0x164: the first-play bonus (plus any pastel field bonus).
    float m_flHotMusicBonus = {};  // +0x168: the hot-music bonus.
    float m_flEarlyPlayBonus = {}; // +0x16c: the early-play bonus.
    float m_flExperienceBonus =
        {}; // +0x170: the experience-point total shown on the result screen.
    // +0x174..+0x17f: trailing presentation state to the allocation size.
    unsigned char m_aReserved174[0xc] = {}; // +0x174
};

// code: language=Objective-C++
// kate: hl Objective-C++;
// vim: set ft=objcpp :
