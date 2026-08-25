#import "deviceenvironment.h"

#import <UIKit/UIKit.h>

#import "AppDelegate.h"
#import "RBMacros.h"
#import "SystemHardware.h"
#import "deviceenvironment_globals.h"

// The API host the server requests target, from RB_API_HOST so a build can be pointed at a
// replacement server; see RBMacros.h.
static NSString *const kApiHostName = @RB_API_HOST;

// The region this build is locked to.
static NSString *const kRegionCode = @"JP";

// The two localization folder names; the primary/fallback pair is chosen by the preferred language.
static NSString *const kJapaneseLprojName = @"ja.lproj";
static NSString *const kEnglishLprojName = @"en.lproj";

// The device asset-suffix tags, selected by interface idiom crossed with Retina.
static NSString *const kAssetTagIPhone = @"iPhone";
static NSString *const kAssetTagIPhone2x = @"iPhone@2x";
static NSString *const kAssetTagIPad = @"iPad";
static NSString *const kAssetTagIPad2x = @"iPad2x";

// The filesystem path components appended when building the derived directories.
static NSString *const kDownloadFolderName = @"Download";
static NSString *const kPrivateDocumentsFolderName = @"Private Documents";
static NSString *const kImagesFolderName = @"Images";

// The device-description format strings: the bracketed variant carries the hardware name, the plain
// variant is used on the simulator where no hardware name is available.
static NSString *const kDeviceDescriptionFormatWithName = @"%@/%@ (%@; iOS %@; %@) [%@]";
static NSString *const kDeviceDescriptionFormatPlain = @"%@/%@ (%@; iOS %@; %@)";

// The product name the description leads with, and so the User-Agent every request carries. It had
// been an empty string, which sent a User-Agent starting at the slash. The binary passes the
// constant at 0x36c9a0, fourteen bytes long, as the first argument at 0x1a1498.
static NSString *const kProductName = @"REFLECBEATplus";

// The tall-screen match dimensions (the 4-inch iPhone's 640x1136 preferred mode).
constexpr double kTallScreenWidth = 640.0;
constexpr double kTallScreenHeight = 1136.0;

// The minimum iOS version that carries a usable Game Center.
static NSString *const kGameCenterMinimumVersion = @"4.1";

// Definitions of the cached environment globals declared in deviceenvironment_globals.h.
bool g_bIsPad = false;
bool g_isHardwareType9 = false;
bool g_isRetina = false;
bool g_bIsTallScreen = false;
bool g_bHasGameCenter = false;
NSString *g_pDeviceAssetTag = nil;
NSString *g_pImageAssetDirectoryPath = nil;
NSString *g_pDownloadDirectoryPath = nil;
NSString *g_pPreferredLanguageCode = nil;
NSString *g_pPrimaryLprojName = nil;
NSString *g_pFallbackLprojName = nil;
NSString *g_pDeviceDescription = nil;
NSString *g_pSystemVersion = nil;
NSString *g_pBundleVersion = nil;
NSString *g_pFormattedVersion = nil;
NSString *g_pRegionCode = nil;
NSString *g_pLocaleLanguageCode = nil;
NSString *g_pDocumentsDirectoryPath = nil;
NSString *g_pCachesDirectoryPath = nil;
NSString *g_pAppSupportPath = nil;
NSString *g_pPrivateDocumentsPath = nil;

#pragma mark - Cached-value accessors

/** @ghidraAddress 0x1a1624 */
NSString *GetDocumentsDirectoryPath(void) {
    return g_pDocumentsDirectoryPath;
}

/** @ghidraAddress 0x1a1224 */
NSString *GetPrivateDocumentsPath(void) {
    return g_pPrivateDocumentsPath;
}

/** @ghidraAddress 0x1a1218 */
NSString *GetCachesDirectoryPath(void) {
    return g_pCachesDirectoryPath;
}

/** @ghidraAddress 0x1a1260 */
NSString *GetImageAssetDirectoryPath(void) {
    return g_pImageAssetDirectoryPath;
}

/** @ghidraAddress 0x1a126c */
NSString *GetDownloadDirectoryPath(void) {
    return g_pDownloadDirectoryPath;
}

/** @ghidraAddress 0x325e4 */
NSString *GetApiHostString(void) {
    return kApiHostName;
}

/** @ghidraAddress 0x1a1278 */
NSString *GetRegionCode(void) {
    return g_pRegionCode;
}

/** @ghidraAddress 0x1a120c */
bool GetIsRetinaFlag(void) {
    return g_isRetina;
}

/** @ghidraAddress 0x1a1248 */
bool GetIsTallScreenFlag(void) {
    return g_bIsTallScreen;
}

/** @ghidraAddress 0x1a123c */
bool GetIsHardwareType9Flag(void) {
    return g_isHardwareType9;
}

/** @ghidraAddress 0x1a1230 */
NSString *GetPreferredLanguageCode(void) {
    return g_pPreferredLanguageCode;
}

/** @ghidraAddress 0x1a1284 */
NSString *GetPrimaryLprojName(void) {
    return g_pPrimaryLprojName;
}

/** @ghidraAddress 0x1a1290 */
NSString *GetFallbackLprojName(void) {
    return g_pFallbackLprojName;
}

/** @ghidraAddress 0x1a160c */
NSString *GetBundleVersionString(void) {
    return g_pBundleVersion;
}

/** @ghidraAddress 0x1a129c */
NSString *GetDeviceDescriptionString(void) {
    return g_pDeviceDescription;
}

/** @ghidraAddress 0x1a1600 */
NSString *GetSystemVersionString(void) {
    return g_pSystemVersion;
}

/** @ghidraAddress 0x1a1618 */
NSString *GetFormattedVersionString(void) {
    return g_pFormattedVersion;
}

/** @ghidraAddress 0x1a1254 */
bool GetHasGameCenterFlag(void) {
    return g_bHasGameCenter;
}

/** @ghidraAddress 0x1a1200 */
bool IsPad(void) {
    return g_bIsPad;
}

#pragma mark - Device-description builder

// Builds the device-description string from the current bundle version, hardware, iOS version, and
// locale. On a real device the hardware name is included in the bracketed suffix; on the simulator
// (no hardware name) the plain variant is used. The system version has its dots stripped.
static NSString *BuildDeviceDescription(NSString *deviceModel, id serverDataElement) {
    NSString *bundleVersion = NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"];
    NSString *systemVersion = UIDevice.currentDevice.systemVersion;
    NSString *localeIdentifier = NSLocale.currentLocale.localeIdentifier;
    NSString *strippedVersion = [systemVersion stringByReplacingOccurrencesOfString:@"."
                                                                         withString:@"_"];

    const bool isSimulator = [deviceModel isEqualToString:@"iPhone Simulator"] ||
                             [deviceModel isEqualToString:@"iPad Simulator"];

    if (!isSimulator) {
        NSString *hardwareName = [SystemHardware getInstance].getHardwareName;
        return [[NSString alloc] initWithFormat:kDeviceDescriptionFormatWithName,
                                                kProductName,
                                                bundleVersion,
                                                hardwareName,
                                                strippedVersion,
                                                localeIdentifier,
                                                serverDataElement];
    }
    if (serverDataElement == nil) {
        return [[NSString alloc] initWithFormat:kDeviceDescriptionFormatPlain,
                                                kProductName,
                                                bundleVersion,
                                                strippedVersion,
                                                localeIdentifier,
                                                serverDataElement];
    }
    NSString *hardwareName = [SystemHardware getInstance].getHardwareName;
    return [[NSString alloc] initWithFormat:kDeviceDescriptionFormatWithName,
                                            kProductName,
                                            bundleVersion,
                                            hardwareName,
                                            strippedVersion,
                                            localeIdentifier,
                                            serverDataElement];
}

/** @ghidraAddress 0x1a12a8 */
void RebuildDeviceDescriptionString(void) {
    // Only rebuild once the server data (and its first element) is available.
    NSArray *serverData = [AppDelegate getServerData];
    if (serverData == nil || serverData[0] == nil) {
        return;
    }
    NSString *deviceModel = UIDevice.currentDevice.model;
    g_pDeviceDescription = BuildDeviceDescription(deviceModel, serverData[0]);
}

#pragma mark - One-time initialiser

/** @ghidraAddress 0x1a04c4 */
void InitializeDeviceEnvironment(void) {
    UIDevice *device = UIDevice.currentDevice;

    // The interface idiom (guarded because -userInterfaceIdiom is unavailable before iOS 3.2).
    if ([device respondsToSelector:@selector(userInterfaceIdiom)]) {
        g_bIsPad = UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad;
    } else {
        g_bIsPad = false;
    }

    g_isHardwareType9 = [SystemHardware getInstance].getHardwareType == 9;
    g_isRetina = UIScreen.mainScreen.scale != 1.0;

    // The tall-screen flag matches the 4-inch iPhone's 640x1136 preferred mode.
    CGSize preferredSize = UIScreen.mainScreen.preferredMode.size;
    g_bIsTallScreen =
        preferredSize.width == kTallScreenWidth && preferredSize.height == kTallScreenHeight;

    g_pSystemVersion = UIDevice.currentDevice.systemVersion;
    g_pBundleVersion = NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"];
    g_pRegionCode = kRegionCode;
    g_pLocaleLanguageCode = [NSLocale.currentLocale objectForKey:NSLocaleLanguageCode];
    // The device's language crossed with the build's region, so a JP build on an English device
    // reports en_JP. The stack setup at 0x1a07e4 pairs the language code at 0x3df3a8 with the
    // region code at 0x3df3a0, and stores the result to 0x3df398.
    g_pFormattedVersion =
        [NSString stringWithFormat:@"%@_%@", g_pLocaleLanguageCode, g_pRegionCode];

    // The asset-suffix tag from idiom crossed with Retina.
    if (g_bIsPad) {
        g_pDeviceAssetTag = g_isRetina ? kAssetTagIPad2x : kAssetTagIPad;
    } else {
        g_pDeviceAssetTag = g_isRetina ? kAssetTagIPhone2x : kAssetTagIPhone;
    }

    // The cached filesystem paths. The Documents path is the one the accessor at 0x1a1624 vends and
    // every persistence route reads; the application-support path is cached here and never read
    // back.
    g_pDocumentsDirectoryPath =
        NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).lastObject;
    g_pCachesDirectoryPath =
        NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).lastObject;
    g_pAppSupportPath =
        NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES)
            .lastObject;
    g_pDownloadDirectoryPath =
        [g_pCachesDirectoryPath stringByAppendingPathComponent:kDownloadFolderName];

    NSString *libraryPath =
        NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES).lastObject;
    g_pPrivateDocumentsPath =
        [libraryPath stringByAppendingPathComponent:kPrivateDocumentsFolderName];
    g_pImageAssetDirectoryPath =
        [[g_pPrivateDocumentsPath stringByAppendingPathComponent:kImagesFolderName]
            stringByAppendingPathComponent:g_pDeviceAssetTag];

    // The primary/fallback localization pair from the preferred language (Japanese versus other).
    g_pPreferredLanguageCode = NSLocale.preferredLanguages[0];
    if ([g_pPreferredLanguageCode isEqualToString:@"ja"] ||
        [g_pPreferredLanguageCode hasPrefix:@"ja-"]) {
        g_pPrimaryLprojName = kJapaneseLprojName;
        g_pFallbackLprojName = kEnglishLprojName;
    } else {
        g_pPrimaryLprojName = kEnglishLprojName;
        g_pFallbackLprojName = kJapaneseLprojName;
    }

    // The device-description string, using the server data's first element when present.
    NSArray *serverData = [AppDelegate getServerData];
    id serverDataElement = (serverData != nil && serverData[0] != nil) ? serverData[0] : nil;
    NSString *deviceModel = UIDevice.currentDevice.model;
    g_pDeviceDescription = BuildDeviceDescription(deviceModel, serverDataElement);

    // Game Center is available when its class exists and the OS is at least 4.1.
    g_bHasGameCenter = true;
    if (NSClassFromString(@"GKLocalPlayer") == nil ||
        [g_pSystemVersion compare:kGameCenterMinimumVersion
                          options:NSNumericSearch] == NSOrderedAscending) {
        g_bHasGameCenter = false;
    }
}
