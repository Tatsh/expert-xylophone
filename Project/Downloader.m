//
//  Downloader.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class Downloader). Verified against the
//  arm64 disassembly (block invocations go through the block's +0x10 invoke pointer, which the
//  decompiler renders but does not type).
//

#import "Downloader.h"

#import "RBHttpUtil.h"

@implementation Downloader

#pragma mark - Body serialisation

+ (NSData *)dictionaryToJsonData:(NSDictionary *)dictionary {
    return [RBHttpUtil dictionaryToJsonData:dictionary];
}

+ (NSData *)dictionaryToQueryData:(NSDictionary *)dictionary {
    return [RBHttpUtil dictionaryToQueryData:dictionary];
}

#pragma mark - Initialisers

- (instancetype)initWithURL:(NSURL *)url save:(NSString *)filePath {
    self = [super init];
    if (self) {
        if (filePath == nil) {
            self.conn = [[RBHttpUtil alloc] initWithGetURL:url];
        } else {
            self.conn = [[RBHttpUtil alloc] initWithDownloadURL:url filePath:filePath];
        }
    }
    return self;
}

- (instancetype)initWithURL:(NSURL *)url post:(NSData *)post contentType:(NSString *)contentType {
    self = [super init];
    if (self) {
        self.conn = [[RBHttpUtil alloc] initWithPostURL:url post:post contentType:contentType];
    }
    return self;
}

- (instancetype)initWithURL:(NSURL *)url
                       post:(NSData *)post
                contentType:(NSString *)contentType
                    timeout:(float)timeout {
    self = [super init];
    if (self) {
        self.conn = [[RBHttpUtil alloc] initWithPostURL:url
                                                   post:post
                                            contentType:contentType
                                        timeoutInterval:timeout];
    }
    return self;
}

#pragma mark - Start / cancel

- (void)startDownloadingWithDelegate:(id<DownloaderDelegate>)delegate {
    self.delegate = delegate;
    [self.conn startDownloading:self];
}

- (void)startDownloadingWithProceed:(DownloaderBlock)proceed
                            success:(DownloaderBlock)success
                            failure:(DownloaderBlock)failure {
    self.proceedBlock = proceed;
    self.successBlock = success;
    self.failureBlock = failure;
    [self startDownloadingWithDelegate:nil];
}

- (void)cancel {
    self.delegate = nil;
    if (self.conn) {
        [self.conn cancel];
    }
}

#pragma mark - Response accessors (forwarded to the connection)

- (unsigned long long)currentSize {
    return self.conn.currentSize;
}

- (float)currentProgress {
    return self.conn.currentProgress;
}

- (NSData *)getData {
    return [self.conn getData];
}

- (id)getDataInJSON {
    return [self.conn getDataInJSON];
}

- (NSDictionary *)getHeader {
    return [self.conn getHeader];
}

- (NSString *)systemErrorMessage {
    return [self.conn systemErrorMessage];
}

- (NSString *)showErrorMessage {
    return [self.conn showErrorMessage];
}

- (BOOL)hashChecked {
    return self.conn.hashChecked;
}

#pragma mark - RBHttpUtil delegate callbacks

- (void)downloaderProceed:(Downloader *)downloader {
    if (self.proceedBlock) {
        self.proceedBlock(self);
    } else if ([self.delegate respondsToSelector:@selector(downloaderProceed:)]) {
        [self.delegate performSelectorOnMainThread:@selector(downloaderProceed:)
                                        withObject:self
                                     waitUntilDone:YES];
    }
}

- (void)downloaderFinished:(Downloader *)downloader {
    if (self.successBlock) {
        self.successBlock(self);
    } else if ([self.delegate respondsToSelector:@selector(downloaderFinished:)]) {
        [self.delegate performSelectorOnMainThread:@selector(downloaderFinished:)
                                        withObject:self
                                     waitUntilDone:YES];
    }
}

- (void)downloaderError:(Downloader *)downloader {
    if (self.failureBlock) {
        self.failureBlock(self);
    } else if ([self.delegate respondsToSelector:@selector(downloaderError:)]) {
        [self.delegate performSelectorOnMainThread:@selector(downloaderError:)
                                        withObject:self
                                     waitUntilDone:YES];
    }
}

#pragma mark - Deallocation

- (void)dealloc {
    self.delegate = nil;
    [self.conn cancel];
    self.conn = nil;
    self.proceedBlock = nil;
    self.successBlock = nil;
    self.failureBlock = nil;
}

@end

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
