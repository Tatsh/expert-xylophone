/**
 * @file
 * The reference-counted GL texture, @c ne::C_TEXTURE, and the texture cache.
 */

#pragma once

class neGLESRenderer;

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

    /**
     * @brief Splice the texture out of the cache list, free its buffers, and drop its GL handle.
     * @ghidraAddress 0x31a24
     * @ghidraAddress 0x31abc (the deleting-destructor thunk)
     */
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
     * @brief Record the texture's logical size and scale, track its GPU byte footprint, and upload.
     *
     * Stores the source image's logical dimensions and content scale, computes the byte size from
     * the pixel format (RGB is 3 bytes per texel, alpha or luminance is 1, RGBA is 4), adds it to the
     * global texture-memory total, then uploads the pixels through @c InitializeTexture2d.
     * @param nWidth The power-of-two texture width.
     * @param nHeight The power-of-two texture height.
     * @param nFormat The pixel format (2 for RGB, 3 for alpha or luminance, otherwise RGBA).
     * @param pData The decoded pixel data to upload.
     * @param nLogicalWidth The source image's logical width in pixels.
     * @param nLogicalHeight The source image's logical height in pixels.
     * @param flScale The texture's content scale.
     * @return Always 1.
     * @ghidraAddress 0x31f80
     */
    int SetDataAndUpload(int nWidth,
                         int nHeight,
                         int nFormat,
                         void *pData,
                         int nLogicalWidth,
                         int nLogicalHeight,
                         float flScale);

    /**
     * @brief Store one sampler parameter, skipping the GL call when the cached value is unchanged.
     *
     * The texture keeps a shadow of its four current sampler-parameter values; a set only reaches GL
     * when the requested value differs from the shadow, after which the shadow is updated.
     * @param pRenderer The GL renderer to issue the parameter change through.
     * @param nIndex The sampler-parameter slot (0 through 3).
     * @param nValue The parameter value.
     * @ghidraAddress 0x31fe0
     */
    void SetCachedTextureParameter(neGLESRenderer *pRenderer, int nIndex, int nValue);

    /**
     * @brief Delete this texture's GL handle (context-loss teardown), leaving the entry reloadable.
     *
     * Deletes the GL texture and zeroes the handle so the entry can be re-uploaded later from its
     * source path; a no-op when the entry has no source path or no live handle.
     * @ghidraAddress 0x32020
     */
    void ReleaseGLHandle();

    /**
     * @brief Reload this texture's pixels from its stored source-image name.
     *
     * Decodes the named image, rounds to a power-of-two RGBA (or tight RGB) buffer, and re-uploads
     * it; used to recover a texture whose GL handle was dropped on a context loss. A no-op when the
     * entry has no source path.
     * @return Non-zero on success (including the no-source-path no-op), zero when the image could not
     *         be loaded.
     * @ghidraAddress 0x3205c
     */
    int ReloadFromSourceName();

    /**
     * @brief Delete the GL handle of every texture in the cache (a context-loss teardown sweep).
     * @ghidraAddress 0x33e1c
     */
    static void ReleaseAllHandles();

    /**
     * @brief Reload every texture in the cache from its source name (context-loss recovery sweep).
     * @ghidraAddress 0x33e5c
     */
    static void ReloadAll();

    /**
     * @brief Build a cached texture directly from decoded pixel data (rather than an image asset).
     *
     * Allocates a texture, uploads the given pixels while tracking their GPU footprint, and, on
     * success, reference-counts the texture and splices it into the head of the live cache list. Used
     * by the @c NSData image decoder path, which decodes to a power-of-two RGBA (or tight RGB) buffer
     * itself.
     * @param nWidth The power-of-two texture width.
     * @param nHeight The power-of-two texture height.
     * @param nFormat The pixel format (2 for RGB, 3 for alpha or luminance, otherwise RGBA).
     * @param pData The decoded pixel data to upload.
     * @param nLogicalWidth The source image's logical width in pixels.
     * @param nLogicalHeight The source image's logical height in pixels.
     * @param flScale The texture's content scale.
     * @return The newly cached texture, or @c nullptr when the upload failed.
     * @ghidraAddress 0x33d3c
     */
    static C_TEXTURE *CreateAndCache(int nWidth,
                                     int nHeight,
                                     int nFormat,
                                     void *pData,
                                     int nLogicalWidth,
                                     int nLogicalHeight,
                                     float flScale);

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

    /**
     * @brief Returns the texture cache's circular-list head-holder (its sentinel node's address).
     * @return The cache-list head-holder, or @c nullptr before @c EnsureCacheList has run.
     * @ghidraAddress 0x33bf0
     */
    static C_TEXTURE **GetCacheList();

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
