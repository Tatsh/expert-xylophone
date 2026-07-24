/**
 * @file
 * The background sprite manager, @c BackgroundSpriteManager.
 */

#pragma once

#include "playfieldlayerbase.h"

namespace ne {
class C_TEXTURE;
class C_SPRITE_INSTANCING;
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

private:
    /**
     * @brief Constructs the manager, chaining the base constructor and zero-clearing its own state.
     * @ghidraAddress 0x10a7d8
     */
    BackgroundSpriteManager();

    ne::C_TEXTURE *m_pTexture = {}; // +0x08: the gm_parts2 atlas.
    ne::C_SPRITE_INSTANCING *m_apSprites[kSpriteSlotCount] =
        {};                                     // +0x10: the per-slot sprite batches.
    int m_aSpriteCounts[kSpriteSlotCount] = {}; // +0x28: each slot's initial count.
    bool m_bBuilt = {};                         // +0x34: set once the nodes are built.
    bool m_bReserved35 = {};                    // +0x35: a further byte flag.
    // +0x36..+0x37 is alignment padding before the trailing int.
    // unsigned char m_aPad36[2]; // +0x36 (alignment padding, compiler-inserted)
    int m_nReserved38 = {};              // +0x38: a further int the constructor zero-clears.
    unsigned char m_aReserved3c[4] = {}; // +0x3c: padding to the 0x40-byte allocation size.
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
