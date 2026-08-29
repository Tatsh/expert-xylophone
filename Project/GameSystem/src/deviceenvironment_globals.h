/**
 * @file
 * The cached device, locale, filesystem-path, and version globals that
 * @c InitializeDeviceEnvironment seeds once at startup and the accessors in @c deviceenvironment.h
 * read.
 */

#pragma once

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/** Whether the device uses the iPad interface idiom. @ghidraAddress 0x3df3d0 */
extern bool g_bIsPad;
/** Whether the device reports hardware type 9. @ghidraAddress 0x3df3d1 */
extern bool g_isHardwareType9;
/** Whether the main screen is Retina (scale differs from 1.0). @ghidraAddress 0x3df3d2 */
extern bool g_isRetina;
/** Whether the main screen is a tall (640x1136) display. @ghidraAddress 0x3df3d3 */
extern bool g_bIsTallScreen;
/** Whether Game Center is available. @ghidraAddress 0x3df3d4 */
extern bool g_bHasGameCenter;

/** The device asset-suffix tag (@c iPhone, @c iPhone@2x, @c iPad, or @c iPad2x).
 * @ghidraAddress 0x3df350 */
extern NSString *_Nullable g_pDeviceAssetTag;
/** The image-asset directory (@c PrivateDocuments/Images/\<assetTag\>).
 * @ghidraAddress 0x3df358 */
extern NSString *_Nullable g_pImageAssetDirectoryPath;
/** The download directory (Caches/Download). @ghidraAddress 0x3df360 */
extern NSString *_Nullable g_pDownloadDirectoryPath;
/** The preferred language code (for example @c "ja" or @c "en"). @ghidraAddress 0x3df368 */
extern NSString *_Nullable g_pPreferredLanguageCode;
/** The primary localization folder name (@c "ja.lproj" or @c "en.lproj").
 * @ghidraAddress 0x3df370 */
extern NSString *_Nullable g_pPrimaryLprojName;
/** The fallback localization folder name (the opposite of the primary).
 * @ghidraAddress 0x3df378 */
extern NSString *_Nullable g_pFallbackLprojName;
/** The device description string (device, iOS, and build). @ghidraAddress 0x3df380 */
extern NSString *_Nullable g_pDeviceDescription;
/** The iOS system version string. @ghidraAddress 0x3df388 */
extern NSString *_Nullable g_pSystemVersion;
/** The CFBundleVersion string. @ghidraAddress 0x3df390 */
extern NSString *_Nullable g_pBundleVersion;
/** The formatted version string. @ghidraAddress 0x3df398 */
extern NSString *_Nullable g_pFormattedVersion;
/** The region code string (@c "JP"). @ghidraAddress 0x3df3a0 */
extern NSString *_Nullable g_pRegionCode;
/** The current locale's language code. @ghidraAddress 0x3df3a8 */
extern NSString *_Nullable g_pLocaleLanguageCode;
/**
 * The Documents directory path, which every persistence route writes to and
 * @c +[NSFileManager freeFileSystemSize] measures.
 * @ghidraAddress 0x3df3b0
 */
extern NSString *_Nullable g_pDocumentsDirectoryPath;
/** The Caches directory path. @ghidraAddress 0x3df3b8 */
extern NSString *_Nullable g_pCachesDirectoryPath;
/** The Application Support directory path, cached but never read. @ghidraAddress 0x3df3c0 */
extern NSString *_Nullable g_pAppSupportPath;
/** The PrivateDocuments directory path (Library/PrivateDocuments). @ghidraAddress 0x3df3c8
 */
extern NSString *_Nullable g_pPrivateDocumentsPath;

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
