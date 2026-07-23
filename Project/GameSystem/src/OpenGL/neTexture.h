#pragma once

namespace ne {

/**
 * @brief A reference-counted GL texture (RTTI @c ne::C_TEXTURE).
 *
 * Textures are owned by the global texture cache (an intrusive @c m_pPrev / @c m_pNext list) and
 * shared by reference count: holders retain with @c AddRef and release through
 * @c ReleaseRefCountedObject, which destroys the texture when the last reference goes away. The
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
    int GetGLHandle() const {
        return m_nGLHandle;
    }

private:
    // +0x00: implicit vtable pointer (from the virtual destructor above).
    int m_nRefCount = {};               // +0x08
    C_TEXTURE *m_pPrev = {};            // +0x10: previous texture in the cache list.
    C_TEXTURE *m_pNext = {};            // +0x18: next texture in the cache list.
    char *m_pKeyName = {};              // +0x20: the cache key.
    char *m_pSourcePath = {};           // +0x28: the source image path.
    int m_nGLHandle = {};               // +0x30
    int m_nAllocWidth = {};             // +0x34: allocated (power-of-two) width.
    int m_nAllocHeight = {};            // +0x38: allocated (power-of-two) height.
    int m_nImageWidth = {};             // +0x3c: source image width.
    int m_nImageHeight = {};            // +0x40: source image height.
    int m_nByteSize = {};               // +0x44
    float m_aUvScale[4] = {};           // +0x48: texture-coordinate scale.
    int m_nParam58 = {};                // +0x58
    float m_flScale = {};               // +0x5c
    bool m_fFlag60 = {};                // +0x60
    unsigned char m_reserved61[7] = {}; // +0x61
};

/**
 * @brief Release one reference to a polymorphic reference-counted object.
 *
 * Decrements the object's reference count and, when it reaches zero, destroys it through its virtual
 * destructor. The engine's ref-counted objects share the @c C_TEXTURE-style layout (a vtable at
 * offset 0 and the count just after it); the parameter is typed @c C_TEXTURE for its current callers
 * until the shared reference-counted base is reconstructed.
 * @param pObject The object to release; may be @c nullptr.
 * @ghidraAddress 0x31af4
 */
void ReleaseRefCountedObject(C_TEXTURE *pObject);

} // namespace ne

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
