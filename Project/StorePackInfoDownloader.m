#import "StorePackInfoDownloader.h"

#import "StorePackInfo.h"
#import "StoreUtil.h"

// The key under which the pack-detail JSON carries a server-side error description.
static NSString *const kStorePackInfoErrorKey = @"Error";

@implementation StorePackInfoDownloader

#pragma mark - Lifecycle

- (instancetype)initWithStorePackInfo:(StorePackInfo *)info {
    self = [super init];
    if (self) {
        self.packInfo = info;
    }
    return self;
}

- (void)dealloc {
    self.delegate = nil;
    self.packInfo = nil;
    self.downloader = nil;
}

#pragma mark - Accessors

- (StorePackInfo *)getPackInfo {
    return self.packInfo;
}

- (NSString *)getErrorMessage {
    return self.errorMessage;
}

#pragma mark - Download control

- (void)downloadDetail:(BOOL)userOpen {
    self.downloader = nil;
    NSURL *url = [StoreUtil packInfoURL:self.packInfo.packID UserOpen:userOpen];
    // A detail download is a plain GET, so its response is not saved to a file.
    Downloader *downloader = [[Downloader alloc] initWithURL:url save:nil];
    self.downloader = downloader;
    [downloader startDownloadingWithDelegate:self];
}

- (void)cancel {
    if (self.downloader != nil) {
        [self.downloader cancel];
        self.downloader = nil;
    }
}

#pragma mark - DownloaderDelegate

- (void)downloaderFinished:(Downloader *)downloader {
    if (self.downloader != downloader) {
        return;
    }
    id json = [downloader getDataInJSON];
    if ([downloader hashChecked]) {
        self.errorMessage = nil;
    } else {
        self.errorMessage = json[kStorePackInfoErrorKey];
    }
    [self.packInfo setDictionary:json];
    if ([self.delegate respondsToSelector:@selector(storePackInfoDownloaderFinished:)]) {
        [self.delegate storePackInfoDownloaderFinished:self];
    }
    self.downloader = nil;
}

- (void)downloaderProceed:(Downloader *)downloader {
    if (self.downloader != downloader) {
        return;
    }
    if ([self.delegate respondsToSelector:@selector(storePackInfoDownloaderProceed:)]) {
        [self.delegate storePackInfoDownloaderProceed:self];
    }
}

- (void)downloaderError:(Downloader *)downloader {
    if (self.downloader != downloader) {
        return;
    }
    if ([self.delegate respondsToSelector:@selector(storePackInfoDownloaderError:)]) {
        [self.delegate storePackInfoDownloaderError:self];
    }
    self.downloader = nil;
}

@end
