/** @file
 * @c NSFileManager convenience helpers used throughout the game: existence and directory checks,
 * directory creation, a free-space guard, and cached accessors for the standard on-device
 * directories.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (category @c NSFileManager(RB), image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 *
 * Although the category's methods are recorded in the binary's instance-method list, every caller
 * dispatches them to the @c NSFileManager class object, so they are reconstructed as class methods.
 */

#import <Foundation/Foundation.h>

/**
 * @brief Filesystem convenience helpers layered on @c NSFileManager.
 */
@interface NSFileManager (RB)

/**
 * @brief Whether a regular (non-directory) file exists at a path.
 * @param path The filesystem path to test.
 * @return @c YES when @p path exists and is not a directory.
 * @ghidraAddress 0x1c9954
 */
+ (BOOL)isFileExist:(NSString *)path;

/**
 * @brief Whether a directory exists at a path.
 * @param path The filesystem path to test.
 * @return @c YES when @p path exists and is a directory.
 * @ghidraAddress 0x1c9a0c
 */
+ (BOOL)isDirectoryExist:(NSString *)path;

/**
 * @brief Create a directory, including any missing intermediate directories.
 * @param path The directory path to create.
 * @return @c YES when the directory was created.
 * @ghidraAddress 0x1c9ac0
 */
+ (BOOL)createDirectory:(NSString *)path;

/**
 * @brief Create a directory tree one component at a time, applying default file attributes to each
 * newly created level.
 * @param path The target directory path.
 * @return @c YES when every component was created (or already existed).
 * @ghidraAddress 0x1c9cec
 */
+ (BOOL)createDirectorysAtPath:(NSString *)path;

/**
 * @brief Whether the volume has more than the required amount of free space.
 * @return @c YES when the free space reported by @c freeFileSystemSize exceeds the minimum.
 * @ghidraAddress 0x1c9b70
 */
+ (BOOL)isFreeSystemSize;

/**
 * @brief The number of free bytes on the application-support volume.
 * @return The free size in bytes.
 * @ghidraAddress 0x1c9ba0
 */
+ (unsigned long long)freeFileSystemSize;

/**
 * @brief The padding-file directory (@c padding under the application-support directory).
 * @return The padding directory path.
 * @ghidraAddress 0x1ca0c8
 */
+ (NSString *)paddingDirName;

/**
 * @brief The cached documents directory path.
 *
 * Despite the name, the shipped build resolves this against @c NSCachesDirectory.
 * @return The cached path.
 * @ghidraAddress 0x1ca130
 */
+ (NSString *)documentDirectoryPath;

/**
 * @brief The cached application-support directory path (@c NSApplicationSupportDirectory).
 * @return The cached path.
 * @ghidraAddress 0x1ca248
 */
+ (NSString *)applicationSupportDirectoryPath;

/**
 * @brief The cached caches directory path.
 *
 * Despite the name, the shipped build resolves this against @c NSLibraryDirectory.
 * @return The cached path.
 * @ghidraAddress 0x1ca360
 */
+ (NSString *)cachesDirectoryPath;

/**
 * @brief The cached temporary directory path.
 *
 * Uses @c NSTemporaryDirectory when available, otherwise falls back to a @c "Temporary Files"
 * directory under the caches directory.
 * @return The cached path.
 * @ghidraAddress 0x1ca478
 */
+ (NSString *)temporaryDirectoryPath;

/**
 * @brief The cached main-bundle resource path.
 * @return The cached path.
 * @ghidraAddress 0x1ca560
 */
+ (NSString *)resourcePath;

@end

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
