#pragma once

//
//  title_screen_layer_classic.h
//  REFLEC BEAT plus
//
//  The interactive title screen layer, as far as its per-frame animation and fade channel observe
//  it. This is the 0x898-byte gesture layer driven by ProcessTitleLayer (the 0x149xxx cluster),
//  distinct from both the 0x168 rb::TitleClassicScene and the 0x898 rb::TitleColetteScene. Two
//  families were previously misattributed here and now live on their real owners: the
//  swing/gesture/fade helpers on TitleColetteScene, and the hidden Konami-code swipe machine
//  (0x152cc8) plus the fade-value tween (0x152548) on rb::TitleClassicScene, whose
//  +0x110/+0x160/+0x164 fields they write. The class is not fully modelled yet: only the fields the
//  reconstructed routines touch are named, with the surrounding object modelled as reserved spans
//  so the named fields land at their real offsets.
//
//  Reconstructed from Ghidra project rb458, program rb458. @ghidraAddress values are relative to
//  the program image base.
//

#include "linear_tween.h"

struct S_VECTOR2;

namespace ne {
class C_SPRITE_INSTANCING_2D;
} // namespace ne

/**
 * @brief The interactive title screen layer, as far as its per-frame animation and fade channel
 * observe it.
 *
 * Only the animation clock, the start-triggered flag, the five instancers, and the fade channel are
 * named; the rest of the 0x898-byte object is reserved padding until the full class is modelled.
 * @ghidraAddress TitleScreenLayerClassic (engine layer, 0x898 bytes)
 */
class TitleScreenLayerClassic {
public:
    // The number of title-screen sprite instancers the layer positions.
    static constexpr int kInstancerCount = 5;
    /**
     * @brief Advances the title screen one frame: ticks the animation clock, handles touch-to-start
     * and the auto-timeout, advances the fade, and re-emits the title sprites.
     *
     * Clears the five sprite instancers, then — until the start is triggered — begins the fade-out
     * to play once the caution has been read and the player taps after the intro (or, failing a
     * tap, once the auto-timeout elapses). When the fade completes it latches the play state. It
     * then emits the white backdrop, the three cross-fading title logo layers (each alpha-driven by
     * its own animation curve, all centred on the viewport), and the black fade-overlay whose alpha
     * tracks the fade channel.
     * @param nDeltaFrames The elapsed frames this tick.
     * @ghidraAddress 0x149c5c
     */
    void ProcessTitleLayer(int nDeltaFrames);
    /**
     * @brief Advances the title fade channel by @p nDeltaFrames.
     * @ghidraAddress 0x149ff4
     */
    void CalculateFade(int nDeltaFrames);

private:
    /**
     * @brief Positions and fills one title-screen sprite instancer slot, if it has a free slot.
     *
     * A no-op for an out-of-range sprite kind or a full instancer. The three textured kinds (1..3)
     * bind their instancer's texture and derive the sprite's anchor (half the point size), size,
     * and UV span from the texture's pixel size, allocated size, and retina scale, drawing opaque
     * white. The two backdrop kinds (0 and 4) draw a full-viewport quad sized from the game system,
     * coloured white for kind 0 and black for kind 4. Either way the caller's position and scale
     * are applied and the instancer's slot count is bumped.
     * @param nKind The sprite kind, also the instancer index (0..4).
     * @param pPosition The sprite's screen position.
     * @param flScale The sprite's uniform scale.
     * @param nAlpha The sprite's alpha.
     * @ghidraAddress 0x14a040
     */
    void SetTitleSprite(unsigned int nKind, const S_VECTOR2 *pPosition, float flScale, int nAlpha);

    unsigned char m_aReserved00[0x4c] = {}; // +0x000
    int m_nState = {};                      // +0x04c the title state (2 = start selected)
    int m_nElapsed = {};                    // +0x050 the title animation clock, advanced each frame
    unsigned char m_aReserved54[0x1c] = {}; // +0x054
    ne::C_SPRITE_INSTANCING_2D *m_apInstancers[kInstancerCount] =
        {};                                   // +0x070 the five title sprite instancers
    unsigned char m_aReserved98[0x28] = {};   // +0x098
    bool m_bStartTriggered = {};              // +0x0c0 latched once the title starts fading to play
    unsigned char m_aReservedC1[3] = {};      // +0x0c1
    LinearTween m_fadeChannel;                // +0x0c4 title fade tween
    unsigned char m_aReserved0d8[0x7c0] = {}; // +0x0d8 remainder of the object
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
