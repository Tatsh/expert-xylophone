/** @file
 * A downloader that fetches a single store pack's detailed music info. It wraps a @c Downloader
 * (itself a façade over @c RBHttpUtil) to GET the pack-detail JSON from the @c v3/packinfo/
 * endpoint, hands the parsed dictionary to its @c StorePackInfo to populate the contained-tune
 * metadata, and reports completion, progress, or failure to its delegate. It is created and driven
 * by @c RBStorePageViewController.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c StorePackInfoDownloader, image
 * base 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <Foundation/Foundation.h>

#import "Downloader.h"

@class StorePackInfo;
@class StorePackInfoDownloader;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Completion callbacks a @c StorePackInfoDownloader sends to its delegate.
 */
@protocol StorePackInfoDownloaderDelegate <NSObject>

@optional

/**
 * @brief Sent when a pack's detailed info finished downloading.
 * @param downloader The reporting downloader.
 */
- (void)storePackInfoDownloaderFinished:(StorePackInfoDownloader *)downloader;

/**
 * @brief Sent as the pack's detailed-info download makes incremental progress.
 * @param downloader The reporting downloader.
 */
- (void)storePackInfoDownloaderProceed:(StorePackInfoDownloader *)downloader;

/**
 * @brief Sent when a pack's detailed-info download failed.
 * @param downloader The reporting downloader.
 */
- (void)storePackInfoDownloaderError:(StorePackInfoDownloader *)downloader;

@end

/**
 * @brief Fetches a store pack's detailed music info.
 */
@interface StorePackInfoDownloader : NSObject <DownloaderDelegate>

/**
 * @brief The pack whose detail is fetched and populated.
 * @ghidraAddress 0x69d14 (getter)
 * @ghidraAddress 0x69d24 (setter)
 */
@property(nonatomic, strong, nullable) StorePackInfo *packInfo;
/**
 * @brief The underlying HTTP download façade driving the in-flight request.
 * @ghidraAddress 0x69d5c (getter)
 * @ghidraAddress 0x69d6c (setter)
 */
@property(nonatomic, strong, nullable) Downloader *downloader;
/**
 * @brief The error message from the most recent failed detail download, if any.
 * @ghidraAddress 0x69da4 (getter)
 * @ghidraAddress 0x69db4 (setter)
 */
@property(nonatomic, strong, nullable) NSString *errorMessage;
/**
 * @brief The delegate notified of completion, progress, and failure.
 * @ghidraAddress 0x69ce0 (getter)
 * @ghidraAddress 0x69d00 (setter)
 */
@property(nonatomic, weak, nullable) id<StorePackInfoDownloaderDelegate> delegate;

/**
 * @brief Create a downloader for the given pack.
 * @param info The pack whose detail to fetch.
 * @return The initialised downloader.
 * @ghidraAddress 0x69688
 */
- (instancetype)initWithStorePackInfo:(StorePackInfo *)info;

/**
 * @brief The pack whose detail was fetched, once finished.
 * @return The completed pack.
 * @ghidraAddress 0x69cc8
 */
- (nullable StorePackInfo *)getPackInfo;

/**
 * @brief The error message from the most recent failed detail download, if any.
 * @return The error message, or @c nil when the last download succeeded.
 * @ghidraAddress 0x69cd4
 */
- (nullable NSString *)getErrorMessage;

/**
 * @brief Begin the detail download.
 * @param userOpen Whether the request is on behalf of a user-initiated open, threaded through to
 * the @c v3/packinfo/ URL builder.
 * @ghidraAddress 0x6977c
 */
- (void)downloadDetail:(BOOL)userOpen;

/**
 * @brief Cancel the in-flight download.
 * @ghidraAddress 0x69880
 */
- (void)cancel;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
