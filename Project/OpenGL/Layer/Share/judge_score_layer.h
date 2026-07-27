/**
 * @file
 * The judgement-score effect layer, @c JudgeScoreLayer.
 */

#pragma once

#include "playfieldlayerbase.h"

namespace ne {
class C_TEXTURE;
class C_SPRITE_INSTANCING;
} // namespace ne

/**
 * @brief The judgement-score effect layer: the score-burst sprites shown as notes are judged.
 *
 * A process-wide singleton, built on first access, deriving from @c PlayFieldLayerBase. It owns one
 * sprite instancer drawing from the @c gm_parts1 atlas and a pool of per-burst effect records. The
 * class carries no RTTI, so the name is inferred from its construction and render helpers. Only the
 * fields the reconstructed methods touch are modelled; the trailing @c // +0xNN comments document the
 * original offsets for reference only.
 * @ghidraAddress JudgeScoreLayer (engine effect layer, 0xa30 bytes)
 */
class JudgeScoreLayer : public PlayFieldLayerBase {
public:
    // The number of pooled score-burst effect records.
    static constexpr int kEffectRecordCount = 128;

    /**
     * @brief The process-wide judgement-score layer, created on first use.
     * @return The shared layer.
     * @ghidraAddress 0x18546c
     */
    static JudgeScoreLayer *shared();

    /**
     * @brief Builds the score-burst sprite batch and binds its atlas on first use.
     *
     * Loads the @c gm_parts1 atlas, creates the world sprite batch sized to the layer's capacity,
     * attaches it under the background layer, makes it visible, and flags its 3D path; on a
     * non-tutorial build it also seeds two texture parameters. Guarded so it runs only once.
     * @ghidraAddress 0x1854bc
     */
    void LoadSprites();

private:
    /**
     * @brief Constructs the layer: chains the base constructor, clears the sprite header and the
     * pooled effect records, and seeds the default scale pair to one.
     * @ghidraAddress 0x185408
     */
    JudgeScoreLayer();

    // One pooled score-burst effect record (20 bytes): its animation state.
    struct EffectRecord {
        unsigned char aReserved00[0x14] = {}; // +0x00: the burst's animation state.
    };

    ne::C_TEXTURE *m_pTexture = {};                   // +0x08: the gm_parts1 atlas.
    ne::C_SPRITE_INSTANCING *m_pSprite = {};          // +0x10: the score-burst sprite instancer.
    unsigned char m_aReserved18[4] = {};              // +0x18
    int m_nCapacity = {};                             // +0x1c: the sprite-batch capacity.
    bool m_bLoaded = {};                              // +0x20: set once the sprite batch is built.
    unsigned char m_aReserved21[3] = {};              // +0x21
    EffectRecord m_aEffects[kEffectRecordCount] = {}; // +0x24: the pooled burst records.
    float m_aScale[2] = {};                           // +0xa24: the default scale pair (one, one).
    unsigned char m_aReservedA2c[4] = {}; // +0xa2c: trailing state to the 0xa30-byte size.
};

// code: language=Objective-C++
// kate: hl Objective-C++;
// vim: set ft=objcpp :
