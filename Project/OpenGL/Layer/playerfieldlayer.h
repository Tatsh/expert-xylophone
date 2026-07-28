/**
 * @file
 * The player-field score layer, @c PlayerFieldLayer.
 */

#pragma once

#include "linear_tween.h"
#include "playfieldlayerbase.h"

struct S_VECTOR2;

namespace ne {
class C_TEXTURE;
class C_SPRITE_INSTANCING_2D;
} // namespace ne

/**
 * @brief One player side's score-digit roll-up tween: the target value and the animation it plays
 * to reach it.
 *
 * The trailing @c // +0xNN comments document the original 32-bit member offsets for reference only.
 */
struct ScoreDigitField {
    int nTarget = {};      // +0x00: the target score value.
    float flFrom = {};     // +0x04: the animation's start value (the current value when armed).
    float flTo = {};       // +0x08: the animation's end value (the target as a float).
    float flCurrent = {};  // +0x0c: the current animated value.
    float flElapsed = {};  // +0x10: the elapsed animation time.
    float flDuration = {}; // +0x14: the animation duration, in seconds.

    /**
     * @brief Rolls the animated value toward the target by @p flDeltaTime, snapping to the end value
     * once the duration is reached.
     * @ghidraAddress 0x18bd58
     */
    void Advance(float flDeltaTime);
};

/**
 * @brief The play-field layer that draws each side's rolling score digits and lane gauges.
 *
 * A process-wide singleton built on first access. The trailing @c // +0xNN comments document the
 * original 32-bit member offsets for reference only; the presentation-transform fields between the
 * base and the score records are still being worked out.
 */
class PlayerFieldLayer : public PlayFieldLayerBase {
public:
    // The number of player sides.
    static constexpr int kSideCount = 2;

    /**
     * @brief One score-digit glyph descriptor: its anchor, size, and UV-table index.
     *
     * The score-number layout tables are arrays of these, one entry per digit glyph; the update reads
     * a glyph's width to lay out the digit string and @c EmitScoreDigitSprite reads its anchor and
     * size and resolves its UV rectangle from the shared sprite-UV table.
     */
    struct ScoreDigitGlyph {
        float flAnchorX = {}; // +0x00: the glyph anchor x.
        float flAnchorY = {}; // +0x04: the glyph anchor y.
        float flSizeW = {};   // +0x08: the glyph width.
        float flSizeH = {};   // +0x0c: the glyph height.
        int nUvIndex = {};    // +0x10: the index into the shared sprite-UV table.
    };

    /**
     * @brief A player side's score-digit roll-up record.
     * @param uSide The player side.
     * @return The side's score-digit field.
     */
    ScoreDigitField &GetScoreDigitField(unsigned int uSide) {
        return m_aScoreFields[uSide];
    }

    // The score-number sprite-instancer capacity the layer builds.
    static constexpr unsigned int kSpriteCapacity = 0x14;

    /**
     * @brief The shared player-field layer, created on first use.
     * @return The shared player-field layer.
     * @ghidraAddress 0x18b668
     */
    static PlayerFieldLayer *shared();

    /**
     * @brief Lazily builds the score-number sprite: loads the gm_parts2 atlas and creates the sprite
     * instancer (attaching it under the background layer's render object, making it visible, binding
     * the atlas, and seeding its sprite count).
     *
     * Guarded so the sprite is built only once.
     * @ghidraAddress 0x18b6fc
     */
    void CreateScoreNumberSpriteBatch();

    /**
     * @brief Begins the score display's fade-in, easing it to fully opaque over @p flDuration
     * (snapping to opaque when the duration is non-positive).
     * @param flDuration The fade duration.
     * @ghidraAddress 0x18b784
     */
    void StartScoreFadeIn(float flDuration);

    /**
     * @brief Begins the score display's fade-out, easing it to transparent over @p flDuration
     * (snapping to transparent when the duration is non-positive).
     * @param flDuration The fade duration.
     * @ghidraAddress 0x18b7ac
     */
    void StartScoreFadeOut(float flDuration);

    /**
     * @brief Sets the side/layout flag, which indexes the per-side score X-alignment table.
     * @param nSide The side flag.
     * @ghidraAddress 0x18b7f4
     */
    void SetScoreSideFlag(int nSide);

    /**
     * @brief Sets one side's score-display position.
     * @param flValue The position value.
     * @param nSide The player side (selecting the first or second slot).
     * @ghidraAddress 0x18b7fc
     */
    void SetScorePosition(float flValue, int nSide);

    /**
     * @brief The per-frame score-display update: advances the fade and rolls each side's score-digit
     * counter, then lays out and emits each side's digit string.
     *
     * Advances the layer's fade channel, then for each of the two player sides: rolls the side's
     * animated score counter, decodes its current value into decimal digits, measures the string
     * width from the orientation's glyph-advance table, resolves the side's base position (folding in
     * a one-shot per-side offset), centres the string about the play field (mirroring the layout and
     * applying a half-turn glyph rotation on the flagged side), and emits each digit right to left
     * with the fade-scaled alpha. Finally it publishes the sprite count to the instancer.
     * @param flDeltaTime The frame delta.
     * @ghidraAddress 0x18b810
     */
    void Update(float flDeltaTime);

private:
    /**
     * @brief Emits one score-digit glyph quad into the score sprite batch.
     *
     * Writes the next sprite slot with the caller's position, the glyph descriptor's anchor and
     * size, the UV rectangle resolved from the descriptor's UV index, the caller's rotation and
     * uniform scale, and opaque white modulated by @p nAlpha; then advances the sprite count.
     * @param pPosition The glyph's screen position.
     * @param nAlpha The glyph alpha.
     * @param glyph The glyph descriptor (anchor, size, and UV index).
     * @param flRotation The glyph rotation, in radians.
     * @param flScale The glyph's uniform scale.
     * @ghidraAddress 0x18bc4c
     */
    void EmitScoreDigitSprite(const S_VECTOR2 &position,
                              int nAlpha,
                              const ScoreDigitGlyph &glyph,
                              float flRotation,
                              float flScale);

    ne::C_TEXTURE *m_pTexture = {};             // +0x08: the score-number atlas (gm_parts2).
    ne::C_SPRITE_INSTANCING_2D *m_pSprite = {}; // +0x10: the score-number sprite instancer.
    int m_nSpriteCount = {};                    // +0x18: the instancer's initial sprite count.
    bool m_bBuilt = {};                         // +0x1c: set once the score sprite is built.
    int m_nScoreSideFlag = {}; // +0x20: the side/layout flag indexing the score X-alignment table.
    LinearTween m_fadeChannel; // +0x24: the score display's fade channel.
    float m_aScorePosition[kSideCount] = {};         // +0x38: each side's score-display position.
    ScoreDigitField m_aScoreFields[kSideCount] = {}; // +0x40: the per-side score-digit records.
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
