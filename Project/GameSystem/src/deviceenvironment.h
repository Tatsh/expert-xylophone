/**
 * @file
 * The cached device, locale, filesystem-path, and version accessors seeded at startup.
 */

#pragma once

#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Returns the cached Application Support directory path.
 * @ghidraAddress 0x1a1624
 */
NSString *GetApplicationSupportPath(void);
/**
 * @brief Returns the cached PrivateDocuments directory path.
 * @ghidraAddress 0x1a1224
 */
NSString *GetPrivateDocumentsPath(void);
/**
 * @brief Returns the cached Caches directory path.
 * @ghidraAddress 0x1a1218
 */
NSString *GetCachesDirectoryPath(void);
/**
 * @brief Returns the cached image-asset directory path (PrivateDocuments/Images/<deviceAssetTag>).
 * @ghidraAddress 0x1a1260
 */
NSString *GetImageAssetDirectoryPath(void);
/**
 * @brief Returns the cached download directory path (Caches/Download).
 * @ghidraAddress 0x1a126c
 */
NSString *GetDownloadDirectoryPath(void);
/**
 * @brief Returns the API host name string.
 * @ghidraAddress 0x325e4
 */
NSString *GetApiHostString(void);
/**
 * @brief Returns the cached region code string (for example @c "JP").
 * @ghidraAddress 0x1a1278
 */
NSString *GetRegionCode(void);
/**
 * @brief Returns the cached "screen is Retina" flag (the main screen scale differs from 1.0).
 * @ghidraAddress 0x1a120c
 */
bool GetIsRetinaFlag(void);
/**
 * @brief Returns the cached "screen is tall" flag (the main screen is a 4-inch or larger display).
 * @ghidraAddress 0x1a1248
 */
bool GetIsTallScreenFlag(void);
/**
 * @brief Returns the cached "device is the older type 9 hardware" flag.
 * @ghidraAddress 0x1a123c
 */
bool GetIsHardwareType9Flag(void);
/**
 * @brief Returns the cached preferred language code (for example @c "ja" or @c "en").
 * @ghidraAddress 0x1a1230
 */
NSString *GetPreferredLanguageCode(void);
/**
 * @brief Returns the cached primary localization folder name (for example @c "ja.lproj").
 * @ghidraAddress 0x1a1284
 */
NSString *GetPrimaryLprojName(void);
/**
 * @brief Returns the cached fallback localization folder name (the opposite of the primary lproj).
 * @ghidraAddress 0x1a1290
 */
NSString *GetFallbackLprojName(void);
/**
 * @brief Returns the cached CFBundleVersion string.
 * @ghidraAddress 0x1a160c
 */
NSString *GetBundleVersionString(void);
/**
 * @brief Returns the cached device description string (device, iOS, and build).
 * @ghidraAddress 0x1a129c
 */
NSString *GetDeviceDescriptionString(void);
/**
 * @brief Rebuilds the cached device description string from the current server data and device
 *        info; a no-op until server data is available.
 * @ghidraAddress 0x1a12a8
 */
void RebuildDeviceDescriptionString(void);
/**
 * @brief Returns the cached iOS system version string.
 * @ghidraAddress 0x1a1600
 */
NSString *GetSystemVersionString(void);
/**
 * @brief Returns the cached formatted version string.
 * @ghidraAddress 0x1a1618
 */
NSString *GetFormattedVersionString(void);
/**
 * @brief Reports whether the device uses the iPad interface idiom.
 *
 * Reads the cached idiom flag (@c UIDevice.userInterfaceIdiom @c == @c UIUserInterfaceIdiomPad) that
 * @c InitializeDeviceEnvironment sets once at startup. It selects the wide (pad) versus narrow
 * (phone) layout branch throughout the UI, and the score-digit glyph-spacing table.
 * @return @c true on an iPad-idiom device, @c false otherwise.
 * @ghidraAddress 0x1a1200
 */
bool IsPad(void);
/**
 * @brief One-time initialiser for the global device, locale, and filesystem environment values.
 * @ghidraAddress 0x1a04c4
 */
void InitializeDeviceEnvironment(void);

#ifdef __cplusplus
}
#endif

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
