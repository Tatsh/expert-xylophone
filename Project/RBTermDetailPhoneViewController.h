/** @file
 * The phone-layout terms-of-use detail view controller, pushed from @c RBTermPhoneViewController
 * when a term with a body (rather than an external link) is selected. This is a minimal stub
 * declaring only the surface @c RBTermPhoneViewController relies on; the full controller is
 * reconstructed separately.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c RBTermDetailPhoneViewController,
 * image base 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

#import "RBBaseViewController.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The phone-layout terms-of-use detail view controller.
 */
@interface RBTermDetailPhoneViewController : RBBaseViewController

/**
 * @brief Create the detail controller for the term identified by @p termID with the given title.
 * @param termID The identifier of the term whose body is shown.
 * @param title The title shown in the navigation bar.
 * @return The initialised controller, or @c nil.
 * @ghidraAddress 0x48508
 */
- (nullable instancetype)initWithID:(nullable id)termID title:(nullable id)title;

/**
 * @brief Configure the controller to present the store's terms of use.
 */
- (void)setViewTypeStore;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
