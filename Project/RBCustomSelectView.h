/** @file
 * The customize item picker hosted by @c RBCustomView. It fills the popup content view and lets
 * the player pick the customization to apply.
 *
 * Speculative interface: only the members @c RBCustomView uses are declared here. Reconstructed
 * from Ghidra project rb458, program rb458 (class @c RBCustomSelectView, image base 0x100000000).
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Customize item picker view.
 */
@interface RBCustomSelectView : UIView

/**
 * @brief Reload the picker's item content.
 */
- (void)reloadData;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
