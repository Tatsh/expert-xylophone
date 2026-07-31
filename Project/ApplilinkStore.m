//
//  ApplilinkStore.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class ApplilinkStore). This is a plain
//  Objective-C file: it drives an ApplilinkViewController through ordinary message sends, guards
//  its shared instance with dispatch_once, and serialises on a private queue with dispatch_sync, so
//  there is no C++.
//
//  ApplilinkStore is the SDK's App Store product-page facade singleton. It is created once,
//  presents the store through an ApplilinkViewController (which owns the
//  SKStoreProductViewController), and is itself the SdkViewDelegate of that view controller. When
//  the view controller reports the open, close, closed, or load-failure notices, the store forwards
//  them to the caller's own sdkDelegate.
//

#import "ApplilinkStore.h"

#import "ApplilinkParameters.h"
#import "ApplilinkViewController.h"

// The one and only ApplilinkStore instance and its dispatch_once tokens.
// File-scope rather than method-local, which the singleton rule would otherwise ask for, because
// +allocWithZone: and +sharedInstance share the instance and each has its own once token. The
// binary agrees: all three live at one global base, the instance at +0x670 and the shared token at
// +0x670+0x18.
static ApplilinkStore *sSharedInstance = nil;
static dispatch_once_t sAllocOnceToken = 0;
static dispatch_once_t sSharedOnceToken = 0;

// The private serial queue -init synchronises its super call onto. It is created in
// +allocWithZone:, which alloc always runs before init, so it is non-nil by the time -init reads it.
static dispatch_queue_t sQueue = nil;

// The label the binary passes to dispatch_queue_create.
static const char *const kQueueLabel = "ApplilinkStore";

// The view controller presenting the store product page while one is on screen, or nil when none
// is. It survives across store requests, so it is a file-scope global rather than an instance ivar.
static ApplilinkViewController *sViewController = nil;

// The first iOS version whose SKStoreProductViewController the SDK is willing to present.
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
    // The queue is the private serial one created in +allocWithZone:, not the main queue. Syncing
    // onto the main queue here would deadlock whenever +sharedInstance is first called from the
    // main thread, which is what +[ApplilinkCore resume] does on entering the foreground.
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
        // The binary stores both values straight into the backing ivars here; in particular the
        // parameters bypass the copy setter, so this keeps the caller's instance rather than a
        // copy.
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
