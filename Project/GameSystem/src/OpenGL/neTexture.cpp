#include "neTexture.h"

#include <cstring>
#include <new>

namespace ne {

/** @ghidraAddress 0x33c78 */
C_TEXTURE *FindOrLoadCachedTexture(const char *pszName) {
    C_TEXTURE *pSentinel = *g_ppTextureCacheHead;
    // Walk the circular cache list; a key match bumps the reference count and returns the entry.
    for (C_TEXTURE *pEntry = pSentinel->m_pPrev; pEntry != pSentinel; pEntry = pEntry->m_pPrev) {
        if (pEntry->m_pKeyName != nullptr && std::strcmp(pEntry->m_pKeyName, pszName) == 0) {
            pEntry->AddRef();
            return pEntry;
        }
    }

    // Not cached: allocate a new entry, initialise it, and load the image.
    auto *pNewEntry = static_cast<C_TEXTURE *>(operator new(sizeof(C_TEXTURE)));
    InitializeTextureEntry(pNewEntry);
    if (LoadTextureFromUIImage(pNewEntry, pszName) == 0) {
        return nullptr;
    }

    pNewEntry->AddRef();
    // Splice the new entry in right after the sentinel, at the head of the live list.
    C_TEXTURE *pOldPrev = pSentinel->m_pPrev;
    pOldPrev->m_pNext = pNewEntry;
    pNewEntry->m_pPrev = pOldPrev;
    pNewEntry->m_pNext = pSentinel;
    pSentinel->m_pPrev = pNewEntry;
    return pNewEntry;
}

/** @ghidraAddress 0x31af4 */
void ReleaseRefCountedObject(C_TEXTURE *pObject) {
    // The reference count is decremented before the null check, matching the binary; callers pass a
    // non-null object.
    int nCount = pObject->ReleaseRef();
    if (pObject != nullptr && nCount == 0) {
        // The binary tail-calls the object's deleting destructor through its vtable slot; delete
        // dispatches the same virtual destructor.
        delete pObject;
    }
}

} // namespace ne
