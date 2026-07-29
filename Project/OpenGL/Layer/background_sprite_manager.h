/**
 * @file
 * The background sprite manager, @c BackgroundSpriteManager.
 */

#pragma once

#include "playfieldlayerbase.h"

struct S_VECTOR2;

namespace ne {
class C_TEXTURE;
class C_SPRITE_INSTANCING_2D;
} // namespace ne

/**
 * @brief The background sprite manager: three sprite instancers drawn beneath the shared background
 * layer.
 *
 * A process-wide singleton, built on first access, deriving from @c PlayFieldLayerBase. It owns a
 * single atlas and three sprite instancers that hang beneath the background layer's render object.
 * The class carries no RTTI (it is non-polymorphic), so the name is inferred from its singleton
 * getter rather than confirmed from the runtime metadata. The trailing @c // +0xNN comments document
 * the original 32-bit offsets for reference only.
 */
class BackgroundSpriteManager : public PlayFieldLayerBase {
public:
    /**
     * @brief The process-wide background sprite manager, created on first use.
     * @return The shared manager.
     * @ghidraAddress 0x10a81c
     */
    static BackgroundSpriteManager *shared();

    /**
     * @brief Lazily builds the three background sprite instancers: loads the atlas and creates each
     * instancer (attaching it under the background layer's render object, making it visible, binding
     * the atlas, seeding its sprite count, and flagging additive blend on the outer two slots).
     *
     * Guarded so the nodes are built only once.
     * @ghidraAddress 0x10a86c
     */
    void BuildBackgroundSpriteNodes();

    // The number of background sprite instancers the manager builds.
    static constexpr int kSpriteSlotCount = 3;

    /**
     * @brief Activates the manager's animation and resets its frame counter.
     * @ghidraAddress 0x10a938
     */
    void SetActiveAndResetCounter();

    /**
     * @brief Deactivates the manager's animation.
     * @ghidraAddress 0x10a948
     */
    void SetInactive();

    /** @brief Whether the manager's intro animation is still active. */
    bool IsActive() const {
        return m_bActive;
    }

    /**
     * @brief Advances the play-field zoom animation by one frame and emits its background sprite
     * instances. Reconstruction pending.
     * @param flDelta The elapsed frame count.
     * @ghidraAddress 0x10a950
     */
    void Update(float flDelta);

private:
    /**
     * @brief Appends one zoom-effect sprite to one of the manager's instancers, if capacity remains.
     *
     * Looks up one of the manager's sprite instancers by @p nSlotIndex; if it still has a free slot,
     * writes a full instance there — the caller's position, the anchor and pixel size from the
     * zoom-effect layout table (indexed by @p nLayoutIndex), the UV rectangle from the shared sprite
     * atlas (the layout record's atlas frame), the caller's scale, and opaque white at @p nAlpha —
     * then bumps the instancer's slot count. A no-op when the instancer is already full.
     * @param flScaleX The instance's X scale.
     * @param flScaleY The instance's Y scale.
     * @param nSlotIndex The manager's sprite-instancer index.
     * @param nLayoutIndex The zoom-effect layout-table index (its anchor, size, and atlas frame).
     * @param pPosition The instance's screen position.
     * @param nAlpha The instance's alpha.
     * @ghidraAddress 0x10b1e0
     */
    void PushSpriteInstanceSlot(float flScaleX,
                                float flScaleY,
                                unsigned int nSlotIndex,
                                unsigned int nLayoutIndex,
                                const S_VECTOR2 *pPosition,
                                int nAlpha);

    /**
     * @brief Constructs the manager, chaining the base constructor and zero-clearing its own state.
     * @ghidraAddress 0x10a7d8
     */
    BackgroundSpriteManager();

    ne::C_TEXTURE *m_pTexture = {}; // +0x08: the gm_parts2 atlas.
    ne::C_SPRITE_INSTANCING_2D *m_apSprites[kSpriteSlotCount] =
        {};                                     // +0x10: the per-slot sprite batches.
    int m_aSpriteCounts[kSpriteSlotCount] = {}; // +0x28: each slot's initial count.
    bool m_bBuilt = {};                         // +0x34: set once the nodes are built.
    bool m_bActive = {};                        // +0x35: whether the manager's animation is active.
    // +0x36..+0x37 is alignment padding before the frame counter.
    // unsigned char m_aPad36[2]; // +0x36 (alignment padding, compiler-inserted)
    int m_nFrameCounter = {};            // +0x38: the animation frame counter, reset on activation.
    unsigned char m_aReserved3c[4] = {}; // +0x3c: padding to the 0x40-byte allocation size.
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
