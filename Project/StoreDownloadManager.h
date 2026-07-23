/** @file
 * Runs a batch of @c StoreDownloadTask jobs, reporting start, progress, completion, and failure to
 * its delegate.
 *
 * Speculative interface: only the members @c RBUnlockView uses are declared here. Reconstructed from
 * Ghidra project rb458, program rb458 (class @c StoreDownloadManager, image base 0x100000000).
 */

#import <Foundation/Foundation.h>

@class StoreDownloadManager;
@class StoreDownloadTask;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Delegate notified of a @c StoreDownloadManager batch's lifecycle.
 */
@protocol StoreDownloadManagerDelegate <NSObject>

/**
 * @brief A task in the batch has started.
 * @param manager The reporting manager.
 */
- (void)downloadManagerStartTask:(StoreDownloadManager *)manager;

/**
 * @brief The batch has finished successfully.
 * @param manager The reporting manager.
 */
- (void)downloadManagerCompleted:(StoreDownloadManager *)manager;

/**
 * @brief The batch has failed.
 * @param manager The reporting manager.
 */
- (void)downloadManagerFailed:(StoreDownloadManager *)manager;

/**
 * @brief The batch made progress.
 * @param manager The reporting manager, whose @c overallProgress has advanced.
 */
- (void)downloadManagerProceed:(StoreDownloadManager *)manager;

@end

/**
 * @brief A batch store-download runner.
 */
@interface StoreDownloadManager : NSObject

/**
 * @brief Create a batch runner over the given tasks.
 * @param tasks The @c StoreDownloadTask jobs to run.
 * @param delegate The delegate notified of the batch's lifecycle.
 * @return The initialised manager, or @c nil.
 */
- (nullable instancetype)initWithTasks:(nullable NSArray<StoreDownloadTask *> *)tasks
                              delegate:(nullable id<StoreDownloadManagerDelegate>)delegate;

/**
 * @brief Start running the batch.
 */
- (void)start;

/**
 * @brief The fraction of the batch completed so far, from @c 0 to @c 1.
 */
@property(assign, nonatomic) float overallProgress;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
