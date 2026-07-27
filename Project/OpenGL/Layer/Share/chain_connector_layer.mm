//
//  chain_connector_layer.mm
//  REFLEC BEAT plus
//
//  The note chain-connector layer (ChainConnectorLayer). Reconstructed from Ghidra project rb458,
//  program rb458. @ghidraAddress values are relative to the program image base.
//

#include "chain_connector_layer.h"

// The shared connector draw count, reset when the layer is constructed.
int g_nChainConnectorDrawCount = {}; // @ghidraAddress 0x3def48

// The process-wide chain-connector layer, created lazily by shared().
static ChainConnectorLayer *g_pChainConnectorLayer = nullptr; // @ghidraAddress 0x3def50

/** @ghidraAddress 0x185844 */
ChainConnectorLayer *ChainConnectorLayer::shared() {
    if (g_pChainConnectorLayer == nullptr) {
        g_pChainConnectorLayer = new ChainConnectorLayer();
    }
    return g_pChainConnectorLayer;
}

/** @ghidraAddress 0x1857e4 */
ChainConnectorLayer::ChainConnectorLayer() {
    // The base constructor and member initialisers clear the sprite header and pooled records; the
    // shared connector draw count resets to zero.
    g_nChainConnectorDrawCount = 0;
}
