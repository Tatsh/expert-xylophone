#include "neTexture.h"

#include <cstring>
#include <new>

#import "neEngineBridge.h"

namespace ne {

// The texture cache's circular-list head-holder, created lazily by EnsureCacheList.
C_TEXTURE **g_ppTextureCacheHead = nullptr; // @ghidraAddress 0x3cff30

/** @ghidraAddress 0x319d0 */
C_TEXTURE::C_TEXTURE() {
    // Every other field is zeroed by its in-class initialiser; the scale defaults to 1 and the flag
    // records whether the device is an iPad.
    m_flScale = 1.0f;
    m_fFlag60 = IsPad();
}

/** @ghidraAddress 0x31a24 */
C_TEXTURE::~C_TEXTURE() {
    g_dwTotalTextureMemory -= m_nByteSize;
    // Splice the entry out of the cache list when both links are set.
    if (m_pPrev != nullptr && m_pNext != nullptr) {
        m_pPrev->m_pNext = m_pNext;
        m_pNext->m_pPrev = m_pPrev;
    }
    if (m_pKeyName != nullptr) {
        delete[] m_pKeyName;
        m_pKeyName = nullptr;
    }
    if (m_pSourcePath != nullptr) {
        delete[] m_pSourcePath;
        m_pSourcePath = nullptr;
    }
    if (m_nGLHandle != 0) {
        GetGlRenderer()->DeleteTexture(m_nGLHandle);
    }
}

/** @ghidraAddress 0x31b18 */
void C_TEXTURE::SetSourcePath(const char *pszPath) {
    if (m_pSourcePath != nullptr) {
        delete[] m_pSourcePath;
        m_pSourcePath = nullptr;
    }
    m_pSourcePath = new char[std::strlen(pszPath) + 1];
    std::strcpy(m_pSourcePath, pszPath);
}

/** @ghidraAddress 0x33c78 */
C_TEXTURE *C_TEXTURE::FindOrLoadCached(const char *pszName) {
    C_TEXTURE *pSentinel = *g_ppTextureCacheHead;
    // Walk the circular cache list; a key match bumps the reference count and returns the entry.
    for (C_TEXTURE *pEntry = pSentinel->m_pPrev; pEntry != pSentinel; pEntry = pEntry->m_pPrev) {
        if (pEntry->m_pKeyName != nullptr && std::strcmp(pEntry->m_pKeyName, pszName) == 0) {
            pEntry->AddRef();
            return pEntry;
        }
    }

    // Not cached: construct a new entry and load the image. On a load failure the binary abandons
    // the entry without freeing it; that is reproduced here.
    auto *pNewEntry = new C_TEXTURE();
    if (pNewEntry->LoadFromUIImage(pszName) == 0) {
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

/** @ghidraAddress 0x33bfc */
void C_TEXTURE::EnsureCacheList() {
    if (g_ppTextureCacheHead != nullptr) {
        return;
    }
    // Value-initialisation zeroes the head cell (the binary stores a null there before the sentinel
    // is ready); the sentinel is then a self-linked one-element circular list.
    g_ppTextureCacheHead = new C_TEXTURE *();
    auto *pSentinel = new C_TEXTURE();
    *g_ppTextureCacheHead = pSentinel;
    pSentinel->m_pPrev = pSentinel;
    pSentinel->m_pNext = pSentinel;
}

/** @ghidraAddress 0x31af4 */
void C_TEXTURE::Release() {
    // Decrement the reference count and destroy the object once it reaches zero. The binary
    // dereferences the object before its now-redundant null check, so callers pass a live object;
    // delete dispatches the same virtual destructor the binary tail-calls through the vtable.
    if (ReleaseRef() == 0) {
        delete this;
    }
}

} // namespace ne
