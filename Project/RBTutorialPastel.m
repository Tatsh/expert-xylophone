#import "RBTutorialPastel.h"

#import "UIImage+RB.h"
#import "deviceenvironment.h"

// Child indices into the clip-rectangle and position tables.
enum {
    kPastelIndexHead = 0,
    kPastelIndexBody = 1,
    kPastelIndexLeft = 2,
    kPastelIndexRight = 3,
    kPastelIndexCount = 4,
};

// The view's square side length before the display-rate scale is applied.
static const CGFloat kPastelBaseSize = 200.0;

// Display-rate values selected by the iPad idiom: half on the compact layout, unity otherwise.
static const CGFloat kPastelDisplayRateCompact = 0.5;
static const CGFloat kPastelDisplayRateFull = 1.0;

// Per-child layout metrics, in display-rate units. Each child's frame origin is derived from these
// bases and its own clip size.
static const CGFloat kPastelRightPositionX = 107.0;
static const CGFloat kPastelTailAnchorX = 95.0;
static const CGFloat kPastelTailAnchorY = 120.0;
static const CGFloat kPastelBodyAnchorX = 101.0;
static const CGFloat kPastelBodyAnchorY = 172.0;
static const CGFloat kPastelHeadAnchorX = 100.0;
static const CGFloat kPastelHeadAnchorY = 76.0;

// The retina clip rectangles cut out of the message artwork atlas, indexed by child. On the compact
// (non-iPad) idiom every field is halved. The runtime seeds a table shared with the sibling
// RBTutorialPastelLayer class at load time (Ghidra backing store 0x1003df3e0).
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

// Half factor for centre-anchored child frames.
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

@implementation RBTutorialPastel

#pragma mark Lifecycle

- (instancetype)init {
    if (!IsPad()) {
        self.displayRate = kPastelDisplayRateCompact;
    } else {
        self.displayRate = kPastelDisplayRateFull;
    }
    CGFloat width = self.displayRate * kPastelBaseSize;
    CGFloat height = self.displayRate * kPastelBaseSize;
    self = [super initWithFrame:CGRectMake(0.0, 0.0, width, height)];
    return self;
}

// The binary's -dealloc is the ARC-generated body (only the super-call plus the .cxx_destruct that
// releases the four strong child views); under ARC the compiler synthesises it, so no override is
// written here. @ghidraAddress 0x1b3390

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
    // Body.
    CGRect bodyClip = [self getClipList:kPastelIndexBody];
    UIImageView *body = [[UIImageView alloc] initWithImage:[image clipImageWithRect:bodyClip]];
    self.bodyView = body;
    self.bodyView.layer.anchorPoint = CGPointMake(kPastelHalf, 1.0);
    self.bodyView.frame = CGRectMake(
        self.displayRate * kPastelBodyAnchorX - self.bodyView.frame.size.width * kPastelHalf,
        self.displayRate * kPastelBodyAnchorY - self.bodyView.frame.size.height,
        self.bodyView.frame.size.width,
        self.bodyView.frame.size.height);
    [self addSubview:self.bodyView];

    // Head.
    CGRect headClip = [self getClipList:kPastelIndexHead];
    UIImageView *head = [[UIImageView alloc] initWithImage:[image clipImageWithRect:headClip]];
    self.headView = head;
    self.headView.layer.anchorPoint = CGPointMake(kPastelHalf, 1.0);
    self.headView.frame = CGRectMake(
        self.displayRate * kPastelHeadAnchorX - self.headView.frame.size.width * kPastelHalf,
        self.displayRate * kPastelHeadAnchorY - self.headView.frame.size.height * kPastelHalf,
        self.headView.frame.size.width,
        self.headView.frame.size.height);
    [self addSubview:self.headView];

    // Right tail.
    CGRect rightClip = [self getClipList:kPastelIndexRight];
    UIImageView *right = [[UIImageView alloc] initWithImage:[image clipImageWithRect:rightClip]];
    self.rightView = right;
    self.rightView.layer.anchorPoint = CGPointMake(0.0, 0.0);
    self.rightView.layer.position = CGPointMake(self.displayRate * kPastelRightPositionX,
                                                self.displayRate * kPastelTailAnchorY);
    [self addSubview:self.rightView];

    // Left tail.
    CGRect leftClip = [self getClipList:kPastelIndexLeft];
    UIImageView *left = [[UIImageView alloc] initWithImage:[image clipImageWithRect:leftClip]];
    self.leftView = left;
    self.leftView.layer.anchorPoint = CGPointMake(1.0, 0.0);
    self.leftView.frame =
        CGRectMake(self.displayRate * kPastelTailAnchorX - self.leftView.frame.size.width,
                   self.displayRate * kPastelTailAnchorY,
                   self.leftView.frame.size.width,
                   self.leftView.frame.size.height);
    [self addSubview:self.leftView];
}

#pragma mark Animations

- (void)startWaveAnimationWithDuration:(float)duration {
    CGPoint origin = self.layer.position;

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

    [self.layer addAnimation:group forKey:kPastelAnimationKeyBase];
    [self.rightView.layer addAnimation:baseRotation forKey:kPastelAnimationKeyRight];
    [self.headView.layer addAnimation:headRotation forKey:kPastelAnimationKeyHead];
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

    CGPoint headOrigin = self.headView.layer.position;
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

    CGPoint baseOrigin = self.layer.position;
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
        [self.rightView.layer addAnimation:rightRotation forKey:kPastelAnimationKeyRight];
        [self.leftView.layer addAnimation:leftRotation forKey:kPastelAnimationKeyLeft];
        [self.headView.layer addAnimation:headPosition forKey:kPastelAnimationKeyHead];
        [self.layer addAnimation:basePosition forKey:kPastelAnimationKeyBase];
    } else {
        [UIView animateWithDuration:delay
                              delay:0.0
                            options:0
                         animations:^{
                           /** @ghidraAddress 0x1b24d4 */
                           [self.rightView.layer addAnimation:rightRotation
                                                       forKey:kPastelAnimationKeyRight];
                           [self.leftView.layer addAnimation:leftRotation
                                                      forKey:kPastelAnimationKeyLeft];
                           [self.headView.layer addAnimation:headPosition
                                                      forKey:kPastelAnimationKeyHead];
                           [self.layer addAnimation:basePosition forKey:kPastelAnimationKeyBase];
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
    RBPastelStopAnimationsOnLayer(self.rightView.layer);
    RBPastelStopAnimationsOnLayer(self.leftView.layer);
    RBPastelStopAnimationsOnLayer(self.bodyView.layer);
    RBPastelStopAnimationsOnLayer(self.headView.layer);
    RBPastelStopAnimationsOnLayer(self.layer);
}

@end
