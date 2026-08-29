/**
 * @file
 * @brief A thin block-and-delegate façade over @c RBHttpUtil.
 *
 * It builds a GET, POST, or file-download
 * request, starts it, and dispatches the proceed/success/failure events either to caller-supplied
 * blocks or, when no block is set, to a delegate on the main thread. It also re-exposes the
 * underlying connection's response accessors (data, header, progress, and error messages).
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class Downloader, image base
 * 0x100000000). Ghidra addresses are offsets relative to the image base.
 */

#import <Foundation/Foundation.h>

@class Downloader, RBHttpUtil;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A lifecycle callback block, passed the downloader that fired it.
 */
typedef void (^DownloaderBlock)(Downloader *downloader);

/**
 * @brief Delegate callbacks delivered on the main thread when the matching block is unset.
 */
@protocol DownloaderDelegate <NSObject>
@optional
/**
 * @brief Sent as the transfer makes incremental progress, when @c proceedBlock is unset.
 * @param downloader The downloader reporting the progress.
 */
- (void)downloaderProceed:(Downloader *)downloader;
/**
 * @brief Sent once the request completes successfully, when @c successBlock is unset.
 * @param downloader The finished downloader, whose response accessors are now populated.
 */
- (void)downloaderFinished:(Downloader *)downloader;
/**
 * @brief Sent when the request fails, when @c failureBlock is unset.
 * @param downloader The failed downloader, whose error-message accessors describe the failure.
 */
- (void)downloaderError:(Downloader *)downloader;
@end

/**
 * @brief An asynchronous HTTP request wrapper with block or delegate completion.
 */
@interface Downloader : NSObject

/**
 * @brief The underlying HTTP connection this façade drives and forwards to.
 * @ghidraAddress 0x738e8 (getter)
 * @ghidraAddress 0x738f8 (setter)
 */
@property(nonatomic, strong, nullable) RBHttpUtil *conn;
/**
 * @brief The delegate that receives lifecycle callbacks when no block is set.
 * @ghidraAddress 0x73930 (getter)
 * @ghidraAddress 0x73950 (setter)
 */
@property(nonatomic, weak, nullable) id<DownloaderDelegate> delegate;
/**
 * @brief Extra object carried alongside the request (caller-defined context).
 * @ghidraAddress 0x738a0 (getter)
 * @ghidraAddress 0x738b0 (setter)
 */
@property(nonatomic, strong, nullable) id addData;
/**
 * @brief Invoked on incremental progress; takes precedence over the delegate's proceed callback.
 * @ghidraAddress 0x73980 (getter)
 * @ghidraAddress 0x73990 (setter)
 */
@property(nonatomic, copy, nullable) DownloaderBlock proceedBlock;
/**
 * @brief Invoked on successful completion; takes precedence over the delegate's finished callback.
 * @ghidraAddress 0x73964 (getter)
 * @ghidraAddress 0x73974 (setter)
 */
@property(nonatomic, copy, nullable) DownloaderBlock successBlock;
/**
 * @brief Invoked on failure; takes precedence over the delegate's error callback.
 * @ghidraAddress 0x7399c (getter)
 * @ghidraAddress 0x739ac (setter)
 */
@property(nonatomic, copy, nullable) DownloaderBlock failureBlock;

/**
 * @brief Serialise a dictionary to JSON @c NSData for a request body.
 * @param dictionary The dictionary to serialise.
 * @return The JSON-encoded body.
 * @ghidraAddress 0x72a0c
 */
+ (NSData *)dictionaryToJsonData:(NSDictionary *)dictionary;
/**
 * @brief Serialise a dictionary to @c application/x-www-form-urlencoded query @c NSData.
 * @param dictionary The dictionary to serialise.
 * @return The form-encoded body.
 * @ghidraAddress 0x729e0
 */
+ (NSData *)dictionaryToQueryData:(NSDictionary *)dictionary;

/**
 * @brief Initialise a GET request, or a download-to-file request when @p filePath is non-nil.
 * @param url The URL to request.
 * @param filePath The destination path the response body is saved to, or @c nil to keep the body
 *        in memory.
 * @return The initialised downloader.
 * @ghidraAddress 0x72a38
 */
- (instancetype)initWithURL:(NSURL *)url save:(nullable NSString *)filePath;
/**
 * @brief Initialise a POST request with a body and content type.
 * @param url The URL to request.
 * @param post The request body, or @c nil for an empty body.
 * @param contentType The @c Content-Type header value, or @c nil to omit the header.
 * @return The initialised downloader.
 * @ghidraAddress 0x72b94
 */
- (instancetype)initWithURL:(NSURL *)url
                       post:(nullable NSData *)post
                contentType:(nullable NSString *)contentType;
/**
 * @brief Initialise a POST request with a body, content type, and timeout (seconds).
 * @param url The URL to request.
 * @param post The request body, or @c nil for an empty body.
 * @param contentType The @c Content-Type header value, or @c nil to omit the header.
 * @param timeout The request timeout, in seconds.
 * @return The initialised downloader.
 * @ghidraAddress 0x72cd4
 */
- (instancetype)initWithURL:(NSURL *)url
                       post:(nullable NSData *)post
                contentType:(nullable NSString *)contentType
                    timeout:(float)timeout;

/**
 * @brief Start the request, delivering callbacks to @p delegate.
 * @param delegate The delegate to receive lifecycle callbacks, or @c nil for none.
 * @ghidraAddress 0x72e24
 */
- (void)startDownloadingWithDelegate:(nullable id<DownloaderDelegate>)delegate;
/**
 * @brief Start the request, delivering callbacks to the given blocks.
 * @param proceed The progress block, or @c nil to fall back to the delegate.
 * @param success The completion block, or @c nil to fall back to the delegate.
 * @param failure The failure block, or @c nil to fall back to the delegate.
 * @ghidraAddress 0x72ed0
 */
- (void)startDownloadingWithProceed:(nullable DownloaderBlock)proceed
                            success:(nullable DownloaderBlock)success
                            failure:(nullable DownloaderBlock)failure;
/**
 * @brief Detach the delegate and cancel the underlying connection.
 * @ghidraAddress 0x72fa8
 */
- (void)cancel;

/**
 * @brief Bytes received so far.
 * @return The number of body bytes received so far.
 * @ghidraAddress 0x73458
 */
- (unsigned long long)currentSize;
/**
 * @brief Fractional download progress in the range 0..1.
 * @return The fractional progress, or zero when the expected length is unknown.
 * @ghidraAddress 0x734b8
 */
- (float)currentProgress;
/**
 * @brief The received response body.
 * @return The accumulated response body, or @c nil when nothing was received.
 * @ghidraAddress 0x73520
 */
- (nullable NSData *)getData;
/**
 * @brief The received response body parsed as JSON.
 * @return The parsed JSON value, or @c nil when the body is absent or malformed.
 * @ghidraAddress 0x73588
 */
- (nullable id)getDataInJSON;
/**
 * @brief The response headers.
 * @return The response header fields, or @c nil when no response was received.
 * @ghidraAddress 0x735f0
 */
- (nullable NSDictionary *)getHeader;
/**
 * @brief The underlying system error message, if any.
 * @return The system error message, or @c nil when the request did not fail.
 * @ghidraAddress 0x73658
 */
- (nullable NSString *)systemErrorMessage;
/**
 * @brief A user-facing error message, if any.
 * @return The user-facing error message, or @c nil when the request did not fail.
 * @ghidraAddress 0x736c0
 */
- (nullable NSString *)showErrorMessage;
/**
 * @brief Whether the response passed its integrity hash check.
 * @return @c YES when the body matched the response's @c code header.
 * @ghidraAddress 0x73728
 */
- (BOOL)hashChecked;

/**
 * @brief @c RBHttpUtil progress callback: fires @c proceedBlock, else forwards to the delegate.
 * @param downloader The downloader reporting the progress.
 * @ghidraAddress 0x73050
 */
- (void)downloaderProceed:(Downloader *)downloader;
/**
 * @brief @c RBHttpUtil completion callback: fires @c successBlock, else forwards to the delegate.
 * @param downloader The finished downloader.
 * @ghidraAddress 0x731a8
 */
- (void)downloaderFinished:(Downloader *)downloader;
/**
 * @brief @c RBHttpUtil failure callback: fires @c failureBlock, else forwards to the delegate.
 * @param downloader The failed downloader.
 * @ghidraAddress 0x73300
 */
- (void)downloaderError:(Downloader *)downloader;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
