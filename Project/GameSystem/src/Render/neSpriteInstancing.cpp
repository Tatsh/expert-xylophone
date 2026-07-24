#include "neSpriteInstancing.h"

#include <new>

#include "neTexture.h"

namespace ne {

/** @ghidraAddress 0x31834 */
C_SPRITE_INSTANCING *CreateWorldSpriteBatch(unsigned int nCapacity) {
    // The binary allocates raw memory and hands it to InitWorldSpriteBatch rather than running a
    // C++ constructor; the allocation size matches sizeof(C_SPRITE_INSTANCING).
    auto *pBatch = static_cast<C_SPRITE_INSTANCING *>(operator new(sizeof(C_SPRITE_INSTANCING)));
    InitWorldSpriteBatch(pBatch, nCapacity);
    return pBatch;
}

/** @ghidraAddress 0x317dc */
void C_SPRITE_INSTANCING::SetRefCountedMember(C_TEXTURE *pTexture) {
    if (m_pTexture != nullptr) {
        m_pTexture->Release();
        m_pTexture = nullptr;
    }
    if (pTexture != nullptr) {
        pTexture->AddRef();
        m_pTexture = pTexture;
    }
}

} // namespace ne
