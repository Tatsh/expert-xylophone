//
//  RBAnimationFactory.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RBAnimationFactory). Verified
//  against the arm64 disassembly: every entry point is a class method, the decompiler drops the
//  variadic arrayWithObjects: element lists (recovered from the stacked register stores), the fade
//  and scale builders use linear timing while the key-path and bound builders use ease-in and the
//  bob builder uses ease-out, and createPositionYAnimWithFromValue: animates the position.x key
//  path exactly as the shipped binary does.
//

#import "RBAnimationFactory.h"

// The layer key paths the factory animates.
static NSString *const kPositionXKeyPath = @"position.x";
static NSString *const kPositionYKeyPath = @"position.y";
static NSString *const kOpacityKeyPath = @"opacity";
static NSString *const kTransformScaleKeyPath = @"transform.scale";
static NSString *const kTransformScaleXKeyPath = @"transform.scale.x";
static NSString *const kTransformScaleYKeyPath = @"transform.scale.y";

// The endpoints of a normalised two-keyframe timeline.
static const double kKeyTimeStart = 0.0;
static const double kKeyTimeEnd = 1.0;

// The repeat count applied to the one-shot builders.
static const float kNoRepeat = 0.0f;

// The vertical overshoot, in points, of the stay-in-place bob.
static const double kBobOvershoot = 10.0;
// The fraction of the bob's duration at which it reaches its peak.
static const double kBobPeakTimeFraction = 0.3;

// The scale keyframes of the bounce: overshoot high, dip low, overshoot again, then settle.
static const float kBounceRestScale = 1.0f;
static const float kBounceOvershootScale = 1.1f;
static const float kBounceUndershootScale = 0.9f;
static const float kBounceSettleScale = 1.05f;

// The normalised key times of the bounce keyframes.
static const float kBounceKeyTimeStart = 0.0f;
static const float kBounceKeyTimeOvershoot = 0.3f;
static const float kBounceKeyTimeUndershoot = 0.6f;
static const float kBounceKeyTimeSettle = 0.8f;
static const float kBounceKeyTimeEnd = 1.0f;

@implementation RBAnimationFactory

+ (CAKeyframeAnimation *)createAnimWithKeyPath:(NSString *)keyPath
                                     fromValue:(double)fromValue
                                       toValue:(double)toValue
                                         delay:(double)delay
                                      duration:(double)duration {
    CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:keyPath];
    animation.beginTime = delay;
    animation.duration = duration;
    animation.repeatCount = kNoRepeat;
    animation.values = @[@(fromValue), @(toValue)];
    animation.keyTimes = @[@(kKeyTimeStart), @(kKeyTimeEnd)];
    CAMediaTimingFunction *easeIn =
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];
    animation.timingFunctions = @[easeIn, easeIn];
    animation.removedOnCompletion = NO;
    animation.fillMode = kCAFillModeForwards;
    return animation;
}

+ (CAKeyframeAnimation *)createFadeAnimWithFromValue:(double)fromValue
                                             toValue:(double)toValue
                                               delay:(double)delay
                                            duration:(double)duration {
    CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:kOpacityKeyPath];
    animation.beginTime = delay;
    animation.duration = duration;
    animation.repeatCount = kNoRepeat;
    animation.values = @[@(fromValue), @(toValue)];
    animation.keyTimes = @[@((float)kKeyTimeStart), @((float)kKeyTimeEnd)];
    CAMediaTimingFunction *linear =
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    animation.timingFunctions = @[linear, linear];
    animation.removedOnCompletion = NO;
    animation.fillMode = kCAFillModeForwards;
    return animation;
}

+ (CAKeyframeAnimation *)createPositionXAnimWithFromValue:(double)fromValue
                                                  toValue:(double)toValue
                                                    delay:(double)delay
                                                 duration:(double)duration {
    return [self createAnimWithKeyPath:kPositionXKeyPath
                             fromValue:fromValue
                               toValue:toValue
                                 delay:delay
                              duration:duration];
}

+ (CAKeyframeAnimation *)createPositionYAnimWithFromValue:(double)fromValue
                                                  toValue:(double)toValue
                                                    delay:(double)delay
                                                 duration:(double)duration {
    return [self createAnimWithKeyPath:kPositionXKeyPath
                             fromValue:fromValue
                               toValue:toValue
                                 delay:delay
                              duration:duration];
}

+ (CAAnimationGroup *)createPositionAnimWithFromValue:(CGPoint)fromValue
                                             toValue:(CGPoint)toValue
                                               delay:(double)delay
                                            duration:(double)duration {
    CAKeyframeAnimation *xAnimation = [self createAnimWithKeyPath:kPositionXKeyPath
                                                        fromValue:fromValue.x
                                                          toValue:toValue.x
                                                            delay:delay
                                                         duration:duration];
    CAKeyframeAnimation *yAnimation = [self createAnimWithKeyPath:kPositionYKeyPath
                                                        fromValue:fromValue.y
                                                          toValue:toValue.y
                                                            delay:delay
                                                         duration:duration];
    CAAnimationGroup *group = [CAAnimationGroup animation];
    group.animations = @[xAnimation, yAnimation];
    group.removedOnCompletion = NO;
    group.fillMode = kCAFillModeForwards;
    return group;
}

+ (CAKeyframeAnimation *)createScaleAnimWithFromValue:(double)fromValue
                                             toValue:(double)toValue
                                                   X:(BOOL)X
                                                   Y:(BOOL)Y
                                               delay:(double)delay
                                            duration:(double)duration {
    NSString *keyPath = nil;
    if (X && Y) {
        keyPath = kTransformScaleKeyPath;
    } else if (X) {
        keyPath = kTransformScaleXKeyPath;
    } else if (Y) {
        keyPath = kTransformScaleYKeyPath;
    } else {
        return nil;
    }
    CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:keyPath];
    animation.beginTime = delay;
    animation.duration = duration;
    animation.repeatCount = kNoRepeat;
    animation.values = @[@(fromValue), @(toValue)];
    animation.keyTimes = @[@((float)kKeyTimeStart), @((float)kKeyTimeEnd)];
    CAMediaTimingFunction *linear =
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    animation.timingFunctions = @[linear, linear];
    animation.removedOnCompletion = NO;
    animation.fillMode = kCAFillModeForwards;
    return animation;
}

+ (CAKeyframeAnimation *)createAnimHereWithDuration:(double)duration
                                                  Y:(double)Y
                                        repeatCount:(int)repeatCount {
    CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:kPositionYKeyPath];
    animation.duration = duration;
    animation.repeatCount = (float)repeatCount;
    animation.values = @[@(Y + kBobOvershoot), @(Y), @(Y + kBobOvershoot)];
    animation.keyTimes = @[@((float)kKeyTimeStart),
                           @(duration * kBobPeakTimeFraction),
                           @(duration)];
    CAMediaTimingFunction *easeOut =
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    animation.timingFunctions = @[easeOut, easeOut, easeOut];
    return animation;
}

+ (CAKeyframeAnimation *)createBoundAnimWithX:(BOOL)X
                                           Y:(BOOL)Y
                                       delay:(double)delay
                                    duration:(double)duration {
    NSString *keyPath = nil;
    if (X && Y) {
        keyPath = kTransformScaleKeyPath;
    } else if (X) {
        keyPath = kTransformScaleXKeyPath;
    } else if (Y) {
        keyPath = kTransformScaleYKeyPath;
    } else {
        return nil;
    }
    CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:keyPath];
    animation.beginTime = delay;
    animation.duration = duration;
    animation.repeatCount = kNoRepeat;
    animation.values = @[@(kBounceRestScale),
                         @(kBounceOvershootScale),
                         @(kBounceUndershootScale),
                         @(kBounceSettleScale),
                         @(kBounceRestScale)];
    animation.keyTimes = @[@(kBounceKeyTimeStart),
                           @(kBounceKeyTimeOvershoot),
                           @(kBounceKeyTimeUndershoot),
                           @(kBounceKeyTimeSettle),
                           @(kBounceKeyTimeEnd)];
    CAMediaTimingFunction *easeIn =
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];
    animation.timingFunctions = @[easeIn, easeIn, easeIn, easeIn, easeIn];
    animation.removedOnCompletion = NO;
    animation.fillMode = kCAFillModeForwards;
    return animation;
}

+ (void)animationDelete:(CALayer *)layer {
    if (layer.animationKeys.count == 0) {
        return;
    }
    for (CALayer *sublayer in layer.sublayers) {
        [sublayer removeAllAnimations];
    }
    [layer removeAllAnimations];
}

@end
