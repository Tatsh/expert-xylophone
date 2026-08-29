#import "ApplilinkStore.h"

#import "ApplilinkParameters.h"
#import "ApplilinkViewController.h"

// File-scope rather than method-local because +allocWithZone: and +sharedInstance share the
// instance, each with its own once token.
static ApplilinkStore *sSharedInstance = nil;
static dispatch_once_t sAllocOnceToken = 0;
static dispatch_once_t sSharedOnceToken = 0;

// Created in +allocWithZone:, so it is non-nil by the time -init reads it.
static dispatch_queue_t sQueue = nil;

static const char *const kQueueLabel = "ApplilinkStore";

// It survives across store requests, so it is a file-scope global rather than an instance ivar.
static ApplilinkViewController *sViewController = nil;

static const float kMinimumStoreSystemVersion = 6.0f;

@implementation ApplilinkStore

#pragma mark - Lifecycle

+ (instancetype)allocWithZone:(struct _NSZone *)zone {
    dispatch_once(&sAllocOnceToken, ^{
      /** @ghidraAddress 0x220538 */
      // The binary passes a null attribute, which makes this a serial queue.
      sQueue = dispatch_queue_create(kQueueLabel, nil);
      // The binary re-tests the singleton inside the once block, after creating the queue.
      if (sSharedInstance == nil) {
          sSharedInstance = [super allocWithZone:zone];
      }
    });
    return sSharedInstance;
}

// @ghidraAddress 0x2202ec
- (instancetype)init {
    __block ApplilinkStore *initResult = self;
    // Syncing onto the main queue instead would deadlock whenever +sharedInstance is first called
    // from the main thread.
    dispatch_sync(sQueue, ^{
      /** @ghidraAddress 0x2203fc */
      initResult = [super init];
    });
    return initResult;
}

+ (instancetype)sharedInstance {
    dispatch_once(&sSharedOnceToken, ^{
      /** @ghidraAddress 0x220604 */
      sSharedInstance = [[ApplilinkStore alloc] init];
    });
    return sSharedInstance;
}

#pragma mark - Store

- (BOOL)showSKStore:(NSString *)appStoreId
           appParam:(ApplilinkParameters *)appParam
           delegate:(id<SdkViewDelegate>)delegate {
    if ([[[UIDevice currentDevice] systemVersion] floatValue] < kMinimumStoreSystemVersion) {
        return NO;
    }
    if (sViewController == nil) {
        // The binary stores straight into the backing ivars, so the parameters bypass the copy
        // setter and the caller's instance is kept.
        _sdkDelegate = delegate;
        _applilinkParams = appParam;
        sViewController = [[ApplilinkViewController alloc] init];
        [sViewController showSKStore:appStoreId appParam:_applilinkParams delegate:self];
    }
    return YES;
}

- (void)closeSKStore {
    if (sViewController != nil) {
        [sViewController productViewControllerDidFinish];
    }
}

#pragma mark - SdkViewDelegate

- (void)appStoreOpenedNoticeWithAppParam:(ApplilinkParameters *)appParam {
    if (_sdkDelegate != nil &&
        [_sdkDelegate respondsToSelector:@selector(appStoreOpenedNoticeWithAppParam:)]) {
        [_sdkDelegate appStoreOpenedNoticeWithAppParam:_applilinkParams];
    }
}

- (void)appStoreCloseNoticeWithAppParam:(ApplilinkParameters *)appParam {
    if (_sdkDelegate != nil &&
        [_sdkDelegate respondsToSelector:@selector(appStoreCloseNoticeWithAppParam:)]) {
        [_sdkDelegate appStoreCloseNoticeWithAppParam:_applilinkParams];
    }
}

- (void)appStoreClosedNoticeWithAppParam:(ApplilinkParameters *)appParam {
    if (sViewController != nil) {
        [sViewController setSdkDelegate:nil];
    }
    sViewController = nil;
    if (_sdkDelegate != nil) {
        if ([_sdkDelegate respondsToSelector:@selector(appStoreClosedNoticeWithAppParam:)]) {
            [_sdkDelegate appStoreClosedNoticeWithAppParam:_applilinkParams];
        }
        _sdkDelegate = nil;
    }
}

- (void)appStoreFailLoadNoticeWithError:(NSError *)error appParam:(ApplilinkParameters *)appParam {
    if (sViewController != nil) {
        [sViewController setSdkDelegate:nil];
    }
    sViewController = nil;
    if (_sdkDelegate != nil) {
        if ([_sdkDelegate
                respondsToSelector:@selector(appStoreFailLoadNoticeWithError:appParam:)]) {
            // The store always reports nil as the error to the caller's delegate, keeping only the
            // request parameters.
            [_sdkDelegate appStoreFailLoadNoticeWithError:nil appParam:_applilinkParams];
        }
        _sdkDelegate = nil;
    }
}

@end
