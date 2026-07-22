/** @file
 * An asynchronous image-fetch wrapper built on @c RBHttpUtil. Given an image URL it downloads the
 * bytes, decodes them into a @c UIImage (optionally choosing an @2x Retina variant), and reports
 * completion either through caller-supplied blocks or, when no block is set, to a delegate via
 * @c performSelector:withObject:withObject: dispatched on the main queue. It also carries an
 * optional table-view index path so a delegate can route the finished image back to a cell.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class ImageDownloader, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

@class ImageDownloader, RBHttpUtil;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A lifecycle callback block, passed the downloader that fired it.
 */
typedef void (^ImageDownloaderBlock)(ImageDownloader *downloader);

/**
 * @brief Delegate callbacks delivered on the main queue when the matching completion block is unset.
 *
 * Both callbacks are sent with the downloader and its @c indexPathInTableView.
 */
@protocol ImageDownloaderDelegate <NSObject>
@optional
- (void)imageDownloader:(ImageDownloader *)downloader didLoad:(nullable NSIndexPath *)indexPath;
- (void)imageDownloaderDidFail:(ImageDownloader *)downloader
                       didLoad:(nullable NSIndexPath *)indexPath;
@end

/**
 * @brief An asynchronous image downloader with block or delegate completion.
 */
@interface ImageDownloader : NSObject

/**
 * @brief Whether to skip the @2x Retina variant and always fetch the plain image.
 * @ghidraAddress 0x854f0 (getter)
 * @ghidraAddress 0x85500 (setter)
 */
@property(nonatomic, assign) BOOL unUseRetina;
/**
 * @brief The image URL to download, as a string.
 * @ghidraAddress 0x85510 (getter)
 * @ghidraAddress 0x85520 (setter)
 */
@property(nonatomic, strong, nullable) NSString *imageURL;
/**
 * @brief The table-view index path passed back to the delegate with the finished image.
 * @ghidraAddress 0x85558 (getter)
 * @ghidraAddress 0x85568 (setter)
 */
@property(nonatomic, strong, nullable) NSIndexPath *indexPathInTableView;
/**
 * @brief The underlying HTTP connection this downloader drives.
 * @ghidraAddress 0x855a0 (getter)
 * @ghidraAddress 0x855b0 (setter)
 */
@property(nonatomic, strong, nullable) RBHttpUtil *conn;
/**
 * @brief The delegate that receives lifecycle callbacks when no block is set.
 * @ghidraAddress 0x855e8 (getter)
 * @ghidraAddress 0x85608 (setter)
 */
@property(nonatomic, weak, nullable) id<ImageDownloaderDelegate> delegate;
/**
 * @brief A cancellable download handle for the plain-resolution request.
 * @ghidraAddress 0x8561c (getter)
 * @ghidraAddress 0x8562c (setter)
 */
@property(nonatomic, strong, nullable) RBHttpUtil *imageTask;
/**
 * @brief A cancellable download handle for the Retina request.
 * @ghidraAddress 0x85664 (getter)
 * @ghidraAddress 0x85674 (setter)
 */
@property(nonatomic, strong, nullable) RBHttpUtil *imageTaskRetina;
/**
 * @brief The decoded image once the download finishes, or @c nil while pending.
 * @ghidraAddress 0x856ac (getter)
 * @ghidraAddress 0x856bc (setter)
 */
@property(nonatomic, strong, nullable) UIImage *downloadedImage;
/**
 * @brief Invoked on incremental progress; takes precedence over the delegate.
 * @ghidraAddress 0x85710 (getter)
 * @ghidraAddress 0x85720 (setter)
 */
@property(nonatomic, copy, nullable) ImageDownloaderBlock proceedBlock;
/**
 * @brief Invoked on successful completion; takes precedence over the delegate.
 * @ghidraAddress 0x856f4 (getter)
 * @ghidraAddress 0x85704 (setter)
 */
@property(nonatomic, copy, nullable) ImageDownloaderBlock successBlock;
/**
 * @brief Invoked on failure; takes precedence over the delegate.
 * @ghidraAddress 0x8572c (getter)
 * @ghidraAddress 0x8573c (setter)
 */
@property(nonatomic, copy, nullable) ImageDownloaderBlock failureBlock;

/**
 * @brief Initialise a downloader for the given image URL string.
 * @param getURL The image URL, as a string.
 * @param unUseRetina Whether to skip the @2x Retina variant.
 * @ghidraAddress 0x83d30
 */
- (instancetype)initWithGetURL:(nullable NSString *)getURL unUseRetina:(BOOL)unUseRetina;

/**
 * @brief Start the download, delivering completion to the given blocks.
 * @ghidraAddress 0x83eb0
 */
- (void)startDownloadWithProceed:(nullable ImageDownloaderBlock)proceed
                         success:(nullable ImageDownloaderBlock)success
                         failure:(nullable ImageDownloaderBlock)failure;
/**
 * @brief Start the download, choosing the Retina or plain variant per @c unUseRetina and screen
 * scale.
 * @ghidraAddress 0x83dc8
 */
- (void)startDownload;

/**
 * @brief The decoded image, once the download has finished.
 * @ghidraAddress 0x84b3c
 */
- (nullable UIImage *)getImage;

/**
 * @brief Detach the delegate, drop the decoded image, and cancel any in-flight download.
 * @ghidraAddress 0x84900
 */
- (void)cancelDownload;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
