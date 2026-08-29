#import "NSFileManager+RB.h"
#import "deviceenvironment.h"

static const unsigned long long kMinimumFreeSystemSize = 50 * 1024 * 1024;

static NSString *const kPaddingDirectoryName = @"padding";

static NSString *const kTemporaryFilesDirectoryName = @"Temporary Files";

static NSString *const kDirectoryOwnerName = @"owner";
static NSString *const kDirectoryGroupName = @"group";

// All but the modification date reach the code as their own constant strings rather than as the
// Foundation symbols of the same spelling.
static NSString *const kFileOwnerAccountNameKey = @"NSFileOwnerAccountName";
static NSString *const kFileGroupOwnerAccountNameKey = @"NSFileGroupOwnerAccountName";
static NSString *const kFilePosixPermissionsKey = @"NSFilePosixPermissions";
static NSString *const kFileExtensionHiddenKey = @"NSFileExtensionHidden";

static NSString *const kRootDirectoryPath = @"/";

// @ghidraAddress 0x3df510 (g_pDocumentDirectoryPathCache)
// @ghidraAddress 0x3df518 (g_pApplicationSupportDirectoryPathCache)
// @ghidraAddress 0x3df520 (g_pCachesDirectoryPathCache)
// @ghidraAddress 0x3df528 (g_pTemporaryDirectoryPathCache)
// @ghidraAddress 0x3df530 (g_pResourcePathCache)
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
    NSError *error = nil;
    return [[NSFileManager defaultManager] createDirectoryAtPath:path
                                     withIntermediateDirectories:YES
                                                      attributes:nil
                                                           error:&error];
}

+ (BOOL)createDirectorysAtPath:(NSString *)path {
    /** @ghidraAddress 0x1c9cec */
    NSArray *components = [NSArray arrayWithArray:path.pathComponents];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager changeCurrentDirectoryPath:kRootDirectoryPath];
    NSError *error = nil;
    NSEnumerator *enumerator = [components objectEnumerator];
    NSString *component = nil;
    while ((component = [enumerator nextObject])) {
        if ([fileManager fileExistsAtPath:component]) {
            [fileManager changeCurrentDirectoryPath:component];
            continue;
        }
        // The fourth object is nil, so the permissions and extension-hidden entries never reach
        // the dictionary.
        NSDictionary *attributes =
            [NSDictionary dictionaryWithObjectsAndKeys:[NSDate date],
                                                       NSFileModificationDate,
                                                       kDirectoryOwnerName,
                                                       kFileOwnerAccountNameKey,
                                                       kDirectoryGroupName,
                                                       kFileGroupOwnerAccountNameKey,
                                                       nil,
                                                       kFilePosixPermissionsKey,
                                                       [NSNumber numberWithBool:YES],
                                                       kFileExtensionHiddenKey,
                                                       nil];
        if (![fileManager createDirectoryAtPath:component
                    withIntermediateDirectories:YES
                                     attributes:attributes
                                          error:&error]) {
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
    // The binary measures the Documents path, not the application-support path this category also
    // vends.
    NSString *path = GetDocumentsDirectoryPath();
    NSError *error = nil;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSDictionary *attributes = [fileManager attributesOfFileSystemForPath:path error:&error];
    return [[attributes valueForKey:NSFileSystemFreeSize] longLongValue];
}

#pragma mark - Standard directories

+ (NSString *)paddingDirName {
    /** @ghidraAddress 0x1ca0c8 */
    return [GetDocumentsDirectoryPath() stringByAppendingPathComponent:kPaddingDirectoryName];
}

+ (NSString *)documentDirectoryPath {
    /** @ghidraAddress 0x1ca130 */
    @synchronized([NSFileManager class]) {
        if (g_pDocumentDirectoryPathCache == nil) {
            g_pDocumentDirectoryPathCache =
                NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)
                    .lastObject;
            g_pDocumentDirectoryPathCache =
                [[NSString alloc] initWithString:g_pDocumentDirectoryPathCache];
        }
        return g_pDocumentDirectoryPathCache;
    }
}

+ (NSString *)applicationSupportDirectoryPath {
    /** @ghidraAddress 0x1ca248 */
    @synchronized([NSFileManager class]) {
        if (g_pApplicationSupportDirectoryPathCache == nil) {
            g_pApplicationSupportDirectoryPathCache =
                NSSearchPathForDirectoriesInDomains(
                    NSApplicationSupportDirectory, NSUserDomainMask, YES)
                    .lastObject;
            g_pApplicationSupportDirectoryPathCache =
                [[NSString alloc] initWithString:g_pApplicationSupportDirectoryPathCache];
        }
        return g_pApplicationSupportDirectoryPathCache;
    }
}

+ (NSString *)cachesDirectoryPath {
    /** @ghidraAddress 0x1ca360 */
    @synchronized([NSFileManager class]) {
        if (g_pCachesDirectoryPathCache == nil) {
            g_pCachesDirectoryPathCache =
                NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)
                    .lastObject;
            g_pCachesDirectoryPathCache =
                [[NSString alloc] initWithString:g_pCachesDirectoryPathCache];
        }
        return g_pCachesDirectoryPathCache;
    }
}

+ (NSString *)temporaryDirectoryPath {
    /** @ghidraAddress 0x1ca478 */
    if (g_pTemporaryDirectoryPathCache == nil) {
        g_pTemporaryDirectoryPathCache = NSTemporaryDirectory();
        if (g_pTemporaryDirectoryPathCache == nil) {
            g_pTemporaryDirectoryPathCache = [[NSFileManager cachesDirectoryPath]
                stringByAppendingPathComponent:kTemporaryFilesDirectoryName];
        }
        g_pTemporaryDirectoryPathCache =
            [[NSString alloc] initWithString:g_pTemporaryDirectoryPathCache];
    }
    return g_pTemporaryDirectoryPathCache;
}

+ (NSString *)resourcePath {
    /** @ghidraAddress 0x1ca560 */
    if (g_pResourcePathCache == nil) {
        g_pResourcePathCache = [[NSString alloc] initWithString:[NSBundle mainBundle].resourcePath];
    }
    return g_pResourcePathCache;
}

@end
