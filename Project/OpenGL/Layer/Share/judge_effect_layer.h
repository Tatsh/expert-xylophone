/**
 * @file
 * The judge-effect layer, @c JudgeEffectLayer.
 */

#pragma once

#include "playfieldlayerbase.h"

namespace ne {
class C_TEXTURE;
class C_SPRITE_INSTANCING;
} // namespace ne

/**
 * @brief The judge-effect layer (the COOL/GREAT/GOOD/BAD hit-judgement graphics).
 *
 * A process-wide singleton, built on first access, deriving from @c PlayFieldLayerBase. It owns one
 * atlas and one sprite instancer, drawn beneath the shared background layer, that presents the
 * hit-judgement graphics. The class carries no RTTI (it is non-polymorphic), so the name is inferred
 * from its singleton getter rather than confirmed from the runtime metadata. The trailing @c // +0xNN
 * comments document the original 32-bit offsets for reference only.
 */
class JudgeEffectLayer : public PlayFieldLayerBase {
public:
    // The sprite-instancer capacity the layer builds.
    static constexpr unsigned int kSpriteCapacity = 0x14;

    /**
     * @brief The process-wide judge-effect layer, created on first use.
     * @return The shared layer.
     * @ghidraAddress 0x184c28
     */
    static JudgeEffectLayer *shared();

    /**
     * @brief Lazily builds the judge-effect sprite: loads the gm_parts2 atlas and creates the sprite
     * instancer (attaching it under the background layer's render object, making it visible, binding
     * the atlas, and seeding its sprite count).
     *
     * Guarded so the sprite is built only once.
     * @ghidraAddress 0x184c78
     */
    void LoadJudgeEffectSprites();

    /**
     * @brief Arms a lane's judgement score/combo popup effect.
     *
     * Marks the lane's record active, stores the displayed score and judgement type, and resets its
     * animation timer.
     * @param nLane The lane (0 or 1).
     * @param nScore The score value to show.
     * @param nJudgeType The judgement kind.
     * @ghidraAddress 0x184d48
     */
    void TriggerJudgeEffect(unsigned int nLane, unsigned int nScore, unsigned int nJudgeType);

private:
    /**
     * @brief Constructs the layer, chaining the base constructor and zero-clearing its own state.
     * @ghidraAddress 0x184bb0
     */
    JudgeEffectLayer();

    // A per-lane judge popup record.
    struct JudgeRecord {
        bool m_bActive = {};            // +0x00: whether the popup is showing.
        unsigned char m_aPad01[3] = {}; // +0x01
        unsigned int m_nScore = {};     // +0x04: the displayed score value.
        unsigned int m_nJudgeType = {}; // +0x08: the judgement kind.
        int m_nTimer = {};              // +0x0c: the popup animation timer.
    };

    ne::C_TEXTURE *m_pTexture = {};          // +0x08: the gm_parts2 atlas.
    ne::C_SPRITE_INSTANCING *m_pSprite = {}; // +0x10: the judge-effect sprite instancer.
    int m_nSpriteCount = {};                 // +0x18: the instancer's initial sprite count.
    bool m_bBuilt = {};                      // +0x1c: set once the sprite is built.
    unsigned char m_aReserved20[0x10] = {};  // +0x20: further layer state, still being worked out.
    int m_nReserved30 = {};                  // +0x30: an int the constructor zero-clears.
    float m_flScaleX = {};                   // +0x34: a scale the constructor seeds to 1.
    float m_flScaleY = {};                   // +0x38: a scale the constructor seeds to 1.
    JudgeRecord m_aJudgeRecords[2] = {};     // +0x3c: two per-judge records.
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
