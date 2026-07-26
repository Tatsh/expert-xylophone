/**
 * @file
 * The play-field main-frame layer, @c MainFrameLayer.
 */

#pragma once

#include "linear_tween.h"
#include "playfieldlayerbase.h"

namespace ne {
class C_SPRITE_INSTANCING;
} // namespace ne

/**
 * @brief The play-field main-frame layer (the frame graphics around the note field).
 *
 * A process-wide singleton, built on first access, deriving from @c PlayFieldLayerBase. It owns the
 * frame's sprite instancers and a fade channel that animates the frame's alpha in and out. The class
 * carries no RTTI (it is non-polymorphic), so the name is inferred from its singleton getter rather
 * than confirmed from the runtime metadata. Only the fields the reconstructed methods touch are
 * modelled; the trailing @c // +0xNN comments document the original 32-bit offsets for reference
 * only. The remaining layer state (the sprite instancers, layout tables, and 3D vertices the build
 * and render paths use) is still being worked out and kept as reserved storage.
 */
class MainFrameLayer : public PlayFieldLayerBase {
public:
    /**
     * @brief The process-wide main-frame layer, created on first use.
     * @return The shared layer.
     * @ghidraAddress 0x17b5d4
     */
    static MainFrameLayer *shared();

    /**
     * @brief Begins the frame fade-in, easing the frame alpha to fully opaque (255) over
     * @p flDuration (snapping to opaque and marking the fade done when the duration is non-positive).
     * @param flDuration The fade duration.
     * @ghidraAddress 0x17c670
     */
    void StartFadeIn(float flDuration);

    /**
     * @brief Begins the frame fade-out, easing the frame alpha to zero over @p flDuration (snapping
     * to zero and marking the fade done when the duration is non-positive).
     * @param flDuration The fade duration.
     * @ghidraAddress 0x17c6a0
     */
    void StartFadeOut(float flDuration);

    /**
     * @brief Shows or hides the main frame sprite. A no-op when the sprite has not been built.
     * @param bEnabled @c true to show the frame, @c false to hide it.
     * @ghidraAddress 0x17c9a8
     */
    void SetMainFrameEnabled(bool bEnabled);

private:
    /**
     * @brief Constructs the layer, chaining the base constructor and seeding its default layout
     * fields. The binary inlines this into @c shared (0x17b5d4).
     */
    MainFrameLayer();

    // +0x08..+0x27: the frame's other sprite instancers and layout state, still being worked out.
    unsigned char m_aReserved08[0x20] = {};      // +0x08
    ne::C_SPRITE_INSTANCING *m_pMainSprite = {}; // +0x28: the main frame sprite instancer.
    // +0x30..+0x47: further layout state, still being worked out.
    unsigned char m_aReserved30[0x18] = {}; // +0x30
    int m_nFrameType = {};                  // +0x48: the frame type, seeded to 0x20 and set by
                                            //        SetMainFrameType (which rebuilds on change).
    // +0x4c..+0x4f: further layout state, still being worked out.
    unsigned char m_aReserved4c[4] = {}; // +0x4c
    int m_nSpriteCapacity = {};          // +0x50: a capacity field the constructor seeds to 5.
    // +0x54..+0x57: further layout state, still being worked out.
    unsigned char m_aReserved54[4] = {}; // +0x54
    LinearTween m_fadeChannel;           // +0x58: the frame alpha fade channel.
    bool m_bFadeDone = {};               // +0x6c: set when the fade snaps to its endpoint.
    // +0x6d..+0x77: the remaining layer state, still being worked out.
    unsigned char m_aReserved6d[0xb] = {}; // +0x6d
};

// code: language=Objective-C++
// kate: hl Objective-C++;
// vim: set ft=objcpp :
