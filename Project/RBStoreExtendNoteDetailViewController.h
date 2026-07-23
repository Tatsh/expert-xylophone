/** @file
 * The phone extend-note detail view controller, pushed onto the store navigation stack to present
 * a single extend note's detail, sample, and purchase controls.
 *
 * Minimal interface; the full class is reconstructed separately.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class
 * @c RBStoreExtendNoteDetailViewController, image base 0x100000000). @ghidraAddress values are
 * offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

#import "RBBaseViewController.h"

@class StoreExtendNoteInfo;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The phone extend-note detail view controller.
 */
@interface RBStoreExtendNoteDetailViewController : RBBaseViewController

/**
 * @brief The delegate that receives detail-view actions.
 */
@property(nonatomic, weak, nullable) id delegate;

/**
 * @brief Loads the given extend-note record into the detail view.
 * @param info The extend-note record to display.
 */
- (void)setInfo:(nullable StoreExtendNoteInfo *)info;
/**
 * @brief Sets the action button to its "installing" state.
 */
- (void)setButtonTextInstalling;
/**
 * @brief Sets the action button to its "installed" state.
 */
- (void)setButtonTextInstalled;
/**
 * @brief Refreshes the action button text from the current note's ownership state.
 */
- (void)selfCheckButtonText;
/**
 * @brief Sets the displayed purchase state of the detail cell.
 * @param state The purchase state to display.
 */
- (void)setPurchaseState:(NSInteger)state;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
