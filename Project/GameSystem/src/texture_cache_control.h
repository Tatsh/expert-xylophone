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
    unsigned char nTag = {}; /*!< The initial tag byte set at construction. +0x00 */
    // unsigned char aReserved1[7] = {};  /*!< Padding before the next-node pointer. +0x01 */
    TextureCacheControl *pNext = {}; /*!< The next control node, null on construction. +0x08 */
    int nValue = {};                 /*!< An int slot, zero on construction. +0x10 */
    // unsigned char aReserved14[4] = {}; /*!< Padding before the spare slot. +0x14 */
    /**
     * @brief Eight bytes the constructor zeroes and nothing else in the binary reads or writes.
     *
     * Their type is unknown, so they are modelled as raw storage rather than claimed as a pointer.
     * +0x18
     */
    // unsigned char aReserved18[8] = {};
};

/**
 * @brief The lazily-allocated texture-cache control singleton.
 * @ghidraAddress 0x3cff20
 */
extern TextureCacheControl *g_pTextureCacheControl;
