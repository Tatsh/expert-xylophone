/** @file
 * Minimal reconstructed interface for the Applilink recommend SDK's @c RecommendAdAreaView.
 *
 * The Applilink SDK ships as a closed third-party library. @c RecommendNetwork needs the class for
 * @c isKindOfClass: subview matching and the @c closeAdArea teardown message. Reconstructed from
 * Ghidra project rb458, program rb458.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The Applilink recommend advert area view.
 */
@interface RecommendAdAreaView : UIView

/**
 * @brief Tear down the advert area before the view is removed from its superview.
 */
- (void)closeAdArea;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
