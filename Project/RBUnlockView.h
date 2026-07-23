/** @file
 * The experience/unlock item picker hosted by @c RBCustomView on the themed layouts. It presents
 * the unlockable experience items and requests their data when shown.
 *
 * Speculative interface: only the members @c RBCustomView uses are declared here. Reconstructed
 * from Ghidra project rb458, program rb458 (class @c RBUnlockView, image base 0x100000000).
 */

#import <UIKit/UIKit.h>

@class RBCustomView;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Experience/unlock item picker view.
 */
@interface RBUnlockView : UIView

/**
 * @brief Request the picker's item data.
 */
- (void)request;

/**
 * @brief The customize popup that owns this picker.
 */
@property(weak, nonatomic, nullable) RBCustomView *parentView;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
