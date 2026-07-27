/**
 * @file
 * The note chain-connector layer, @c ChainConnectorLayer.
 */

#pragma once

#include "playfieldlayerbase.h"

namespace ne {
class C_TEXTURE;
class C_SPRITE_INSTANCING_2D;
} // namespace ne

// The shared chain-connector draw count, reset when the layer is constructed.
extern int g_nChainConnectorDrawCount; // @ghidraAddress 0x3def48

/**
 * @brief The note chain-connector layer: the connector sprites drawn between chained notes.
 *
 * A process-wide singleton, built on first access, deriving from @c PlayFieldLayerBase. The class
 * carries no RTTI, so the name is inferred from its @c GetChainConnectorLayer accessor. Only the
 * fields the reconstructed methods touch are modelled; the trailing @c // +0xNN comments document the
 * original offsets for reference only.
 * @ghidraAddress ChainConnectorLayer (engine effect layer, 0xc28 bytes)
 */
class ChainConnectorLayer : public PlayFieldLayerBase {
public:
    // The number of pooled chain-connector records.
    static constexpr int kChainRecordCount = 128;

    /**
     * @brief The process-wide chain-connector layer, created on first use.
     * @return The shared layer.
     * @ghidraAddress 0x185844
     */
    static ChainConnectorLayer *shared();

    /**
     * @brief Builds the gm_parts1 connector sprite batch and binds its atlas on first use.
     *
     * Creates the world sprite batch sized to the layer's capacity, attaches it under the background
     * layer, makes it visible, flags additive blend, (on a non-tutorial build) seeds two texture
     * parameters, and resets the shared connector draw count. Guarded so it runs only once.
     * @ghidraAddress 0x185894
     */
    void CreateSprites();

private:
    /**
     * @brief Constructs the layer: chains the base constructor, clears the sprite header and the
     * pooled chain records, and resets the shared connector draw count.
     * @ghidraAddress 0x1857e4
     */
    ChainConnectorLayer();

    // One pooled chain-connector record (24 bytes): its per-connector animation state.
    struct ChainRecord {
        unsigned char aReserved00[0x18] = {}; // +0x00: the connector's animation state.
    };

    ne::C_TEXTURE *m_pTexture = {};             // +0x08: the connector atlas.
    ne::C_SPRITE_INSTANCING_2D *m_pSprite = {}; // +0x10: the connector sprite instancer.
    unsigned char m_aReserved18[4] = {};        // +0x18
    int m_nCapacity = {};                       // +0x1c: the sprite-batch capacity.
    bool m_bLoaded = {};                        // +0x20: set once the sprite batch is built.
    unsigned char m_aReserved21[7] = {};        // +0x21
    ChainRecord m_aChains[kChainRecordCount] =
        {}; // +0x28: the pooled connector records (to 0xc28).
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
