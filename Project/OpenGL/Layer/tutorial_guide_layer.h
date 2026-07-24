/**
 * @file
 * The tutorial-guide layer, @c TutorialGuideLayer.
 */

#pragma once

#include "playfieldlayerbase.h"

namespace ne {
class C_TEXTURE;
class C_SPRITE_INSTANCING;
} // namespace ne

/**
 * @brief The tutorial-guide layer.
 *
 * A process-wide singleton, built on first access, deriving from @c PlayFieldLayerBase. It presents
 * the tap-tutorial guide: a 20-sprite instancer plus a set of hard-coded keyframe timings and two
 * per-step coordinate grids, laid out so the guide sweeps a row of taps across the play field. The
 * class carries no RTTI (it is non-polymorphic), so the name is inferred from its singleton getter
 * rather than confirmed from the runtime metadata. The trailing @c // +0xNN comments document the
 * original 32-bit offsets for reference only.
 */
class TutorialGuideLayer : public PlayFieldLayerBase {
public:
    // The number of keyframe steps in the guide sweep.
    static constexpr int kKeyframeCount = 9;
    // The two grid dimensions filled per keyframe: kGridRows rows of kGridColumns entries.
    static constexpr int kGridRows = 4;
    static constexpr int kGridColumns = 6;
    // The sprite-instancer capacity the guide builds.
    static constexpr unsigned int kSpriteCapacity = 0x14;

    /**
     * @brief The process-wide tutorial-guide layer, created on first use.
     * @return The shared layer.
     * @ghidraAddress 0x10b3b0
     */
    static TutorialGuideLayer *shared();

    /**
     * @brief Lazily builds the guide's sprite and its keyframe and coordinate tables.
     *
     * Loads the tutorial atlas, creates the 20-sprite instancer (registered in the global scene
     * tree, made visible, and bound to the atlas), then seeds the nine keyframe timings and the
     * frame-index and coordinate tables and fills the two per-step coordinate grids by adding each
     * keyframe's base X to the shared per-column offset tables. Guarded so the tables are built only
     * once (but the transient visibility byte is always cleared first).
     * @ghidraAddress 0x10b44c
     */
    void BuildTutorialGuideSpriteTable();

private:
    // A keyframe step: the guide sweeps its taps from a start X to an end X over one step.
    struct Keyframe {
        float flStartX = {}; // +0x00
        float flEndX = {};   // +0x04
        int nStep = {};      // +0x08
    };

    // One coordinate-grid entry: an X position and a tag (a sprite frame or enable flag).
    struct CoordEntry {
        float flX = {};         // +0x00
        unsigned int nTag = {}; // +0x04
    };

    unsigned char m_aReserved08[8] =
        {};                         // +0x08: transient state; the low byte is cleared each call.
    ne::C_TEXTURE *m_pTexture = {}; // +0x10: the gm_tutorial atlas.
    ne::C_SPRITE_INSTANCING *m_pSprite = {}; // +0x18: the guide sprite instancer.
    int m_nSpriteCount = {};                 // +0x20: the instancer's initial sprite count.
    bool m_bBuilt = {};                      // +0x24: set once the tables are built.
    unsigned char m_aReserved25[0x1b] = {};  // +0x25: further layer state, still being worked out.
    Keyframe m_aKeyframes[kKeyframeCount] = {}; // +0x40: the nine keyframe timings.
    int m_nStepHi0 = {};                        // +0xac: a trailing step index (14).
    int m_nStepHi1 = {};                        // +0xb0: a trailing step index (15).
    int m_aFrameIndices[7] = {};                // +0xb4: sprite frame indices (16 through 22).
    float m_aCoords[8] = {};                    // +0xd0: four screen-coordinate pairs.
    // +0xf0: the two per-step coordinate grids, filled from the keyframes and the per-column offset
    // tables. The first drives one sprite set, the second (kGridBias entries later) the other.
    CoordEntry m_aGridA[kKeyframeCount][kGridRows][kGridColumns] = {}; // +0xf0
    CoordEntry m_aGridB[kKeyframeCount][kGridRows][kGridColumns] = {}; // +0x7b0
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
