/**
 * @file
 * The Limelight-theme layer, @c LimelightThemeLayer.
 */

#pragma once

#include "playfieldlayerbase.h"

namespace ne {
class C_TEXTURE;
class C_SPRITE_INSTANCING;
} // namespace ne

/**
 * @brief The Limelight-theme layer.
 *
 * A process-wide singleton, built on first access, deriving from @c PlayFieldLayerBase. It owns the
 * three full-combo atlases and four sprite instancers, drawn beneath the shared background layer,
 * that present the Limelight full-combo effect. The class carries no RTTI (it is non-polymorphic),
 * so the name is inferred from its singleton getter rather than confirmed from the runtime metadata.
 * The trailing @c // +0xNN comments document the original 32-bit offsets for reference only.
 */
class LimelightThemeLayer : public PlayFieldLayerBase {
public:
    /**
     * @brief The process-wide Limelight-theme layer, created on first use.
     * @return The shared layer.
     * @ghidraAddress 0x1206c8
     */
    static LimelightThemeLayer *shared();

    /**
     * @brief Lazily builds the full-combo layer's textures and sprites: loads the three atlases and
     * creates the four sprite instancers (attaching each under the background layer's render object,
     * making it visible, binding its atlas for the textured slots, seeding its sprite count, and
     * flagging additive blend on the last slot).
     *
     * Guarded so the sprites are built only once.
     * @ghidraAddress 0x120718
     */
    void InitFullComboLayerTextures();

    // The number of full-combo sprite instancers the layer builds.
    static constexpr int kSpriteSlotCount = 4;

private:
    /**
     * @brief Constructs the layer, chaining the base constructor and zero-clearing its own state.
     * @ghidraAddress 0x120630
     */
    LimelightThemeLayer();

    float m_flWidth = {};                 // +0x08: the layer's layout width (384).
    float m_flHeight = {};                // +0x0c: the layer's layout height (680).
    ne::C_TEXTURE *m_pPartsTexture = {};  // +0x10: the gm_parts2 atlas.
    ne::C_TEXTURE *m_pEffectTexture = {}; // +0x18: the ti_parts_eff atlas.
    ne::C_TEXTURE *m_pWinTexture = {};    // +0x20: the gm_win atlas.
    ne::C_SPRITE_INSTANCING *m_apSprites[kSpriteSlotCount] =
        {};                                     // +0x28: the per-slot sprite batches.
    int m_aSpriteCounts[kSpriteSlotCount] = {}; // +0x48: each slot's initial count.
    bool m_bBuilt = {};                         // +0x58: set once the sprites are built.
    // +0x59..+0x5b is alignment padding before the trailing state.
    unsigned char m_aPad59[3] = {}; // +0x59
    int m_nReserved5c = {};         // +0x5c: seeded to 1 by the constructor.
    bool m_bReserved60 = {};        // +0x60
    bool m_bReserved61 = {};        // +0x61
    unsigned char m_aPad62[2] = {}; // +0x62
    int m_nReserved64 = {};         // +0x64
    // +0x68..+0x87: further layer state (three 8-byte fields and one int the constructor zero-clears)
    // still being worked out, kept to preserve the allocation size.
    unsigned char m_aReserved68[0x20] = {}; // +0x68
    int m_aCellCounts[2] = {};              // +0x88: a two-entry {4, 4} cell-count record.
    // +0x90..+0x97: the remaining layer state, still being worked out.
    unsigned char m_aReserved90[8] = {}; // +0x90
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
