/**
 * @file
 * The slide-note judge-result layer, @c SlideNoteResultLayer.
 */

#pragma once

#include "playfieldlayerbase.h"

struct S_VECTOR2;

namespace ne {
class C_TEXTURE;
class C_SPRITE_INSTANCING_2D;
} // namespace ne

/**
 * @brief The slide-note judge-result layer (the spinning result marks a slide note leaves behind).
 *
 * A process-wide singleton, built on first access, deriving from @c PlayFieldLayerBase. It owns one
 * atlas and a single sprite batch drawn beneath the shared background layer. Each frame the layer
 * advances two independent spin phases and, for every result mark queued that frame, emits a spinning
 * sprite whose graphic is chosen from the mark's judge. The class name comes from its embedded
 * @c slide_note_result_layer.mm path; it carries no RTTI (it is non-polymorphic). The trailing
 * @c // +0xNN comments document the original 32-bit offsets for reference only.
 */
class SlideNoteResultLayer : public PlayFieldLayerBase {
public:
    // The judge kinds a queued result mark may carry (its judge grade).
    enum SlideJudge {
        kSlideJudge0 = 0,   /*!< The first judge grade. */
        kSlideJudge1 = 1,   /*!< The second judge grade. */
        kSlideJudge2 = 2,   /*!< The third judge grade. */
        kSlideJudgeMax = 4, /*!< The exclusive upper bound Create asserts against. */
    };

    // The sprite-graphic kinds CreateSprite can emit.
    enum SlideSpriteType {
        kSlideSpriteType0 = 0,   /*!< The judge-0 result graphic. */
        kSlideSpriteType1 = 1,   /*!< A result graphic. */
        kSlideSpriteType2 = 2,   /*!< A result graphic. */
        kSlideSpriteType3 = 3,   /*!< A result graphic. */
        kSlideSpriteType4 = 4,   /*!< The judge-1 result graphic. */
        kSlideSpriteType5 = 5,   /*!< The judge-2 result graphic. */
        kSlideSpriteTypeMax = 6, /*!< The exclusive upper bound CreateSprite asserts against. */
    };

    // The most result marks the layer can queue in one frame (its sprite-batch capacity).
    static constexpr int kMaxResults = 40;

    /**
     * @brief The process-wide slide-note result layer, created on first use.
     * @return The shared layer.
     * @ghidraAddress 0x66ab8
     */
    static SlideNoteResultLayer *shared();

    /**
     * @brief Lazily builds the result sprite batch: loads the gm_parts1 atlas, creates the batch
     * (attaching it under the background layer's render object, making it visible, binding the atlas,
     * and flagging additive blend), and, on the newer hardware, sets its two texture-environment
     * parameters. Guarded so the batch is built only once.
     * @ghidraAddress 0x66b08
     */
    void BuildSpriteBatch();

    /**
     * @brief Queues a slide-note result mark at @p position for the current frame.
     *
     * Finds the first free slot in the queue (up to @c kMaxResults marks) and stores the judge and
     * position; drops the mark when the queue is full.
     * @param nJudge The mark's judge grade (0 through @c kSlideJudgeMax - 1).
     * @param position The mark's position.
     * @ghidraAddress 0x66bb8
     */
    void Create(int nJudge, const S_VECTOR2 &position);

    /**
     * @brief Advances the layer one frame: steps the two spin phases (wrapping each into range),
     * then, for every queued mark, emits its spinning sprite and clears the queue.
     * @param flDeltaSeconds The frame delta in seconds.
     * @ghidraAddress 0x66c6c
     */
    void Update(float flDeltaSeconds);

    /**
     * @brief Emits one result sprite into the batch at the running write index.
     *
     * Writes the sprite's position, anchor, size, UV rect (chosen from @p nSpriteType), rotation,
     * scale, and colour, then advances the write index.
     * @param nSpriteType The sprite graphic to emit (0 through @c kSlideSpriteTypeMax - 1).
     * @param pPosition The sprite position.
     * @param nAlpha The sprite alpha.
     * @param flRotation The sprite rotation, in radians.
     * @param flScaleX The sprite X scale.
     * @param flScaleY The sprite Y scale.
     * @ghidraAddress 0x66e04
     */
    void CreateSprite(unsigned int nSpriteType,
                      const S_VECTOR2 *pPosition,
                      int nAlpha,
                      float flRotation,
                      float flScaleX,
                      float flScaleY);

private:
    /**
     * @brief Constructs the layer, chaining the base constructor, clearing its header fields, and
     * marking every queue slot free.
     * @ghidraAddress 0x66a60
     */
    SlideNoteResultLayer();

    // One queued result mark: whether the slot is in use, its judge, and its position. Laid out on
    // a 0x14-byte stride in the queue.
    struct ResultMark {
        bool bActive = {};       // +0x00
        int nJudge = {};         // +0x04
        S_VECTOR2 position = {}; // +0x08
    };

    ne::C_TEXTURE *m_pTexture = {};            // +0x08: the gm_parts1 atlas.
    ne::C_SPRITE_INSTANCING_2D *m_pBatch = {}; // +0x10: the result sprite batch.
    int m_nWriteIndex = {};                    // +0x18: the running sprite write index for a frame.
    bool m_bBuilt = {};                        // +0x1c: set once the batch is built.
    float m_flSpinPhaseA = {}; // +0x20: the first spin phase, wrapped to (-3000, 3000].
    float m_flSpinPhaseB = {}; // +0x24: the second spin phase, wrapped to [-400/3, 400/3).
    ResultMark m_aResults[kMaxResults] = {}; // +0x28: the per-frame result-mark queue.
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
