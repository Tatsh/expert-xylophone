/** @file
 * A circular progress overlay drawn over a view while a download runs. It animates in when the
 * operation begins, fills as progress is reported, and animates out when the operation finishes.
 *
 * Speculative interface: only the members @c RBUnlockView uses are declared here. This is the
 * third-party @c DAProgressOverlayView control shipped with the application.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A circular download-progress overlay.
 */
@interface DAProgressOverlayView : UIView

/**
 * @brief Create the overlay with the given frame.
 * @param frame The overlay's frame rectangle.
 * @return The initialised overlay, or @c nil.
 */
- (nullable instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief Animate the overlay in as its operation begins.
 */
- (void)displayOperationWillTriggerAnimation;

/**
 * @brief Animate the overlay out as its operation finishes.
 */
- (void)displayOperationDidFinishAnimating;

/**
 * @brief The reported progress, from @c 0 to @c 1.
 */
@property(assign, nonatomic) CGFloat progress;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
