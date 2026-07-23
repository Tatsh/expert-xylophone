/** @file
 * The bundled SSZipArchive extraction helper and its progress delegate. Only the class method and
 * delegate callbacks the game calls are declared here.
 *
 * Speculative interface reconstructed from Ghidra project rb458, program rb458 (third-party class
 * @c SSZipArchive, image base 0x100000000). @ghidraAddress values are offsets relative to the image
 * base.
 */

#include <minizip/unzip.h>

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Progress callbacks delivered while an archive is being unzipped.
 */
@protocol SSZipArchiveDelegate <NSObject>
@optional
- (void)zipArchiveWillUnzipArchiveAtPath:(NSString *)path zipInfo:(unz_global_info)zipInfo;
- (void)zipArchiveDidUnzipArchiveAtPath:(NSString *)path
                                zipInfo:(unz_global_info)zipInfo
                           unzippedPath:(NSString *)unzippedPath;
- (void)zipArchiveWillUnzipFileAtIndex:(NSInteger)fileIndex
                            totalFiles:(NSInteger)totalFiles
                           archivePath:(NSString *)archivePath
                              fileInfo:(unz_file_info)fileInfo;
- (void)zipArchiveDidUnzipFileAtIndex:(NSInteger)fileIndex
                           totalFiles:(NSInteger)totalFiles
                          archivePath:(NSString *)archivePath
                             fileInfo:(unz_file_info)fileInfo;
@end

/**
 * @brief Zip archive extraction utility.
 */
@interface SSZipArchive : NSObject

/**
 * @brief Unzip @p path into @p destination, overwriting, using @p password, reporting to
 * @p delegate.
 * @return @c YES when extraction succeeds.
 * @ghidraAddress 0x1c2444
 */
+ (BOOL)unzipFileAtPath:(NSString *)path
          toDestination:(NSString *)destination
              overwrite:(BOOL)overwrite
               password:(nullable NSString *)password
                  error:(NSError *_Nullable *_Nullable)error
               delegate:(nullable id<SSZipArchiveDelegate>)delegate;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
