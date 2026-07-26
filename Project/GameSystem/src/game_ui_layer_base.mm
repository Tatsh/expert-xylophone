//
//  game_ui_layer_base.mm
//  REFLEC BEAT plus
//
//  The C_TASK-derived game UI layer base. Reconstructed from Ghidra project rb458, program rb458.
//  @ghidraAddress values are relative to the program image base.
//

#include "game_ui_layer_base.h"

#include "deviceenvironment.h"

/** @ghidraAddress 0x18bd9c */
GameUiLayerBase::GameUiLayerBase() {
    // The task-node base constructor ran first (self-linking the node); the compiler installs this
    // class's vtable. Cache the device presentation flags.
    m_bFontVariant = IsPad();
    m_bHardwareType9 = GetIsHardwareType9Flag();
}
