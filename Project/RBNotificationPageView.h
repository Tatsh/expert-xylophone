/** @file
 * The in-game news / information page overlay presented over the music menu on the pad build. It
 * is an @c RBMusicMenuPopupView subclass (popup type @c RBMusicMenuPopupViewTypeInformation) that
 * @c RBMenuView presents; it hosts an @c RBWebView loading the news web-info URL inside the base
 * popup's content view. As the web view's delegate it intercepts the @c reflecbeat deep links
 * (@c twitter, @c openurl, and the @c rbplus://store pack routes), forwards store navigations to
 * the owning menu, and drives a loading spinner and a network-error alert. On the phone build the
 * sibling @c RBNotificationPagePhoneViewController is pushed instead.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c RBNotificationPageView, image
 * base 0x100000000). @ghidraAddress values are offsets relative to the image base. The class
 * adopts @c UIWebViewDelegate and @c UIAlertViewDelegate (its @c class_ro_t protocol list).
 */

#import <UIKit/UIKit.h>

#import "RBMusicMenuPopupView.h"

@class RBSettingView;
@class RBWebView;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The news / information overlay popup that hosts an @c RBWebView over the music menu.
 */
@interface RBNotificationPageView : RBMusicMenuPopupView <UIWebViewDelegate, UIAlertViewDelegate>

#pragma mark Lifecycle

/**
 * @brief Create the notification page popup, select the information popup type, build its content,
 * and mark it as the first request.
 * @param frame The view's frame rectangle.
 * @return The initialised view, or @c nil.
 * @ghidraAddress 0x1932b8
 */
- (nullable instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief Build the notification page content: consume the pending news web-info URL and the
 * last-update time (recording the read time and clearing them), then add a full-width @c RBWebView
 * loading that URL (or the pre-release fallback) into the base popup's content view.
 * @ghidraAddress 0x19335c
 */
- (void)setupView;

/**
 * @brief Fade the popup out unless a transition is already running.
 * @ghidraAddress 0x193a68
 */
- (void)hideAnimation;

#pragma mark Store navigation

/**
 * @brief Handle a store deep link: stamp the pack identifier for the store, ask the owning menu to
 * open the store, and dismiss the popup.
 * @param packID The pack identifier to open in the store; ignored when @c nil or non-positive.
 * @ghidraAddress 0x193918
 */
- (void)moveStore:(nullable id)packID;

#pragma mark Orientation

/**
 * @brief Whether the receiver may rotate to @p interfaceOrientation; permits the two portrait
 * orientations only.
 * @param interfaceOrientation The candidate interface orientation.
 * @return @c YES for either portrait orientation.
 * @ghidraAddress 0x194138
 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation;

/**
 * @brief The interface orientations the receiver supports: the two landscape orientations.
 * @return The supported orientation mask.
 * @ghidraAddress 0x194148
 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations;

/**
 * @brief Whether the receiver should autorotate; always @c YES.
 * @ghidraAddress 0x194150
 */
- (BOOL)shouldAutorotate;

#pragma mark Properties

/** @brief The web view rendering the news / information page. */
@property(assign, nonatomic, nullable) RBWebView *notificationPage;
/** @brief Whether this is the first request, gating the alert-driven dismiss. */
@property(assign, nonatomic) BOOL isFirstRequest;
/** @brief The pending news web-info URL consumed by @c setupView. */
@property(strong, nonatomic, nullable) NSURL *requestURL;
/** @brief The settings view that owns and presents this popup, held weakly. */
@property(weak, nonatomic, nullable) RBSettingView *settingView;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
