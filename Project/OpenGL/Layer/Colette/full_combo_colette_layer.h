/**
 * @file
 * The Colette-theme full-combo layer, @c FullComboColetteLayer.
 */

#pragma once

#include "playfieldlayerbase.h"

struct S_VECTOR2;

namespace ne {
class C_TEXTURE;
class C_SPRITE_INSTANCING_2D;
} // namespace ne

/**
 * The Colette-theme full-combo layer.
 *
 * A process-wide singleton, built on first access, deriving from @c PlayFieldLayerBase. It owns
 * three sprite instancers, drawn beneath the shared background layer, that present the Colette
 * full-combo effect (all three sharing the gm_parts2 atlas). The class carries no RTTI (it is
 * non-polymorphic), so the name is inferred from its singleton getter rather than confirmed from
 * the runtime metadata. The trailing @c // +0xNN comments document the original 32-bit offsets for
 * reference only.
 */
class FullComboColetteLayer : public PlayFieldLayerBase {
public:
    /**
     * The process-wide Colette full-combo layer, created on first use.
     * @return The shared layer.
     * @ghidraAddress 0x9b18c
     */
    static FullComboColetteLayer *shared();

    /**
     * Constructs the layer: chains the base-layer constructor and seeds the layout size,
     * leaving the texture, sprite, count, and effect state zero-cleared.
     * @ghidraAddress 0x9b118
     */
    FullComboColetteLayer();

    /**
     * Lazily builds the layer's textures and sprites: loads the atlas into each of the three
     * texture fields and creates the three sprite instancers (attaching each under the background
     * layer's render object, making it visible, binding its atlas, clearing its sprite count,
     * flagging additive blend on the middle slot, and enabling its two texture-environment
     * parameters).
     *
     * Guarded so the sprites are built only once.
     * @ghidraAddress 0x9b1dc
     */
    void InitializeBackgroundSpriteLayers();

    /**
     * Activates the full-combo effect for a player colour.
     * @param nColor The player colour (0 or 1).
     * @ghidraAddress 0x9b2e4
     */
    void CreateFullComboColette(unsigned int nColor);

    /**
     * Emits one full-combo sprite of the given type into its batch group.
     *
     * Looks up the sprite type's batch group, anchor, size, and UV-table index from the descriptor
     * table, and (while the group's batch has free capacity) appends a sprite at @p pPosition with
     * the given scale, rotation, and alpha. The colour is always opaque white modulated by
     * @p nAlpha. A no-op when the group's batch is full.
     * @param nType The sprite type (0 through 102).
     * @param pPosition The sprite position.
     * @param nAlpha The sprite alpha.
     * @param flScaleX The sprite x scale.
     * @param flScaleY The sprite y scale.
     * @param flRotation The sprite rotation, in radians.
     * @ghidraAddress 0x9c264
     */
    void CreateSprite(int nType,
                      const S_VECTOR2 *pPosition,
                      unsigned int nAlpha,
                      float flScaleX,
                      float flScaleY,
                      float flRotation);

    /**
     * Clears every player colour's full-combo effect active flag.
     *
     * The binary reuses this on the Classic and Limelight full-combo layers too, whose
     * effect-record arrays share this layout.
     * @ghidraAddress 0x9b35c
     */
    void ClearEffectFlags();

    /**
     * Whether any player colour's full-combo effect is currently active.
     * @return @c true when at least one effect record's active flag is set.
     * @ghidraAddress 0x9b378
     */
    bool IsAnyEffectActive() const;

    /**
     * Advances every active full-combo effect by one frame and emits its sprites.
     *
     * Returns early, clearing the instancers outright, when no effect is playing. Otherwise, for
     * every active player colour, advances the effect clock, fires the themed voice cue inside its
     * window, and emits seven groups: three fans of rising motes (2, 9, and 21 sprites), a strobing
     * fourth fan of 12, a centred flare pair, the ten @c FULLCOMBO! letters, and a final banner.
     * @param flDelta The elapsed frame time, in milliseconds.
     * @ghidraAddress 0x9b3a8
     */
    void Update(float flDelta);

    /** The number of full-combo sprite instancers the layer builds. */
    static constexpr int kSpriteSlotCount = 3;
    /** The number of player colours with a full-combo effect record. */
    static constexpr int kColorCount = 2;

private:
    struct EffectRecord {
        bool m_bActive = {}; /*!< Whether the effect is playing. +0x00 */
        // unsigned char m_aPad1[3]; // +0x01
        float m_flTimer = {};    /*!< The effect animation clock, in milliseconds. +0x04 */
        bool m_bVoiceFired = {}; /*!< Set once the effect has fired its themed voice cue. +0x08 */
        // unsigned char m_aPad9[3]; // +0x09
    };

    float m_flWidth = {};            // +0x08: 384.
    float m_flHeight = {};           // +0x0c: 1098.
    ne::C_TEXTURE *m_pTexture0 = {}; // +0x10: the gm_parts2 atlas.
    ne::C_TEXTURE *m_pTexture1 = {}; // +0x18: a second gm_parts2 handle.
    ne::C_TEXTURE *m_pTexture2 = {}; // +0x20: a third gm_parts2 handle.
    ne::C_SPRITE_INSTANCING_2D *m_apSprites[kSpriteSlotCount] = {}; // +0x28
    int m_aSpriteCounts[kSpriteSlotCount] = {};                     // +0x40
    bool m_bBuilt = {};                                             // +0x4c
    // unsigned char m_aPad4d[3]; // +0x4d
    EffectRecord m_aEffects[kColorCount] = {}; // +0x50
};
