/**
 * @file
 * Runs a batch of @c StoreDownloadTask jobs sequentially, downloading each task's URL,
 * writing the
 * body to that task's file path, and reporting start, progress, completion, and failure to its
 * delegate.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c StoreDownloadManager, image
 * base 0x100000000). Ghidra addresses are offsets relative to the image base.
 */

#import <Foundation/Foundation.h>

@class Downloader;
@class StoreDownloadManager;
@class StoreDownloadTask;

NS_ASSUME_NONNULL_BEGIN

/**
 * Delegate notified of a @c StoreDownloadManager batch's lifecycle.
 */
@protocol StoreDownloadManagerDelegate <NSObject>

@optional
/**
 * A task in the batch has started.
 * @param manager The reporting manager.
 */
- (void)downloadManagerStartTask:(StoreDownloadManager *)manager;

/**
 * The batch has finished successfully.
 * @param manager The reporting manager.
 */
- (void)downloadManagerCompleted:(StoreDownloadManager *)manager;

/**
 * The batch has failed.
 * @param manager The reporting manager.
 */
- (void)downloadManagerFailed:(StoreDownloadManager *)manager;

/**
 * The batch made progress.
 * @param manager The reporting manager, whose @c overallProgress has advanced.
 */
- (void)downloadManagerProceed:(StoreDownloadManager *)manager;

@end

/**
 * A batch store-download runner.
 */
@interface StoreDownloadManager : NSObject

/**
 * The @c StoreDownloadTask jobs run by the batch.
 * @ghidraAddress 0xf377c (getter)
 * @ghidraAddress 0xf378c (setter)
 */
@property(nonatomic, strong, nullable) NSArray<StoreDownloadTask *> *tasks;
/**
 * The delegate notified of the batch's lifecycle.
 * @ghidraAddress 0xf37c4 (getter)
 * @ghidraAddress 0xf37e4 (setter)
 */
@property(nonatomic, weak, nullable) id<StoreDownloadManagerDelegate> delegate;
/**
 * The downloader driving the current task, or @c nil while idle.
 * @ghidraAddress 0xf37f8 (getter)
 * @ghidraAddress 0xf3808 (setter)
 */
@property(nonatomic, strong, nullable) Downloader *fileDownloader;
/**
 * The index of the task currently being downloaded.
 * @ghidraAddress 0xf376c
 */
@property(nonatomic, assign, readonly) unsigned int currentIndex;
/**
 * The number of tasks in the batch.
 * @ghidraAddress 0xf268c
 */
@property(nonatomic, assign, readonly) unsigned long long numTasks;
/**
 * The current task's own download progress, from @c 0 to @c 1.
 * @ghidraAddress 0xf25c4
 */
@property(nonatomic, assign, readonly) float currentProgress;
/**
 * The fraction of the batch completed so far, from @c 0 to @c 1.
 * @ghidraAddress 0xf262c
 */
@property(nonatomic, assign, readonly) float overallProgress;

/**
 * Create a batch runner over the given tasks.
 * @param tasks The @c StoreDownloadTask jobs to run; copied into a new array.
 * @param delegate The delegate notified of the batch's lifecycle.
 * @return The initialised manager, or @c nil when @p tasks is @c nil.
 * @ghidraAddress 0xf2468
 */
- (nullable instancetype)initWithTasks:(nullable NSArray<StoreDownloadTask *> *)tasks
                              delegate:(nullable id<StoreDownloadManagerDelegate>)delegate;

/**
 * Start running the batch from the first task.
 * @ghidraAddress 0xf26ec
 */
- (void)start;
/**
 * Cancel the in-flight download, if any, and re-enable the idle timer.
 * @ghidraAddress 0xf299c
 */
- (void)cancel;
/**
 * Resume the batch: start it if it has not begun, otherwise re-download the current task.
 * @ghidraAddress 0xf2a88
 */
- (void)restart;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
