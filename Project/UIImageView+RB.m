//
//  UIImageView+RB.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (category UIImageView(RB)). Verified
//  against the arm64 disassembly: the flash pulse is a CABasicAnimation on the "opacity" key path
//  that auto-reverses and repeats forever (repeat count is the FLT_MAX bit pattern 0x7f7fffff),
//  eases with the cubic control points (0.5, 0.0, 0.75, 0.8), keeps its final value
//  (removedOnCompletion = NO), and is installed under the "FLUSH_ANIM" key. The opacity endpoints
//  reach numberWithFloat: as raw float bit patterns, and the standard duration (0.333), fast
//  duration, and dimmed end opacity (0.2) were recovered from the referenced float constants. The
//  convenience starters dispatch SetFlashEffectDuration:Start:End: on the receiver, so their true
//  receiver is self.
//

#import "UIImageView+RB.h"

#import <QuartzCore/QuartzCore.h>

// The layer animation key under which the flash pulse is installed, and the key path it animates.
static NSString *const kFlashAnimationKey = @"FLUSH_ANIM";
static NSString *const kFlashOpacityKeyPath = @"opacity";

// The one-way pulse durations, in seconds: the standard period and the shorter "fast" period.
// @ghidraAddress 0x2fefb8 (g_flFlashDefaultDuration)
static const CGFloat kFlashDefaultDuration = 0.333333343;
static const CGFloat kFlashFastDuration = 0.25;

// The opacity endpoints of a pulse: fully opaque down to the dimmed minimum.
static const CGFloat kFlashFullOpacity = 1.0;
// @ghidraAddress 0x2ec6b4 (g_flFlashMinOpacity)
static const CGFloat kFlashMinOpacity = 0.2;

// The cubic timing-function control points of a pulse.
static const float kFlashTimingControlPoint1X = 0.5f;
static const float kFlashTimingControlPoint1Y = 0.0f;
static const float kFlashTimingControlPoint2X = 0.75f;
// @ghidraAddress 0x2f856c (g_flFlashTimingControlPointX2)
static const float kFlashTimingControlPoint2Y = 0.8f;

@implementation UIImageView (RB)

- (void)SetFlashEffectFast {
    /** @ghidraAddress 0x41830a */
    [self SetFlashEffectDuration:kFlashFastDuration Start:kFlashFullOpacity End:kFlashMinOpacity];
}

- (void)StartDefaultFlashEffect {
    /** @ghidraAddress 0x1a3710 */
    [self SetFlashEffectDuration:kFlashDefaultDuration
                           Start:kFlashFullOpacity
                             End:kFlashMinOpacity];
}

- (void)SetFlashEffectDuration:(CGFloat)duration Start:(CGFloat)start End:(CGFloat)end {
    /** @ghidraAddress 0x41831d */
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:kFlashOpacityKeyPath];
    animation.duration = duration;
    animation.repeatCount = HUGE_VALF;
    animation.autoreverses = YES;
    animation.fromValue = @(start);
    animation.toValue = @(end);
    animation.timingFunction =
        [CAMediaTimingFunction functionWithControlPoints:kFlashTimingControlPoint1X
                                                        :kFlashTimingControlPoint1Y
                                                        :kFlashTimingControlPoint2X
                                                        :kFlashTimingControlPoint2Y];
    animation.removedOnCompletion = NO;
    [self.layer addAnimation:animation forKey:kFlashAnimationKey];
}

- (void)RemoveFlashEffect {
    /** @ghidraAddress 0x1a3760 */
    [self.layer removeAnimationForKey:kFlashAnimationKey];
}

@end
