#import "DownloadResourceManager.h"

#import "NSFileManager+RB.h"
#import "RBUserSettingData.h"
#import "SSZipArchive.h"
#import "deviceenvironment.h"

static NSString *const kArchivePassword = @"mt972";

static NSString *const kManifestArchiveSuffix = @"/list";
static NSString *const kManifestListSuffix = @"/lists";
static NSString *const kPathSeparator = @"/";
static NSString *const kManifestLineSeparator = @"\n";

static NSString *const kBuiltInResourceVersion = @"4.5.6";

static NSString *const kResponseKeyVersion = @"Version";
static NSString *const kResponseKeyType = @"Type";
static NSString *const kResponseTypeAcceptable = @"1";

@implementation DownloadResourceManager

+ (BOOL)fileListCheck {
    NSString *manifestArchivePath =
        [GetImageAssetDirectoryPath() stringByAppendingString:kManifestArchiveSuffix];
    BOOL unzipped = [SSZipArchive unzipFileAtPath:manifestArchivePath
                                    toDestination:GetImageAssetDirectoryPath()
                                        overwrite:YES
                                         password:kArchivePassword
                                            error:nil
                                         delegate:nil];
    if (!unzipped) {
        return NO;
    }

    NSString *manifestListPath =
        [GetImageAssetDirectoryPath() stringByAppendingString:kManifestListSuffix];
    NSString *manifest = [NSString stringWithContentsOfFile:manifestListPath
                                                   encoding:NSUTF8StringEncoding
                                                      error:nil];
    if (manifest == nil) {
        return NO;
    }

    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager
        removeItemAtPath:[GetImageAssetDirectoryPath() stringByAppendingString:kManifestListSuffix]
                   error:nil];
    NSArray *entries = [manifest componentsSeparatedByString:kManifestLineSeparator];
    if (entries == nil) {
        return NO;
    }

    BOOL allPresent = YES;
    for (NSUInteger i = 0; i < entries.count; ++i) {
        NSString *filePath = [[GetImageAssetDirectoryPath() stringByAppendingString:kPathSeparator]
            stringByAppendingString:entries[i]];
        allPresent = allPresent && [fileManager fileExistsAtPath:filePath];
        if (!allPresent) {
            break;
        }
    }
    return allPresent;
}

+ (DownloadResourceManagerResult)offlineCheck {
    if (![NSFileManager isDirectoryExist:GetImageAssetDirectoryPath()]) {
        return DownloadResourceManagerResultMissing;
    }
    NSString *installedVersion = [RBUserSettingData sharedInstance].resourceDownloadVersion;
    if (installedVersion == nil) {
        return DownloadResourceManagerResultOutdated;
    }
    if ([installedVersion compare:kBuiltInResourceVersion
                          options:NSNumericSearch] == NSOrderedAscending) {
        return DownloadResourceManagerResultUpdate;
    }
    return DownloadResourceManagerResultCurrent;
}

+ (DownloadResourceManagerResult)onlineChek:(NSDictionary *)response {
    NSString *installedVersion = [RBUserSettingData sharedInstance].resourceDownloadVersion;
    if ([installedVersion compare:response[kResponseKeyVersion]
                          options:NSNumericSearch] != NSOrderedAscending) {
        return [DownloadResourceManager fileListCheck] ? DownloadResourceManagerResultCurrent :
                                                         DownloadResourceManagerResultUpdate;
    }
    // The binary returns the inverse of whether the "Type" flag equals "1".
    NSString *type = response[kResponseKeyType];
    BOOL acceptable = type != nil && [kResponseTypeAcceptable isEqualToString:type];
    return acceptable ? DownloadResourceManagerResultMissing :
                        DownloadResourceManagerResultOutdated;
}

@end
