#import "StoreDownloadManager.h"

#import <UIKit/UIKit.h>

#import "Downloader.h"
#import "RBExtendNoteManager.h"
#import "RBMusicManager.h"
#import "StoreDownloadTask.h"

@interface StoreDownloadManager ()

@property(nonatomic, assign) BOOL m_IsStarted;
@property(nonatomic, assign, readwrite) unsigned int currentIndex;

@end

// The download-start and delegate-dispatch blocks below are repeated verbatim in -start, -restart,
// and -downloaderFinished:. They are shared as file-static functions rather than as methods
// because the binary has no selector for either, and a method would add a name to the class that
// the runtime metadata does not carry.
static void StartTaskAtCurrentIndex(StoreDownloadManager *manager);
static void NotifyDelegate(StoreDownloadManager *manager, SEL selector);

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
    StartTaskAtCurrentIndex(self);
    self.m_IsStarted = YES;
    NotifyDelegate(self, @selector(downloadManagerStartTask:));
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
        StartTaskAtCurrentIndex(self);
        NotifyDelegate(self, @selector(downloadManagerStartTask:));
    } else {
        [UIApplication sharedApplication].idleTimerDisabled = NO;
        NotifyDelegate(self, @selector(downloadManagerCompleted:));
    }
}

// Build a plain (in-memory) downloader for the current task's URL and start it against this
// manager. The task's own file path is applied later, when the body is written in
// -downloaderFinished:.
static void StartTaskAtCurrentIndex(StoreDownloadManager *manager) {
    StoreDownloadTask *task = manager.tasks[manager.currentIndex];
    NSURL *url = [NSURL URLWithString:task.fileURL];
    manager.fileDownloader = [[Downloader alloc] initWithURL:url save:nil];
    [manager.fileDownloader startDownloadingWithDelegate:manager];
}

// Forward a lifecycle event to the delegate when it responds. The binary dispatches through
// -performSelector:withObject: rather than a direct message.
static void NotifyDelegate(StoreDownloadManager *manager, SEL selector) {
    if ([manager.delegate respondsToSelector:selector]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [manager.delegate performSelector:selector withObject:manager];
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
    NotifyDelegate(self, @selector(downloadManagerProceed:));
}

- (void)downloaderFinished:(Downloader *)downloader {
    NSData *data = [self.fileDownloader getData];
    self.fileDownloader = nil;
    StoreDownloadTask *task = self.tasks[self.currentIndex];
    BOOL written = [data writeToFile:task.filePath options:NSDataWritingAtomic error:nil];
    if (!written) {
        NotifyDelegate(self, @selector(downloadManagerFailed:));
        return;
    }
    [[RBMusicManager getInstance] setMusicDataArrayDirty];
    [[RBExtendNoteManager getInstance] setExtendNoteDataArrayDirty];
    self.currentIndex = self.currentIndex + 1;
    if (self.currentIndex < self.tasks.count) {
        StartTaskAtCurrentIndex(self);
        NotifyDelegate(self, @selector(downloadManagerStartTask:));
    } else {
        [UIApplication sharedApplication].idleTimerDisabled = NO;
        NotifyDelegate(self, @selector(downloadManagerCompleted:));
    }
}

- (void)downloaderError:(Downloader *)downloader {
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    if (self.fileDownloader) {
        self.fileDownloader = nil;
    }
    NotifyDelegate(self, @selector(downloadManagerFailed:));
}

@end
