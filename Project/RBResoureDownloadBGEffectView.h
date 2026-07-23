/** @file
 * The animated background-effect view shown behind the resource-download flow for the wide
 * iPad idiom. @c RBResourceDownloadViewController creates one, calls @c setupView to build its
 * rainbow and particle layers, and drives it with @c startAnimation and @c stopAnimation (both
 * inherited from @c RBMenuBGEffectView).
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class
 * @c RBResoureDownloadBGEffectView, image base 0x100000000; the "Resoure" misspelling is the
 * binary's own).
 */

#import "RBMenuBGEffectView.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Animated rainbow-and-particle background for the resource-download screen.
 *
 * A concrete @c RBMenuBGEffectView that seeds the inherited rainbow and ring image base paths,
 * then populates the effect with @c RBResourceDownloadBGEffectPartView particle layers.
 */
@interface RBResoureDownloadBGEffectView : RBMenuBGEffectView

/**
 * @brief Build the rainbow layer and the particle layers for the current bounds.
 * @ghidraAddress 0x19c40
 */
- (void)setupView;
/**
 * @brief Create and attach one @c RBResourceDownloadBGEffectPartView per effect slot.
 * @ghidraAddress 0x19c90
 */
- (void)setupParticle;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
