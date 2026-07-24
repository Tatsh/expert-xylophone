/** @file
 * A @c UIAlertController subclass that pins its rotation to a caller-supplied orientation mask.
 * The erosion-mark score-correction dialog uses it so the alert honours the same
 * layout-dependent rotation rules the rest of the application enforces: the plain (phone) layout
 * allows every orientation, while the wide (iPad) layout is constrained to the portrait
 * orientations.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class RBErosionMarkUpdaterAlertController,
 * image base 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Orientation-locking @c UIAlertController used by the erosion-mark score updater.
 */
@interface RBErosionMarkUpdaterAlertController : UIAlertController

/**
 * @brief The interface orientations this alert reports as supported.
 *
 * Backed by the @c _orientationMask ivar. Seeded by @c -init from the current layout, or set
 * explicitly through @c -initWithOrientationMask: .
 */
@property(nonatomic) UIInterfaceOrientationMask orientationMask;

/**
 * @brief Initialise the alert with an orientation mask chosen from the current layout.
 * @return The initialised alert, or @c nil if the superclass initialiser failed.
 * @discussion The plain (phone) layout seeds @c orientationMask with
 * @c UIInterfaceOrientationMaskAll; the wide (iPad) layout seeds it with the portrait orientations
 * (@c UIInterfaceOrientationMaskPortrait | @c UIInterfaceOrientationMaskPortraitUpsideDown).
 * @ghidraAddress 0x142a00
 */
- (nullable instancetype)init;

/**
 * @brief Initialise the alert with an explicit orientation mask.
 * @param orientationMask The interface orientations the alert should report as supported.
 * @return The initialised alert, or @c nil if the superclass initialiser failed.
 * @ghidraAddress 0x142a98
 */
- (nullable instancetype)initWithOrientationMask:(UIInterfaceOrientationMask)orientationMask;

/**
 * @brief Report the interface orientations this alert supports.
 * @return The value of @c orientationMask.
 * @ghidraAddress 0x142b1c
 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
