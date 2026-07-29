/**
 * @file
 * The note chain-connector layer, @c ChainConnectorLayer.
 */

#pragma once

#include "playfieldlayerbase.h"

struct S_VECTOR2;

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
 * fields the reconstructed methods touch are modelled; the trailing @c // +0xNN comments document
 * the original offsets for reference only.
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
     * Creates the world sprite batch sized to the layer's capacity, attaches it under the
     * background layer, makes it visible, flags additive blend, (on a non-tutorial build) seeds two
     * texture parameters, and resets the shared connector draw count. Guarded so it runs only once.
     * @ghidraAddress 0x185894
     */
    void CreateSprites();

    /**
     * @brief Emits one connector sprite of the given type into the batch.
     *
     * Both types draw a fixed 14x16 quad anchored at (7, 0); the type only selects the UV-table
     * entry. Appends a sprite at @p pPosition with the given rotation and y-scale (x-scale is
     * unit), in opaque white modulated by @p nAlpha.
     * @param nType The connector sprite type (0 or 1).
     * @param pPosition The sprite position.
     * @param nAlpha The sprite alpha.
     * @param flRotation The sprite rotation, in radians.
     * @param flScaleY The sprite y scale.
     * @ghidraAddress 0x185b94
     */
    void CreateSprite(int nType,
                      const S_VECTOR2 *pPosition,
                      unsigned int nAlpha,
                      float flRotation,
                      float flScaleY);

    /**
     * @brief Enqueues one chain connector between two note endpoints for this frame.
     *
     * Finds the first free pooled record and stores the connector's colour (0 or 1) and its two
     * endpoints, then advances the shared draw count. Silently drops the connector when the pool is
     * full. The colour selects the connector sprite type; @c Update later resolves each active
     * record into a sprite.
     * @param nColor The connector colour (0 or 1).
     * @param flStartX The start endpoint's x (the sprite's position x).
     * @param flStartY The start endpoint's y (the sprite's position y).
     * @param flEndX The end endpoint's x.
     * @param flEndY The end endpoint's y.
     * @ghidraAddress 0x185944
     */
    void Create(int nColor, float flStartX, float flStartY, float flEndX, float flEndY);

    /**
     * @brief Resolves this frame's queued connectors into sprites and clears the queue.
     *
     * Derives the frame's connector alpha from the play colour and the rival-alpha setting (the
     * play side's connectors draw fully opaque, the rival side's at the scaled rival alpha), then
     * walks the pooled records. For each active record it clears the slot and forms the endpoint
     * delta; a connector at least one pixel long is oriented along the delta (its rotation from the
     * delta's angle plus a quarter turn), while a shorter one keeps a zero rotation. Either way its
     * length is scaled by one sixteenth into the sprite's y-scale, and a connector sprite of the
     * record's colour is emitted at that alpha. Finally it commits the batch's sprite count and
     * resets the shared draw count for the next frame.
     * @ghidraAddress 0x1859fc
     */
    void Update();

private:
    /**
     * @brief Constructs the layer: chains the base constructor, clears the sprite header and the
     * pooled chain records, and resets the shared connector draw count.
     * @ghidraAddress 0x1857e4
     */
    ChainConnectorLayer();

    // One pooled chain-connector record (24 bytes): a colour and the two endpoints a connector
    // spans.
    struct ChainRecord {
        bool bActive = {};   // +0x00: set while the record holds a queued connector.
        int nColor = {};     // +0x04: the connector colour (0 or 1), selecting the sprite type.
        float flStartX = {}; // +0x08: the start endpoint x (the sprite position x).
        float flStartY = {}; // +0x0c: the start endpoint y (the sprite position y).
        float flEndX = {};   // +0x10: the end endpoint x.
        float flEndY = {};   // +0x14: the end endpoint y.
    };

    ne::C_TEXTURE *m_pTexture = {};             // +0x08: the connector atlas.
    ne::C_SPRITE_INSTANCING_2D *m_pSprite = {}; // +0x10: the connector sprite instancer.
    int m_nSpriteCount = {};                    // +0x18: the batch's live sprite count.
    int m_nCapacity = {};                       // +0x1c: the sprite-batch capacity.
    bool m_bLoaded = {};                        // +0x20: set once the sprite batch is built.
    // unsigned char m_aReserved21[3] = {};        // +0x21
    ChainRecord m_aChains[kChainRecordCount] =
        {}; // +0x24: the pooled connector records (to 0xc24).
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
