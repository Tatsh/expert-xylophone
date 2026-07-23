/** @file
 * Base class for the animated rainbow-and-particle background effects. Concrete subclasses (for
 * example @c RBResoureDownloadBGEffectView) seed the image base paths and populate @c effList with
 * their particle layers.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c RBMenuBGEffectView, image base
 * 0x100000000). Only the binary-verified public surface used by
 * @c RBResoureDownloadBGEffectView is declared here; the remaining methods await a full
 * reconstruction of this class.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Animated rainbow-and-particle background base view.
 */
@interface RBMenuBGEffectView : UIView

/** @brief The animation frames driving the rainbow layer. */
@property(strong, nonatomic, nullable) NSMutableArray *animImageList; // +0x8
/** @brief The base name of the rainbow (bow) artwork, without its index suffix. */
@property(strong, nonatomic, nullable) NSString *rainbowImageBasePath; // +0x10
/** @brief The base name of the ring artwork, without its index suffix. */
@property(strong, nonatomic, nullable) NSString *ringImageBasePath; // +0x18
/** @brief The number of particle effect slots this background hosts. */
@property(assign, nonatomic) int EFFECT_NUM; // +0x20
/** @brief The live particle layers attached to this background. */
@property(strong, nonatomic, nullable) NSMutableArray *effList; // +0x28

/** @brief Build the rainbow layer from @c rainbowImageBasePath and @c ringImageBasePath. */
- (void)setupRainbow;
/** @brief Build the background effect layers. */
- (void)setupView;
/** @brief Start the background animation. */
- (void)startAnimation;
/** @brief Stop the background animation. */
- (void)stopAnimation;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
