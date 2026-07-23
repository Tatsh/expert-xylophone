#import "RBMenuBGEffectView.h"

#include <iterator>

#import <QuartzCore/QuartzCore.h>

#import "RBMenuBGEffectPartView.h"
#import "UIImage+RB.h"

// The default particle-layer count seeded by @c initWithFrame:.
static const int kDefaultEffectNum = 50;

// The layout mask that keeps every layer stretched to the container's bounds
// (@c UIViewAutoresizingFlexibleWidth | @c UIViewAutoresizingFlexibleHeight).
static const UIViewAutoresizing kEffectAutoresizingMask =
    UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

// The rainbow and ring artwork base names; each is completed with a @c "%02d" one-based index.
static NSString *const kRainbowImageBasePath = @"00_texture/re_";
static NSString *const kRingImageBasePath = @"00_texture/ring_";
static NSString *const kImageNameFormat = @"%@%02d";

// Core Animation keys and key paths.
static NSString *const kRainbowAnimationKey = @"rainbowanimation";
static NSString *const kRingAnimationKey = @"ringanimation";
static NSString *const kOpacityKeyPath = @"opacity";
static NSString *const kPositionKeyPath = @"position";

// The rainbow layers are the first three entries of @c animImageList, the ring layers the next
// four.
static const int kRainbowImageCount = 3;
static const int kRingImageCount = 4;

// Animation durations, in seconds.
static const CFTimeInterval kOpacityAnimationDuration = 15.0;
static const CFTimeInterval kRingAnimationDuration = 20.0;
// The per-ring start delay, in seconds, applied as @c (type - kRingTypeBase) * kRingBeginStep.
static const CFTimeInterval kRingBeginStep = 5.5;

// @c createAnimation:type: dispatches on these ranges: 1-3 flash opacity, 4-7 sweep a ring upward.
enum {
    kOpacityTypeMax = 3,
    kRingTypeBase = 4,
    kRingTypeMax = 7,
};

// The nine opacity key frames for each flash variant.
static const float kOpacityValuesType1[] = {0, 1, 1, 1, 1, 0, 0, 0, 0};
static const float kOpacityValuesType2[] = {0, 0, 0, 1, 1, 1, 1, 0, 0};
static const float kOpacityValuesType3[] = {1, 0, 0, 0, 0, 1, 1, 1, 1};
// The shared key times for the opacity flash.
static const float kOpacityKeyTimes[] = {0.0f, 0.05f, 0.25f, 0.3f, 0.5f, 0.55f, 0.75f, 0.8f, 1.0f};

// The ring sweep starts at these bottom positions and rises to @c kRingEndY at the same x.
static const CGPoint kRingStartPoints[] = {
    {250, 1400},
    {600, 1400},
    {200, 1400},
    {450, 1400},
};
static const CGFloat kRingEndY = 0.0;
// The two-frame ring sweep key times.
static const float kRingKeyTimes[] = {0.0f, 1.0f};

// The origins of the three rainbow layers; each layer is sized from its own image.
static const CGPoint kRainbowOrigins[] = {
    {0, 696},
    {0, 200},
    {0, 0},
};

@implementation RBMenuBGEffectView

#pragma mark - Lifecycle

/** @ghidraAddress 0xe7104 */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.EFFECT_NUM = kDefaultEffectNum;
        self.autoresizingMask = kEffectAutoresizingMask;
        self.effList = [[NSMutableArray alloc] init];
        self.animImageList = [[NSMutableArray alloc] init];
        self.rainbowImageBasePath = kRainbowImageBasePath;
        self.ringImageBasePath = kRingImageBasePath;
    }
    return self;
}

/** @ghidraAddress 0xe8894 */
- (void)removeFromSuperview {
    [super removeFromSuperview];
}

#pragma mark - Layout

/** @ghidraAddress 0xe7288 */
- (void)setupView {
    [self setupRainbow];
    [self setupParticle];
}

/** @ghidraAddress 0xe88c8 */
- (void)setupRainbow {
    for (int i = 0; i < kRainbowImageCount; ++i) {
        NSString *name =
            [NSString stringWithFormat:kImageNameFormat, self.rainbowImageBasePath, i + 1];
        UIImage *image = [UIImage imageWithName:name];
        UIImageView *layer = [[UIImageView alloc] initWithImage:image];
        layer.frame = CGRectMake(
            kRainbowOrigins[i].x, kRainbowOrigins[i].y, image.size.width, image.size.height);
        layer.autoresizingMask = kEffectAutoresizingMask;
        [self addSubview:layer];
        [self.animImageList addObject:layer];
    }

    for (int i = 0; i < kRingImageCount; ++i) {
        NSString *name =
            [NSString stringWithFormat:kImageNameFormat, self.ringImageBasePath, i + 1];
        UIImage *image = [UIImage imageWithName:name];
        UIImageView *layer = [[UIImageView alloc] initWithImage:image];
        layer.frame = CGRectMake(
            kRingStartPoints[i].x, kRingStartPoints[i].y, image.size.width, image.size.height);
        layer.autoresizingMask = kEffectAutoresizingMask;
        [self addSubview:layer];
        [self.animImageList addObject:layer];
    }
}

/** @ghidraAddress 0xe8ccc */
- (void)setupParticle {
    for (int i = 0; i < self.EFFECT_NUM; ++i) {
        RBMenuBGEffectPartView *part = [[RBMenuBGEffectPartView alloc] init];
        [part setupView];
        [self.effList addObject:part];
        [self addSubview:part];
    }
}

#pragma mark - Animation

/** @ghidraAddress 0xe8404 */
- (void)startAnimation {
    for (int i = 0; i < self.EFFECT_NUM; ++i) {
        RBMenuBGEffectPartView *part = self.effList[i];
        if (part) {
            [part startAnimation];
        }
    }

    for (int i = 0; i < kRainbowImageCount; ++i) {
        [self createAnimation:self.animImageList[i] type:i + 1];
    }
    for (int i = 0; i < kRingImageCount; ++i) {
        int index = kRainbowImageCount + i;
        [self createAnimation:self.animImageList[index] type:index + 1];
    }
}

/** @ghidraAddress 0xe8614 */
- (void)stopAnimation {
    for (int i = 0; i < self.EFFECT_NUM; ++i) {
        RBMenuBGEffectPartView *part = self.effList[i];
        if (part) {
            [part stopAnimation];
            [part setAnimationLoopFlag:NO];
        }
    }

    for (UIImageView *layer in self.animImageList) {
        [layer.layer removeAllAnimations];
    }
    [self.layer removeAllAnimations];
}

/** @ghidraAddress 0xe72bc */
- (void)createAnimation:(UIView *)view type:(int)type {
    // The binary always builds and configures this opacity animation up front, then discards it
    // unused for the ring types below.
    CAKeyframeAnimation *opacity = [CAKeyframeAnimation animationWithKeyPath:kOpacityKeyPath];
    opacity.duration = kOpacityAnimationDuration;
    opacity.repeatCount = HUGE_VALF;

    if (type <= kOpacityTypeMax) {
        static_cast<void>(view.frame); // Yes, the binary fetches and discards the layer frame here.

        const float *values = nullptr;
        if (type == 1) {
            values = kOpacityValuesType1;
        } else if (type == 2) {
            values = kOpacityValuesType2;
        } else if (type == kOpacityTypeMax) {
            values = kOpacityValuesType3;
        }

        if (values) {
            NSMutableArray *valueArray = [NSMutableArray array];
            for (size_t i = 0; i < std::size(kOpacityValuesType1); ++i) {
                [valueArray addObject:@(values[i])];
            }
            opacity.values = valueArray;
        }

        NSMutableArray *keyTimes = [NSMutableArray array];
        NSMutableArray *timingFunctions = [NSMutableArray array];
        CAMediaTimingFunction *linear =
            [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
        for (size_t i = 0; i < std::size(kOpacityKeyTimes); ++i) {
            [keyTimes addObject:@(kOpacityKeyTimes[i])];
            [timingFunctions addObject:linear];
        }
        opacity.keyTimes = keyTimes;
        opacity.timingFunctions = timingFunctions;

        [view.layer addAnimation:opacity forKey:kRainbowAnimationKey];
    } else if (type <= kRingTypeMax) {
        static_cast<void>(view.frame); // Yes, the binary fetches and discards the layer frame here.

        int ringIndex = type - kRingTypeBase;
        CGPoint start = kRingStartPoints[ringIndex];
        CGPoint end = CGPointMake(start.x, kRingEndY);

        CAKeyframeAnimation *position = [CAKeyframeAnimation animationWithKeyPath:kPositionKeyPath];
        position.duration = kRingAnimationDuration;
        position.repeatCount = HUGE_VALF;
        position.beginTime = ringIndex * kRingBeginStep;

        position.values = @[ [NSValue valueWithCGPoint:start], [NSValue valueWithCGPoint:end] ];

        NSMutableArray *keyTimes = [NSMutableArray array];
        NSMutableArray *timingFunctions = [NSMutableArray array];
        CAMediaTimingFunction *linear =
            [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
        for (size_t i = 0; i < std::size(kRingKeyTimes); ++i) {
            [keyTimes addObject:@(kRingKeyTimes[i])];
            [timingFunctions addObject:linear];
        }
        position.keyTimes = keyTimes;
        position.timingFunctions = timingFunctions;

        [view.layer addAnimation:position forKey:kRingAnimationKey];
    }
}

@end
