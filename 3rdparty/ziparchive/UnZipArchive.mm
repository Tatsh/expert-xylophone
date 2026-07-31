//
//  UnZipArchive.mm
//
//  Reconstructed from Ghidra project rb458, program rb458 (class UnZipArchive). Verified against
//  the arm64 disassembly of all ten methods the binary defines. The class name, the three ivar
//  names, and every selector come from the binary's own runtime metadata; it is the application's
//  own read-only minizip wrapper rather than the Google Code "ziparchive" library, which the
//  binary does not contain. The file keeps its .mm extension because the build files name it.
//

#import "UnZipArchive.h"

#include <cstdlib>

// The read chunk -getCurrentData pulls each entry through, in bytes.
constexpr unsigned int kReadChunkSize = 0x1000;

// The C-string encoding the entry names are decoded with.
constexpr NSStringEncoding kEntryNameEncoding = NSASCIIStringEncoding;

@implementation UnZipArchive

#pragma mark Lifecycle

/** @ghidraAddress 0x14d40 */
- (instancetype)init {
    self = [super init];
    if (self) {
        m_ZipFile = nullptr;
    }
    return self;
}

/** @ghidraAddress 0x14d84 */
- (void)dealloc {
    // The binary closes the archive and then chains [super dealloc]; ARC chains automatically.
    [self closeFile];
}

#pragma mark Opening and closing

/** @ghidraAddress 0x14e08 */
- (BOOL)openFile:(NSString *)path {
    if (path == nil) {
        return NO;
    }
    if (m_ZipFile != nullptr) {
        unzClose(m_ZipFile);
        m_ZipFile = nullptr;
    }
    m_ZipFile = unzOpen(path.UTF8String);
    if (m_ZipFile == nullptr) {
        return NO;
    }
    if (unzGetGlobalInfo(m_ZipFile, &m_ZipFileGlobalInfo) != UNZ_OK) {
        unzClose(m_ZipFile);
        m_ZipFile = nullptr;
        return NO;
    }
    return YES;
}

/** @ghidraAddress 0x14ec8 */
- (void)closeFile {
    if (m_ZipFile != nullptr) {
        unzClose(m_ZipFile);
        m_ZipFile = nullptr;
    }
}

#pragma mark Entries

/** @ghidraAddress 0x14efc */
- (unsigned long)getEntryNum {
    if (m_ZipFile == nullptr) {
        return 0;
    }
    return m_ZipFileGlobalInfo.number_entry;
}

/** @ghidraAddress 0x1503c */
- (BOOL)setFirst {
    if (m_ZipFile == nullptr) {
        return NO;
    }
    return unzGoToFirstFile(m_ZipFile) == UNZ_OK;
}

/** @ghidraAddress 0x15070 */
- (BOOL)setNext {
    if (m_ZipFile == nullptr) {
        return NO;
    }
    return unzGoToNextFile(m_ZipFile) == UNZ_OK;
}

/** @ghidraAddress 0x150a4 */
- (NSString *)getCurrentFileName {
    if (m_ZipFile == nullptr) {
        return nil;
    }
    // The first pass fills in the entry info so the name length is known; the second reads the
    // name into a buffer sized from it.
    if (unzGetCurrentFileInfo(m_ZipFile, &m_ZipFileInfo, nullptr, 0, nullptr, 0, nullptr, 0) !=
        UNZ_OK) {
        return nil;
    }
    const uint16_t nBufferSize = static_cast<uint16_t>(m_ZipFileInfo.size_filename + 1);
    char *pName = static_cast<char *>(malloc(nBufferSize));
    if (unzGetCurrentFileInfo(
            m_ZipFile, &m_ZipFileInfo, pName, nBufferSize, nullptr, 0, nullptr, 0) != UNZ_OK) {
        free(pName);
        return nil;
    }
    pName[m_ZipFileInfo.size_filename] = '\0';
    NSString *name = [NSString stringWithCString:pName encoding:kEntryNameEncoding];
    free(pName);
    return name;
}

/** @ghidraAddress 0x1519c */
- (NSData *)getCurrentData {
    if (m_ZipFile == nullptr || unzOpenCurrentFile(m_ZipFile) != UNZ_OK) {
        return nil;
    }
    NSMutableData *data = [NSMutableData dataWithCapacity:0];
    unsigned char aChunk[kReadChunkSize];
    int nRead = 0;
    do {
        nRead = unzReadCurrentFile(m_ZipFile, aChunk, kReadChunkSize);
        // Yes, the binary appends before testing the read: a final zero-length read appends
        // nothing, but a negative (error) read is sign-extended into the length.
        [data appendBytes:aChunk length:static_cast<NSUInteger>(nRead)];
    } while (nRead > 0);
    unzCloseCurrentFile(m_ZipFile);
    return data;
}

/** @ghidraAddress 0x14f24 */
- (NSData *)getData:(NSString *)entryName {
    if (m_ZipFile == nullptr || ![self setFirst]) {
        return nil;
    }
    do {
        NSString *name = [self getCurrentFileName];
        if ([name isEqualToString:entryName]) {
            return [self getCurrentData];
        }
    } while ([self setNext]);
    return nil;
}

@end
