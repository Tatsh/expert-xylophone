/** @file
 * Reconstructed interface for the Applilink recommend advert SDK's @c RecommendAdWebView.
 *
 * @c RecommendAdWebView is the @c UIWebView subclass that renders a recommend advert (a banner or
 * an interstitial) and drives its whole lifecycle. It acts as its own @c UIWebViewDelegate: it
 * starts a recommend session through @c RecommendCore, fetches the banner detail through
 * @c RecommendWebAPI, loads the advert request, intercepts advert taps (routing clicks through
 * @c RecommendCore and closing the advert on a @c close command), and reports progress and failures
 * to its @c applilinkDelegate by way of @c ApplilinkCore. The Applilink SDK ships as a closed
 * third-party library. Reconstructed from Ghidra project rb458, program rb458.
 */

#import <UIKit/UIKit.h>

@protocol ApplilinkViewDelegate;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The Applilink recommend advert web view.
 * @ghidraAddress 0x3cda40
 */
@interface RecommendAdWebView : UIWebView <UIWebViewDelegate>

/**
 * @brief The advert delegate notified of the advert list lifecycle and failures.
 */
@property(nonatomic, weak, nullable) id<ApplilinkViewDelegate> applilinkDelegate;

/**
 * @brief Whether the advert web content has finished loading.
 */
@property(nonatomic, assign) BOOL loadComplete;

/**
 * @brief Whether the advert web view has already reloaded once.
 */
@property(nonatomic, assign) BOOL reloadFlg;

/**
 * @brief Whether the advert load has been cancelled (for example by removal from the view tree).
 */
@property(nonatomic, assign) BOOL cancelFlg;

/**
 * @brief Whether scrolling is enabled for the advert web view.
 */
@property(nonatomic, assign) BOOL scrollFlg;

/**
 * @brief The current web-view load status (0 idle, 1 started, 2 finished).
 */
@property(nonatomic, assign) int webViewStatus;

/**
 * @brief The advert-model identifier being displayed.
 */
@property(nonatomic, assign) int adModel;

/**
 * @brief The advert-location identifier being displayed.
 */
@property(nonatomic, strong, nullable) NSString *adLocation;

/**
 * @brief The vertical-alignment identifier for the advert.
 */
@property(nonatomic, assign) int verticalAlign;

/**
 * @brief The caller's opaque request code echoed back in delegate callbacks.
 */
@property(nonatomic, unsafe_unretained, nullable) id requestCode;

/**
 * @brief Apply the shared advert web-view configuration (transparent background, autoresizing, and
 * reset flags).
 * @ghidraAddress 0x216a48
 */
- (void)setInitParam;

/**
 * @brief Load the advert web content for an advert model at an advert location.
 * @param adModel The advert-model identifier.
 * @param adLocation The advert-location identifier.
 * @param verticalAlign The vertical-alignment identifier.
 * @param requestCode The caller's request code.
 * @param delegate The advert delegate to notify.
 * @ghidraAddress 0x216c00
 */
- (void)loadRequestWithAdModel:(int)adModel
                    adLocation:(nullable NSString *)adLocation
                 verticalAlign:(int)verticalAlign
                   requestCode:(nullable id)requestCode
                      delegate:(nullable id<ApplilinkViewDelegate>)delegate;

/**
 * @brief Begin the recommend session and load the advert.
 * @ghidraAddress 0x216d88
 */
- (void)loadRequest;

/**
 * @brief Load an advert request built from a URL string and its query parameters.
 * @param URL The advert request URL string.
 * @param parameters The request parameters appended to the URL.
 * @ghidraAddress 0x217b7c
 */
- (void)loadRequestWithURL:(nullable NSString *)URL parameters:(nullable NSDictionary *)parameters;

/**
 * @brief Stop any in-flight load and notify the delegate that the advert list closed.
 * @ghidraAddress 0x217c90
 */
- (void)closeAdArea;

/**
 * @brief Enable or disable scrolling on the advert's scroll subviews.
 * @param scrollEnabled @c YES to enable scrolling.
 * @ghidraAddress 0x217ce4
 */
- (void)setScrollEnabled:(BOOL)scrollEnabled;

/**
 * @brief Enable or disable the bounce on the advert's scroll subviews.
 * @param scrollBoundsEnabled @c YES to enable bouncing.
 * @ghidraAddress 0x217fec
 */
- (void)setScrollBoundsEnabled:(BOOL)scrollBoundsEnabled;

/**
 * @brief Show or hide the scroll indicators on the advert's scroll subviews.
 * @param scrollBarEnabled @c YES to show the scroll indicators.
 * @ghidraAddress 0x2182c4
 */
- (void)setScrollBarEnabled:(BOOL)scrollBarEnabled;

/**
 * @brief Stop loading the advert web view.
 * @ghidraAddress 0x2184a0
 */
- (void)unloadRecommendView;

/**
 * @brief Handle the hosting controller disappearing.
 * @param viewDidDisappear @c YES if the disappearance was animated.
 * @ghidraAddress 0x2184b0
 */
- (void)viewDidDisappear:(BOOL)viewDidDisappear;

/**
 * @brief Unload the advert, clear the advert location, and notify that the advert list disappeared.
 * @ghidraAddress 0x2184b4
 */
- (void)appliListClosed;

/**
 * @brief Notify the delegate that the advert list started.
 * @ghidraAddress 0x218ae0
 */
- (void)appListDidStart;

/**
 * @brief Notify the delegate that the advert list appeared.
 * @ghidraAddress 0x218b84
 */
- (void)appListDidAppear;

/**
 * @brief Notify the delegate that the advert list disappeared and clear the delegate.
 * @ghidraAddress 0x218c4c
 */
- (void)appListDidDisappear;

/**
 * @brief Notify the delegate of an advert-list load failure and clear the delegate.
 * @param error The load failure error.
 * @ghidraAddress 0x218d24
 */
- (void)appListFailLoadWithError:(nullable NSError *)error;

/**
 * @brief Notify the delegate of an advert-list link failure.
 * @param error The link failure error.
 * @ghidraAddress 0x218e24
 */
- (void)appListFailLinkWithError:(nullable NSError *)error;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
