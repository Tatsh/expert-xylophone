#import "StoreDownloadManager.h"

#import <UIKit/UIKit.h>

#import "Downloader.h"
#import "RBExtendNoteManager.h"
#import "RBMusicManager.h"
#import "StoreDownloadTask.h"

@interface StoreDownloadManager ()

@property(nonatomic, assign) BOOL m_IsStarted;
@property(nonatomic, assign, readwrite) unsigned int currentIndex;

// De-inlined from the repeated download-start and delegate-dispatch blocks the binary inlines into
// -start, -restart, and -downloaderFinished:; they have no selector of their own in the binary.
- (void)_startTaskAtCurrentIndex;
- (void)_notifyDelegateSelector:(SEL)selector;

@end

@implementation StoreDownloadManager

// The binary's flag ivar has no leading underscore, so keep its exact name.
@synthesize m_IsStarted = m_IsStarted;

#pragma mark Lifecycle

- (instancetype)initWithTasks:(NSArray<StoreDownloadTask *> *)tasks
                     delegate:(id<StoreDownloadManagerDelegate>)delegate {
    if (!tasks) {
        return nil;
    }
    self = [super init];
    if (self) {
        self.tasks = [[NSArray alloc] initWithArray:tasks];
        self.delegate = delegate;
        self.m_IsStarted = NO;
    }
    return self;
}

#pragma mark Running the batch

- (void)start {
    if (self.m_IsStarted) {
        return;
    }
    [UIApplication sharedApplication].idleTimerDisabled = YES;
    self.currentIndex = 0;
    [self _startTaskAtCurrentIndex];
    self.m_IsStarted = YES;
    [self _notifyDelegateSelector:@selector(downloadManagerStartTask:)];
}

- (void)cancel {
    if (self.fileDownloader) {
        [self.fileDownloader cancel];
        self.fileDownloader = nil;
        [UIApplication sharedApplication].idleTimerDisabled = NO;
    }
}

- (void)restart {
    if (!self.m_IsStarted) {
        [self start];
        return;
    }
    self.fileDownloader = nil;
    if (self.currentIndex < self.tasks.count) {
        [self _startTaskAtCurrentIndex];
        [self _notifyDelegateSelector:@selector(downloadManagerStartTask:)];
    } else {
        [UIApplication sharedApplication].idleTimerDisabled = NO;
        [self _notifyDelegateSelector:@selector(downloadManagerCompleted:)];
    }
}

// Build a plain (in-memory) downloader for the current task's URL and start it against this
// manager. The task's own file path is applied later, when the body is written in
// -downloaderFinished:.
- (void)_startTaskAtCurrentIndex {
    StoreDownloadTask *task = self.tasks[self.currentIndex];
    NSURL *url = [NSURL URLWithString:task.fileURL];
    self.fileDownloader = [[Downloader alloc] initWithURL:url save:nil];
    [self.fileDownloader startDownloadingWithDelegate:self];
}

// Forward a lifecycle event to the delegate when it responds. The binary dispatches through
// -performSelector:withObject: rather than a direct message.
- (void)_notifyDelegateSelector:(SEL)selector {
    if ([self.delegate respondsToSelector:selector]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self.delegate performSelector:selector withObject:self];
#pragma clang diagnostic pop
    }
}

#pragma mark Progress

- (unsigned long long)numTasks {
    return self.tasks.count;
}

- (float)currentProgress {
    return self.fileDownloader.currentProgress;
}

- (float)overallProgress {
    return ((float)self.currentIndex + self.currentProgress) / (float)self.numTasks;
}

#pragma mark DownloaderDelegate

- (void)downloaderProceed:(Downloader *)downloader {
    [self _notifyDelegateSelector:@selector(downloadManagerProceed:)];
}

- (void)downloaderFinished:(Downloader *)downloader {
    NSData *data = [self.fileDownloader getData];
    self.fileDownloader = nil;
    StoreDownloadTask *task = self.tasks[self.currentIndex];
    BOOL written = [data writeToFile:task.filePath options:NSDataWritingAtomic error:nil];
    if (!written) {
        [self _notifyDelegateSelector:@selector(downloadManagerFailed:)];
        return;
    }
    [[RBMusicManager getInstance] setMusicDataArrayDirty];
    [[RBExtendNoteManager getInstance] setExtendNoteDataArrayDirty];
    self.currentIndex = self.currentIndex + 1;
    if (self.currentIndex < self.tasks.count) {
        [self _startTaskAtCurrentIndex];
        [self _notifyDelegateSelector:@selector(downloadManagerStartTask:)];
    } else {
        [UIApplication sharedApplication].idleTimerDisabled = NO;
        [self _notifyDelegateSelector:@selector(downloadManagerCompleted:)];
    }
}

- (void)downloaderError:(Downloader *)downloader {
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    if (self.fileDownloader) {
        self.fileDownloader = nil;
    }
    [self _notifyDelegateSelector:@selector(downloadManagerFailed:)];
}

@end
