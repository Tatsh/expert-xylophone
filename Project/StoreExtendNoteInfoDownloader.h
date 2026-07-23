/** @file
 * A downloader that fetches a store extend note's detailed info. It wraps a @c Downloader (itself a
 * façade over @c RBHttpUtil) to GET the extend-note-detail JSON from the extend-note-info endpoint,
 * hands the parsed dictionary to its @c StoreExtendNoteInfo to populate the tune metadata, and
 * reports completion, progress, or failure to its delegate. It is created and driven by
 * @c RBStorePageViewController and @c RBStoreExtendPageViewController.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c StoreExtendNoteInfoDownloader,
 * image base 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <Foundation/Foundation.h>

#import "Downloader.h"

@class StoreExtendNoteInfo;
@class StoreExtendNoteInfoDownloader;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Completion callbacks a @c StoreExtendNoteInfoDownloader sends to its delegate.
 */
@protocol StoreExtendNoteInfoDownloaderDelegate <NSObject>

@optional

/**
 * @brief Sent when an extend note's detailed info finished downloading.
 * @param downloader The reporting downloader.
 */
- (void)storeExtendNoteInfoDownloaderFinished:(StoreExtendNoteInfoDownloader *)downloader;

/**
 * @brief Sent as the extend note's detailed-info download makes incremental progress.
 * @param downloader The reporting downloader.
 */
- (void)storeExtendNoteInfoDownloaderProceed:(StoreExtendNoteInfoDownloader *)downloader;

/**
 * @brief Sent when an extend note's detailed-info download failed.
 * @param downloader The reporting downloader.
 */
- (void)storeExtendNoteInfoDownloaderError:(StoreExtendNoteInfoDownloader *)downloader;

@end

/**
 * @brief Fetches a store extend note's detailed info.
 */
@interface StoreExtendNoteInfoDownloader : NSObject <DownloaderDelegate>

/**
 * @brief The extend note whose detail is fetched and populated.
 * @ghidraAddress 0x17a368 (getter)
 * @ghidraAddress 0x17a378 (setter)
 */
@property(nonatomic, strong, nullable) StoreExtendNoteInfo *extendNoteInfo;
/**
 * @brief The underlying HTTP download façade driving the in-flight request.
 * @ghidraAddress 0x17a3b0 (getter)
 * @ghidraAddress 0x17a3c0 (setter)
 */
@property(nonatomic, strong, nullable) Downloader *downloader;
/**
 * @brief The error message from the most recent failed detail download, if any.
 * @ghidraAddress 0x17a3f8 (getter)
 * @ghidraAddress 0x17a408 (setter)
 */
@property(nonatomic, strong, nullable) NSString *errorMessage;
/**
 * @brief The delegate notified of completion, progress, and failure.
 * @ghidraAddress 0x17a334 (getter)
 * @ghidraAddress 0x17a354 (setter)
 */
@property(nonatomic, weak, nullable) id<StoreExtendNoteInfoDownloaderDelegate> delegate;

/**
 * @brief Create a downloader for the given extend note.
 * @param info The extend note whose detail to fetch.
 * @return The initialised downloader.
 * @ghidraAddress 0x179bc0
 */
- (instancetype)initWithStoreExtendNoteInfo:(StoreExtendNoteInfo *)info;

/**
 * @brief The extend note whose detail was fetched, once finished.
 * @return The completed extend note.
 * @ghidraAddress 0x17a31c
 */
- (nullable StoreExtendNoteInfo *)getExtendNoteInfo;

/**
 * @brief The error message from the most recent failed detail download, if any.
 * @return The error message, or @c nil when the last download succeeded.
 * @ghidraAddress 0x17a328
 */
- (nullable NSString *)getErrorMessage;

/**
 * @brief Begin the detail download.
 * @param userOpen Whether the request is on behalf of a user-initiated open, threaded through to the
 * extend-note-info URL builder.
 * @ghidraAddress 0x179d10
 */
- (void)downloadDetail:(BOOL)userOpen;

/**
 * @brief Cancel the in-flight download.
 * @ghidraAddress 0x179e44
 */
- (void)cancel;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
