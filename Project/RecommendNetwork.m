//
//  RecommendNetwork.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RecommendNetwork). Verified
//  against the arm64 disassembly: the CGRect passed to +openAdAreaWithParentView:rect:... is
//  carried in the d0-d3 vector registers and forwarded verbatim to the requestCode: variant, so
//  there is no soft-float arithmetic to recover. This is a plain Objective-C file because every
//  collaborator is reached through ordinary message sends, with no C++.
//
//  The class is a thin facade over the Applilink recommend SDK: each entry point asks
//  ApplilinkConsts whether it may run, then either forwards to the shared RecommendCore
//  (dispatching the status queries onto a global queue) or reports a localised error straight back
//  to the caller.
//

#import "RecommendNetwork.h"

#import "ApplilinkConsts.h"
#import "ApplilinkCore.h"
#import "ApplilinkNetworkError.h"
#import "ApplilinkParameters.h"
#import "RecommendAdAreaView.h"
#import "RecommendCore.h"
#import "RecommendWebView.h"

// Applilink error codes. The SDK-unavailable code is reported when the SDK may not run at all; the
// fail-open code is reported when an open request is rejected because the SDK never finished
// initialising.
static const NSInteger kApplilinkErrorSdkUnavailable = 0x401;
static const NSInteger kApplilinkErrorOpenFailed = 0x3f2;

// The keys of the display-status dictionary handed to the callback on the SDK-unavailable path.
static NSString *const kRecommendUnreadCountKey = @"unreadCount";
static NSString *const kRecommendBannerDisplayStatusKey = @"bannerDisplayStatus";

// The zero-count and zero-status placeholders for the SDK-unavailable display-status dictionary.
static const int kRecommendUnreadCountNone = 0;
static const int kRecommendBannerDisplayStatusNone = 0;

// The implicit request code the convenience entry points forward when the caller supplies none.
static const NSInteger kRecommendRequestCodeNone = 0;

// The vertical alignment the app-list and interstitial flows request; they do not expose it.
static const int kRecommendVerticalAlignDefault = 0;

@implementation RecommendNetwork

#pragma mark Status queries

+ (void)getAppListStatusWithCallback:(RecommendAdStatusCallback)callback {
    [self getAdStatusWithAdModel:RecommendAdModelAppList callback:callback];
}

+ (void)getAdStatusWithAdModel:(RecommendAdModel)adModel
                      callback:(RecommendAdStatusCallback)callback {
    if (![ApplilinkConsts canUseApplilinkSdk]) {
        NSError *error =
            [ApplilinkNetworkError localizedApplilinkErrorWithCode:kApplilinkErrorSdkUnavailable];
        callback(0, error);
        return;
    }
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      /** @ghidraAddress 0x212038 */
      [[RecommendCore sharedInstance] getAdStatusWithAdModel:(int)adModel callback:callback];
    });
}

+ (void)getUnreadCountWithAdModel:(RecommendAdModel)adModel
                       adLocation:(NSString *)adLocation
                         callback:(RecommendAdStatusCallback)callback {
    if (![ApplilinkConsts canUseApplilinkSdk]) {
        NSError *error =
            [ApplilinkNetworkError localizedApplilinkErrorWithCode:kApplilinkErrorSdkUnavailable];
        callback(0, error);
        return;
    }
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      /** @ghidraAddress 0x2121d4 */
      [[RecommendCore sharedInstance] getUnreadCountWithAdModel:(int)adModel
                                                     adLocation:adLocation
                                                       callback:callback];
    });
}

+ (void)getAdDisplayStatusWithAdModel:(RecommendAdModel)adModel
                           adLocation:(NSString *)adLocation
                             callback:(RecommendAdDisplayStatusCallback)callback {
    if (![ApplilinkConsts canUseApplilinkSdk]) {
        NSMutableDictionary *status = [NSMutableDictionary dictionaryWithCapacity:2];
        [status setValue:@(kRecommendUnreadCountNone) forKey:kRecommendUnreadCountKey];
        [status setValue:@(kRecommendBannerDisplayStatusNone)
                  forKey:kRecommendBannerDisplayStatusKey];
        NSError *error =
            [ApplilinkNetworkError localizedApplilinkErrorWithCode:kApplilinkErrorSdkUnavailable];
        callback(status, error);
        return;
    }
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      /** @ghidraAddress 0x212488 */
      [[RecommendCore sharedInstance] getAdDisplayStatusWithAdModel:(int)adModel
                                                         adLocation:adLocation
                                                           callback:callback];
    });
}

#pragma mark First-party adverts

+ (void)showOwnAdWithAdLocation:(NSString *)adLocation
                      toAppliId:(NSString *)appliId
                     creativeId:(NSString *)creativeId {
    if ([ApplilinkConsts canUseApplilinkSdk]) {
        [[RecommendCore sharedInstance] showOwnAdWithAdLocation:adLocation
                                                      toAppliId:appliId
                                                     creativeId:creativeId];
    }
}

+ (void)touchOwnAdWithAdLocation:(NSString *)adLocation
                       toAppliId:(NSString *)appliId
                      creativeId:(NSString *)creativeId
                     requestCode:(NSInteger)requestCode
                        delegate:(id)delegate {
    if ([ApplilinkConsts checkUseSDKWithAdModel:(int)RecommendAdModelOwnAd
                                     adLocation:adLocation
                                  verticalAlign:kRecommendVerticalAlignDefault
                                    requestCode:requestCode
                                       delegate:delegate]) {
        [[RecommendCore sharedInstance] touchOwnAdWithAdLocation:adLocation
                                                       toAppliId:appliId
                                                      creativeId:creativeId
                                                     requestCode:requestCode
                                                        delegate:delegate];
    }
}

#pragma mark Application list

+ (void)openAppListWithAdLocation:(NSString *)adLocation delegate:(id)delegate {
    [self openAppListWithAdLocation:adLocation
                        requestCode:kRecommendRequestCodeNone
                           delegate:delegate];
}

+ (void)openAppListWithAdLocation:(NSString *)adLocation
                      requestCode:(NSInteger)requestCode
                         delegate:(id)delegate {
    if (![ApplilinkConsts checkUseSDKWithAdModel:(int)RecommendAdModelAppList
                                      adLocation:adLocation
                                   verticalAlign:kRecommendVerticalAlignDefault
                                     requestCode:requestCode
                                        delegate:delegate]) {
        return;
    }
    RecommendCore *core = [RecommendCore sharedInstance];
    if (core.initializeFlg == 0 && ![ApplilinkCore isInitializeStatusFlg]) {
        ApplilinkParameters *params = [[ApplilinkParameters alloc] init];
        [params setRequestWithAdModel:(int)RecommendAdModelAppList
                           adLocation:adLocation
                          requestCode:requestCode];
        NSError *error =
            [ApplilinkNetworkError localizedApplilinkErrorWithCode:kApplilinkErrorOpenFailed];
        [ApplilinkCore toDelegateFailOpenWithError:error appParam:params delegate:delegate];
        return;
    }
    [core openAdScreenWithParentView:nil
                             adModel:(int)RecommendAdModelAppList
                          adLocation:adLocation
                       verticalAlign:kRecommendVerticalAlignDefault
                         requestCode:requestCode
                            delegate:delegate];
}

#pragma mark Advert screen

+ (void)openAdScreenWithAdModel:(RecommendAdModel)adModel
                     adLocation:(NSString *)adLocation
                       delegate:(id)delegate {
    [self openAdScreenWithAdModel:adModel
                       adLocation:adLocation
                      requestCode:kRecommendRequestCodeNone
                         delegate:delegate];
}

+ (void)openAdScreenWithAdModel:(RecommendAdModel)adModel
                     adLocation:(NSString *)adLocation
                    requestCode:(NSInteger)requestCode
                       delegate:(id)delegate {
    if (![ApplilinkConsts checkUseSDKWithAdModel:(int)adModel
                                      adLocation:adLocation
                                   verticalAlign:kRecommendVerticalAlignDefault
                                     requestCode:requestCode
                                        delegate:delegate]) {
        return;
    }
    RecommendCore *core = [RecommendCore sharedInstance];
    if (core.initializeFlg == 0 && ![ApplilinkCore isInitializeStatusFlg]) {
        ApplilinkParameters *params = [[ApplilinkParameters alloc] init];
        [params setRequestWithAdModel:(int)adModel adLocation:adLocation requestCode:requestCode];
        NSError *error =
            [ApplilinkNetworkError localizedApplilinkErrorWithCode:kApplilinkErrorOpenFailed];
        [ApplilinkCore toDelegateFailOpenWithError:error appParam:params delegate:delegate];
        return;
    }
    [core openAdScreenWithParentView:nil
                             adModel:(int)adModel
                          adLocation:adLocation
                       verticalAlign:kRecommendVerticalAlignDefault
                         requestCode:requestCode
                            delegate:delegate];
}

#pragma mark Advert area

+ (void)openAdAreaWithParentView:(UIView *)parentView
                            rect:(CGRect)rect
                         adModel:(RecommendAdModel)adModel
                      adLocation:(NSString *)adLocation
                   verticalAlign:(int)verticalAlign
                        delegate:(id)delegate {
    [self openAdAreaWithParentView:parentView
                              rect:rect
                           adModel:adModel
                        adLocation:adLocation
                     verticalAlign:verticalAlign
                       requestCode:kRecommendRequestCodeNone
                          delegate:delegate];
}

+ (void)openAdAreaWithParentView:(UIView *)parentView
                            rect:(CGRect)rect
                         adModel:(RecommendAdModel)adModel
                      adLocation:(NSString *)adLocation
                   verticalAlign:(int)verticalAlign
                     requestCode:(NSInteger)requestCode
                        delegate:(id)delegate {
    if (![ApplilinkConsts checkUseSDKWithAdModel:(int)adModel
                                      adLocation:adLocation
                                   verticalAlign:verticalAlign
                                     requestCode:requestCode
                                        delegate:delegate]) {
        return;
    }
    RecommendCore *core = [RecommendCore sharedInstance];
    if (core.initializeFlg == 0 && ![ApplilinkCore isInitializeStatusFlg]) {
        ApplilinkParameters *params = [[ApplilinkParameters alloc] init];
        [params setRequestWithAdModel:(int)adModel adLocation:adLocation requestCode:requestCode];
        NSError *error =
            [ApplilinkNetworkError localizedApplilinkErrorWithCode:kApplilinkErrorOpenFailed];
        [ApplilinkCore toDelegateFailOpenWithError:error appParam:params delegate:delegate];
        return;
    }
    [core openAdAreaWithParentView:parentView
                              rect:rect
                           adModel:(int)adModel
                        adLocation:adLocation
                     verticalAlign:verticalAlign
                       requestCode:requestCode
                          delegate:delegate];
}

#pragma mark Interstitial

+ (void)openInterstitialWithAdLocation:(NSString *)adLocation delegate:(id)delegate {
    [self openInterstitialWithAdLocation:adLocation
                             requestCode:kRecommendRequestCodeNone
                                delegate:delegate];
}

+ (void)openInterstitialWithAdLocation:(NSString *)adLocation
                           requestCode:(NSInteger)requestCode
                              delegate:(id)delegate {
    if (![ApplilinkConsts checkUseSDKWithAdModel:(int)RecommendAdModelInterstitial
                                      adLocation:adLocation
                                   verticalAlign:kRecommendVerticalAlignDefault
                                     requestCode:requestCode
                                        delegate:delegate]) {
        return;
    }
    RecommendCore *core = [RecommendCore sharedInstance];
    if (core.initializeFlg == 0 && ![ApplilinkCore isInitializeStatusFlg]) {
        ApplilinkParameters *params = [[ApplilinkParameters alloc] init];
        [params setRequestWithAdModel:(int)RecommendAdModelInterstitial
                           adLocation:adLocation
                          requestCode:requestCode];
        NSError *error =
            [ApplilinkNetworkError localizedApplilinkErrorWithCode:kApplilinkErrorOpenFailed];
        [ApplilinkCore toDelegateFailOpenWithError:error appParam:params delegate:delegate];
        return;
    }
    [core openFullViewControllerWithAdModel:(int)RecommendAdModelInterstitial
                                 adLocation:adLocation
                              verticalAlign:kRecommendVerticalAlignDefault
                                requestCode:requestCode
                                   delegate:delegate];
}

#pragma mark Teardown

+ (void)closeAdScreen {
    if ([ApplilinkConsts canUseApplilinkSdk]) {
        [[RecommendCore sharedInstance] closeAdScreen];
    }
}

+ (void)closeAdAreaWithParentView:(UIView *)parentView {
    if (![ApplilinkConsts canUseApplilinkSdk]) {
        return;
    }
    UIView *host = parentView ?: [ApplilinkCore mainWindow];
    for (UIView *subview in host.subviews) {
        BOOL isWebView = [subview isKindOfClass:[RecommendWebView class]];
        BOOL isAreaView = [subview isKindOfClass:[RecommendAdAreaView class]];
        if (isWebView || isAreaView) {
            if (isAreaView) {
                [(RecommendAdAreaView *)subview closeAdArea];
            }
            [subview removeFromSuperview];
        }
    }
}

+ (void)setAdAreaVisibleWithParentView:(UIView *)parentView flag:(BOOL)flag {
    if (![ApplilinkConsts canUseApplilinkSdk]) {
        return;
    }
    UIView *host = parentView ?: [ApplilinkCore mainWindow];
    for (UIView *subview in host.subviews) {
        BOOL isWebView = [subview isKindOfClass:[RecommendWebView class]];
        BOOL isAreaView = [subview isKindOfClass:[RecommendAdAreaView class]];
        if (isWebView || isAreaView) {
            subview.hidden = !flag;
        }
    }
}

@end
