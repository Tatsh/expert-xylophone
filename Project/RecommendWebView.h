/** @file
 * Reconstructed interface for the Applilink recommend advert SDK's @c RecommendWebView.
 *
 * @c RecommendWebView is the @c UIView container that hosts a recommend advert. Unlike
 * @c RecommendAdWebView (which is the @c UIWebView that actually renders the advert and drives its
 * network lifecycle), @c RecommendWebView is a lightweight wrapper that lazily creates the inner
 * advert view, overlays a loading activity indicator, and forwards the advert-list lifecycle to its
 * @c applilinkDelegate. It picks the concrete inner view at load time: for a cached HTML advert it
 * builds a @c RecommendAdAreaView from a local file, and for a live advert it dispatches a layout
 * block on the main queue that builds a @c RecommendAdWebView and issues the request. The class
 * adopts the @c ApplilinkViewDelegate protocol in the binary so it can receive the advert-list
 * callbacks from those inner views; since that protocol has no definition in the reconstruction,
 * those callbacks are declared here as an informal delegate. The Applilink SDK ships as a closed
 * third-party library. Reconstructed from Ghidra project rb458, program rb458.
 */

#import <UIKit/UIKit.h>

@class ApplilinkParameters;
@class RecommendAdAreaView;
@class RecommendAdWebView;
@protocol ApplilinkViewDelegate;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The Applilink recommend advert web-view container.
 * @ghidraAddress 0x3bd9e0
 */
@interface RecommendWebView : UIView

/**
 * @brief The loading activity indicator overlaid while the advert loads.
 */
@property(nonatomic, strong, nullable) UIActivityIndicatorView *indicator;

/**
 * @brief The inner web view that renders a live recommend advert.
 */
@property(nonatomic, strong, nullable) RecommendAdWebView *webView;

/**
 * @brief The inner area view that renders a cached (local HTML) recommend advert.
 */
@property(nonatomic, strong, nullable) RecommendAdAreaView *adAreaWebView;

/**
 * @brief The advert delegate notified of the advert-list lifecycle and failures.
 */
@property(nonatomic, weak, nullable) id<ApplilinkViewDelegate> applilinkDelegate;

/**
 * @brief The request parameters for the advert currently being displayed.
 */
@property(nonatomic, copy, nullable) ApplilinkParameters *applilinkParams;

/**
 * @brief Whether the inner web view is allowed to bounce when scrolled.
 */
@property(nonatomic, assign) BOOL webViewBounces;

/**
 * @brief Initialise from an archive and apply the shared container configuration.
 * @param coder The unarchiver to decode from.
 * @return The initialised container, or @c nil.
 * @ghidraAddress 0x245490
 */
- (nullable instancetype)initWithCoder:(NSCoder *)coder;

/**
 * @brief Apply the shared container configuration (transparent, non-opaque, flexible autoresizing,
 * scale-to-fill content mode).
 * @ghidraAddress 0x2454f4
 */
- (void)setInitParam;

/**
 * @brief Load the advert web content for an advert model at an advert location.
 *
 * Builds the request parameters, then delegates to
 * @c loadRequestWithAdModel:adLocation:verticalAlign:delegate:.
 * @param adModel The advert-model identifier.
 * @param adLocation The advert-location identifier.
 * @param verticalAlign The vertical-alignment identifier.
 * @param requestCode The caller's request code echoed back in delegate callbacks.
 * @param delegate The advert delegate to notify.
 * @ghidraAddress 0x2455f0
 */
- (void)loadRequestWithAdModel:(int)adModel
                    adLocation:(nullable NSString *)adLocation
                 verticalAlign:(int)verticalAlign
                   requestCode:(nullable id)requestCode
                      delegate:(nullable id<ApplilinkViewDelegate>)delegate;

/**
 * @brief Load the advert, choosing the cached-HTML or live path based on the advert model.
 *
 * When the SDK may be used and the recommend core is initialised: advert models @c 5 and
 * @c 100..101 build a cached @c RecommendAdAreaView from a local HTML file, and every other model
 * dispatches a layout block on the main queue that builds a @c RecommendAdWebView and issues the
 * request. Failures are reported through @c ApplilinkCore.
 * @param adModel The advert-model identifier.
 * @param adLocation The advert-location identifier.
 * @param verticalAlign The vertical-alignment identifier.
 * @param delegate The advert delegate to notify.
 * @ghidraAddress 0x2456f8
 */
- (void)loadRequestWithAdModel:(int)adModel
                    adLocation:(nullable NSString *)adLocation
                 verticalAlign:(int)verticalAlign
                      delegate:(nullable id<ApplilinkViewDelegate>)delegate;

/**
 * @brief Set whether the inner web view may scroll, recording it as the bounce state and forwarding
 * it to the inner web view.
 * @param scrollEnabled @c YES to allow scrolling.
 * @ghidraAddress 0x246120
 */
- (void)setScrollEnabled:(BOOL)scrollEnabled;

/**
 * @brief Stop animating and cancel the pending auto-hide of the loading indicator.
 * @ghidraAddress 0x246028
 */
- (void)hiddenIndicator;

/**
 * @brief Tear down both inner advert views before this view leaves the tree.
 * @ghidraAddress 0x24607c
 */
- (void)closeAdArea;

/**
 * @brief Notify the delegate that the advert list started.
 * @ghidraAddress 0x246158
 */
- (void)appListDidStart;

/**
 * @brief Remove the loading indicator and notify the delegate that the advert list appeared.
 * @ghidraAddress 0x2461c0
 */
- (void)appListDidAppear;

/**
 * @brief Remove the loading indicator and inner web view, notify the delegate that the advert list
 * disappeared, and clear the delegate.
 * @ghidraAddress 0x24628c
 */
- (void)appListDidDisappear;

/**
 * @brief Notify the delegate of an advert-list load failure and clear the delegate.
 * @param error The load failure error.
 * @ghidraAddress 0x246374
 */
- (void)appListFailLoadWithError:(nullable NSError *)error;

/**
 * @brief Notify the delegate of an advert-list link failure.
 * @param error The link failure error.
 * @ghidraAddress 0x24647c
 */
- (void)appListFailLinkWithError:(nullable NSError *)error;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
