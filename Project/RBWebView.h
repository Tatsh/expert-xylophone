/** @file
 * A @c UIWebView subclass used to present remote HTML content (news, store, and campaign pages)
 * inside the game. It owns a translucent "gray" cover view and a centred activity indicator that
 * are shown while a page is loading, and it acts as its own delegate so it can drive those loading
 * affordances and enforce a small allow-list of navigation hosts.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class RBWebView, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A self-delegating @c UIWebView that shows a loading cover and indicator and filters
 * navigations.
 *
 * On construction the view builds a translucent @c grayView cover and a scaled, centred
 * @c indicatorView activity indicator, sets itself as the web-view delegate, disables data
 * detectors, suppresses the iOS touch callout, and seeds @c urlList with the recognised
 * @c reflecbeat scheme host keywords (@c link, @c store, @c openurl, and @c twitter).
 *
 * While a request loads it optionally reveals @c grayView (when @c useGrayView is set) and animates
 * @c indicatorView; on completion or failure it hides them and forwards the corresponding delegate
 * callback to @c parentView when that object responds to it.
 */
@interface RBWebView : UIWebView <UIWebViewDelegate>

/**
 * @brief Create the web view with the given frame and parent view.
 *
 * Calls through to @c super, then builds the loading cover and indicator, configures the web-view
 * delegate and content settings, records @p superView as the (weak) @c parentView, and seeds the
 * navigation host allow-list.
 * @param frame The view's frame rectangle.
 * @param superView The object notified of load completion and failure, held weakly. May be @c nil.
 * @return The initialised view, or @c nil.
 * @ghidraAddress 0x72af8
 */
- (nullable instancetype)initWithFrame:(CGRect)frame superView:(nullable id)superView;

/**
 * @brief Enable or disable the translucent loading cover.
 *
 * Convenience forwarder to @c setIsUseGrayView:.
 * @param useGrayView @c YES to show @c grayView while a page loads.
 * @ghidraAddress 0x72ff0
 */
- (void)setUseGrayView:(BOOL)useGrayView;

/**
 * @brief Stamp the outgoing request with the device description as its @c User-Agent header.
 *
 * A @c WebResourceLoadDelegate hook: returns @p willSendRequest after setting the @c User-Agent
 * HTTP header field to the shared device description string.
 * @param uiWebView The web view issuing the request (unused).
 * @param resource The resource identifier (unused).
 * @param willSendRequest The request about to be sent.
 * @param redirectResponse The redirect response, if any (unused).
 * @param fromDataSource The originating data source (unused).
 * @return The (mutated) request to send.
 * @ghidraAddress 0x72ffc
 */
- (nullable id)uiWebView:(nullable id)uiWebView
                resource:(nullable id)resource
         willSendRequest:(nullable id)willSendRequest
        redirectResponse:(nullable id)redirectResponse
          fromDataSource:(nullable id)fromDataSource;

/**
 * @brief The view notified of load completion and failure, held weakly.
 */
@property(weak, nonatomic, nullable) id parentView;

/**
 * @brief The translucent cover shown over the content while a page loads.
 */
@property(strong, nonatomic, nullable) UIView *grayView;

/**
 * @brief The centred activity indicator animated while a page loads.
 */
@property(strong, nonatomic, nullable) UIActivityIndicatorView *indicatorView;

/**
 * @brief Whether @c grayView is revealed while a page loads.
 */
@property(nonatomic, getter=isUseGrayView) BOOL isUseGrayView;

/**
 * @brief The recognised @c reflecbeat scheme host keywords, in priority order
 * (@c link, @c store, @c openurl, and @c twitter).
 */
@property(strong, nonatomic, nullable) NSMutableArray *urlList;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
