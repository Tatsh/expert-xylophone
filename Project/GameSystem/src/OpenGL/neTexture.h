/**
 * @file
 * The reference-counted GL texture, @c ne::C_TEXTURE, and the texture cache.
 */

#pragma once

namespace ne {

/**
 * @brief A reference-counted GL texture (RTTI @c ne::C_TEXTURE).
 *
 * Textures are owned by the global texture cache (an intrusive @c m_pPrev / @c m_pNext list) and
 * shared by reference count: holders retain with @c AddRef and release through @c Release, which
 * destroys the texture when the last reference goes away. The
 * class is polymorphic, so it is modelled with a virtual destructor (the vtable at offset 0 is what
 * the release helper dispatches through). Trailing @c // +0xNN comments document the original 32-bit
 * offsets for reference only.
 */
class C_TEXTURE {
public:
    C_TEXTURE();
    virtual ~C_TEXTURE();

    /**
     * @brief Add a reference to the texture.
     */
    void AddRef() {
        ++m_nRefCount;
    }

    /**
     * @brief Remove a reference from the texture.
     * @return The reference count after the decrement.
     */
    int ReleaseRef() {
        return --m_nRefCount;
    }

    /**
     * @brief Release one reference and destroy the texture once the count reaches zero.
     *
     * The binary dereferences the object before its now-redundant null check, so this must be called
     * on a live texture; destruction runs through the virtual destructor.
     * @ghidraAddress 0x31af4
     */
    void Release();

    /**
     * @brief The texture's current reference count.
     */
    int GetRefCount() const {
        return m_nRefCount;
    }

    /**
     * @brief The texture's cache key, or @c nullptr when it is not cached.
     */
    const char *GetKeyName() const {
        return m_pKeyName;
    }

    /**
     * @brief The OpenGL texture handle.
     */
    unsigned int GetGLHandle() const {
        return m_nGLHandle;
    }

    /**
     * @brief The allocated (power-of-two) texture width in texels.
     */
    int GetAllocWidth() const {
        return m_nAllocWidth;
    }

    /**
     * @brief The allocated (power-of-two) texture height in texels.
     */
    int GetAllocHeight() const {
        return m_nAllocHeight;
    }

    /**
     * @brief The source image width in pixels (the used region of the allocation).
     */
    int GetImageWidth() const {
        return m_nImageWidth;
    }

    /**
     * @brief The source image height in pixels (the used region of the allocation).
     */
    int GetImageHeight() const {
        return m_nImageHeight;
    }

    /**
     * @brief The texture's content scale: pixel dimensions divided by it give layout points.
     */
    float GetScale() const {
        return m_flScale;
    }

    /**
     * @brief Store a copy of the source asset path, freeing any path already held.
     * @param pszPath The source asset path to store.
     * @ghidraAddress 0x31b18
     */
    void SetSourcePath(const char *pszPath);

    /**
     * @brief Load this texture's pixels from the named UIImage asset.
     * @param pszName The image asset name.
     * @return Non-zero on success, zero when the image could not be loaded.
     * @ghidraAddress 0x31b60
     */
    int LoadFromUIImage(const char *pszName);

    /**
     * @brief Create the GL texture object from decoded pixel data and store its handle.
     * @param nWidth The power-of-two texture width.
     * @param nHeight The power-of-two texture height.
     * @param nFormat The pixel format: 1 for RGBA, 2 for tight 24-bit RGB.
     * @param pData The decoded pixel data to upload.
     * @ghidraAddress 0x31eb0
     */
    void InitializeTexture2d(int nWidth, int nHeight, int nFormat, void *pData);

    /**
     * @brief Find a cached texture by key, loading and caching it on a miss.
     *
     * Walks the cache list for an entry whose key matches @p pszName; on a hit the entry's reference
     * count is incremented and it is returned. On a miss a new entry is allocated, initialised, and
     * loaded from the named image; on success it is reference-counted, spliced into the list, and
     * returned, otherwise @c nullptr.
     * @param pszName The texture key (an image asset path).
     * @return The cached or newly loaded texture, or @c nullptr when the image could not be loaded.
     * @ghidraAddress 0x33c78
     */
    static C_TEXTURE *FindOrLoadCached(const char *pszName);

    /**
     * @brief Lazily create the global texture-cache list.
     *
     * On first call allocates the cache head-holder and its self-linked sentinel entry, so the live
     * list is always a non-empty circular list; a no-op once the list exists.
     * @ghidraAddress 0x33bfc
     */
    static void EnsureCacheList();

private:
    // +0x00: implicit vtable pointer (from the virtual destructor above).
    int m_nRefCount = {};          // +0x08
    C_TEXTURE *m_pPrev = {};       // +0x10: previous texture in the cache list.
    C_TEXTURE *m_pNext = {};       // +0x18: next texture in the cache list.
    char *m_pKeyName = {};         // +0x20: the cache key.
    char *m_pSourcePath = {};      // +0x28: the source image path.
    unsigned int m_nGLHandle = {}; // +0x30
    int m_nAllocWidth = {};        // +0x34: allocated (power-of-two) width.
    int m_nAllocHeight = {};       // +0x38: allocated (power-of-two) height.
    int m_nImageWidth = {};        // +0x3c: source image width.
    int m_nImageHeight = {};       // +0x40: source image height.
    int m_nByteSize = {};          // +0x44
    int m_aTexParams[4] = {};      // +0x48: sampler-parameter shadow (min, mag, wrap S, wrap T).
    int m_nFormat = {};            // +0x58: the pixel format (1 = RGBA, 2 = tight 24-bit RGB).
    float m_flScale = {};          // +0x5c
    bool m_fFlag60 = {};           // +0x60
    // +0x61..+0x67 is compiler alignment padding to the 0x68-byte object size (no member there).
};

/**
 * @brief The texture cache's circular list, addressed through its sentinel node.
 *
 * Dereferencing it yields the sentinel @c C_TEXTURE whose @c pNext / @c pPrev links thread the live
 * cache. Created lazily by @c EnsureCacheList.
 * @ghidraAddress 0x3cff30
 */
extern C_TEXTURE **g_ppTextureCacheHead;

/**
 * @brief Running total of the bytes held by all live textures, for memory accounting.
 * @ghidraAddress 0x3cff28
 */
extern int g_dwTotalTextureMemory;

} // namespace ne

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
