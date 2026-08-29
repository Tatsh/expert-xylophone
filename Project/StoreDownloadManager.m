#import "StoreDownloadManager.h"

#import <UIKit/UIKit.h>

#import "Downloader.h"
#import "RBExtendNoteManager.h"
#import "RBMusicManager.h"
#import "StoreDownloadTask.h"

@interface StoreDownloadManager () {
    // Reached as ivars: a property setter would add a selector the shipped class does not carry.
    BOOL m_IsStarted;
    unsigned int _currentIndex;
}

@end

// File-static rather than methods: the binary carries no selector for either.
static void StartTaskAtCurrentIndex(StoreDownloadManager *manager);
static void NotifyDelegate(StoreDownloadManager *manager, SEL selector);

@implementation StoreDownloadManager

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
        m_IsStarted = NO;
    }
    return self;
}

- (void)dealloc {
    if (self.fileDownloader) {
        [self.fileDownloader cancel];
        self.fileDownloader = nil;
    }
}

#pragma mark Running the batch

- (void)start {
    if (m_IsStarted) {
        return;
    }
    [UIApplication sharedApplication].idleTimerDisabled = YES;
    _currentIndex = 0;
    StartTaskAtCurrentIndex(self);
    m_IsStarted = YES;
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
    if (!m_IsStarted) {
        [self start];
        return;
    }
    self.fileDownloader = nil;
    if (_currentIndex < self.tasks.count) {
        StartTaskAtCurrentIndex(self);
        NotifyDelegate(self, @selector(downloadManagerStartTask:));
    } else {
        [UIApplication sharedApplication].idleTimerDisabled = NO;
        NotifyDelegate(self, @selector(downloadManagerCompleted:));
    }
}

// The downloader is in-memory; the task's file path is applied later in -downloaderFinished:.
static void StartTaskAtCurrentIndex(StoreDownloadManager *manager) {
    StoreDownloadTask *task = manager.tasks[manager->_currentIndex];
    NSURL *url = [NSURL URLWithString:task.fileURL];
    manager.fileDownloader = [[Downloader alloc] initWithURL:url save:nil];
    [manager.fileDownloader startDownloadingWithDelegate:manager];
}

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
    StoreDownloadTask *task = self.tasks[_currentIndex];
    NSError *error = nil;
    // The error is collected and never read; only ARC touches it after the call.
    BOOL written = [data writeToFile:task.filePath options:NSDataWritingAtomic error:&error];
    if (!written) {
        NotifyDelegate(self, @selector(downloadManagerFailed:));
        return;
    }
    [[RBMusicManager getInstance] setMusicDataArrayDirty];
    [[RBExtendNoteManager getInstance] setExtendNoteDataArrayDirty];
    _currentIndex = _currentIndex + 1;
    if (_currentIndex < self.tasks.count) {
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
