//
//  classic_theme_animation.cpp
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458. Pure C++.
//

#include "classic_theme_animation.h"

/** @ghidraAddress 0x10a5fc */
void ClassicThemeAnimation::AdvanceEasedProgress(float flDelta) {
    m_easeChannel.Advance(flDelta);
}
