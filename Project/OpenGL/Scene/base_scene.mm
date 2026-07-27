//
//  base_scene.mm
//  REFLEC BEAT plus
//
//  The scene base, rb::BaseScene. Reconstructed from Ghidra project rb458, program rb458.
//  @ghidraAddress values are relative to the program image base.
//

#include "base_scene.h"

#include "deviceenvironment.h"

namespace rb {

/** @ghidraAddress 0x18bd9c */
BaseScene::BaseScene() {
    // The task-node base constructor ran first (self-linking the node); the compiler installs this
    // class's vtable. Cache the device presentation flags.
    m_bIsPad = ::IsPad();
    m_bHardwareType9 = GetIsHardwareType9Flag();
}

} // namespace rb
