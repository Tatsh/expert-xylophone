#import "classic_theme_layer.h"

#import "../../../GameSystem/src/OpenGL/neTexture.h"
#import "../../../GameSystem/src/Render/neRender.h"
#import "../../../GameSystem/src/Render/neSpriteInstancing.h"
#import "../Share/bg_layer.h"

// The background texture the Classic-theme batches all draw from.
static const char *const g_szGmParts2TextureKey = "00_texture/gm_parts2"; // @ghidraAddress 0x3ceaa8

// The sprite capacities (maximum sprite counts) for the three Classic-theme background batches.
static const int g_anClassicThemeBatchCapacities[] = {1, 7, 30}; // @ghidraAddress 0x301970

/** @ghidraAddress 0x109f30 */
void ClassicThemeLayer::InitializeBackgroundSceneNodes() {
    if (m_fInitialized) {
        return;
    }

    ne::C_RENDER *pRootNode = GetBackgroundLayer()->GetBackgroundRenderObject();
    m_pTexture = ne::C_TEXTURE::FindOrLoadCached(g_szGmParts2TextureKey);

    for (int nBatchIndex = 0; nBatchIndex < kBackgroundBatchCount; ++nBatchIndex) {
        ne::C_SPRITE_INSTANCING *pBatch =
            ne::CreateWorldSpriteBatch(g_anClassicThemeBatchCapacities[nBatchIndex]);
        pRootNode->AttachChild(pBatch);
        pBatch->SetVisible(true);
        // The first batch is stored without being given the shared texture; only the second and
        // third batches take it, exactly as the binary does.
        if (nBatchIndex != 0) {
            pBatch->SetRefCountedMember(m_pTexture);
        }
        pBatch->SetSpriteCount(m_anSpriteCount[nBatchIndex]);
        // The last batch is additively blended over the others.
        if (nBatchIndex == kBackgroundBatchCount - 1) {
            pBatch->SetBlendMode(1);
        }
        m_apSpriteBatch[nBatchIndex] = pBatch;
    }

    m_fInitialized = true;
}
