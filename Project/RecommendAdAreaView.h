/** @file
 * Reconstructed interface for the Applilink recommend advert SDK's @c RecommendAdAreaView.
 *
 * @c RecommendAdAreaView is the @c UIWebView subclass that renders an interstitial recommend
 * advert area (advert type 5) loaded from a cached HTML file on disk. It acts as its own
 * @c UIWebViewDelegate: it loads the advert file, registers the impression through
 * @c RecommendWebAPI and @c RecommendCore once the content finishes loading, intercepts advert
 * taps on the @c applilink://ext-app scheme (routing clicks through @c AnalysisNetworkCore,
 * @c RecommendWebAPI, @c RecommendAdId, and the native App Store via @c ApplilinkCore, and closing
 * the advert on a @c close command), and reports the advert-list lifecycle and failures to its
 * @c applilinkDelegate through @c ApplilinkCore and to its @c sdkDelegate directly. The Applilink
 * SDK ships as a closed third-party library. Reconstructed from Ghidra project rb458, program
 * rb458.
 */

#import <UIKit/UIKit.h>

#import "ApplilinkStore.h"

@protocol ApplilinkViewDelegate;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The Applilink recommend advert area web view.
 */
@interface RecommendAdAreaView : UIWebView <SdkViewDelegate, UIWebViewDelegate>

/**
 * @brief The advert delegate notified of the advert-list lifecycle and failures.
 */
@property(nonatomic, weak, nullable) id<ApplilinkViewDelegate> applilinkDelegate;

/**
 * @brief The SDK delegate notified of the raw open, close, and failure notices.
 */
@property(nonatomic, weak, nullable) id<SdkViewDelegate> sdkDelegate;

/**
 * @brief The current web-view load status (0 idle, 1 started, 2 finished).
 */
@property(nonatomic, assign) int webViewStatus;

/**
 * @brief The advert-type identifier being displayed.
 */
@property(nonatomic, assign) int adType;

/**
 * @brief The advert-model identifier being displayed.
 */
@property(nonatomic, assign) int adModel;

/**
 * @brief The advert-location identifier being displayed.
 */
@property(nonatomic, strong, nullable) NSString *adLocation;

/**
 * @brief The impression identifier assigned when the advert content finishes loading.
 */
@property(nonatomic, strong, nullable) NSString *impressionId;

/**
 * @brief The caller's opaque request code echoed back in delegate callbacks.
 */
@property(nonatomic, unsafe_unretained, nullable) id requestCode;

/**
 * @brief Configure the advert area with its advert model, location, type, request code, and
 * delegate, then apply the per-model scroll behaviour.
 * @param adModel The advert-model identifier.
 * @param adLocation The advert-location identifier.
 * @param adType The advert-type identifier.
 * @param requestCode The caller's request code.
 * @param delegate The advert delegate.
 * @ghidraAddress 0x23eb70
 */
- (void)setAdModel:(int)adModel
        adLocation:(nullable NSString *)adLocation
            adType:(int)adType
       requestCode:(nullable id)requestCode
          delegate:(nullable id<ApplilinkViewDelegate>)delegate;

/**
 * @brief Load the advert-area contents from a filesystem path.
 * @param path The advert-content file path.
 * @ghidraAddress 0x23ea44
 */
- (void)startPath:(nullable NSString *)path;

/**
 * @brief Tear down the advert area, notifying that the advert list disappeared.
 * @ghidraAddress 0x23ed6c
 */
- (void)closeAdArea;

/**
 * @brief Enable or disable scrolling on the advert's scroll subviews.
 * @param scrollEnabled @c YES to enable scrolling.
 * @ghidraAddress 0x23ed7c
 */
- (void)setScrollEnabled:(BOOL)scrollEnabled;

/**
 * @brief Enable or disable the bounce on the advert's scroll subviews.
 * @param scrollBoundsEnabled @c YES to enable bouncing.
 * @ghidraAddress 0x23f078
 */
- (void)setScrollBoundsEnabled:(BOOL)scrollBoundsEnabled;

/**
 * @brief Show or hide the scroll indicators on the advert's scroll subviews.
 * @param scrollBarEnabled @c YES to show the scroll indicators.
 * @ghidraAddress 0x23f350
 */
- (void)setScrollBarEnabled:(BOOL)scrollBarEnabled;

/**
 * @brief Notify the delegates that the advert list appeared and register the impression.
 * @ghidraAddress 0x23fa28
 */
- (void)appListDidAppear;

/**
 * @brief Notify the delegates that the advert list disappeared and clear the delegates.
 * @ghidraAddress 0x23fb70
 */
- (void)appListDidDisappear;

/**
 * @brief Notify the delegates of an advert-list load failure and clear the SDK delegate.
 * @param error The load failure error.
 * @ghidraAddress 0x23fcd4
 */
- (void)appListFailLoadWithError:(nullable NSError *)error;

/**
 * @brief Notify the delegates of an advert-list link failure.
 * @param error The link failure error.
 * @ghidraAddress 0x23fe44
 */
- (void)appListFailLinkWithError:(nullable NSError *)error;

/**
 * @brief Handle an advert-tap request, routing App Store transitions, first-party clicks, and the
 * close command.
 * @param request The intercepted advert request.
 * @return 1 to let the web view load the request, 0 when the request was consumed.
 * @ghidraAddress 0x23ffa8
 */
- (int)redirectWithRequest:(nullable NSURLRequest *)request;

/**
 * @brief Handle the App Store product page opening.
 * @ghidraAddress 0x241364
 */
- (void)openedNotice;

/**
 * @brief Tear down the advert area and remove it from its superview.
 * @ghidraAddress 0x241368
 */
- (void)closeNotice;

/**
 * @brief Handle an App Store product-page open error.
 * @ghidraAddress 0x2413a4
 */
- (void)openErrorNotice;

/**
 * @brief Handle the App Store product page opening.
 * @ghidraAddress 0x2413a8
 */
- (void)appStoreOpenedNotice;

/**
 * @brief Handle the App Store product page closing, tearing down the advert for advert model 5.
 * @ghidraAddress 0x2413ac
 */
- (void)appStoreCloseNotice;

/**
 * @brief Handle the App Store product page having closed.
 * @ghidraAddress 0x2413d4
 */
- (void)appStoreClosedNotice;

/**
 * @brief Handle an App Store product-page load failure.
 * @param error The load failure error.
 * @ghidraAddress 0x2413d8
 */
- (void)appStoreFailLoadNoticeWithError:(nullable NSError *)error;

/**
 * @brief Handle the App Store product page transitioning.
 * @ghidraAddress 0x2413dc
 */
- (void)appStoreTransitionNotice;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
