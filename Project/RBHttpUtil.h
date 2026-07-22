/** @file
 * The foundational HTTP request wrapper the @c Downloader façade drives. It builds a mutable
 * @c NSURLRequest (GET, POST, or a download-to-file GET), stamps the common @c User-Agent,
 * @c Accept-Language, and optional @c Content-Type headers on it, and runs it through an
 * @c NSURLSession. As the session delegate it accumulates the response body, tracks progress,
 * verifies an optional body hash against the response's @c code header, and reports proceed,
 * finished, and error events to its delegate (or the caller's completion blocks).
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class RBHttpUtil, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <Foundation/Foundation.h>

@class RBHttpUtil;

/**
 * @brief A lifecycle callback block, passed the connection that fired it.
 */
typedef void (^RBHttpUtilBlock)(RBHttpUtil *connection);

/**
 * @brief Delegate callbacks delivered when the matching completion block is unset.
 *
 * The data-task path dispatches @c downloaderProceed:, @c downloaderFinished:, and
 * @c downloaderError: through @c performSelector:withObject: on the session's delegate queue;
 * the file-download path dispatches them (and @c downloadProceed:) on the main thread.
 */
@protocol RBHttpUtilDelegate <NSObject>
@optional
- (void)downloaderProceed:(RBHttpUtil *)connection;
- (void)downloaderFinished:(RBHttpUtil *)connection;
- (void)downloaderError:(RBHttpUtil *)connection;
@end

/**
 * @brief An asynchronous HTTP request wrapper built on @c NSURLSession.
 */
@interface RBHttpUtil : NSObject <NSURLSessionDataDelegate, NSURLSessionDownloadDelegate>

/**
 * @brief The mutable request this connection sends.
 * @ghidraAddress 0x398a8 (getter)
 * @ghidraAddress 0x398b8 (setter)
 */
@property(nonatomic, strong) NSMutableURLRequest *request;
/**
 * @brief The in-flight data task, or nil once cancelled or reset.
 * @ghidraAddress 0x398f0 (getter)
 * @ghidraAddress 0x39900 (setter)
 */
@property(nonatomic, strong) NSURLSessionDataTask *dataTask;
/**
 * @brief The in-flight download task, or nil once cancelled or reset.
 * @ghidraAddress 0x39938 (getter)
 * @ghidraAddress 0x39948 (setter)
 */
@property(nonatomic, strong) NSURLSessionDownloadTask *downloadTask;
/**
 * @brief The expected body length reported by the response, or a non-positive value if unknown.
 * @ghidraAddress 0x39980 (getter)
 * @ghidraAddress 0x39990 (setter)
 */
@property(nonatomic, assign) long long downloadSize;
/**
 * @brief The accumulated response body.
 * @ghidraAddress 0x399a0 (getter)
 * @ghidraAddress 0x399b0 (setter)
 */
@property(nonatomic, strong) NSMutableData *downloadedData;
/**
 * @brief The response's header fields.
 * @ghidraAddress 0x399e8 (getter)
 * @ghidraAddress 0x399f8 (setter)
 */
@property(nonatomic, strong) NSDictionary *downloadedHeader;
/**
 * @brief The delegate that receives lifecycle callbacks when no block is set.
 * @ghidraAddress 0x39a30 (getter)
 * @ghidraAddress 0x39a50 (setter)
 */
@property(nonatomic, weak) id<RBHttpUtilDelegate> delegate;
/**
 * @brief The destination path for a download-to-file request, or nil for an in-memory request.
 * @ghidraAddress 0x39a64 (getter)
 * @ghidraAddress 0x39a74 (setter)
 */
@property(nonatomic, strong) NSString *filePath;
/**
 * @brief Whether the received body passed its optional integrity hash check.
 * @ghidraAddress 0x39aac (getter)
 * @ghidraAddress 0x39abc (setter)
 */
@property(nonatomic, assign) BOOL hashCheck;
/**
 * @brief Invoked on successful completion; takes precedence over the delegate's finished callback.
 * @ghidraAddress 0x39acc (getter)
 * @ghidraAddress 0x39adc (setter)
 */
@property(nonatomic, copy) RBHttpUtilBlock successBlock;
/**
 * @brief Invoked on incremental progress; takes precedence over the delegate's proceed callback.
 * @ghidraAddress 0x39ae8 (getter)
 * @ghidraAddress 0x39af8 (setter)
 */
@property(nonatomic, copy) RBHttpUtilBlock proceedBlock;
/**
 * @brief Invoked on failure; takes precedence over the delegate's error callback.
 * @ghidraAddress 0x39b04 (getter)
 * @ghidraAddress 0x39b14 (setter)
 */
@property(nonatomic, copy) RBHttpUtilBlock failureBlock;
/**
 * @brief Extra object carried alongside the request (caller-defined context).
 * @ghidraAddress 0x397d0 (getter)
 * @ghidraAddress 0x397e0 (setter)
 */
@property(nonatomic, strong) id addData;
/**
 * @brief The underlying system error message, if any.
 * @ghidraAddress 0x39818 (getter)
 * @ghidraAddress 0x39828 (setter)
 */
@property(nonatomic, strong) NSString *systemErrorMessage;
/**
 * @brief A user-facing error message, if any.
 * @ghidraAddress 0x39860 (getter)
 * @ghidraAddress 0x39870 (setter)
 */
@property(nonatomic, strong) NSString *showErrorMessage;
/**
 * @brief The request timeout interval, or -1 when unset. Retained for parity; not applied here.
 * @ghidraAddress 0x39790 (getter)
 * @ghidraAddress 0x397a0 (setter)
 */
@property(nonatomic, assign) long long requestTimeoutInterval;
/**
 * @brief The resource timeout interval, or -1 when unset. Retained for parity; not applied here.
 * @ghidraAddress 0x397b0 (getter)
 * @ghidraAddress 0x397c0 (setter)
 */
@property(nonatomic, assign) long long resourceTimeoutInterval;

/**
 * @brief Serialise a dictionary to JSON @c NSData for a request body.
 * @ghidraAddress 0x36aa8
 */
+ (NSData *)dictionaryToJsonData:(NSDictionary *)dictionary;
/**
 * @brief Serialise a dictionary to @c application/x-www-form-urlencoded query @c NSData.
 * @ghidraAddress 0x36754
 */
+ (NSData *)dictionaryToQueryData:(NSDictionary *)dictionary;

/**
 * @brief Initialise a GET request for @p url with the common headers.
 * @ghidraAddress 0x36bd0
 */
- (instancetype)initWithGetURL:(NSURL *)url;
/**
 * @brief Initialise a POST request with a body and content type (15 second timeout).
 * @ghidraAddress 0x36e0c
 */
- (instancetype)initWithPostURL:(NSURL *)url
                           post:(NSData *)post
                    contentType:(NSString *)contentType;
/**
 * @brief Initialise a POST request with a body, content type, and timeout (seconds).
 * @ghidraAddress 0x36ea4
 */
- (instancetype)initWithPostURL:(NSURL *)url
                           post:(NSData *)post
                    contentType:(NSString *)contentType
                timeoutInterval:(float)timeoutInterval;
/**
 * @brief Initialise a GET request that saves the response body to @p filePath.
 * @ghidraAddress 0x371b0
 */
- (instancetype)initWithDownloadURL:(NSURL *)url filePath:(NSString *)filePath;

/**
 * @brief Rebuild the request for @p url with the given method, content type, body, and save path.
 * @ghidraAddress 0x3741c
 */
- (void)updateRequest:(NSURL *)url
           HTTPMethod:(NSString *)HTTPMethod
          contentType:(NSString *)contentType
             sendData:(NSData *)sendData
             filePath:(NSString *)filePath;

/**
 * @brief Start the request, delivering callbacks to @p delegate.
 * @ghidraAddress 0x376ec
 */
- (NSURLSessionTask *)startDownloading:(id<RBHttpUtilDelegate>)delegate;
/**
 * @brief Set the completion blocks and start the request.
 * @ghidraAddress 0x377a8
 */
- (NSURLSessionTask *)startDownloadingWithProceed:(RBHttpUtilBlock)proceed
                                          success:(RBHttpUtilBlock)success
                                          failure:(RBHttpUtilBlock)failure;
/**
 * @brief Detach the delegate, cancel any in-flight task, and clear the completion blocks.
 * @ghidraAddress 0x37894
 */
- (void)cancel;

/**
 * @brief Bytes received so far.
 * @ghidraAddress 0x3930c
 */
- (unsigned long long)currentSize;
/**
 * @brief Fractional download progress in the range 0..1.
 * @ghidraAddress 0x3936c
 */
- (float)currentProgress;
/**
 * @brief The received response body.
 * @ghidraAddress 0x39430
 */
- (NSData *)getData;
/**
 * @brief The received response body parsed as JSON (allowing fragments).
 * @ghidraAddress 0x3943c
 */
- (id)getDataInJSON;
/**
 * @brief The response headers.
 * @ghidraAddress 0x39520
 */
- (NSDictionary *)getHeader;
/**
 * @brief Whether the response passed its integrity hash check.
 * @ghidraAddress 0x3952c
 */
- (BOOL)hashChecked;

@end

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
