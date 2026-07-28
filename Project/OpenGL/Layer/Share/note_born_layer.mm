//
//  note_born_layer.mm
//  REFLEC BEAT plus
//
//  The note-spawn ("born") effect layer (NoteBornLayer). Reconstructed from Ghidra project rb458,
//  program rb458. @ghidraAddress values are relative to the program image base.
//

#include "note_born_layer.h"

#include <cassert>

/** @ghidraAddress 0x185564 */
void NoteBornLayer::Create(int nColor, float flX, float flY) {
    assert(nColor >= 0 && nColor < kPlayerColorMax);

    // Claim the first inactive pooled effect; a full pool drops the effect.
    for (NoteBornEffect &effect : m_aEffects) {
        if (!effect.bActive) {
            effect.nColorOne = nColor == 1;
            effect.bActive = true;
            effect.flX = flX;
            effect.flY = flY;
            effect.flTimer = 0.0f;
            return;
        }
    }
}
