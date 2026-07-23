#import "bg_layer.h"

#import <cassert>

#import "../../../GameSystem/src/Render/neRender.h"

/** @ghidraAddress 0x17278c */
ne::C_RENDER *BgLayer::GetBackgroundRenderObject() {
    if (!m_fBuilt) {
        InitializeBackgroundLayer();
    }
    // The binary asserts "m_RootSprite!=NULL" here before returning the root node.
    assert(m_pRootSprite != nullptr);
    return m_pRootSprite;
}
