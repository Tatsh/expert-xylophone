/** @file
 * The terms-of-service agreement popup. It is an @c RBMusicMenuPopupView subclass (popup type
 * @c RBMusicMenuPopupViewTypeTerms) presented at first run and whenever the terms change; it shows
 * the terms body in a scrolling text view, gates the Agree button until the reader scrolls to the
 * bottom, and POSTs the acceptance to the server through @c Downloader.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class RBTermAgreeView, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

#import "RBMusicMenuPopupView.h"

@class Downloader;
@class RBTermAgreeView;
@class RBViewController;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Callbacks sent by @c RBTermAgreeView once the user has accepted the terms.
 *
 * The binary's protocol carries a single, required callback: the view notifies its delegate after
 * the acceptance has been successfully submitted to the server. There is no decline callback — a
 * decline simply dismisses the view.
 */
@protocol RBTermAgreeViewDelegate <NSObject>

/**
 * @brief Sent after the terms acceptance has been submitted to the server and stored.
 *
 * Sent from the main queue by the send-agree completion block once the server has confirmed the
 * acceptance and the accepted terms version has been persisted.
 * @ghidraAddress 0x1c8908
 */
- (void)didFinishedSendAgree;

@end

/**
 * @brief The terms-of-service agreement popup shown at first run or when the terms change.
 *
 * The class adopts @c UIAlertViewDelegate and @c UITextViewDelegate (transcribed from the binary's
 * @c class_ro_t @c baseProtocols list, in order).
 */
@interface RBTermAgreeView : RBMusicMenuPopupView <UIAlertViewDelegate, UITextViewDelegate>

#pragma mark Lifecycle

/**
 * @brief Create the terms popup with the given frame and terms type.
 *
 * Calls through to @c super, selects @c RBMusicMenuPopupViewTypeTerms, allocates the empty
 * @c terms dictionary, records the terms type, and builds all of the popup content through
 * @c setupView.
 * @param frame The view's frame rectangle.
 * @param type The terms type carried in the fetch and agree requests.
 * @return The initialised view, or @c nil.
 * @ghidraAddress 0x1c3d58
 */
- (nullable instancetype)initWithFrame:(CGRect)frame termType:(int)type;

/**
 * @brief Build the popup content: the gradation overlay, the title bar, the scrolling terms text
 * view, the Agree and Cancel buttons, the loading indicator, and the mascot/progress artwork.
 *
 * The geometry depends on the current theme and font variant. The method calls through to @c super
 * and then fetches the terms body through @c loadDetail.
 * @ghidraAddress 0x1c3e7c
 */
- (void)setupView;

#pragma mark Terms flow

/**
 * @brief Populate the terms text view with the fetched body and animate the popup content in.
 * @ghidraAddress 0x1c6c50
 */
- (void)showTermView;

/**
 * @brief Fetch the terms body from the server and, on success, show it through @c showTermView.
 * @ghidraAddress 0x1c7958
 */
- (void)loadDetail;

/**
 * @brief Agree-button handler: disable both buttons and submit the acceptance.
 * @ghidraAddress 0x1c7698
 */
- (void)selectAgree;

/**
 * @brief Cancel-button handler: disable both buttons and dismiss the popup.
 * @ghidraAddress 0x1c7744
 */
- (void)selectDisAgree;

/**
 * @brief POST the terms acceptance (user identity, region, terms type, and terms version) to the
 * server and, on success, persist the accepted version and notify the delegate.
 * @ghidraAddress 0x1c813c
 */
- (void)sendAgree;

#pragma mark Loading indicator

/**
 * @brief Show the optional grey overlay and start the loading indicator.
 * @ghidraAddress 0x1c77f0
 */
- (void)startLoadAnimation;

/**
 * @brief Hide the optional grey overlay and stop the loading indicator.
 * @ghidraAddress 0x1c78a4
 */
- (void)endLoadAnimation;

#pragma mark Properties

/**
 * @brief The terms type carried in the fetch and agree requests.
 */
@property(assign, nonatomic) int type;

/**
 * @brief The view's own load-completion flag, distinct from the superclass @c animating flag.
 *
 * Cleared once a request finishes; the show/hide transitions still drive the inherited
 * @c animating flag.
 */
@property(assign, nonatomic) BOOL isAnimating;

/**
 * @brief Whether @c startLoadAnimation / @c endLoadAnimation also toggle the grey overlay.
 */
@property(assign, nonatomic, getter=isUseGrayView) BOOL useGrayView;

/**
 * @brief The rendered height of the terms text, used to gauge scroll progress.
 */
@property(assign, nonatomic) float termTextViewHeight;

/**
 * @brief The fetched terms payload, keyed by @c "contents" and @c "terms_version".
 */
@property(strong, nonatomic, nullable) NSMutableDictionary *terms;

/**
 * @brief The in-flight terms fetch or agree request.
 */
@property(strong, nonatomic, nullable) Downloader *downloader;

/**
 * @brief The view controller that presents this popup.
 */
@property(weak, nonatomic, nullable) RBViewController *parentViewController;

/**
 * @brief The delegate notified once the acceptance has been submitted.
 */
@property(weak, nonatomic, nullable) id<RBTermAgreeViewDelegate> delegate;

/**
 * @brief The container view that hosts the scrolling terms text view.
 */
@property(assign, nonatomic, nullable) UIView *termView;

/**
 * @brief The scrolling text view that shows the terms body.
 */
@property(assign, nonatomic, nullable) UITextView *termTextView;

/**
 * @brief The grey overlay shown behind the loading indicator.
 */
@property(assign, nonatomic, nullable) UIView *grayView;

/**
 * @brief The loading spinner shown while a request is in flight.
 */
@property(assign, nonatomic, nullable) UIActivityIndicatorView *indicatorView;

/**
 * @brief The Agree button, enabled once the reader scrolls to the bottom.
 */
@property(assign, nonatomic, nullable) UIButton *agreeButton;

/**
 * @brief The Cancel (decline) button.
 */
@property(assign, nonatomic, nullable) UIButton *disAgreeButton;

/**
 * @brief The container view for the animated mascot and the scroll-progress artwork.
 */
@property(assign, nonatomic, nullable) UIView *pastelView;

/**
 * @brief The animated mascot shown while scrolling.
 */
@property(assign, nonatomic, nullable) UIImageView *pastelImageView;

/**
 * @brief The mascot shown once the reader has scrolled to the bottom.
 */
@property(assign, nonatomic, nullable) UIImageView *pastelImageFinishView;

/**
 * @brief The scroll-progress track artwork.
 */
@property(assign, nonatomic, nullable) UIImageView *trackImageView;

/**
 * @brief The scroll-progress fill artwork, clipped to the current scroll fraction.
 */
@property(assign, nonatomic, nullable) UIImageView *progressImageView;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
