#import "RBTutorialPastelLayer.h"

#import "UIImage+RB.h"
#import "deviceenvironment.h"

// Child-layer indices into the clip-rectangle and position tables.
enum {
    kPastelLayerIndexHead = 0,
    kPastelLayerIndexBody = 1,
    kPastelLayerIndexLeft = 2,
    kPastelLayerIndexRight = 3,
    kPastelLayerIndexCount = 4,
};

// The layer's square side length before the display-rate scale is applied.
static const CGFloat kPastelLayerBaseSize = 200.0;

// Display-rate values selected by the iPad idiom: half on the compact layout, unity otherwise.
static const CGFloat kPastelDisplayRateCompact = 0.5;
static const CGFloat kPastelDisplayRateFull = 1.0;

// Per-child layout metrics, in display-rate units. Each child's frame origin is derived from these
// bases and its own clip size.
static const CGFloat kPastelRightAnchorX = 95.0;
static const CGFloat kPastelRightAnchorY = 120.0;
static const CGFloat kPastelRightPositionX = 107.0;
static const CGFloat kPastelRightPositionY = 120.0;
static const CGFloat kPastelBodyAnchorX = 101.0;
static const CGFloat kPastelBodyAnchorY = 172.0;
static const CGFloat kPastelHeadAnchorX = 100.0;
static const CGFloat kPastelHeadAnchorY = 76.0;

// The retina clip rectangles cut out of the message artwork atlas, indexed by child. On the compact
// iPad idiom every field is halved. The runtime seeds an identical table shared with the sibling
// RBTutorialPastel class at load time (Ghidra 0x1b81d8, backing store 0x1003df3e0).
static const CGRect kPastelClipRects[] = {
    {{361.0, 274.0}, {136.0, 96.0}}, // head
    {{499.0, 274.0}, {48.0, 56.0}},  // body
    {{498.0, 332.0}, {24.0, 22.0}},  // left tail
    {{525.0, 332.0}, {24.0, 22.0}},  // right tail
};

// The child layout points (Ghidra backing store 0x1003df460). Declared by the class but unused by
// the shipped app, which drives the children through setupView: only.
static const CGPoint kPastelPositions[] = {
    {101.0, 172.0}, // head
    {100.0, 76.0},  // body
    {107.0, 120.0}, // left tail
    {95.0, 120.0},  // right tail
};

// Half-width and half-height factors for centre-anchored child frames.
static const CGFloat kPastelHalf = 0.5;

// Wave-animation timing and value constants. The key times reach the code as doubles read out of
// one dense pool run, and several of the animations share the same slot.
static const NSTimeInterval kWaveDuration = 2.5;
static const CGFloat kWavePositionXDrift = -12.5;
static const CGFloat kWavePositionYDrift = -8.5;
static const double kWavePositionXKeyTime1 = 0.066;
static const double kWavePositionXKeyTime2 = 0.133;
static const double kWavePositionYKeyTime0 = 0.1;
static const double kWavePositionYKeyTime1 = 0.133;
static const double kWavePositionYKeyTime2 = 0.166;
static const CGFloat kWaveRotationTilt = -0.17453292519943295; // -10 degrees, in radians.
static const CGFloat kWaveRotationSwing = -0.7853981633974483; // -45 degrees, in radians (-pi/4).
static const CGFloat kWaveHeadTilt = -0.08726646259971647;     // -5 degrees, in radians.
static const double kWaveBaseKeyTime1 = 0.066;
static const double kWaveBaseKeyTime2 = 0.133;
static const double kWaveRightKeyTime1 = 0.133;
static const double kWaveRightKeyTime2 = 0.2;
static const double kWaveRightKeyTime3 = 0.266;
static const double kWaveRightKeyTime4 = 0.333;
static const double kWaveRightKeyTime5 = 0.4;
static const double kWaveRightKeyTime6 = 0.466;
static const double kWaveRightKeyTime7 = 0.533;
static const double kWaveRightKeyTime8 = 0.6;
static const double kWaveRightKeyTime9 = 0.666;
static const double kWaveRightKeyTime10 = 0.733;
static const double kWaveHeadKeyTime1 = 0.133;
static const double kWaveHeadKeyTime2 = 0.166;

// Jump-animation timing and value constants.
static const CGFloat kJumpDelayThreshold = 0.001;
static const CGFloat kJumpRotationSwing = 0.7853981633974483; // +45 degrees, in radians (+pi/4).
static const CGFloat kJumpRotationRest = 0.2617993877991494;  // +15 degrees, in radians.
static const CGFloat kJumpPositionYDrift = 3.0;
static const CGFloat kJumpPositionYDip = -6.0;
static const double kJumpKeyTime1 = 0.125;
static const double kJumpKeyTime2 = 0.175;
static const double kJumpKeyTime3 = 0.275;
static const double kJumpKeyTime4 = 0.725;
static const double kJumpKeyTime5 = 0.825;
static const double kJumpKeyTime6 = 0.875;

// Animation keys used when adding the grouped animations to each child layer.
static NSString *const kPastelAnimationKeyBase = @"base";
static NSString *const kPastelAnimationKeyRight = @"right";
static NSString *const kPastelAnimationKeyLeft = @"left";
static NSString *const kPastelAnimationKeyHead = @"head";

// Layer key paths.
static NSString *const kKeyPathPositionX = @"position.x";
static NSString *const kKeyPathPositionY = @"position.y";
static NSString *const kKeyPathRotation = @"transform.rotation";

@implementation RBTutorialPastelLayer

#pragma mark Lifecycle

- (instancetype)init {
    if (!IsPad()) {
        self.displayRate = kPastelDisplayRateCompact;
    } else {
        self.displayRate = kPastelDisplayRateFull;
    }
    self = [super init];
    CGFloat side = self.displayRate * kPastelLayerBaseSize;
    self.frame = CGRectMake(0.0, 0.0, side, side);
    return self;
}

#pragma mark Layout tables

- (CGRect)getClipList:(int)index {
    CGRect rect = kPastelClipRects[index];
    if (!IsPad()) {
        rect = CGRectMake(rect.origin.x * kPastelHalf,
                          rect.origin.y * kPastelHalf,
                          rect.size.width * kPastelHalf,
                          rect.size.height * kPastelHalf);
    }
    return rect;
}

- (CGPoint)getPosition:(int)index {
    IsPad(); // Yes, the binary calls this and discards the result.
    return kPastelPositions[index];
}

#pragma mark Setup

- (void)setupView:(UIImage *)image {
    // Right tail.
    CGRect rightClip = [self getClipList:kPastelLayerIndexRight];
    CALayer *right = [CALayer layer];
    right.contents = (__bridge id)[image clipImageWithRect:rightClip].CGImage;
    right.frame = CGRectMake(self.displayRate * kPastelRightAnchorX - rightClip.size.width,
                             self.displayRate * kPastelRightAnchorY,
                             rightClip.size.width,
                             rightClip.size.height);
    right.anchorPoint = CGPointMake(0.0, 0.0);
    right.position = CGPointMake(self.displayRate * kPastelRightPositionX,
                                 self.displayRate * kPastelRightPositionY);
    [self addSublayer:right];
    self.rightLayer = right;

    // Left tail.
    CGRect leftClip = [self getClipList:kPastelLayerIndexLeft];
    CALayer *left = [CALayer layer];
    left.contents = (__bridge id)[image clipImageWithRect:leftClip].CGImage;
    left.anchorPoint = CGPointMake(1.0, 0.0);
    left.frame = CGRectMake(self.displayRate * kPastelRightAnchorX - leftClip.size.width,
                            self.displayRate * kPastelRightAnchorY,
                            leftClip.size.width,
                            leftClip.size.height);
    [self addSublayer:left];
    self.leftLayer = left;

    // Body.
    CGRect bodyClip = [self getClipList:kPastelLayerIndexBody];
    CALayer *body = [CALayer layer];
    body.contents = (__bridge id)[image clipImageWithRect:bodyClip].CGImage;
    body.anchorPoint = CGPointMake(kPastelHalf, 1.0);
    body.frame =
        CGRectMake(self.displayRate * kPastelBodyAnchorX - bodyClip.size.width * kPastelHalf,
                   self.displayRate * kPastelBodyAnchorY - bodyClip.size.height,
                   bodyClip.size.width,
                   bodyClip.size.height);
    [self addSublayer:body];
    self.bodyLayer = body;

    // Head.
    CGRect headClip = [self getClipList:kPastelLayerIndexHead];
    CALayer *head = [CALayer layer];
    head.contents = (__bridge id)[image clipImageWithRect:headClip].CGImage;
    head.anchorPoint = CGPointMake(kPastelHalf, 1.0);
    head.frame =
        CGRectMake(self.displayRate * kPastelHeadAnchorX - headClip.size.width * kPastelHalf,
                   self.displayRate * kPastelHeadAnchorY - headClip.size.height * kPastelHalf,
                   headClip.size.width,
                   headClip.size.height);
    [self addSublayer:head];
    self.headLayer = head;
}

#pragma mark Animations

- (void)startWaveAnimationWithDuration:(float)duration {
    CGPoint origin = self.position;

    CAKeyframeAnimation *positionX = [CAKeyframeAnimation animationWithKeyPath:kKeyPathPositionX];
    positionX.repeatCount = 1.0;
    positionX.values = @[
        @(origin.x),
        @(origin.x),
        @(origin.x + self.displayRate * kWavePositionXDrift),
        @(origin.x + self.displayRate * kWavePositionXDrift)
    ];
    positionX.keyTimes = @[ @0.0, @(kWavePositionXKeyTime1), @(kWavePositionXKeyTime2), @1.0 ];
    positionX.timingFunctions = @[
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear],
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear],
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear],
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear]
    ];
    positionX.removedOnCompletion = NO;
    positionX.fillMode = kCAFillModeForwards;

    CAKeyframeAnimation *positionY = [CAKeyframeAnimation animationWithKeyPath:kKeyPathPositionY];
    positionY.repeatCount = 1.0;
    positionY.values = @[
        @(origin.y),
        @(origin.y + self.displayRate * kWavePositionYDrift),
        @(origin.y),
        @(origin.y)
    ];
    positionY.keyTimes =
        @[ @(kWavePositionYKeyTime0), @(kWavePositionYKeyTime1), @(kWavePositionYKeyTime2), @1.0 ];
    positionY.timingFunctions = @[
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut],
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn],
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear],
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear]
    ];
    positionY.removedOnCompletion = NO;
    positionY.fillMode = kCAFillModeForwards;

    // The third member of the group, so it rotates the layer itself rather than a tail. It is the
    // only animation here the binary leaves without a fill mode.
    CAKeyframeAnimation *baseRotation = [CAKeyframeAnimation animationWithKeyPath:kKeyPathRotation];
    baseRotation.repeatCount = 1.0;
    baseRotation.values = @[ @0, @0, @(kWaveRotationTilt), @(kWaveRotationTilt) ];
    baseRotation.keyTimes = @[ @0.0f, @(kWaveBaseKeyTime1), @(kWaveBaseKeyTime2), @1.0f ];
    baseRotation.timingFunctions = @[
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear],
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear],
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear],
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear]
    ];

    CAKeyframeAnimation *rightRotation =
        [CAKeyframeAnimation animationWithKeyPath:kKeyPathRotation];
    rightRotation.duration = kWaveDuration;
    rightRotation.repeatCount = 1.0;
    rightRotation.values = @[
        @0,
        @0,
        @(kWaveRotationSwing),
        @0,
        @(kWaveRotationSwing),
        @0,
        @(kWaveRotationSwing),
        @0,
        @(kWaveRotationSwing),
        @0,
        @(kWaveRotationSwing)
    ];
    // The binary's last key time is 0.733 rather than 1.0, and it sets no timing functions here.
    rightRotation.keyTimes = @[
        @0.0,
        @(kWaveRightKeyTime1),
        @(kWaveRightKeyTime2),
        @(kWaveRightKeyTime3),
        @(kWaveRightKeyTime4),
        @(kWaveRightKeyTime5),
        @(kWaveRightKeyTime6),
        @(kWaveRightKeyTime7),
        @(kWaveRightKeyTime8),
        @(kWaveRightKeyTime9),
        @(kWaveRightKeyTime10)
    ];
    rightRotation.removedOnCompletion = NO;
    rightRotation.fillMode = kCAFillModeForwards;

    CAKeyframeAnimation *headRotation = [CAKeyframeAnimation animationWithKeyPath:kKeyPathRotation];
    headRotation.duration = kWaveDuration;
    headRotation.repeatCount = 1.0;
    headRotation.values = @[ @0, @0, @(kWaveHeadTilt), @(kWaveHeadTilt) ];
    headRotation.keyTimes = @[ @0.0f, @(kWaveHeadKeyTime1), @(kWaveHeadKeyTime2), @1.0f ];
    headRotation.timingFunctions = @[
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear],
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear],
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear],
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear]
    ];
    headRotation.removedOnCompletion = NO;
    headRotation.fillMode = kCAFillModeForwards;

    CAAnimationGroup *group = [CAAnimationGroup animation];
    group.duration = kWaveDuration;
    group.repeatCount = 1.0;
    group.animations = @[ positionX, positionY, baseRotation ];
    group.removedOnCompletion = NO;
    group.fillMode = kCAFillModeForwards;

    [self addAnimation:group forKey:kPastelAnimationKeyBase];
    [self.rightLayer addAnimation:rightRotation forKey:kPastelAnimationKeyRight];
    [self.headLayer addAnimation:headRotation forKey:kPastelAnimationKeyHead];
}

- (void)startJumpAnimationWithDuration:(float)duration delay:(float)delay {
    CAKeyframeAnimation *rightRotation =
        [CAKeyframeAnimation animationWithKeyPath:kKeyPathRotation];
    rightRotation.duration = duration;
    rightRotation.repeatCount = 1.0;
    rightRotation.values = @[
        @0,
        @0,
        @(kJumpRotationRest),
        @(-kJumpRotationSwing),
        @(-kJumpRotationSwing),
        @(-kJumpRotationSwing),
        @(kJumpRotationRest),
        @0,
        @0
    ];
    // The binary boxes 0.0f twice at the head of this list, so it has nine key times.
    rightRotation.keyTimes = @[
        @0.0f,
        @0.0f,
        @(kJumpKeyTime1),
        @(kJumpKeyTime2),
        @(kJumpKeyTime3),
        @(kJumpKeyTime4),
        @(kJumpKeyTime5),
        @(kJumpKeyTime6),
        @1.0f
    ];
    rightRotation.removedOnCompletion = NO;
    rightRotation.fillMode = kCAFillModeForwards;

    CAKeyframeAnimation *leftRotation = [CAKeyframeAnimation animationWithKeyPath:kKeyPathRotation];
    leftRotation.duration = duration;
    leftRotation.repeatCount = 1.0;
    leftRotation.values = @[
        @0,
        @(-kJumpRotationRest),
        @(kJumpRotationSwing),
        @(kJumpRotationSwing),
        @(kJumpRotationSwing),
        @(-kJumpRotationRest),
        @0,
        @0
    ];
    leftRotation.keyTimes = @[
        @0.0f,
        @(kJumpKeyTime1),
        @(kJumpKeyTime2),
        @(kJumpKeyTime3),
        @(kJumpKeyTime4),
        @(kJumpKeyTime5),
        @(kJumpKeyTime6),
        @1.0f
    ];
    leftRotation.removedOnCompletion = NO;
    leftRotation.fillMode = kCAFillModeForwards;

    CGPoint headOrigin = self.headLayer.position;
    CAKeyframeAnimation *headPosition =
        [CAKeyframeAnimation animationWithKeyPath:kKeyPathPositionY];
    headPosition.duration = duration;
    headPosition.repeatCount = 1.0;
    headPosition.values = @[
        @(headOrigin.y),
        @(headOrigin.y + self.displayRate * kJumpPositionYDrift),
        @(headOrigin.y),
        @(headOrigin.y),
        @(headOrigin.y),
        @(headOrigin.y + self.displayRate * kJumpPositionYDrift),
        @(headOrigin.y),
        @(headOrigin.y)
    ];
    headPosition.keyTimes = @[
        @0.0f,
        @(kJumpKeyTime1),
        @(kJumpKeyTime2),
        @(kJumpKeyTime3),
        @(kJumpKeyTime4),
        @(kJumpKeyTime5),
        @(kJumpKeyTime6),
        @1.0f
    ];
    headPosition.timingFunctions = @[
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear],
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear],
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear],
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear]
    ];
    headPosition.removedOnCompletion = NO;
    headPosition.fillMode = kCAFillModeForwards;

    CGPoint baseOrigin = self.position;
    CAKeyframeAnimation *basePosition =
        [CAKeyframeAnimation animationWithKeyPath:kKeyPathPositionY];
    basePosition.duration = duration;
    basePosition.repeatCount = 1.0;
    basePosition.values = @[
        @(baseOrigin.y),
        @(baseOrigin.y),
        @(baseOrigin.y + self.displayRate * kJumpPositionYDip),
        @(baseOrigin.y + self.displayRate * kJumpPositionYDip),
        @(baseOrigin.y + self.displayRate * kJumpPositionYDip),
        @(baseOrigin.y),
        @(baseOrigin.y),
        @(baseOrigin.y)
    ];
    basePosition.keyTimes = @[
        @0.0f,
        @(kJumpKeyTime1),
        @(kJumpKeyTime2),
        @(kJumpKeyTime3),
        @(kJumpKeyTime4),
        @(kJumpKeyTime5),
        @(kJumpKeyTime6),
        @1.0f
    ];
    basePosition.timingFunctions = @[
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear],
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear],
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear],
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear]
    ];
    basePosition.removedOnCompletion = NO;
    basePosition.fillMode = kCAFillModeForwards;

    if (delay <= kJumpDelayThreshold) {
        [self.rightLayer addAnimation:rightRotation forKey:kPastelAnimationKeyRight];
        [self.leftLayer addAnimation:leftRotation forKey:kPastelAnimationKeyLeft];
        [self.headLayer addAnimation:headPosition forKey:kPastelAnimationKeyHead];
        [self addAnimation:basePosition forKey:kPastelAnimationKeyBase];
    } else {
        // The binary passes an empty global block for animations: and does all of the work in the
        // completion handler, so the delay behaves as a plain wait rather than as a tween.
        [UIView animateWithDuration:delay
            delay:0.0
            options:0
            animations:^{
              /** @ghidraAddress 0x1b76c0 (animations block, empty in the binary) */
            }
            completion:^(BOOL finished) {
              /** @ghidraAddress 0x1b76c4 (completion block) */
              [self.rightLayer addAnimation:rightRotation forKey:kPastelAnimationKeyRight];
              [self.leftLayer addAnimation:leftRotation forKey:kPastelAnimationKeyLeft];
              [self.headLayer addAnimation:headPosition forKey:kPastelAnimationKeyHead];
              [self addAnimation:basePosition forKey:kPastelAnimationKeyBase];
            }];
    }
}

#pragma mark Teardown

// Remove every running animation from a layer and each of its sublayers, but only when the layer
// actually has animations to clear. The binary open-codes this block once per layer.
static void RBPastelStopAnimationsOnLayer(CALayer *layer) {
    if (layer.animationKeys != nil && layer.animationKeys.count != 0) {
        for (CALayer *sublayer in layer.sublayers) {
            [sublayer removeAllAnimations];
        }
        [layer removeAllAnimations];
    }
}

- (void)stopAnimation {
    RBPastelStopAnimationsOnLayer(self.rightLayer);
    RBPastelStopAnimationsOnLayer(self.leftLayer);
    RBPastelStopAnimationsOnLayer(self.bodyLayer);
    RBPastelStopAnimationsOnLayer(self.headLayer);
    RBPastelStopAnimationsOnLayer(self);
}

@end
