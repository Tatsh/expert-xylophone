#include "neSpriteInstancing.h"

#include "../OpenGL/neTexture.h"

namespace ne {

/** @ghidraAddress 0x317dc */
void SetRefCountedMember(C_SPRITE_INSTANCING *pBatch, C_TEXTURE *pTexture) {
    if (pBatch->m_pTexture != nullptr) {
        ReleaseRefCountedObject(pBatch->m_pTexture);
        pBatch->m_pTexture = nullptr;
    }
    if (pTexture != nullptr) {
        pTexture->AddRef();
        pBatch->m_pTexture = pTexture;
    }
}

} // namespace ne
