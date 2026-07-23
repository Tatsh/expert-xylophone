/** @file
 * A downloader that fetches a store extend note's detailed info, and the delegate protocol it uses
 * to report completion. This is a minimal stub declaring only the surface
 * @c RBStorePageViewController relies on; the full class is reconstructed separately.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c StoreExtendNoteInfoDownloader,
 * image base 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <Foundation/Foundation.h>

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
 * @brief Sent when an extend note's detailed-info download failed.
 * @param downloader The reporting downloader.
 */
- (void)storeExtendNoteInfoDownloaderError:(StoreExtendNoteInfoDownloader *)downloader;

@end

/**
 * @brief Fetches a store extend note's detailed info.
 */
@interface StoreExtendNoteInfoDownloader : NSObject

/**
 * @brief The delegate notified of completion.
 */
@property(nonatomic, weak, nullable) id<StoreExtendNoteInfoDownloaderDelegate> delegate;

/**
 * @brief Create a downloader for the given extend note.
 * @param info The extend note whose detail to fetch.
 * @return The initialised downloader.
 */
- (instancetype)initWithStoreExtendNoteInfo:(StoreExtendNoteInfo *)info;

/**
 * @brief The extend note whose detail was fetched, once finished.
 * @return The completed extend note.
 */
- (nullable StoreExtendNoteInfo *)getExtendNoteInfo;

/**
 * @brief Begin the detail download.
 * @param flag Whether to fetch the full detail set.
 */
- (void)downloadDetail:(BOOL)flag;

/**
 * @brief Cancel the in-flight download.
 */
- (void)cancel;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
