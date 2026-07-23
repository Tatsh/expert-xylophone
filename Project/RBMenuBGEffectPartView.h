/** @file
 * Base class for a single animated particle layer of an @c RBMenuBGEffectView background. Concrete
 * subclasses (for example @c RBResourceDownloadBGEffectPartView) seed the three artwork paths.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c RBMenuBGEffectPartView, image
 * base 0x100000000). Only the binary-verified surface used by @c RBResoureDownloadBGEffectView is
 * declared here; the remaining members await a full reconstruction of this class.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A single animated particle layer of a background effect.
 */
@interface RBMenuBGEffectPartView : UIView

/** @brief Build the particle's layers for the current bounds. */
- (void)setupView;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
