/** @file
 * Minimal reconstructed interface for the Applilink recommend SDK's @c RecommendWebView.
 *
 * The Applilink SDK ships as a closed third-party library. @c RecommendNetwork only needs the
 * class itself, for @c isKindOfClass: subview matching. Reconstructed from Ghidra project rb458,
 * program rb458.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The Applilink recommend advert web view.
 */
@interface RecommendWebView : UIView
@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
