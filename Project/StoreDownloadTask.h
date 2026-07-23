/** @file
 * A single music-file download job: the source URL, the destination file path, and the display
 * name recorded when the download completes.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c StoreDownloadTask, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A queued store download job.
 */
@interface StoreDownloadTask : NSObject

/**
 * @brief The source URL string the job downloads from.
 * @ghidraAddress 0xf2360 (getter)
 * @ghidraAddress 0xf2370 (setter)
 */
@property(nonatomic, strong, nullable) NSString *fileURL;
/**
 * @brief The destination path the downloaded body is written to.
 * @ghidraAddress 0xf23a8 (getter)
 * @ghidraAddress 0xf23b8 (setter)
 */
@property(nonatomic, strong, nullable) NSString *filePath;
/**
 * @brief The display name recorded when the download completes.
 * @ghidraAddress 0xf23f0 (getter)
 * @ghidraAddress 0xf2400 (setter)
 */
@property(nonatomic, strong, nullable) id addObject;

/**
 * @brief Create a download job.
 * @param url The source URL string; copied into @c fileURL.
 * @param path The destination file path; copied into @c filePath.
 * @param addObject The display name recorded when the download completes, or @c nil.
 * @return The initialised task, or @c nil.
 * @ghidraAddress 0xf2164
 */
- (nullable instancetype)initWithURL:(nullable NSString *)url
                                path:(nullable NSString *)path
                           AddObject:(nullable id)addObject;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
