/**
 * @file
 * The note-trail layer, @c NoteTrailLayer.
 */

#pragma once

#include "playfieldlayerbase.h"
#include "s_vector2.h"

namespace ne {
class C_TEXTURE;
class C_SPRITE_INSTANCING_2D;
} // namespace ne

/**
 * The note-trail layer (the trailing ribbons behind long notes).
 *
 * A process-wide singleton, built on first access, deriving from @c PlayFieldLayerBase. It owns one
 * atlas and one sprite instancer, drawn beneath the shared background layer, that presents the note
 * trails, plus a table of per-trail records. The class carries no RTTI (it is non-polymorphic), so
 * the name is inferred from its singleton getter rather than confirmed from the runtime metadata.
 * Only the sprite-batch fields are modelled so far; the per-trail record table is kept as a
 * reserved span. The trailing @c // +0xNN comments document the original 32-bit offsets for
 * reference only.
 */
class NoteTrailLayer : public PlayFieldLayerBase {
public:
    /** The sprite-instancer capacity the layer builds. */
    static constexpr unsigned int kSpriteCapacity = 0x28;

    /**
     * The process-wide note-trail layer, created on first use.
     * @return The shared layer.
     * @ghidraAddress 0x184708
     */
    static NoteTrailLayer *shared();

    /**
     * Lazily builds the note-trail sprite: loads the gm_parts1 atlas and creates the sprite
     * instancer (attaching it under the background layer's render object, making it visible,
     * binding the atlas, flagging additive blend, and, except on the tutorial hardware, enabling
     * its two texture-environment parameters).
     *
     * Guarded so the sprite is built only once.
     * @ghidraAddress 0x184758
     */
    void LoadNoteTrailSprites();

    /** The judge grades a queued result mark may carry, asserted by @c Create. */
    static constexpr int kJudgeMax = 4;
    /** The most result marks the queue holds in one frame. */
    static constexpr int kMaxResults = 40;
    /** The number of result sprite graphics @c CreateSprite can emit. */
    static constexpr int kResultSpriteTypeCount = 6;

    /**
     * Queues a note-trail result mark at (@p flX, @p flY) for the current frame.
     *
     * Finds the first free slot in the queue (up to @c kMaxResults marks) and stores the judge and
     * position; drops the mark when the queue is full.
     * @param nJudge The mark's judge grade (0 through @c kJudgeMax - 1).
     * @param flX The mark X.
     * @param flY The mark Y.
     * @ghidraAddress 0x184800
     */
    void Create(int nJudge, float flX, float flY);

    /**
     * Advances the layer one frame: steps the two spin phases (wrapping each into range),
     * then emits every queued result mark's spinning sprite and clears the queue.
     *
     * The first spin phase drives the sprite rotation; the second selects the spin frame (0 through
     * 3) for judge-0 marks. Judge-1 and judge-2 marks emit fixed sprite graphics 4 and 5. Every
     * sprite is scaled by the game system's scaled sheet radius. Finishes by publishing the frame's
     * sprite count to the batch.
     * @param flDeltaSeconds The frame delta in seconds.
     * @ghidraAddress 0x1848b0
     */
    void Update(float flDeltaSeconds);

    /**
     * Emits one result sprite into the batch at the running write index.
     *
     * Both graphics draw a fixed 58-anchored, 116-square quad; the type only selects the UV rect.
     * Writes the sprite's position, anchor, size, UV rect, rotation, scale, and colour (opaque
     * white modulated by @p nAlpha), then advances the write index.
     * @param nSpriteType The sprite graphic to emit (0 through @c kResultSpriteTypeCount - 1).
     * @param pPosition The sprite position.
     * @param nAlpha The sprite alpha.
     * @param flRotation The sprite rotation, in radians.
     * @param flScaleX The sprite X scale.
     * @param flScaleY The sprite Y scale.
     * @ghidraAddress 0x184a48
     */
    void CreateSprite(unsigned int nSpriteType,
                      const S_VECTOR2 *pPosition,
                      unsigned int nAlpha,
                      float flRotation,
                      float flScaleX,
                      float flScaleY);

private:
    /**
     * Constructs the layer, chaining the base constructor and zero-clearing its own state.
     * @ghidraAddress 0x1846b0
     */
    NoteTrailLayer();

    // One queued result mark (16 bytes): whether the slot is in use, its judge, and its position.
    struct ResultMark {
        bool bActive = {};       /*!< Whether the slot holds a queued mark. +0x00 */
        int nJudge = {};         /*!< The mark's judge grade. +0x04 */
        S_VECTOR2 position = {}; /*!< The mark position. +0x08 */
    };

    ne::C_TEXTURE *m_pTexture = {};             // +0x08: the gm_parts1 atlas.
    ne::C_SPRITE_INSTANCING_2D *m_pSprite = {}; // +0x10: the note-trail sprite instancer.
    int m_nSpriteCount = {};                    // +0x18: the instancer's live sprite count.
    bool m_bBuilt = {};                         // +0x1c: set once the sprite is built.
    float m_flSpinPhaseA = {};                  // +0x20: the rotation spin phase, wrapped to 3000.
    float m_flSpinPhaseB = {}; // +0x24: the frame-select spin phase, wrapped to 400/3.
    ResultMark m_aResults[kMaxResults] = {}; // +0x28: the per-frame result-mark queue (to 0x2a8).
};
