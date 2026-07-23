/** @file
 * A downloader that fetches a store pack's detailed music info, and the delegate protocol it uses to
 * report completion. This is a minimal stub declaring only the surface
 * @c RBStorePageViewController relies on; the full class is reconstructed separately.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c StorePackInfoDownloader, image
 * base 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <Foundation/Foundation.h>

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
 * @brief Sent when a pack's detailed-info download failed.
 * @param downloader The reporting downloader.
 */
- (void)storePackInfoDownloaderError:(StorePackInfoDownloader *)downloader;

@end

/**
 * @brief Fetches a store pack's detailed music info.
 */
@interface StorePackInfoDownloader : NSObject

/**
 * @brief The delegate notified of completion.
 */
@property(nonatomic, weak, nullable) id<StorePackInfoDownloaderDelegate> delegate;

/**
 * @brief Create a downloader for the given pack.
 * @param info The pack whose detail to fetch.
 * @return The initialised downloader.
 */
- (instancetype)initWithStorePackInfo:(StorePackInfo *)info;

/**
 * @brief The pack whose detail was fetched, once finished.
 * @return The completed pack.
 */
- (nullable StorePackInfo *)getPackInfo;

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
