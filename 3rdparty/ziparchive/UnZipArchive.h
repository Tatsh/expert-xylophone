/**
 * @file
 * The application's own zip-reading wrapper, @c UnZipArchive.
 *
 * The class name is the binary's, and so are the ivar and selector names: the Objective-C runtime
 * metadata records all three. It is a small read-only wrapper over the bundled minizip, not the
 * Google Code "ziparchive" class of the same era — the binary defines exactly the ten methods
 * declared here and none of that library's archive-writing API.
 */

#import <Foundation/Foundation.h>

#include "minizip/mz_compat.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A read-only zip archive, opened from a path and iterated entry by entry.
 *
 * The archive is opened with @c -openFile: and closed with @c -closeFile; @c -dealloc closes it
 * too. @c -getData: is the whole-entry convenience the chart loader uses: it walks the entries from
 * the first, comparing each name, and returns the matching entry's bytes.
 *
 * Trailing @c // +0xNN comments document the binary's ivar offsets for reference only.
 */
@interface UnZipArchive : NSObject {
@private
    unzFile _Nullable m_ZipFile;         // +0x08: the open archive, or null.
    unz_global_info m_ZipFileGlobalInfo; // +0x10: the archive's global info, read at open.
    unz_file_info m_ZipFileInfo;         // +0x20: the current entry's info, refilled per entry.
}

/**
 * @brief Opens the archive at @p path, closing any archive already open.
 * @param path The filesystem path of the archive to open.
 * @return @c YES when the archive opened and its global info was read.
 * @ghidraAddress 0x14e08
 */
- (BOOL)openFile:(nullable NSString *)path;

/**
 * @brief Closes the open archive. A no-op when none is open.
 * @ghidraAddress 0x14ec8
 */
- (void)closeFile;

/**
 * @brief The number of entries the open archive holds.
 * @return The entry count, or 0 when no archive is open.
 * @ghidraAddress 0x14efc
 */
- (unsigned long)getEntryNum;

/**
 * @brief The bytes of the named entry.
 *
 * Walks the entries from the first, comparing each entry's name against @p entryName, and returns
 * the first match's uncompressed bytes.
 * @param entryName The entry name to find.
 * @return The entry's bytes, or nil when no archive is open or no entry matches.
 * @ghidraAddress 0x14f24
 */
- (nullable NSData *)getData:(nullable NSString *)entryName;

/**
 * @brief Seeks to the archive's first entry.
 * @return @c YES on success, @c NO when no archive is open or the seek failed.
 * @ghidraAddress 0x1503c
 */
- (BOOL)setFirst;

/**
 * @brief Seeks to the entry after the current one.
 * @return @c YES on success, @c NO when no archive is open or the last entry has been passed.
 * @ghidraAddress 0x15070
 */
- (BOOL)setNext;

/**
 * @brief The current entry's name.
 * @return The entry name, or nil when no archive is open or the entry info could not be read.
 * @ghidraAddress 0x150a4
 */
- (nullable NSString *)getCurrentFileName;

/**
 * @brief The current entry's uncompressed bytes.
 * @return The entry's bytes, or nil when no archive is open or the entry could not be opened.
 * @ghidraAddress 0x1519c
 */
- (nullable NSData *)getCurrentData;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
