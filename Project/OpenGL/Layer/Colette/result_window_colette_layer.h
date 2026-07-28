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
class C_SPRITE_INSTANCING_2D;
class C_TEXTURE;
} // namespace ne

/**
 * @brief One result-panel touch hit-region: the tracked touch id and its press, tap-edge, and
 * enabled flags. The input pass claims a touch inside the region's anchor box and reports a press or
 * a tap-edge (a press that ended inside).
 */
struct ResultTouchRegion {
    int nTouchId = {};              // +0x00: the tracked touch id (-1 when none).
    bool bDown = {};                // +0x04: whether a touch is currently inside the region.
    bool bTapEdge = {};             // +0x05: latched when a press ends inside the region.
    bool bEnabled = {};             // +0x06: whether the region accepts input this frame.
    unsigned char m_aPad07[1] = {}; // +0x07
};

/**
 * @brief One result-panel display animation channel: a value easing from @c flFrom to @c flTo over
 * @c flDuration, with the interpolated result held in @c flCurrent.
 */
struct ResultTweenChannel {
    float flFrom = {};     // +0x00: the start value.
    float flTo = {};       // +0x04: the target value.
    float flDuration = {}; // +0x08: the tween duration.
    float flElapsed = {};  // +0x0c: the elapsed time.
    float flReserved = {}; // +0x10: an unused slot.
    float flCurrent = {};  // +0x14: the current interpolated value.
};

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
    // The number of open/close display animation channels.
    static constexpr int kTweenChannelCount = 5;
    // The number of touch hit-regions the input pass tracks.
    static constexpr int kTouchRegionCount = 4;

    /**
     * @brief The process-wide Colette result-window layer, created on first use.
     * @return The shared layer.
     * @ghidraAddress 0x73edc
     */
    static ResultWindowColetteLayer *shared();

    /** @brief Whether a tutorial touch was just released this frame (the tutorial advance gate). */
    bool IsTutorialTouchEnded() const {
        return m_bTutorialTouchEnded;
    }

    /** @brief Whether a flick changed the result page this frame. */
    bool IsPageDirty() const {
        return m_bPageDirty;
    }

    /** @brief The current result page index (0 or 1), also the running/initialised marker. */
    int GetActivePage() const {
        return m_nActive;
    }

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
     * @brief Initialises the result-screen state flags at the start of the result screen.
     *
     * Marks the panel active, arms the bonus voice cue when the game system's result-bonus feature is
     * set, resets the bonus-cue timer, and records whether the Twitter share API is available.
     * @ghidraAddress 0x7ab54
     */
    void InitializeResultScreenFlags();

    /**
     * @brief Starts the result panel's show animation: keyframes the alpha channel to fully opaque
     * and the four offset/scale channels in from their start values over @p flDuration, with a
     * per-channel stagger that cascades them (snapping the alpha immediately when non-positive).
     * @param flDuration The animation duration.
     * @ghidraAddress 0x740ec
     */
    void StartShowTween(float flDuration);

    /**
     * @brief Starts the result panel's hide animation: keyframes each display animation channel from
     * its current shown value toward zero over @p flDuration (snapping immediately when
     * non-positive) and clears the panel-active flag.
     * @param flDuration The animation duration.
     * @ghidraAddress 0x74190
     */
    void StartHideTween(float flDuration);

    /**
     * @brief Updates the four touch hit-regions: claims or tracks one touch per region against its
     * anchor box, reporting a press (@c bDown) and latching a tap-edge when a press ends inside.
     * @ghidraAddress 0x744cc
     */
    void UpdateTouchHitRegions();

    /**
     * @brief The result screen's per-frame input pass: gates on the fade-in, tracks a vertical swipe
     * to toggle the result page and fire its sound, updates the touch hit-regions, and posts the
     * Twitter share when its region is tapped.
     * @ghidraAddress 0x7427c
     */
    void ProcessResultScreenInput();

    /**
     * @brief The phone-layout result input pass: like @c ProcessResultScreenInput but gates the
     * interactive flags by the tutorial game phase and detects a horizontal flick (setting the page
     * dirty flag) rather than a vertical swipe.
     * @ghidraAddress 0x74c70
     */
    void UpdateResultTouchInput();

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
     * @brief Resolves a non-phone anchor-box position by index, offset relative to the play field.
     *
     * The non-phone counterpart of @c getPosition_Phone using 20-byte @c AnchorBoxRecord entries.
     * Selects one of three tables — the pad table when the layer is on an iPad, otherwise the
     * portrait or default table by the orientation flag — copies the record's leading 16-byte box
     * into @p pOutRect, then shifts the box origin by the play-field viewport's half or full width
     * and height according to the record's anchor mode.
     * @param nIndex The record index.
     * @param pOutRect Receives the resolved box.
     * @ghidraAddress 0x73ce4
     */
    void getPosition(int nIndex, PhoneLayoutRect *pOutRect) const;

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
     * @brief Renders a non-negative integer as a row of parts-atlas digit sprites.
     *
     * Extracts @p nDigitCount base-ten digits of @p nValue (least significant first) into a local
     * buffer, then draws the significant digits right to left, walking downward through the layout
     * position bank from @p nBasePositionIndex, each glyph part id being @p nDigitPartBase plus the
     * digit. In wide-leading mode an all-zero value still draws its two low slots, the leading digit
     * takes the family's wider variant and also draws an under-digit prefix glyph beneath itself, and
     * (when @p bDrawPrefix is also set) a standalone prefix glyph is drawn before the whole number.
     * Optional left padding fills the unused leading slots with the family's '0' glyph at a dimmed
     * alpha. When the base position index is the achievement-rate sentinel, a trailing slash or dot
     * separator is drawn, selected by @p flRed.
     * @param nValue The non-negative integer to render.
     * @param nDigitCount The number of digit slots.
     * @param nBasePositionIndex The base layout position-bank index (the row is drawn downward).
     * @param nDigitPartBase The base part id of the digit family (the digit is added to it).
     * @param bWideLeading Whether to draw the wider leading-digit variant with its under-digit prefix.
     * @param bDrawPrefix Whether to draw the family's standalone prefix glyph before the number.
     * @param bLeftPad Whether to fill the unused leading slots with a dimmed padding glyph.
     * @param nAlpha The glyph alpha, in @c [0, 255].
     * @param flRotation The sprite rotation slot (in the @c s0 register); accepted but unused, as the
     * digits always draw upright.
     * @param flRed The red colour channel, which also discriminates the rate separator glyph.
     * @param flGreen The green colour channel.
     * @param flBlue The blue colour channel.
     * @ghidraAddress 0x76ce8
     */
    void RenderNumberDigitsAsParts(int nValue,
                                   int nDigitCount,
                                   int nBasePositionIndex,
                                   int nDigitPartBase,
                                   bool bWideLeading,
                                   bool bDrawPrefix,
                                   bool bLeftPad,
                                   unsigned int nAlpha,
                                   float flRotation,
                                   float flRed,
                                   float flGreen,
                                   float flBlue);

    /**
     * @brief Renders a non-negative integer as a row of proportionally-spaced digit sprites.
     *
     * The proportional-spacing twin of @c RenderNumberDigitsAsParts: rather than stepping through the
     * layout position bank, it seeds an X cursor from the base position and advances it by each
     * glyph's measured width (the device-selected parts record's width field). It draws the
     * significant digits right to left from the seeded position, offsetting the cursor left by half
     * the widened leading digit, the prefix glyphs, and each drawn digit; the leading digit takes the
     * family's wider variant with an under-digit prefix, a standalone prefix glyph is drawn first when
     * the prefix flag is set, and optional left padding fills the unused leading slots.
     * @param nValue The non-negative integer to render.
     * @param nDigitCount The number of digit slots.
     * @param nBasePositionIndex The layout position-bank index seeding the X cursor.
     * @param nDigitPartBase The base part id of the digit family (the digit is added to it).
     * @param bWideLeading Whether to draw the wider leading-digit variant with its under-digit and
     * standalone prefix glyphs (a single flag gating the whole prefix path).
     * @param bLeftPad Whether to fill the unused leading slots with a dimmed padding glyph.
     * @param nAlpha The glyph alpha, in @c [0, 255].
     * @param flRed The red colour channel.
     * @param flGreen The green colour channel.
     * @param flBlue The blue colour channel.
     * @ghidraAddress 0x77118
     */
    void RenderNumberDigitsProportional(int nValue,
                                        int nDigitCount,
                                        int nBasePositionIndex,
                                        int nDigitPartBase,
                                        bool bWideLeading,
                                        bool bLeftPad,
                                        unsigned int nAlpha,
                                        float flRed,
                                        float flGreen,
                                        float flBlue);

    /**
     * @brief Renders two numbers separated by a slash as monospaced parts-atlas digit sprites.
     *
     * Draws @p nLeftValue and @p nRightValue (each up to four significant digits, rank-family digits)
     * as a "left/right" pair centred on the base position, advancing a proportional cursor by the
     * monospace '0'-glyph width. The right number is drawn first (rightmost), then the slash
     * separator, then the left number, each stepping the cursor left by the digit width. The left and
     * right numbers take their colours from the bonus palette by @p nLeftColorIndex and
     * @p nRightColorIndex.
     * @param nLeftValue The left number (drawn after the separator).
     * @param nRightValue The right number (drawn first, rightmost).
     * @param pBasePosition The pair's base position (the cursor is centred on it).
     * @param nAlpha The glyph alpha, in @c [0, 255].
     * @param nLeftColorIndex The bonus-palette colour index for the left number.
     * @param nRightColorIndex The bonus-palette colour index for the right number and the separator.
     * @ghidraAddress 0x77654
     */
    void RenderNumberPairWithSeparator(int nLeftValue,
                                       int nRightValue,
                                       const S_VECTOR2 *pBasePosition,
                                       unsigned int nAlpha,
                                       int nLeftColorIndex,
                                       int nRightColorIndex);

    /**
     * @brief Constructs the layer: chains the base-layer constructor and zero-clears its state,
     * seeding the swipe touch id and the four touch-region touch ids to the "none" sentinel (-1).
     * The binary inlines this into @c shared (0x73edc).
     * @ghidraAddress 0x7aba8
     */
    ResultWindowColetteLayer();

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

    /**
     * @brief Emits one glyph sprite from the phone parts table by part id, with an explicit
     * per-vertex colour.
     *
     * The non-dimmable colour twin of @c RenderDimmableGlyphFromTable: it looks up the glyph's
     * placement rectangle from the phone parts table indexed by @p nPartId and its texture rectangle
     * from the Colette glyph UV palette, then appends the quad to the slot at @p position with the
     * given rotation, scale, and red, green, and blue channels. Part ids at or above the phone parts
     * table count are ignored.
     * @param nSlot The slot index (0 through 7).
     * @param nPartId The glyph part id (below the phone parts table count).
     * @param position The glyph's world position.
     * @param nAlpha The glyph alpha.
     * @param nRed The glyph's red channel.
     * @param nGreen The glyph's green channel.
     * @param nBlue The glyph's blue channel.
     * @param flRotation The glyph rotation, in radians.
     * @param flScaleX The glyph X scale.
     * @param flScaleY The glyph Y scale.
     * @ghidraAddress 0x79d54
     */
    void RenderGlyphPartFromTable(int nSlot,
                                  int nPartId,
                                  const S_VECTOR2 &position,
                                  unsigned int nAlpha,
                                  unsigned int nRed,
                                  unsigned int nGreen,
                                  unsigned int nBlue,
                                  float flRotation,
                                  float flScaleX,
                                  float flScaleY);

    // +0x08/+0x09: the tutorial touch-hint flags the touch pass drives from the live touch count
    // (whether a touch is present, and whether one was just released).
    bool m_bTutorialTouchPresent = {}; // +0x08
    bool m_bTutorialTouchEnded = {};   // +0x09
    bool m_bPageDirty = {}; // +0x0a: set when a flick changes the result page this frame.
    // +0x0b..+0x0f: presentation-transform state seeded by the constructor, whose individual fields
    // are still being worked out.
    unsigned char m_aReserved0b[5] = {};      // +0x0b
    ne::C_TEXTURE *m_pBackgroundTexture = {}; // +0x10: the selection-background texture.
    ne::C_TEXTURE *m_pPartsTexture = {};      // +0x18: the result-parts atlas texture, bound to the
                                              //        parts slot.
    ne::C_TEXTURE *m_pOverlayTexture = {};    // +0x20: the texture bound to the overlay slot; not
                                              //        set by the sprite builder.
    ne::C_SPRITE_INSTANCING_2D *m_apSlots[kSlotCount] =
        {};                // +0x28: the eight sprite-instancer nodes.
    bool m_bBuilt = {};    // +0x68: whether the sprite instancers have been built.
    bool m_bPortrait = {}; // +0x69: selects the portrait anchor-position table.
    // +0x6a..+0x6b is alignment padding before the glyph-table base indices.
    unsigned char m_aPad6a[2] = {}; // +0x6a
    int m_nGlyphBaseA = {};         // +0x6c: glyph-table base index A (0x4e).
    int m_nGlyphBaseB = {};         // +0x70: glyph-table base index B (0x45).
    int m_nGlyphBaseC = {};         // +0x74: glyph-table base index C (0x3a).
    float m_flPartsScale = {};      // +0x78: the parts-sprite scale (1.0).
    int m_nActive = {};             // +0x7c: set once the result screen is initialised and running.
    float m_flSwipeDir = {};        // +0x80: the last vertical swipe direction (+1 up, -1 down).
    // +0x84: the four touch hit-regions the input pass tracks.
    ResultTouchRegion m_aTouchRegion[kTouchRegionCount] = {}; // +0x84
    int m_nSwipeTouchId = {};   // +0xa4: the tracked swipe touch id (-1 when none).
    float m_flSwipeStartY = {}; // +0xa8: the swipe touch's start Y, for the up/down threshold test.
    // +0xac..+0xcb: further per-frame presentation state, still being worked out.
    unsigned char m_aReservedAc[0x20] = {}; // +0xac
    // +0xcc: the five open/close display animation channels (an alpha fade plus four offset/scale
    // channels) the show and hide tweens keyframe.
    ResultTweenChannel m_aTween[kTweenChannelCount] = {}; // +0xcc
    bool m_bBonusCueArmed = {}; // +0x144: whether the bonus voice cue is still pending.
    // +0x145..+0x147 is alignment padding before the bonus-cue timer.
    unsigned char m_aPad145[3] = {}; // +0x145
    float m_flBonusCueTimer = {};    // +0x148: time accumulated toward the bonus voice cue.
    // +0x14c..+0x153: further presentation state, still being worked out.
    unsigned char m_aReserved14c[8] = {}; // +0x14c
    bool m_bTwitterAvailable = {};        // +0x154: whether the Twitter share API is available.
    // +0x155..+0x157 is alignment padding before the bonus values.
    unsigned char m_aPad155[3] = {}; // +0x155
    // +0x158..+0x173: the seven result-bonus display values, computed by
    // rb::GameScene::ComputeResultBonusesAndExperience.
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
