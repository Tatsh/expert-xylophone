/** @file
 * The pad-layout pack detail panel shown over the dimming cover. This is a minimal stub declaring
 * only the surface @c RBStorePageViewController relies on; the full view class is reconstructed
 * separately.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c StorePackDetailViewPad, image
 * base 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

#import "StorePackView.h"

@class StorePackInfo;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The pad-layout pack detail panel.
 */
@interface StorePackDetailViewPad : UIView

/**
 * @brief The delegate that drives the panel's purchase and download actions.
 */
@property(nonatomic, weak, nullable) id<StorePackViewDelegate> delegate;

/**
 * @brief The pack the panel currently displays.
 */
@property(nonatomic, strong, nullable) StorePackInfo *packInfo;

/**
 * @brief Load and display the given pack's detail.
 */
- (void)loadInfo;

/**
 * @brief Cancel any in-flight detail load.
 */
- (void)cancelLoading;

/**
 * @brief Stop the panel's sample playback.
 */
- (void)stopSample;

/**
 * @brief Clear the displayed pack.
 */
- (void)removePackInfo;

/**
 * @brief Set the purchase button label to the installing state.
 */
- (void)setButtonTextInstalling;

/**
 * @brief Set the purchase button label to the installed state.
 */
- (void)setButtonTextInstalled;

/**
 * @brief Recompute the purchase button label from the current ownership and download state.
 */
- (void)selfCheckButtonText;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
