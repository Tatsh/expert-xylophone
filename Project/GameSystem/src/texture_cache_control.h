/**
 * @file
 * The texture-cache control singleton node, @c TextureCacheControl.
 */

#pragma once

/**
 * @brief The small tagged control node the texture cache keeps as a lazily-allocated singleton.
 *
 * A 32-byte node holding a tag byte, a next-node pointer, an int slot, and a spare slot. It is
 * distinct from the live-texture cache list (@c C_TEXTURE::GetCacheList); it appears to be a
 * cache-control singleton added in this build. The trailing @c // +0xNN comments document the
 * original member offsets for reference only.
 */
struct TextureCacheControl {
    unsigned char nTag = {};           // +0x00: the initial tag byte set at construction.
    unsigned char aReserved1[7] = {};  // +0x01: padding before the next-node pointer.
    TextureCacheControl *pNext = {};   // +0x08: the next control node (null on construction).
    int nValue = {};                   // +0x10: an int slot (zero on construction).
    unsigned char aReserved14[4] = {}; // +0x14: padding before the spare slot.
    void *pSpare = {};                 // +0x18: a spare slot (null on construction).
};

/**
 * @brief The lazily-allocated texture-cache control singleton.
 * @ghidraAddress 0x3cff20
 */
extern TextureCacheControl *g_pTextureCacheControl;

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
