/** @file
 * Reconstructed interface for the Applilink recommend SDK's @c RecommendWebViewController.
 *
 * @c RecommendWebViewController is the advert-screen web view controller that @c RecommendCore
 * presents. It is a thin subclass of @c RewardWebViewController: it inherits the whole web-view
 * host (the base view, web view, navigation bar, loading indicator, rotation handling, and
 * @c SdkViewDelegate reporting) and only specialises the redirect handling so that advert clicks
 * are routed through @c RecommendCore rather than @c RewardCore. Reconstructed from Ghidra project
 * rb458, program rb458.
 */

#import <UIKit/UIKit.h>

#import "RewardWebViewController.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The Applilink recommend advert-screen web view controller.
 *
 * Adds no public members of its own; it exists to override the load-lifecycle and redirect hooks of
 * @c RewardWebViewController so the recommend advert flow reports to and is driven by
 * @c RecommendCore.
 */
@interface RecommendWebViewController : RewardWebViewController

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
