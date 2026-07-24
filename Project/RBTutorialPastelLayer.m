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
    {{360.0, 274.0}, {136.0, 96.0}}, // head
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

// Wave-animation timing and value constants.
static const NSTimeInterval kWaveDuration = 2.5;
static const CGFloat kWavePositionXDrift = -12.5;
static const CGFloat kWavePositionYDrift = -8.5;
static const CGFloat kWavePositionYHold = -8.5;
static const double kWavePositionXKeyTime1 = 0.0658;
static const double kWavePositionXKeyTime2 = 0.1330;
static const double kWavePositionYKeyTime0 = 0.1;
static const double kWavePositionYKeyTime1 = 0.1330;
static const double kWavePositionYKeyTime2 = 0.1660;
static const CGFloat kWaveRotationTilt = -0.17453;  // -10 degrees, in radians.
static const CGFloat kWaveRotationSwing = -0.78539; // -45 degrees, in radians (-pi/4).
static const CGFloat kWaveRotationReturn = 0.78539; // +45 degrees, in radians (+pi/4).
static const double kWaveRotationKeyTime1 = 0.4;
static const double kWaveRotationKeyTime2 = 0.6;
static const double kWaveHeadKeyTime1 = 0.2;
static const double kWaveHeadKeyTime2 = 0.266;
static const double kWaveHeadKeyTime3 = 0.332;
static const double kWaveHeadKeyTime4 = 0.466;
static const double kWaveHeadKeyTime5 = 0.532;
static const double kWaveHeadKeyTime6 = 0.6;
static const double kWaveHeadKeyTime7 = 0.664;
static const double kWaveHeadKeyTime8 = 0.733;
static const CGFloat kWaveHeadTilt = -0.087266; // -5 degrees, in radians.

// Jump-animation timing and value constants.
static const CGFloat kJumpDelayThreshold = 0.001;
static const CGFloat kJumpRotationRise = -0.26362;
static const CGFloat kJumpRotationSwing = 0.78539; // +pi/4.
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
    IsPad();
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
        @(kWavePositionYHold),
        @(kWavePositionYHold)
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

    CAKeyframeAnimation *rightRotation =
        [CAKeyframeAnimation animationWithKeyPath:kKeyPathRotation];
    rightRotation.repeatCount = 1.0;
    rightRotation.values = @[ @0, @0, @(kWaveRotationTilt), @(kWaveRotationSwing) ];
    rightRotation.keyTimes = @[ @0.0f, @(kWaveRotationKeyTime1), @(kWaveRotationKeyTime2), @1.0f ];
    rightRotation.timingFunctions = @[
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear],
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear],
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear],
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear]
    ];

    CAKeyframeAnimation *headRotation = [CAKeyframeAnimation animationWithKeyPath:kKeyPathRotation];
    headRotation.duration = kWaveDuration;
    headRotation.repeatCount = 1.0;
    headRotation.values = @[ @0, @0, @(kWaveRotationSwing), @0 ];
    headRotation.keyTimes = @[
        @(kWaveHeadKeyTime1),
        @(kWaveHeadKeyTime2),
        @(kWaveHeadKeyTime3),
        @(kWaveHeadKeyTime4),
        @(kWaveHeadKeyTime5),
        @(kWaveHeadKeyTime6),
        @(kWaveHeadKeyTime7),
        @(kWaveHeadKeyTime8)
    ];
    headRotation.removedOnCompletion = NO;
    headRotation.fillMode = kCAFillModeForwards;

    CAKeyframeAnimation *baseRotation = [CAKeyframeAnimation animationWithKeyPath:kKeyPathRotation];
    baseRotation.duration = kWaveDuration;
    baseRotation.repeatCount = 1.0;
    baseRotation.values = @[ @0, @(kWaveHeadTilt), @(kWaveRotationReturn), @1.0f ];
    baseRotation.keyTimes = @[ @0.0f, @(kWaveRotationKeyTime1), @(kWaveRotationKeyTime2), @1.0f ];
    baseRotation.timingFunctions = @[
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear],
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear],
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear],
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear]
    ];
    baseRotation.removedOnCompletion = NO;
    baseRotation.fillMode = kCAFillModeForwards;

    CAAnimationGroup *group = [CAAnimationGroup animation];
    group.duration = kWaveDuration;
    group.repeatCount = 1.0;
    group.animations = @[ positionX, positionY, rightRotation ];
    group.removedOnCompletion = NO;
    group.fillMode = kCAFillModeForwards;

    [self addAnimation:group forKey:kPastelAnimationKeyBase];
    [self.rightLayer addAnimation:baseRotation forKey:kPastelAnimationKeyRight];
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
        @(kJumpRotationSwing),
        @(kJumpRotationRise),
        @(kJumpRotationRise),
        @(kJumpRotationSwing),
        @0,
        @0
    ];
    rightRotation.keyTimes = @[
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
        @(kJumpRotationSwing),
        @(kJumpRotationRise),
        @(kJumpRotationRise),
        @(kJumpRotationSwing),
        @0,
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
        @(headOrigin.y + self.displayRate * kJumpPositionYDrift),
        @(headOrigin.y),
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
        [UIView
            animateWithDuration:delay
                          delay:0.0
                        options:0
                     animations:^{
                       /** @ghidraAddress 0x1b76c4 */
                       [self.rightLayer addAnimation:rightRotation forKey:kPastelAnimationKeyRight];
                       [self.leftLayer addAnimation:leftRotation forKey:kPastelAnimationKeyLeft];
                       [self.headLayer addAnimation:headPosition forKey:kPastelAnimationKeyHead];
                       [self addAnimation:basePosition forKey:kPastelAnimationKeyBase];
                     }
                     completion:nil];
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
