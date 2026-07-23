#import "bg_layer.h"

#import <cassert>

#import "../../../GameSystem/src/Render/neRender.h"

// The process-wide background layer, created lazily by GetBackgroundLayer.
static BgLayer *g_pBackgroundLayer = nullptr; // @ghidraAddress 0x3de808

/** @ghidraAddress 0x17278c */
ne::C_RENDER *BgLayer::GetBackgroundRenderObject() {
    if (!m_fBuilt) {
        InitializeBackgroundLayer();
    }
    // The binary asserts "m_RootSprite!=NULL" here before returning the root node.
    assert(m_pRootSprite != nullptr);
    return m_pRootSprite;
}

/** @ghidraAddress 0x17203c */
BgLayer *GetBackgroundLayer() {
    if (g_pBackgroundLayer == nullptr) {
        // Value-initialisation zeroes the layer; InitBaseLayer fills in the base fields and the
        // factory stamps the background layer kind, matching the binary's raw allocation plus
        // explicit initialisation.
        BgLayer *pLayer = new BgLayer();
        InitBaseLayer(pLayer);
        pLayer->m_nField30 = 1;
        pLayer->m_nLayerKind = BgLayer::kBackgroundLayerKind;
        g_pBackgroundLayer = pLayer;
    }
    return g_pBackgroundLayer;
}
