//
//  NSFileManager+RB.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (category NSFileManager(RB)). Verified
//  against the arm64 disassembly (the createDirectorysAtPath: attributes dictionary is variadic and
//  partly dropped by the decompiler, and every path getter dispatches to the NSFileManager class
//  object even though the metadata files the methods in the instance-method list).
//

#import "NSFileManager+RB.h"

/// The minimum free space, in bytes, that @c isFreeSystemSize requires (50 MiB).
static const unsigned long long kMinimumFreeSystemSize = 50 * 1024 * 1024;

/// The sub-directory of the application-support directory that holds padding files.
static NSString *const kPaddingDirectoryName = @"padding";

/// The caches sub-directory used as the temporary directory when @c NSTemporaryDirectory is
/// unavailable.
static NSString *const kTemporaryFilesDirectoryName = @"Temporary Files";

/// Attribute keys applied to each directory level created by @c createDirectorysAtPath:.
static NSString *const kDirectoryOwnerName = @"owner";
static NSString *const kDirectoryGroupName = @"group";

/// Lazily initialised, owned copies of the resolved standard directory paths.
/// @ghidraAddress 0x3df510 (g_pDocumentDirectoryPathCache)
/// @ghidraAddress 0x3df518 (g_pApplicationSupportDirectoryPathCache)
/// @ghidraAddress 0x3df520 (g_pCachesDirectoryPathCache)
/// @ghidraAddress 0x3df528 (g_pTemporaryDirectoryPathCache)
/// @ghidraAddress 0x3df530 (g_pResourcePathCache)
static NSString *g_pDocumentDirectoryPathCache = nil;
static NSString *g_pApplicationSupportDirectoryPathCache = nil;
static NSString *g_pCachesDirectoryPathCache = nil;
static NSString *g_pTemporaryDirectoryPathCache = nil;
static NSString *g_pResourcePathCache = nil;

@implementation NSFileManager (RB)

#pragma mark - Existence checks

+ (BOOL)isFileExist:(NSString *)path {
    /** @ghidraAddress 0x1c9954 */
    BOOL isDirectory = YES;
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory];
    return exists && !isDirectory;
}

+ (BOOL)isDirectoryExist:(NSString *)path {
    /** @ghidraAddress 0x1c9a0c */
    BOOL isDirectory = NO;
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory];
    return exists && isDirectory;
}

#pragma mark - Directory creation

+ (BOOL)createDirectory:(NSString *)path {
    /** @ghidraAddress 0x1c9ac0 */
    return [[NSFileManager defaultManager] createDirectoryAtPath:path
                                     withIntermediateDirectories:YES
                                                      attributes:nil
                                                           error:nil];
}

+ (BOOL)createDirectorysAtPath:(NSString *)path {
    /** @ghidraAddress 0x1c9cec */
    NSArray *components = [NSArray arrayWithArray:path.pathComponents];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager changeCurrentDirectoryPath:@"/"];
    for (NSString *component in components) {
        if ([fileManager fileExistsAtPath:component]) {
            [fileManager changeCurrentDirectoryPath:component];
            continue;
        }
        NSDictionary *attributes =
            [NSDictionary dictionaryWithObjectsAndKeys:[NSDate date],
                                                       NSFileModificationDate,
                                                       kDirectoryOwnerName,
                                                       NSFileOwnerAccountName,
                                                       kDirectoryGroupName,
                                                       NSFileGroupOwnerAccountName,
                                                       nil,
                                                       NSFilePosixPermissions,
                                                       [NSNumber numberWithBool:YES],
                                                       NSFileExtensionHidden,
                                                       nil];
        if (![fileManager createDirectoryAtPath:component
                    withIntermediateDirectories:YES
                                     attributes:attributes
                                          error:nil]) {
            return NO;
        }
        [fileManager changeCurrentDirectoryPath:component];
    }
    return YES;
}

#pragma mark - Free space

+ (BOOL)isFreeSystemSize {
    /** @ghidraAddress 0x1c9b70 */
    return [NSFileManager freeFileSystemSize] > kMinimumFreeSystemSize;
}

+ (unsigned long long)freeFileSystemSize {
    /** @ghidraAddress 0x1c9ba0 */
    NSString *path = [NSFileManager applicationSupportDirectoryPath];
    NSDictionary *attributes =
        [[NSFileManager defaultManager] attributesOfFileSystemForPath:path error:nil];
    return [[attributes valueForKey:NSFileSystemFreeSize] longLongValue];
}

#pragma mark - Standard directories

+ (NSString *)paddingDirName {
    /** @ghidraAddress 0x1ca0c8 */
    return [[NSFileManager applicationSupportDirectoryPath]
        stringByAppendingPathComponent:kPaddingDirectoryName];
}

+ (NSString *)documentDirectoryPath {
    /** @ghidraAddress 0x1ca130 */
    @synchronized([NSFileManager class]) {
        if (g_pDocumentDirectoryPathCache == nil) {
            NSString *path =
                NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)
                    .lastObject;
            g_pDocumentDirectoryPathCache = [[NSString alloc] initWithString:path];
        }
        return g_pDocumentDirectoryPathCache;
    }
}

+ (NSString *)applicationSupportDirectoryPath {
    /** @ghidraAddress 0x1ca248 */
    @synchronized([NSFileManager class]) {
        if (g_pApplicationSupportDirectoryPathCache == nil) {
            NSString *path = NSSearchPathForDirectoriesInDomains(
                                 NSApplicationSupportDirectory, NSUserDomainMask, YES)
                                 .lastObject;
            g_pApplicationSupportDirectoryPathCache = [[NSString alloc] initWithString:path];
        }
        return g_pApplicationSupportDirectoryPathCache;
    }
}

+ (NSString *)cachesDirectoryPath {
    /** @ghidraAddress 0x1ca360 */
    @synchronized([NSFileManager class]) {
        if (g_pCachesDirectoryPathCache == nil) {
            NSString *path =
                NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES)
                    .lastObject;
            g_pCachesDirectoryPathCache = [[NSString alloc] initWithString:path];
        }
        return g_pCachesDirectoryPathCache;
    }
}

+ (NSString *)temporaryDirectoryPath {
    /** @ghidraAddress 0x1ca478 */
    if (g_pTemporaryDirectoryPathCache == nil) {
        NSString *path = NSTemporaryDirectory();
        if (path == nil) {
            path = [[NSFileManager cachesDirectoryPath]
                stringByAppendingPathComponent:kTemporaryFilesDirectoryName];
        }
        g_pTemporaryDirectoryPathCache = [[NSString alloc] initWithString:path];
    }
    return g_pTemporaryDirectoryPathCache;
}

+ (NSString *)resourcePath {
    /** @ghidraAddress 0x1ca560 */
    if (g_pResourcePathCache == nil) {
        g_pResourcePathCache =
            [[NSString alloc] initWithString:[NSBundle mainBundle].resourcePath];
    }
    return g_pResourcePathCache;
}

@end

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
