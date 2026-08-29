#import <QuartzCore/QuartzCore.h>

#import "RBMacros.h"
#import "UIView+RB.h"

static NSString *const kFlashAnimationKey = @"FLUSH_ANIM";
static NSString *const kAlphaAnimationKey = @"ALPHA_ANIM";
static NSString *const kPopAnimationKey = @"PopAnim";
static NSString *const kOpacityKeyPath = @"opacity";
static NSString *const kRotationKeyPath = @"transform.rotation.z";
static NSString *const kPositionKeyPath = @"position";

// @ghidraAddress 0x301648 (g_flFlashRepeatCountForever)
static const float kFlashRepeatCountForever = FLT_MAX;

static const int kFlashMultiPulseStepCount = 12;

// @ghidraAddress 0x2fefb8 (g_flFlashDefaultDuration)
static const float kFlashDefaultDuration = 0.333333343f;
// @ghidraAddress 0x2ec6b4 (g_flFlashMinOpacity)
static const float kFlashMinOpacity = 0.2f;
static const float kFlashRotatingDuration = 4.0f;
static const float kFlashFullOpacity = 1.0f;

// @ghidraAddress 0x310448 (g_flFlashRotationTwoPi)
static const float kFlashRotationTwoPi = 6.28318548f;

static const float kFlashTimingControlPoint1X = 0.5f;
static const float kFlashTimingControlPoint1Y = 0.0f;
static const float kFlashTimingControlPoint2X = 0.75f;
// @ghidraAddress 0x2f856c (g_flFlashTimingControlPointY2)
static const float kFlashTimingControlPoint2Y = 0.8f;

// @ghidraAddress 0x2f8574 (g_flJumpEffectOvershootOffsetY)
static const float kPopBounceOffsets[] = {-40.0f, -10.0f, -5.0f, -2.0f, 0.0f, 0.0f, 0.0f, 0.0f};

static const CFTimeInterval kPopBounceDuration = 3.0;
static const float kPopBounceTimingControlPoint1X = 0.25f;
// @ghidraAddress 0x2fd000 (g_flPopAnimTimingControlPointY1)
static const float kPopBounceTimingControlPoint1Y = 0.1f;
static const float kPopBounceTimingControlPoint2X = 0.5f;
static const float kPopBounceTimingControlPoint2Y = 0.5f;

@implementation UIView (RB)

#pragma mark - Flash effect

+ (void)setFlashEffectView:(UIView *)view
                  Duration:(float)duration
                     Start:(float)start
                       End:(float)end
                    Rotate:(BOOL)rotate {
    /** @ghidraAddress 0x1a376c */
    [UIView removeFlashEffectView:view];
    if (!rotate) {
        CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:kOpacityKeyPath];
        animation.duration = duration;
        animation.repeatCount = kFlashRepeatCountForever;
        animation.autoreverses = YES;
        animation.fromValue = @(start);
        animation.toValue = @(end);
        animation.timingFunction = [CAMediaTimingFunction
             functionWithControlPoints:
            kFlashTimingControlPoint1X:kFlashTimingControlPoint1Y:kFlashTimingControlPoint2X
                                      :kFlashTimingControlPoint2Y];
        animation.removedOnCompletion = NO;
        [view.layer addAnimation:animation forKey:kFlashAnimationKey];
        return;
    }

    NSMutableArray *animations = [[NSMutableArray alloc] init];
    float stepDuration = duration / kFlashMultiPulseStepCount;
    for (int step = 0; step < kFlashMultiPulseStepCount; ++step) {
        CABasicAnimation *pulse = [CABasicAnimation animationWithKeyPath:kOpacityKeyPath];
        pulse.beginTime = stepDuration * step;
        pulse.duration = stepDuration;
        pulse.autoreverses = NO;
        // The binary sets both endpoints here and then again in the arm below, with the same
        // values each time.
        pulse.fromValue = @((step & 1) == 0 ? start : end);
        pulse.toValue = @((step & 1) == 0 ? end : start);
        if ((step & 1) == 0) {
            pulse.fromValue = @(start);
            pulse.toValue = @(end);
            pulse.timingFunction = [CAMediaTimingFunction
                 functionWithControlPoints:
                kFlashTimingControlPoint1X:kFlashTimingControlPoint1Y:kFlashTimingControlPoint2X
                                          :kFlashTimingControlPoint2Y];
        } else {
            pulse.fromValue = @(end);
            pulse.toValue = @(start);
            pulse.timingFunction = [CAMediaTimingFunction
                 functionWithControlPoints:
                kFlashTimingControlPoint2Y:kFlashTimingControlPoint2X:kFlashTimingControlPoint1Y
                                          :kFlashTimingControlPoint1X];
        }
        [animations addObject:pulse];
    }

    CABasicAnimation *rotation = [CABasicAnimation animationWithKeyPath:kRotationKeyPath];
    rotation.beginTime = 0.0;
    rotation.duration = duration;
    rotation.autoreverses = NO;
    rotation.fromValue = @(0.0f);
    rotation.toValue = @(kFlashRotationTwoPi);
    [animations addObject:rotation];

    CAAnimationGroup *group = [CAAnimationGroup animation];
    group.duration = duration;
    group.repeatCount = kFlashRepeatCountForever;
    group.animations = animations;
    [view.layer addAnimation:group forKey:kFlashAnimationKey];
}

+ (void)removeFlashEffectView:(UIView *)view {
    /** @ghidraAddress 0x1a3ecc */
    [view.layer removeAnimationForKey:kFlashAnimationKey];
}

- (void)SetFlashEffectDuration:(float)duration Start:(float)start End:(float)end {
    /** @ghidraAddress 0x1a36d4 */
    [UIView setFlashEffectView:self Duration:duration Start:start End:end Rotate:NO];
}

- (void)RemoveFlashEffect {
    /** @ghidraAddress 0x1a36f4 */
    [UIView removeFlashEffectView:self];
}

- (void)SetFlashEffectFast {
    /** @ghidraAddress 0x1a3710 */
    [self SetFlashEffectDuration:kFlashDefaultDuration
                           Start:kFlashFullOpacity
                             End:kFlashMinOpacity];
}

- (void)SetFlashEffectFastWithRotate {
    /** @ghidraAddress 0x1a3730 */
    [UIView setFlashEffectView:self
                      Duration:kFlashRotatingDuration
                         Start:kFlashFullOpacity
                           End:kFlashMinOpacity
                        Rotate:YES];
}

- (void)SetFlashEffectSlow {
    /** @ghidraAddress 0x1a3760 */
    [self RemoveFlashEffect];
}

#pragma mark - Alpha animation

- (void)SetAlphaAnimationDuration:(float)duration End:(float)end {
    /** @ghidraAddress 0x1a3f34 */
    CALayer *layer = self.layer;
    float from = layer.opacity;
    layer.opacity = end;
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:kOpacityKeyPath];
    animation.duration = duration;
    animation.fromValue = @(from);
    animation.toValue = @(end);
    animation.removedOnCompletion = NO;
    [layer addAnimation:animation forKey:kAlphaAnimationKey];
}

- (void)RemoveAlphaAnimation {
    /** @ghidraAddress 0x1a40d8 */
    [self.layer removeAnimationForKey:kAlphaAnimationKey];
}

#pragma mark - Jump (pop) effect

- (void)SetJumpEffectBaseX:(float)baseX BaseY:(float)baseY {
    /** @ghidraAddress 0x1a4134 */
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathMoveToPoint(path, NULL, baseX, baseY);
    for (size_t i = 0; i < ARRAY_SIZE(kPopBounceOffsets); ++i) {
        float controlY = baseY + kPopBounceOffsets[i];
        CGPathAddCurveToPoint(path, NULL, baseX, controlY, baseX, controlY, baseX, baseY);
    }
    CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:kPositionKeyPath];
    animation.path = path;
    animation.duration = kPopBounceDuration;
    animation.timingFunction = [CAMediaTimingFunction
             functionWithControlPoints:
        kPopBounceTimingControlPoint1X:kPopBounceTimingControlPoint1Y:kPopBounceTimingControlPoint2X
                                      :kPopBounceTimingControlPoint2Y];
    animation.repeatCount = kFlashRepeatCountForever;
    animation.removedOnCompletion = NO;
    CGPathRelease(path);
    [self.layer addAnimation:animation forKey:kPopAnimationKey];
}

- (void)RemoveJumpEffect {
    /** @ghidraAddress 0x1a4414 */
    [self.layer removeAnimationForKey:kPopAnimationKey];
}

#pragma mark - Frame geometry

- (CGFloat)x {
    /** @ghidraAddress 0x1a3668 */
    return self.frame.origin.x;
}

- (CGFloat)y {
    /** @ghidraAddress 0x1a3674 */
    return self.frame.origin.y;
}

- (CGFloat)width {
    /** @ghidraAddress 0x1a3694 */
    return self.frame.size.width;
}

- (CGFloat)height {
    /** @ghidraAddress 0x1a36b4 */
    return self.frame.size.height;
}

- (CGFloat)left {
    /** @ghidraAddress 0x1a35ac */
    return self.frame.origin.x;
}

- (CGFloat)top {
    /** @ghidraAddress 0x1a35b8 */
    return self.frame.origin.y;
}

- (CGFloat)right {
    /** @ghidraAddress 0x1a35d8 */
    return self.frame.origin.x + self.frame.size.width;
}

- (CGFloat)bottom {
    /** @ghidraAddress 0x1a3620 */
    return self.frame.origin.y + self.frame.size.height;
}

@end
