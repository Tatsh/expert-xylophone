/**
 * @file
 * The score-star effect layer, @c StarEffectLayer.
 */

#pragma once

#include "playfieldlayerbase.h"
#include "s_vector2.h"

namespace ne {
class C_SPRITE_INSTANCING;
} // namespace ne

/**
 * @brief The score-star effect layer.
 *
 * A process-wide singleton, built on first access, deriving from @c PlayFieldLayerBase. It animates
 * up to twelve score-star quads, each with a numeric label, through one sprite instancer. The
 * trailing @c // +0xNN comments document the original 32-bit offsets for reference only.
 */
class StarEffectLayer : public PlayFieldLayerBase {
public:
    // The number of animated star quads.
    static constexpr int kQuadCount = 12;

    /**
     * @brief The process-wide star effect layer, created on first use.
     * @ghidraAddress 0x1892fc
     */
    static StarEffectLayer *shared();

private:
    // Constructs the layer: clears the quad positions and records and seeds the default scale.
    // @ghidraAddress 0x189294
    StarEffectLayer();

    /** @brief One animated star quad: its activity, kind, timer, and numeric label. */
    struct StarQuad {
        bool bActive = {};              // +0x00: whether the quad is animating.
        unsigned char m_aPad01[3] = {}; // +0x01
        int nKind = {};                 // +0x04: the star kind, selecting its animation frame.
        float flTimer = {};             // +0x08: the quad's elapsed animation time.
        int nNumber = {};               // +0x0c: the numeric label drawn beside the quad.
    };

    void *m_pHandle = {};                     // +0x08: a retained handle.
    ne::C_SPRITE_INSTANCING *m_pSprites = {}; // +0x10: the star sprite instancer.
    int m_nSpriteCount = {};               // +0x18: the instancer's live sprite count this frame.
    S_VECTOR2 m_aQuadPos[kQuadCount] = {}; // +0x1c: each quad's screen position.
    int m_nState = {};                     // +0x7c: the layer's animation state.
    bool m_bCreated = {};                  // +0x80: set once the effect is created.
    unsigned char m_aPad81[3] = {};        // +0x81
    float m_flBaseSize = {};               // +0x84: the base sprite size the quads scale by.
    StarQuad m_aQuads[kQuadCount] = {};    // +0x88: the twelve quad records (end at +0x148).
    float m_flScaleA = {};                 // +0x148: the scale for the first six quads.
    float m_flScaleB = {};                 // +0x14c: the scale for the last six quads.
};

// code: language=Objective-C++
// kate: hl Objective-C++;
// vim: set ft=objcpp :
