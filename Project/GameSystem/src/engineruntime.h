/**
 * @file
 * Miscellaneous engine-runtime free functions the application layer calls: the sound-effect
 * backend, customize-asset paths, the texture cache, the global scene tree, and the media timer.
 */

#pragma once

#include <stddef.h>

#ifdef __OBJC__
#import <Foundation/Foundation.h>
#endif

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Returns the clear rank for the given achievement rate.
 * @ghidraAddress 0x14992c
 */
int GetClearRank(float achievementRate);
#ifdef __OBJC__
/**
 * @brief Builds the bundle image path for a customize asset of the given category and variant.
 *
 * Formats a name of the form @c "04_customize/cus_i<category>_<variant>" for the bgm (0), shot (1),
 * explosion (2), frame (3), background (4), object (5), and thema (10) categories, or the
 * variant-less @c "04_customize/cus_imusic" for a music item (7); returns @c nil for any other
 * category.
 * @param assetType The customize asset category.
 * @param variantIndex The index into the category's variant-name table.
 * @return An autoreleased path string, or @c nil for an unhandled category.
 * @ghidraAddress 0x54ee0
 */
NSString *_Nullable BuildCustomizeAssetPathString(int assetType, int variantIndex);
/**
 * @brief Builds the bundle image path for a customize music-item frame overlay.
 * @param kind The customize element id; only the music kind (7) yields a path.
 * @return An autoreleased path string, or @c nil for any other kind.
 * @ghidraAddress 0x550dc
 */
NSString *_Nullable GetCustomizeFrameImagePath(int kind);
#endif
// The texture-cache sweeps at 0x33e5c, 0x33e1c, and 0x33bf0 are static members of ne::C_TEXTURE
// (ReloadAll, ReleaseAllHandles, and GetCacheList in neTexture.h), not free functions; they are
// declared there rather than duplicated here.
/**
 * @brief Renders the whole global scene tree for the current frame.
 * @ghidraAddress 0x29d58
 */
void RenderGlobalSceneTree(void);
/**
 * @brief Constructs the title/gauge scene layer matching the current UI theme and registers it in
 * the sorted listener list at priority 1.
 *
 * The concrete layer class is chosen by the selected theme.
 * @ghidraAddress 0x4fa24
 */
void CreateTitleLayerForTheme(void);
/**
 * @brief Dispatches the per-frame notification (an opaque frame-elapsed argument) to every live
 *        node in the engine listener list.
 * @ghidraAddress 0x36628
 */
void DispatchListenerList(int nElapsedMs);
/**
 * @brief Zeroes @p nSize bytes of @p pBuffer, guarding against a null pointer.
 * @param pBuffer The buffer to clear, or @c nullptr to do nothing.
 * @param nSize The number of bytes to clear.
 * @ghidraAddress 0x12e900
 */
void ZeroMemoryIfNonNull(void *_Nullable pBuffer, size_t nSize);

#ifdef __cplusplus
}
#endif

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
