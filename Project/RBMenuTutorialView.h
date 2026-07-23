/** @file
 * The in-menu tutorial overlay. @c RBCustomView drives it to run the customize and experience
 * tutorials once their pickers are on screen.
 *
 * Speculative interface: only the members the popup views use are declared here. Reconstructed
 * from Ghidra project rb458, program rb458 (class @c RBMenuTutorialView, image base 0x100000000).
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief In-menu tutorial overlay view.
 */
@interface RBMenuTutorialView : UIView

/**
 * @brief Start the tutorial of the given type, highlighting @p rootView.
 * @param type The tutorial type identifier.
 * @param rootView The view the tutorial step points at.
 */
- (void)startTutorialWithType:(NSInteger)type withRootView:(nullable UIView *)rootView;

/**
 * @brief Start the tutorial of the given type, optionally animating its appearance.
 * @param type The tutorial type identifier.
 * @param animation Whether to animate the tutorial in.
 */
- (void)startTutorialWithType:(NSInteger)type withAnimation:(BOOL)animation;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
