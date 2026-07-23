/** @file
 * The push-notification prompt overlay. It is a @c UIView that slides a themed banner
 * (@c bgView with a two-line @c messageLabel) down from above the top edge of the music-menu
 * screen, auto-hides itself after a delay, and — when tapped — routes the banner's URL through
 * @c RBUrlSchemeManager or hands an @c http URL back to its delegate. @c RBMenuView owns one
 * instance, sets itself as the delegate through @c setupViewWithDelegate:, and shows the next
 * queued notification through @c showNotification.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class RBPushNotificationView, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The push-notification prompt overlay slid down over the music-menu screen.
 *
 * The binary's @c class_ro_t names @c UIView as the superclass and adopts no protocols. The
 * @c delegate is stored as a bare weak @c id (property encoding @c T\@,W): the class dispatches to
 * it dynamically with @c performSelector: (@c actionFromPushNotificationView and
 * @c finishPushNotification), so the binary defines no formal delegate protocol.
 */
@interface RBPushNotificationView : UIView

/**
 * @brief The background banner image view that holds the message label and is slid on- and
 * off-screen.
 */
@property(strong, nonatomic, nullable) UIImageView *bgView;

/**
 * @brief The two-line label that shows the notification body text.
 */
@property(strong, nonatomic, nullable) UILabel *messageLabel;

/**
 * @brief The notification body text, taken from the popped notification's @c body entry.
 */
@property(strong, nonatomic, nullable) NSString *message;

/**
 * @brief The notification's target URL, taken from the popped notification's @c url entry.
 */
@property(copy, nonatomic, nullable) NSString *urlString;

/**
 * @brief The one-shot timer that fires @c hideAnimationStart after the auto-hide delay.
 */
@property(strong, nonatomic, nullable) NSTimer *timer;

/**
 * @brief The top inset, in points, applied above the banner (2.0 by default).
 */
@property(assign, nonatomic) float upMargin;

/**
 * @brief The delegate messaged when the banner is tapped or dismissed.
 *
 * Stored weakly and messaged dynamically; @c RBMenuView is the delegate and responds to
 * @c actionFromPushNotificationView and @c finishPushNotification.
 */
@property(weak, nonatomic, nullable) id delegate;

/**
 * @brief Create the banner overlay with the given frame.
 * @param frame The overlay's frame rectangle.
 * @return The initialised view, or @c nil.
 * @ghidraAddress 0x18e3cc
 */
- (nullable instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief Build the banner: the clear background, the notification background image view, the
 * two-line message label sized for the current iPad idiom, the tap recogniser, and the initial
 * off-screen layout, and record the delegate.
 * @param delegate The object to message on tap and dismissal.
 * @ghidraAddress 0x18e400
 */
- (void)setupViewWithDelegate:(nullable id)delegate;

/**
 * @brief Load the next queued notification and slide the banner into view.
 * @ghidraAddress 0x18eac4
 */
- (void)showNotification;

/**
 * @brief Pop the next queued notification from the app delegate, store its body and URL, and set
 * the message label text.
 * @ghidraAddress 0x18eaf8
 */
- (void)setNextNotification;

/**
 * @brief Slide the banner down into place, play the show sound effect, and (on completion) start
 * the auto-hide timer.
 * @ghidraAddress 0x18ec60
 */
- (void)showAnimation;

/**
 * @brief Stop the auto-hide timer and dispatch @c hideAnimation onto the main thread.
 * @ghidraAddress 0x18efa0
 */
- (void)hideAnimationStart;

/**
 * @brief Slide the banner back off-screen above the top edge and, on completion, hide it and tell
 * the delegate that the notification finished.
 * @ghidraAddress 0x18efe4
 */
- (void)hideAnimation;

/**
 * @brief Tap handler: parse the banner URL through @c RBUrlSchemeManager, or hand an @c http URL
 * to the app delegate and the view delegate, then hide the banner.
 * @param sender The tap gesture recogniser.
 * @ghidraAddress 0x18f348
 */
- (void)onTapped:(nullable UITapGestureRecognizer *)sender;

/**
 * @brief Invalidate and clear the auto-hide timer.
 * @ghidraAddress 0x18f6b4
 */
- (void)stopTimer;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
