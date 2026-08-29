#import <QuartzCore/QuartzCore.h>

#import "UIImageView+RB.h"

static NSString *const kFlashAnimationKey = @"FLUSH_ANIM";
static NSString *const kFlashOpacityKeyPath = @"opacity";

// @ghidraAddress 0x2fefb8 (g_flFlashDefaultDuration)
static const CGFloat kFlashDefaultDuration = 0.333333343;
static const CGFloat kFlashFastDuration = 0.25;

static const CGFloat kFlashFullOpacity = 1.0;
// @ghidraAddress 0x2ec6b4 (g_flFlashMinOpacity)
static const CGFloat kFlashMinOpacity = 0.2;

static const float kFlashTimingControlPoint1X = 0.5f;
static const float kFlashTimingControlPoint1Y = 0.0f;
static const float kFlashTimingControlPoint2X = 0.75f;
// @ghidraAddress 0x2f856c (g_flFlashTimingControlPointX2)
static const float kFlashTimingControlPoint2Y = 0.8f;

@implementation UIImageView (RB)

- (void)SetFlashEffectFast {
    [self SetFlashEffectDuration:kFlashFastDuration Start:kFlashFullOpacity End:kFlashMinOpacity];
}

- (void)StartDefaultFlashEffect {
    /** @ghidraAddress 0x1a3710 */
    [self SetFlashEffectDuration:kFlashDefaultDuration
                           Start:kFlashFullOpacity
                             End:kFlashMinOpacity];
}

- (void)SetFlashEffectDuration:(CGFloat)duration Start:(CGFloat)start End:(CGFloat)end {
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:kFlashOpacityKeyPath];
    animation.duration = duration;
    animation.repeatCount = HUGE_VALF;
    animation.autoreverses = YES;
    animation.fromValue = @(start);
    animation.toValue = @(end);
    animation.timingFunction = [CAMediaTimingFunction
         functionWithControlPoints:
        kFlashTimingControlPoint1X:kFlashTimingControlPoint1Y:kFlashTimingControlPoint2X
                                  :kFlashTimingControlPoint2Y];
    animation.removedOnCompletion = NO;
    [self.layer addAnimation:animation forKey:kFlashAnimationKey];
}

- (void)RemoveFlashEffect {
    [self.layer removeAnimationForKey:kFlashAnimationKey];
}

@end
