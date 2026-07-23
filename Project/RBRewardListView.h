/** @file
 * The reward list hosted by @c RBCustomView. It slides in over the customize picker to show the
 * unlockable rewards and loads its contents on demand.
 *
 * Speculative interface: only the members @c RBCustomView uses are declared here. Reconstructed
 * from Ghidra project rb458, program rb458 (class @c RBRewardListView, image base 0x100000000).
 */

#import <UIKit/UIKit.h>

@class RBCustomView;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Reward list view.
 */
@interface RBRewardListView : UIView

/**
 * @brief Start loading the reward list contents.
 * @ghidraAddress 0x10d824
 */
- (void)loadStart;

/**
 * @brief The customize popup that owns this reward list.
 */
@property(weak, nonatomic, nullable) RBCustomView *parentView;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
