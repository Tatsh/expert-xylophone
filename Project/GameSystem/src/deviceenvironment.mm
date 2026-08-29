#import "deviceenvironment.h"

#import <UIKit/UIKit.h>

#import "AppDelegate.h"
#import "RBMacros.h"
#import "SystemHardware.h"
#import "deviceenvironment_globals.h"

static NSString *const kApiHostName = @RB_API_HOST;

static NSString *const kRegionCode = @"JP";

static NSString *const kJapaneseLprojName = @"ja.lproj";
static NSString *const kEnglishLprojName = @"en.lproj";

static NSString *const kAssetTagIPhone = @"iPhone";
static NSString *const kAssetTagIPhone2x = @"iPhone@2x";
static NSString *const kAssetTagIPad = @"iPad";
static NSString *const kAssetTagIPad2x = @"iPad2x";

static NSString *const kDownloadFolderName = @"Download";
static NSString *const kPrivateDocumentsFolderName = @"Private Documents";
static NSString *const kImagesFolderName = @"Images";

static NSString *const kDeviceDescriptionFormatWithName = @"%@/%@ (%@; iOS %@; %@) [%@]";
static NSString *const kDeviceDescriptionFormatPlain = @"%@/%@ (%@; iOS %@; %@)";

// @ghidraAddress 0x36c9a0
static NSString *const kProductName = @"REFLECBEATplus";

// The 4-inch iPhone's preferred mode.
constexpr double kTallScreenWidth = 640.0;
constexpr double kTallScreenHeight = 1136.0;

static NSString *const kGameCenterMinimumVersion = @"4.1";

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

    // -userInterfaceIdiom is unavailable before iOS 3.2.
    if ([device respondsToSelector:@selector(userInterfaceIdiom)]) {
        g_bIsPad = UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad;
    } else {
        g_bIsPad = false;
    }

    g_isHardwareType9 = [SystemHardware getInstance].getHardwareType == 9;
    g_isRetina = UIScreen.mainScreen.scale != 1.0;

    CGSize preferredSize = UIScreen.mainScreen.preferredMode.size;
    g_bIsTallScreen =
        preferredSize.width == kTallScreenWidth && preferredSize.height == kTallScreenHeight;

    g_pSystemVersion = UIDevice.currentDevice.systemVersion;
    g_pBundleVersion = NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"];
    g_pRegionCode = kRegionCode;
    g_pLocaleLanguageCode = [NSLocale.currentLocale objectForKey:NSLocaleLanguageCode];
    // A JP build on an English device reports en_JP.
    // @ghidraAddress 0x1a07e4
    g_pFormattedVersion =
        [NSString stringWithFormat:@"%@_%@", g_pLocaleLanguageCode, g_pRegionCode];

    if (g_bIsPad) {
        g_pDeviceAssetTag = g_isRetina ? kAssetTagIPad2x : kAssetTagIPad;
    } else {
        g_pDeviceAssetTag = g_isRetina ? kAssetTagIPhone2x : kAssetTagIPhone;
    }

    g_pDocumentsDirectoryPath =
        NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).lastObject;
    g_pCachesDirectoryPath =
        NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).lastObject;
    // The application-support path is cached here and never read back.
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

    g_pPreferredLanguageCode = NSLocale.preferredLanguages[0];
    if ([g_pPreferredLanguageCode isEqualToString:@"ja"] ||
        [g_pPreferredLanguageCode hasPrefix:@"ja-"]) {
        g_pPrimaryLprojName = kJapaneseLprojName;
        g_pFallbackLprojName = kEnglishLprojName;
    } else {
        g_pPrimaryLprojName = kEnglishLprojName;
        g_pFallbackLprojName = kJapaneseLprojName;
    }

    NSArray *serverData = [AppDelegate getServerData];
    id serverDataElement = (serverData != nil && serverData[0] != nil) ? serverData[0] : nil;
    NSString *deviceModel = UIDevice.currentDevice.model;
    g_pDeviceDescription = BuildDeviceDescription(deviceModel, serverDataElement);

    g_bHasGameCenter = true;
    if (NSClassFromString(@"GKLocalPlayer") == nil ||
        [g_pSystemVersion compare:kGameCenterMinimumVersion
                          options:NSNumericSearch] == NSOrderedAscending) {
        g_bHasGameCenter = false;
    }
}
