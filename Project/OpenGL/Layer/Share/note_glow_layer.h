/**
 * @file
 * The note-glow (combo/aura) effect layer, @c NoteGlowLayer.
 */

#pragma once

#include "playfieldlayerbase.h"

struct S_VECTOR2;

namespace ne {
class C_TEXTURE;
class C_SPRITE_INSTANCING_2D;
} // namespace ne

/**
 * The small note-glow effect layer (the combo/aura glow shown at note-render time).
 *
 * A process-wide singleton, built on first access, deriving from @c PlayFieldLayerBase. The class
 * carries no RTTI, so the name is inferred from its @c GetNoteGlowLayer accessor and render-time
 * use. Only the fields the reconstructed methods touch are modelled; the trailing @c // +0xNN
 * comments document the original offsets for reference only.
 *
 * Reconstructed type @c NoteGlowLayer: engine effect layer, 0x40 bytes.
 */
class NoteGlowLayer : public PlayFieldLayerBase {
public:
    /**
     * The process-wide note-glow layer, created on first use.
     * @return The shared layer.
     * @ghidraAddress 0x1769a8
     */
    static NoteGlowLayer *shared();

    /**
     * Refreshes the theme and rebinds the @c gm_parts1 atlas to the sprite instancer.
     *
     * A no-op until the sprite instancer has been built.
     * @ghidraAddress 0x176a84
     */
    void SetTexture();

    /**
     * Builds the glow sprite batch and binds its atlas on first use.
     *
     * Loads the @c gm_parts1 atlas, creates a two-sprite world batch attached under the background
     * layer, makes it visible, and flags additive blend. Guarded so it runs only once.
     * @ghidraAddress 0x1769f8
     */
    void InitializeSprites();

    /**
     * Triggers the glow effect for one player colour.
     *
     * Builds the sprite batch on first use, then activates the colour's effect slot and resets its
     * timer.
     * @param nColor The player colour (0 or 1).
     * @ghidraAddress 0x176ad8
     */
    void CreateEffect(unsigned int nColor);

    /**
     * Advances and redraws each active per-colour glow for the frame.
     *
     * Resets the sprite count, then for each colour advances its animation timer; a glow past its
     * lifetime is deactivated, otherwise its bar sprite is emitted centred on the play field,
     * mirrored for the non-play colour, faded out by the timer, and scaled by the colour's scale.
     * Finally commits the sprite count to the instancer.
     * @param flDelta The frame's elapsed time, in frames.
     * @ghidraAddress 0x176b64
     */
    void Process(float flDelta);

    /** The number of player colours the glow tracks. */
    static constexpr int kColorCount = 2;

private:
    /**
     * Emits one glow bar sprite for a colour into the batch.
     *
     * Resolves the colour's atlas UV, writes the next sprite with a fixed anchor and bar size, the
     * caller's position, the given horizontal scale and rotation, and opaque white modulated by the
     * alpha, then advances the sprite count.
     * @param nColor The player colour (0 or 1), selecting the atlas UV row.
     * @param pPosition The bar's centre position.
     * @param nAlpha The bar's alpha.
     * @param flScale The bar's horizontal scale.
     * @param flRotation The bar's rotation, in radians.
     * @ghidraAddress 0x176cb0
     */
    void EmitGlowSprite(unsigned int nColor,
                        const S_VECTOR2 *pPosition,
                        int nAlpha,
                        float flScale,
                        float flRotation);

    /** One per-colour glow effect slot: its active flag and animation timer. */
    struct EffectSlot {
        bool bActive = {}; /*!< Whether the colour's glow is animating. +0x00 */
        // unsigned char aReserved01[3] = {}; // +0x01
        float flTimer = {}; /*!< The glow's animation timer, in frames. +0x04 */
    };

    /**
     * Constructs the layer: chains the base constructor, clears the sprite header and count
     * state, and seeds the default scale pair to one.
     * @ghidraAddress 0x176964
     */
    NoteGlowLayer();

    ne::C_TEXTURE *m_pTexture = {};             // +0x08
    ne::C_SPRITE_INSTANCING_2D *m_pSprite = {}; // +0x10
    int m_nSpriteCount = {};                    // +0x18: reset each frame.
    int m_nCapacity = {};                       // +0x1c
    bool m_bLoaded = {};                        // +0x20
    // unsigned char m_aReserved21[3] = {};        // +0x21
    EffectSlot m_aEffects[kColorCount] = {}; // +0x24: stride 8.
    float m_aScale[2] = {};                  // +0x34: defaults to (1, 1).
    // unsigned char m_aReserved3c[4] = {};        // +0x3c: trailing state to the 0x40-byte size.
};
