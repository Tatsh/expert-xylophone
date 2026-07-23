/** @file
 * A single music-file download job: the source URL, the destination path, and the display name
 * added to the purchased-music list on completion.
 *
 * Speculative interface: only the members @c RBUnlockView uses are declared here. Reconstructed from
 * Ghidra project rb458, program rb458 (class @c StoreDownloadTask, image base 0x100000000).
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A queued store download job.
 */
@interface StoreDownloadTask : NSObject

/**
 * @brief Create a download job.
 * @param url The source URL string.
 * @param path The destination file path.
 * @param addObject The display name recorded when the download completes.
 * @return The initialised task, or @c nil.
 */
- (nullable instancetype)initWithURL:(nullable NSString *)url
                                path:(nullable NSString *)path
                           AddObject:(nullable NSString *)addObject;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
