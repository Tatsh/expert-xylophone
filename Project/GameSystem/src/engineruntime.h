/**
 * @file
 * Miscellaneous engine-runtime free functions the application layer calls: the sound-effect
 * backend, customize-asset paths, the texture cache, the global scene tree, and the media timer.
 */

#pragma once

#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Constructs and initialises the AVFoundation sound-effect backend.
 * @ghidraAddress 0x4a5e8
 */
void InitializeSourceManager(void);
/**
 * @brief Returns the clear rank for the given achievement rate.
 * @ghidraAddress 0x14992c
 */
int GetClearRank(float achievementRate);
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
/**
 * @brief Lazily constructs the global touch-manager singleton.
 * @ghidraAddress 0x17c44
 */
void EnsureTouchManagerSingleton(void);
/**
 * @brief Lazily allocates the texture-cache control singleton.
 * @ghidraAddress 0x3198c
 */
void EnsureTextureCacheSingleton(unsigned char firstByte);
/**
 * @brief Reloads every cached texture from its stored image name after a context loss.
 * @ghidraAddress 0x33e5c
 */
void LoadAllCachedTextures(void);
/**
 * @brief Releases every texture handle held in the global texture cache.
 * @ghidraAddress 0x33e1c
 */
void ReleaseAllCachedTextures(void);
/**
 * @brief The head of the global live-texture cache list.
 *
 * The release-and-reload helpers read the list head as a side effect before cycling the cache; the
 * returned value is otherwise unused at the call sites that pair it with them.
 * @ghidraAddress 0x33bf0
 */
void *GetTextureCacheList(void);
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
void DispatchListenerList(void *pFrameArg);
/**
 * @brief Returns the elapsed time since the timer was last started, scaled to frames, as a float.
 * @ghidraAddress 0x3671c
 */
float GetElapsedMediaTime(double *pStartTime);
/**
 * @brief Records the current media time as a timer start value.
 * @ghidraAddress 0x366f8
 */
void StartMediaTimer(double *pStartTime);

#ifdef __cplusplus
}
#endif

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
