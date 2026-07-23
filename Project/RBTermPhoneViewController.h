/** @file
 * The phone-layout terms-of-use view controller, pushed from the pack detail table's terms row.
 * This is a minimal stub declaring only the surface @c RBStoreDetailViewController relies on; the
 * full controller is reconstructed separately.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c RBTermPhoneViewController, image
 * base 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The phone-layout terms-of-use view controller.
 */
@interface RBTermPhoneViewController : UIViewController

/**
 * @brief Configure the controller to present the store's terms of use.
 */
- (void)setViewTypeStore;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
