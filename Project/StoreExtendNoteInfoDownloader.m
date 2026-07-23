#import "StoreExtendNoteInfoDownloader.h"

#import "StoreExtendNoteInfo.h"
#import "StoreUtil.h"

// The key under which the extend-note-detail JSON carries a server-side error description.
static NSString *const kStoreExtendNoteInfoErrorKey = @"Error";

@implementation StoreExtendNoteInfoDownloader

#pragma mark - Lifecycle

- (instancetype)initWithStoreExtendNoteInfo:(StoreExtendNoteInfo *)info {
    self = [super init];
    if (self) {
        self.extendNoteInfo = info;
    }
    return self;
}

- (void)dealloc {
    self.delegate = nil;
    self.extendNoteInfo = nil;
    self.downloader = nil;
}

#pragma mark - Accessors

- (StoreExtendNoteInfo *)getExtendNoteInfo {
    return self.extendNoteInfo;
}

- (NSString *)getErrorMessage {
    return self.errorMessage;
}

#pragma mark - Download control

- (void)downloadDetail:(BOOL)userOpen {
    self.downloader = nil;
    NSURL *url = [StoreUtil extendNoteInfoURL:self.extendNoteInfo.pid UserOpen:userOpen];
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
        self.errorMessage = json[kStoreExtendNoteInfoErrorKey];
    }
    [self.extendNoteInfo setDictionary:json];
    if ([self.delegate respondsToSelector:@selector(storeExtendNoteInfoDownloaderFinished:)]) {
        [self.delegate storeExtendNoteInfoDownloaderFinished:self];
    }
    self.downloader = nil;
}

- (void)downloaderProceed:(Downloader *)downloader {
    if (self.downloader != downloader) {
        return;
    }
    // Faithful oddity: the respondsToSelector: guard names -storeExtendInfoDownloaderProceed: (no
    // "Note"), whereas the message actually sent is -storeExtendNoteInfoDownloaderProceed:.
    if ([self.delegate respondsToSelector:@selector(storeExtendInfoDownloaderProceed:)]) {
        [self.delegate storeExtendNoteInfoDownloaderProceed:self];
    }
}

- (void)downloaderError:(Downloader *)downloader {
    if (self.downloader != downloader) {
        return;
    }
    // Faithful oddity: the respondsToSelector: guard names -storeExtendInfoDownloaderError: (no
    // "Note"), whereas the message actually sent is -storeExtendNoteInfoDownloaderError:.
    if ([self.delegate respondsToSelector:@selector(storeExtendInfoDownloaderError:)]) {
        [self.delegate storeExtendNoteInfoDownloaderError:self];
    }
    self.downloader = nil;
}

@end
