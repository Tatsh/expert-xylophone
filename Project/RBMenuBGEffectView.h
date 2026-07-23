/** @file
 * Animated rainbow-and-particle background effect container view. It builds a stack of rainbow
 * (@c "00_texture/re_NN") and ring (@c "00_texture/ring_NN") @c UIImageView layers, hosts a pool of
 * @c RBMenuBGEffectPartView particle layers, and drives them with staggered, infinitely repeating
 * Core Animation keyframe animations. Concrete subclasses (for example
 * @c RBResoureDownloadBGEffectView) seed the inherited image base paths and populate @c effList
 * with their own particle layers.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c RBMenuBGEffectView, image base
 * 0x100000000).
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class RBMenuBGEffectPartView;

/**
 * @brief Animated rainbow-and-particle background container view.
 *
 * @c initWithFrame: seeds @c EFFECT_NUM, the two empty collections, and the two texture base paths.
 * @c setupView lays out the rainbow and ring image layers and spawns the particle layers;
 * @c startAnimation and @c stopAnimation drive the whole ensemble.
 */
@interface RBMenuBGEffectView : UIView

/**
 * @brief The @c UIImageView layers whose opacity and position are keyframe animated.
 *
 * Populated by @c setupRainbow with the three rainbow and four ring images, in that order.
 */
@property(strong, nonatomic, nullable) NSMutableArray *animImageList; // +0x28
/** @brief The base name of the rainbow (bow) artwork, without its @c "%02d" index suffix. */
@property(strong, nonatomic, nullable) NSString *rainbowImageBasePath; // +0x10
/** @brief The base name of the ring artwork, without its @c "%02d" index suffix. */
@property(strong, nonatomic, nullable) NSString *ringImageBasePath; // +0x18
/** @brief The number of @c RBMenuBGEffectPartView particle layers this background hosts. */
@property(assign, nonatomic) int EFFECT_NUM; // +0x08
/** @brief The live @c RBMenuBGEffectPartView particle layers attached to this background. */
@property(strong, nonatomic, nullable) NSMutableArray *effList; // +0x20

/**
 * @brief Build the rainbow and ring image layers from @c rainbowImageBasePath and
 * @c ringImageBasePath and add them to @c animImageList.
 * @ghidraAddress 0xe88c8
 */
- (void)setupRainbow;
/**
 * @brief Create and attach one @c RBMenuBGEffectPartView per @c EFFECT_NUM slot.
 * @ghidraAddress 0xe8ccc
 */
- (void)setupParticle;
/**
 * @brief Build the background effect layers by chaining @c setupRainbow then @c setupParticle.
 * @ghidraAddress 0xe7288
 */
- (void)setupView;
/**
 * @brief Attach a keyframe animation to one image layer.
 * @param view The @c UIImageView layer to animate.
 * @param type The animation variant: 1-3 select an opacity flash pattern, 4-7 a bottom-to-top
 * ring sweep whose start position and stagger derive from @c type.
 * @ghidraAddress 0xe72bc
 */
- (void)createAnimation:(UIView *)view type:(int)type;
/**
 * @brief Start every particle layer and attach the rainbow and ring keyframe animations.
 * @ghidraAddress 0xe8404
 */
- (void)startAnimation;
/**
 * @brief Stop every particle layer and remove all attached image-layer animations.
 * @ghidraAddress 0xe8614
 */
- (void)stopAnimation;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
