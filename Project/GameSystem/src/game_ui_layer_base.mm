//
//  game_ui_layer_base.mm
//  REFLEC BEAT plus
//
//  The C_TASK-derived game UI layer base. Reconstructed from Ghidra project rb458, program rb458.
//  @ghidraAddress values are relative to the program image base.
//

#include "game_ui_layer_base.h"

#include "deviceenvironment.h"

namespace {
// The base UI-layer dispatch table (@ghidraAddress 0x35e730): a no-op per-frame callback plus the
// node destructors. Concrete layers install their own table over it in their constructors.
void BaseLayerOnFrame(SortedListenerNode *, void *) {
}
void BaseLayerDestroyNode(SortedListenerNode *pNode) {
    pNode->Unlink();
}
void BaseLayerDeleteNode(SortedListenerNode *pNode) {
    pNode->DestroyAndFree();
}
SortedListenerNodeVtable g_baseUiLayerVtable = {
    BaseLayerOnFrame, BaseLayerDestroyNode, BaseLayerDeleteNode};
} // namespace

/** @ghidraAddress 0x18bd9c */
GameUiLayerBase::GameUiLayerBase() {
    // The task-node base constructor ran first (self-linking the node); install this layer's base
    // dispatch table over the node's, then cache the device presentation flags.
    m_pVtable = &g_baseUiLayerVtable;
    m_bFontVariant = IsPad();
    m_bHardwareType9 = GetIsHardwareType9Flag();
}
