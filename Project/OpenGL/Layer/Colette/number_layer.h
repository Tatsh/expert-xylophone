/**
 * @file
 * The score-digit number layer, @c NumberLayer.
 */

#pragma once

#include "playfieldlayerbase.h"
#include "s_vector2.h"

namespace ne {
class C_TEXTURE;
class C_SPRITE_INSTANCING_2D;
} // namespace ne

/**
 * The score-digit number layer.
 *
 * A process-wide singleton, built on first access, deriving from @c PlayFieldLayerBase. It owns two
 * atlases and two sprite instancers, drawn beneath the shared background layer, that present the
 * score digits. The class carries no RTTI (it is non-polymorphic), so the name is inferred from its
 * singleton getter rather than confirmed from the runtime metadata. The trailing @c // +0xNN
 * comments document the original 32-bit offsets for reference only.
 */
class NumberLayer : public PlayFieldLayerBase {
public:
    /**
     * The process-wide number layer, created on first use.
     * @return The shared layer.
     * @ghidraAddress 0x17dde0
     */
    static NumberLayer *shared();

    /**
     * Lazily builds the number layer's sprites: loads the two atlases and creates the two
     * sprite instancers (attaching each under the background layer's render object, making it
     * visible, binding its atlas, and seeding its sprite count).
     *
     * Guarded so the sprites are built only once.
     * @ghidraAddress 0x17de30
     */
    void InitializeNumberLayer();

    /** The number of number-layer sprite instancers the layer builds. */
    static constexpr int kSpriteSlotCount = 2;

    /**
     * Marks the number display ready to show and resets its frame counter.
     * @ghidraAddress 0x17df2c
     */
    void SetReady();

    /**
     * Clears the number display's ready flag.
     * @param flDuration A duration slot the routine never reads; every caller passes zero.
     * @ghidraAddress 0x17df3c
     */
    void ClearReady(float flDuration);

    /**
     * Whether the number display is ready to show (its intro is complete).
     * @return @c true once the intro is complete.
     */
    bool IsReady() const {
        return m_bReady;
    }

    /**
     * Advances the number display's intro animation one frame and re-emits its digit
     * markers.
     *
     * A no-op until the display is made ready. It advances the animation timer and turns the
     * display off once it runs out; otherwise it caches the viewport size, clears the sprite
     * batches, and re-emits each of the twelve digit markers (its base position, its alpha from the
     * per-digit envelope curve, and its scale from the per-digit scale curve) plus the leading
     * label marker (driven by its own scale and alpha curves). The phone layout halves the marker
     * scale.
     * @param flDelta The frame delta.
     * @ghidraAddress 0x17df44
     */
    void Process(float flDelta);

    /**
     * Appends one score-digit marker sprite to its batch at a world position, at the given
     * scale and alpha.
     *
     * A no-op when the target batch is full. The anchor, size, and atlas frame come from the shared
     * number-marker layout table (indexed by @p uMarkerIndex). The position is blended toward the
     * screen centre from @p pPosition: the phone (non-iPad) layout averages the point with the
     * field edge and adds half the cached viewport size on both axes; the iPad layout offsets only
     * the Y. The sprite is drawn opaque white at @p iAlpha.
     * @param uMarkerIndex The marker layout index (also the atlas-frame source).
     * @param pPosition The sprite's world position (adjusted in place).
     * @param iAlpha The sprite alpha (0 through 255).
     * @param flScaleW The sprite's X scale.
     * @param flScaleH The sprite's Y scale.
     * @ghidraAddress 0x17e1b4
     */
    void EmitMarkerSprite(unsigned int uMarkerIndex,
                          S_VECTOR2 *pPosition,
                          int iAlpha,
                          float flScaleW,
                          float flScaleH);

private:
    /**
     * Constructs the layer, chaining the base constructor and zero-clearing its own state.
     * @ghidraAddress 0x17dd98
     */
    NumberLayer();

    ne::C_TEXTURE *m_pPartsTexture = {};  // +0x08: the gm_parts2 atlas.
    ne::C_TEXTURE *m_pEffectTexture = {}; // +0x10: the ti_parts_eff atlas.
    ne::C_SPRITE_INSTANCING_2D *m_apSprites[kSpriteSlotCount] = {}; // +0x18
    int m_aSpriteCounts[kSpriteSlotCount] = {};                     // +0x28
    bool m_bBuilt = {};                                             // +0x30
    // unsigned char m_aPad31[3]; // +0x31..+0x33 (alignment padding, compiler-inserted)
    float m_flViewportWidth = {};  // +0x34
    float m_flViewportHeight = {}; // +0x38
    bool m_bReady = {};            // +0x3c
    // unsigned char m_aPad3d[3]; // +0x3d (alignment padding, compiler-inserted)
    float m_flAnimTime = {}; // +0x40
    // unsigned char m_aReserved44[4] = {}; // +0x44
};
