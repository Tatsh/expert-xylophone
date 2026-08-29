#import "RBHttpUtil.h"

#import "deviceenvironment.h"
#import "enginecrypto.h"
#import "neDebugLog.h"

static NSString *const kUserAgentHeaderField = @"User-Agent";
static NSString *const kAcceptLanguageHeaderField = @"Accept-Language";
static NSString *const kContentTypeHeaderField = @"Content-Type";

static NSString *const kHTTPMethodGet = @"GET";
static NSString *const kHTTPMethodPost = @"POST";

static const NSTimeInterval kDefaultTimeoutInterval = 15.0;
// A float, not an NSTimeInterval: the initialiser it feeds encodes its timeout parameter as f.
static const float kDefaultPostTimeoutInterval = 15.0f;
static const long long kUnsetTimeoutInterval = -1;

static const NSURLRequestCachePolicy kRequestCachePolicy =
    NSURLRequestReloadIgnoringLocalAndRemoteCacheData;

static const NSInteger kHTTPStatusOK = 200;

static const NSUInteger kDefaultResponseCapacity = 65536;

// cspell:ignore Rhdvru Yvgs
static NSString *const kResponseCodeHeaderKey = @"code";
static NSString *const kHashCheckSalt = @"kdRhdvruVoJ1sUan4TJpsXYvgsSNG2yn";

static NSString *const kQueryPairFormat = @"%@=%@";
static NSString *const kQueryPairSeparator = @"&";
static NSString *const kQueryPercentEscapeCharacters = @"!*'();:@&=+$,/?%#[]";

static NSString *const kHashCheckErrorMessage = @"hash check error ...";

#if RBPDBG
// neDebugLog formats into a 512-byte buffer, so longer text is emitted in numbered pieces.
static const NSUInteger kLogChunkLength = 400;

static void RBLogLong(const char *label, NSString *text) {
    if (text.length <= kLogChunkLength) {
        neDebugLog("%s %s", label, text.UTF8String);
        return;
    }
    NSUInteger offset = 0;
    int part = 0;
    while (offset < text.length) {
        const NSUInteger length =
            (text.length - offset) < kLogChunkLength ? (text.length - offset) : kLogChunkLength;
        neDebugLog("%s[%d] %s",
                   label,
                   part,
                   [text substringWithRange:NSMakeRange(offset, length)].UTF8String);
        offset += length;
        ++part;
    }
}

static void RBLogRequest(NSURLRequest *request) {
    RBLogLong("request",
              [NSString stringWithFormat:@"%@ %@", request.HTTPMethod, request.URL.absoluteString]);
    for (NSString *field in request.allHTTPHeaderFields) {
        neDebugLog(
            "  header %s: %s", field.UTF8String, [request.allHTTPHeaderFields[field] UTF8String]);
    }
    NSData *body = request.HTTPBody;
    if (body.length == 0) {
        return;
    }
    NSString *text = [[NSString alloc] initWithData:body encoding:NSUTF8StringEncoding];
    if (text != nil) {
        RBLogLong("  body", text);
    } else {
        neDebugLog("  body %lu bytes, not UTF-8", (unsigned long)body.length);
    }
}
#endif

@implementation RBHttpUtil

#pragma mark - Body serialisation

+ (NSData *)dictionaryToJsonData:(NSDictionary *)dictionary {
    if (!dictionary) {
        return nil;
    }
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:dictionary options:0 error:&error];
    if (error) {
        return nil;
    }
    return data;
}

+ (NSData *)dictionaryToQueryData:(NSDictionary *)dictionary {
    if (!dictionary) {
        return nil;
    }
    NSMutableArray *pairs = [[NSMutableArray alloc] initWithCapacity:dictionary.count];
    for (id key in dictionary) {
        id value = dictionary[key];
        if (value) {
            CFStringRef escapeSet = (__bridge CFStringRef)kQueryPercentEscapeCharacters;
            NSString *escapedKey =
                (__bridge_transfer NSString *)CFURLCreateStringByAddingPercentEscapes(
                    kCFAllocatorDefault,
                    (__bridge CFStringRef)key,
                    NULL,
                    escapeSet,
                    kCFStringEncodingUTF8);
            id escapeValue = value;
#ifdef ENABLE_PATCHES
            // The binary escapes the raw value, but callers box NSNumbers into the dictionary, so
            // CFURLCreateStringByAddingPercentEscapes aborts on a modern CoreFoundation.
            // @ghidraAddress 0x17d52c
            // @ghidraAddress 0x17d554
            // @ghidraAddress 0x17d580
            if (![escapeValue isKindOfClass:NSString.class]) {
                escapeValue = [escapeValue description];
            }
#endif
            NSString *escapedValue =
                (__bridge_transfer NSString *)CFURLCreateStringByAddingPercentEscapes(
                    kCFAllocatorDefault,
                    (__bridge CFStringRef)escapeValue,
                    NULL,
                    escapeSet,
                    kCFStringEncodingUTF8);
            [pairs
                addObject:[NSString stringWithFormat:kQueryPairFormat, escapedKey, escapedValue]];
        }
    }
    NSString *query = [pairs componentsJoinedByString:kQueryPairSeparator];
    return [query dataUsingEncoding:NSUTF8StringEncoding];
}

#pragma mark - Initialisers

- (instancetype)init {
    self = [super init];
    if (self) {
        [self reset];
    }
    return self;
}

- (instancetype)initWithGetURL:(NSURL *)url {
    self = [super init];
    if (self) {
        [self reset];
        self.request = [[NSMutableURLRequest alloc] initWithURL:url
                                                    cachePolicy:kRequestCachePolicy
                                                timeoutInterval:kDefaultTimeoutInterval];
        [self.request setValue:GetDeviceDescriptionString()
            forHTTPHeaderField:kUserAgentHeaderField];
        [self.request setValue:GetRegionCode() forHTTPHeaderField:kAcceptLanguageHeaderField];
        [self.request setHTTPMethod:kHTTPMethodGet];
    }
    return self;
}

- (instancetype)initWithPostURL:(NSURL *)url
                           post:(NSData *)post
                    contentType:(NSString *)contentType {
    return [self initWithPostURL:url
                            post:post
                     contentType:contentType
                 timeoutInterval:kDefaultPostTimeoutInterval];
}

- (instancetype)initWithPostURL:(NSURL *)url
                           post:(NSData *)post
                    contentType:(NSString *)contentType
                timeoutInterval:(float)timeoutInterval {
    self = [super init];
    if (self) {
        [self reset];
        self.request = [[NSMutableURLRequest alloc] initWithURL:url
                                                    cachePolicy:kRequestCachePolicy
                                                timeoutInterval:timeoutInterval];
        [self.request setValue:GetDeviceDescriptionString()
            forHTTPHeaderField:kUserAgentHeaderField];
        [self.request setValue:GetRegionCode() forHTTPHeaderField:kAcceptLanguageHeaderField];
        [self.request setHTTPMethod:kHTTPMethodPost];
        if (contentType) {
            [self.request setValue:contentType forHTTPHeaderField:kContentTypeHeaderField];
        }
        if (post) {
            [self.request setHTTPBody:post];
        }
    }
    return self;
}

- (instancetype)initWithDownloadURL:(NSURL *)url filePath:(NSString *)filePath {
    self = [super init];
    if (self) {
        [self reset];
        self.request = [[NSMutableURLRequest alloc] initWithURL:url
                                                    cachePolicy:kRequestCachePolicy
                                                timeoutInterval:kDefaultTimeoutInterval];
        [self.request setValue:GetDeviceDescriptionString()
            forHTTPHeaderField:kUserAgentHeaderField];
        [self.request setValue:GetRegionCode() forHTTPHeaderField:kAcceptLanguageHeaderField];
        [self.request setHTTPMethod:kHTTPMethodGet];
        self.filePath = filePath;
    }
    return self;
}

- (void)updateRequest:(NSURL *)url
           HTTPMethod:(NSString *)HTTPMethod
          contentType:(NSString *)contentType
             sendData:(NSData *)sendData
             filePath:(NSString *)filePath {
    self.request = [[NSMutableURLRequest alloc] initWithURL:url
                                                cachePolicy:kRequestCachePolicy
                                            timeoutInterval:kDefaultTimeoutInterval];
    [self.request setValue:GetDeviceDescriptionString() forHTTPHeaderField:kUserAgentHeaderField];
    [self.request setValue:GetRegionCode() forHTTPHeaderField:kAcceptLanguageHeaderField];
    [self.request setHTTPMethod:HTTPMethod];
    if (contentType) {
        [self.request setValue:contentType forHTTPHeaderField:kContentTypeHeaderField];
    }
    if (sendData) {
        [self.request setHTTPBody:sendData];
    }
    self.filePath = filePath;
}

#pragma mark - Start / cancel

- (NSURLSessionTask *)startDownloading:(id<RBHttpUtilDelegate>)delegate {
    NE_DBG(RBLogRequest(self.request));
    self.delegate = delegate;
    if (self.filePath == nil) {
        return [self startDataTask];
    }
    return [self startDownloadTask];
}

- (NSURLSessionTask *)startDownloadingWithProceed:(RBHttpUtilBlock)proceed
                                          success:(RBHttpUtilBlock)success
                                          failure:(RBHttpUtilBlock)failure {
    self.proceedBlock = proceed;
    self.successBlock = success;
    self.failureBlock = failure;
    return [self startDownloading:nil];
}

- (void)cancel {
    self.delegate = nil;
    if (self.dataTask) {
        [self.dataTask cancel];
        self.dataTask = nil;
    }
    if (self.downloadTask) {
        [self.downloadTask cancel];
        self.downloadTask = nil;
    }
    self.proceedBlock = nil;
    self.successBlock = nil;
    self.failureBlock = nil;
}

#pragma mark - Task creation

/**
 * Create and resume an in-memory data task for the current request.
 * @ghidraAddress 0x379e8
 */
- (NSURLSessionDataTask *)startDataTask {
    __weak RBHttpUtil *weakSelf = self;
    NSURLSessionConfiguration *configuration =
        [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration
                                                          delegate:weakSelf
                                                     delegateQueue:nil];
    weakSelf.dataTask = [session dataTaskWithRequest:weakSelf.request];
    [weakSelf.dataTask resume];
    return weakSelf.dataTask;
}

/**
 * Create and resume a download-to-file task for the current request.
 * @ghidraAddress 0x37c20
 */
- (NSURLSessionDownloadTask *)startDownloadTask {
    __weak RBHttpUtil *weakSelf = self;
    NSURLSessionConfiguration *configuration =
        [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration
                                                          delegate:weakSelf
                                                     delegateQueue:nil];
    weakSelf.downloadTask = [session
        downloadTaskWithRequest:weakSelf.request
              completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
                /** @ghidraAddress 0x37ec4 */
                RBHttpUtil *strongSelf = weakSelf;
                NSInteger statusCode = ((NSHTTPURLResponse *)response).statusCode;
                if (error == nil && statusCode == kHTTPStatusOK) {
                    [strongSelf.downloadTask cancel];
                    strongSelf.downloadTask = nil;
                    if (strongSelf.successBlock) {
                        strongSelf.successBlock(strongSelf);
                    } else if ([strongSelf.delegate
                                   respondsToSelector:@selector(downloaderFinished:)]) {
                        [strongSelf.delegate performSelector:@selector(downloaderFinished:)
                                                  withObject:strongSelf];
                    }
                } else {
                    strongSelf.systemErrorMessage = error.userInfo.description;
                    [strongSelf.downloadTask cancel];
                    strongSelf.downloadTask = nil;
                    if (strongSelf.failureBlock) {
                        strongSelf.failureBlock(strongSelf);
                    } else if ([strongSelf.delegate
                                   respondsToSelector:@selector(downloaderError:)]) {
                        [strongSelf.delegate performSelector:@selector(downloaderError:)
                                                  withObject:strongSelf];
                    }
                }
              }];
    [weakSelf.downloadTask resume];
    return weakSelf.downloadTask;
}

#pragma mark - NSURLSessionDataDelegate

- (void)URLSession:(NSURLSession *)session
              dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveResponse:(NSURLResponse *)response
     completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    if ([response respondsToSelector:@selector(allHeaderFields)]) {
        self.downloadedHeader = ((NSHTTPURLResponse *)response).allHeaderFields;
    }
    if (![response respondsToSelector:@selector(statusCode)] ||
        ((NSHTTPURLResponse *)response).statusCode == kHTTPStatusOK) {
        self.downloadSize = response.expectedContentLength;
        if (self.downloadSize > 0) {
            self.downloadedData = [[NSMutableData alloc] initWithCapacity:self.downloadSize];
        }
        completionHandler(NSURLSessionResponseAllow);
    } else {
        self.systemErrorMessage = [NSString
            stringWithFormat:@"status code = %zd", ((NSHTTPURLResponse *)response).statusCode];
        [self.dataTask cancel];
        [self.downloadTask cancel];
        if (self.failureBlock) {
            self.failureBlock(self);
        } else if ([self.delegate respondsToSelector:@selector(downloaderError:)]) {
            [self.delegate performSelector:@selector(downloaderError:) withObject:self];
        }
        [session invalidateAndCancel];
        [self cancel];
    }
}

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data {
    if (self.downloadedData == nil) {
        self.downloadedData = [[NSMutableData alloc] initWithCapacity:kDefaultResponseCapacity];
    }
    [self.downloadedData appendData:data];
    if (self.proceedBlock) {
        self.proceedBlock(self);
    } else if ([self.delegate respondsToSelector:@selector(downloaderProceed:)]) {
        [self.delegate performSelector:@selector(downloaderProceed:) withObject:self];
    }
}

- (void)URLSession:(NSURLSession *)session
                    task:(NSURLSessionTask *)task
    didCompleteWithError:(NSError *)error {
    if (error) {
        self.systemErrorMessage = error.userInfo.description;
        if (self.failureBlock) {
            self.failureBlock(self);
        } else if ([self.delegate respondsToSelector:@selector(downloaderError:)]) {
            [self.delegate performSelector:@selector(downloaderError:) withObject:self];
        }
        [session invalidateAndCancel];
        [self cancel];
        return;
    }

    if (self.downloadedHeader == nil || self.downloadedHeader[kResponseCodeHeaderKey] == nil ||
        self.downloadedData == nil) {
        self.hashCheck = YES;
    } else {
        NSString *expected = self.downloadedHeader[kResponseCodeHeaderKey];
        NSString *body = [[[NSString alloc] initWithData:self.downloadedData
                                                encoding:NSUTF8StringEncoding] description];
        NSString *seed = [NSString stringWithFormat:@"%@%@", kHashCheckSalt, body];
        NSString *digest = ComputeSha256HexString([seed cStringUsingEncoding:NSUTF8StringEncoding]);
        self.hashCheck = [expected isEqualToString:digest];
    }

    if (self.hashCheck) {
        if (self.successBlock) {
            self.successBlock(self);
        } else if ([self.delegate respondsToSelector:@selector(downloaderFinished:)]) {
            [self.delegate performSelector:@selector(downloaderFinished:) withObject:self];
        }
    } else {
        self.systemErrorMessage = kHashCheckErrorMessage;
        if (self.failureBlock) {
            self.failureBlock(self);
        } else if ([self.delegate respondsToSelector:@selector(downloaderError:)]) {
            [self.delegate performSelector:@selector(downloaderError:) withObject:self];
        }
    }
    [session invalidateAndCancel];
    [self cancel];
}

#pragma mark - NSURLSessionDownloadDelegate

- (void)URLSession:(NSURLSession *)session
          downloadTask:(NSURLSessionDownloadTask *)downloadTask
     didResumeAtOffset:(int64_t)fileOffset
    expectedTotalBytes:(int64_t)expectedTotalBytes {
}

/**
 * Report download progress to the proceed block, or failing that to the delegate.
 * @ghidraAddress 0x38fc0
 */
- (void)URLSession:(NSURLSession *)session
                 downloadTask:(NSURLSessionDownloadTask *)downloadTask
                 didWriteData:(int64_t)bytesWritten
            totalBytesWritten:(int64_t)totalBytesWritten
    totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    if (self.proceedBlock) {
        self.proceedBlock(self);
    } else if (self.delegate) {
        // No class implements downloadProceed:, so this throws when a delegate but no proceed
        // block is set; that is the original's behaviour.
        [(NSObject *)self.delegate performSelectorOnMainThread:@selector(downloadProceed:)
                                                    withObject:self
                                                 waitUntilDone:NO];
    }
}

- (void)URLSession:(NSURLSession *)session
                 downloadTask:(NSURLSessionDownloadTask *)downloadTask
    didFinishDownloadingToURL:(NSURL *)location {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *destination = [NSURL fileURLWithPath:self.filePath];
    NSError *error = nil;
    [fileManager moveItemAtURL:location toURL:destination error:&error];
    if (error == nil) {
        [(NSObject *)self.delegate performSelectorOnMainThread:@selector(downloaderFinished:)
                                                    withObject:self
                                                 waitUntilDone:NO];
    } else {
        self.systemErrorMessage = error.userInfo.description;
        [(NSObject *)self.delegate performSelectorOnMainThread:@selector(downloaderError:)
                                                    withObject:self
                                                 waitUntilDone:NO];
    }
}

#pragma mark - Response accessors

- (unsigned long long)currentSize {
    return self.downloadedData.length;
}

- (float)currentProgress {
    if (self.downloadSize < 1) {
        return 0.0f;
    }
    float progress = (float)self.downloadedData.length / (float)self.downloadSize;
    if (progress > 1.0f) {
        progress = 1.0f;
    }
    return progress;
}

- (NSData *)getData {
    return self.downloadedData;
}

- (id)getDataInJSON {
    if (self.downloadedData == nil) {
        return nil;
    }
    NSError *error = nil;
    return [NSJSONSerialization JSONObjectWithData:self.downloadedData
                                           options:NSJSONReadingAllowFragments
                                             error:&error];
}

- (NSDictionary *)getHeader {
    return self.downloadedHeader;
}

- (BOOL)hashChecked {
    return self.hashCheck;
}

#pragma mark - Reset / deallocation

/**
 * Cancel any in-flight task and restore every field to its initial state.
 * @ghidraAddress 0x39538
 */
- (void)reset {
    self.request = nil;
    [self.dataTask cancel];
    self.dataTask = nil;
    [self.downloadTask cancel];
    self.downloadTask = nil;
    self.downloadSize = 0;
    self.downloadedData = nil;
    self.downloadedHeader = nil;
    self.delegate = nil;
    self.filePath = nil;
    self.hashCheck = NO;
    self.successBlock = nil;
    self.proceedBlock = nil;
    self.failureBlock = nil;
    self.systemErrorMessage = nil;
    self.showErrorMessage = nil;
    self.requestTimeoutInterval = kUnsetTimeoutInterval;
    self.resourceTimeoutInterval = kUnsetTimeoutInterval;
}

- (void)dealloc {
    [self cancel];
}

@end
