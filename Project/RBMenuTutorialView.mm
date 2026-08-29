#import "RBMenuTutorialView.h"

#include <cmath>

#import "RBAnimationFactory.h"
#import "RBCustomView.h"
#import "RBExperienceData.h"
#import "RBMenuButton.h"
#import "RBMenuView.h"
#import "RBMusicCell.h"
#import "RBMusicView.h"
#import "RBSettingMenuButton.h"
#import "RBSettingView.h"
#import "RBTutorialManager.h"
#import "RBTutorialPastelLayer.h"
#import "RBUnlockView.h"
#import "RBUserSettingData.h"
#import "UIImage+RB.h"
#import "UIView+RB.h"
#import "deviceenvironment.h"
#import "soundeffectmanager.h"

@interface RBMenuTutorialView () <CAAnimationDelegate>
@end

// @ghidraAddress 0x3de058
extern "C" CGRect g_pTutorialClipRect[];

static NSString *const kTutorialArtworkImageName = @"10_tutorial/tu_tex01";

static NSString *const kCursorAnimationKey = @"here";

static NSString *const kContentPositionKeyPath = @"position";

constexpr float kContentWidthNarrow = 300.0f;
constexpr float kContentHeightNarrow = 100.0f;
constexpr float kContentWidthWide = 640.0f;
constexpr float kContentHeightWide = 300.0f;

constexpr float kCustomizeTutorialRewardPoints = 1000.0f;

constexpr unsigned int kTutorialSeenValue = 1;

constexpr int kSoundEffectDecide = 9;

enum {
    kTutorialTexTypeCursor = 0x19,
    kTutorialTexTypeTouch = 0x1a,
    kTutorialTexTypeTouchFrame = 0x1b,
    kTutorialTexTypeMessageWide = 0x1c,
    kTutorialTexTypeMessageNarrow = 0x1d,
    kTutorialTexTypeCornerTL = 0x1e,
    kTutorialTexTypeCornerTR = 0x1f,
    kTutorialTexTypeCornerBL = 0x20,
    kTutorialTexTypeCornerBR = 0x21,
};

enum {
    kTutorialStepMusicSelectA = 0,
    kTutorialStepMusicSelectB = 1,
    kTutorialStepCollectionView = 2,
    kTutorialStepMusicCell = 3,
    kTutorialStepFullScreen = 4,
    kTutorialStepDifficultyBasic = 5,
    kTutorialStepDifficultyMedium = 6,
    kTutorialStepDifficultyHard = 7,
    kTutorialStepDoubleButton = 8,
    kTutorialStepDecideButton = 9,
    kTutorialStepPlayIntro = 10,
    kTutorialStepReportOnlyFirst = 0x12,
    kTutorialStepReportOnlyLast = 0x17,
    kTutorialStepNoTarget = 0x18,
    kTutorialStepSettingButton = 0x19,
    kTutorialStepSettingButtonB = 0x1a,
    kTutorialStepCustomizeButton = 0x1b,
    kTutorialStepCustomizeMessage = 0x1c,
    kTutorialStepUnlockButton = 0x1d,
    kTutorialStepUnlockItem = 0x1e,
    kTutorialStepUnlockMessage = 0x1f,
    kTutorialStepCustomButton = 0x20,
    kTutorialStepCustomizeItem = 0x21,
    kTutorialStepCloseCustomize = 0x22,
    kTutorialStepNone = 0x28,
};

enum {
    kDifficultyButtonBasic = 0,
    kDifficultyButtonMedium = 1,
    kDifficultyButtonHard = 2,
};

constexpr NSTimeInterval kOverlayFadeDuration = 0.25;

constexpr CGFloat kRotationDimAlpha = 0.5;

constexpr CGFloat kSpotlightPixelSnap = 0.5;
constexpr CGFloat kSpotlightPixelGrow = 1.0;

constexpr CGFloat kContentViewSpotlightGap = 10.0;

constexpr CGFloat kMessageWindowInsetXWide = 20.0;
constexpr CGFloat kMessageWindowInsetXNarrow = 26.0;
constexpr CGFloat kMessageWindowInsetYWide = 16.0;
constexpr CGFloat kMessageWindowInsetYNarrow = 8.0;

constexpr CGFloat kMessageWindowNarrowOffsetScale = -0.85; // @ghidraAddress 0x308cb8

constexpr CGFloat kPastelDropScaleWide = 1.5;
constexpr CGFloat kPastelDropScaleNarrow = 0.8; // @ghidraAddress 0x2eea40

constexpr CGFloat kPastelNarrowInsetDivisor = 3.0;

constexpr unsigned int kTutorialClipRectMessageWide = 9;
constexpr unsigned int kTutorialClipRectMessageNarrow = 10;
constexpr CGFloat kNarrowClipRectScale = 0.5;

constexpr CGFloat kCursorBobDuration = 0.5;
constexpr int kCursorBobRepeatCount = 0;

// @ghidraAddress 0x310450
constexpr UIViewAutoresizing kAutoresizingMaskFlexibleAll =
    UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth |
    UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin |
    UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;

// The reveal arms of -startAnimation: (0x13de2c) and the snap arms of -resetAnimation: (0x13f7f0),
// which the binary emits inline with no selector of their own.
static inline void RevealBubbleOnly(RBMenuTutorialView *view);
static inline void RevealBubbleAndMessage(RBMenuTutorialView *view);
static inline void RevealBubbleMessageAndMove(RBMenuTutorialView *view, CGRect targetFrame);
static inline void SnapContentViewOpaqueMovingTo(RBMenuTutorialView *view, CGRect targetFrame);
static inline void SnapContentViewOpaque(RBMenuTutorialView *view);

@implementation RBMenuTutorialView

#pragma mark - Lifecycle

- (instancetype)initWithFrame:(CGRect)frame {
    /** @ghidraAddress 0x137b0c */
    self = [super initWithFrame:frame];
    if (self) {
        self.exclusiveTouch = YES;
        if (!IsPad()) {
            self.contentViewWidth = kContentWidthNarrow;
            self.contentViewHeight = kContentHeightNarrow;
        } else {
            self.contentViewWidth = kContentWidthWide;
            self.contentViewHeight = kContentHeightWide;
        }
    }
    return self;
}

- (void)dealloc {
    /** @ghidraAddress 0x140cd0 */
    // ARC chains to super and clears the ivars in .cxx_destruct (0x141334) implicitly.
}

#pragma mark - Layout

- (void)setupView {
    /** @ghidraAddress 0x137bfc */
    self.alpha = 0.0;
    self.backgroundColor = UIColor.clearColor;
    self.autoresizingMask = kAutoresizingMaskFlexibleAll;

    BOOL narrow = !IsPad();

    self.baseView = [[UIImageView alloc] initWithFrame:self.frame];
    self.baseView.autoresizingMask =
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.baseView.alpha = kRotationDimAlpha;
    [self addSubview:self.baseView];

    self.messageImage = [UIImage imageWithName:kTutorialArtworkImageName useCache:NO];

    self.contentView =
        [[UIView alloc] initWithFrame:CGRectMake(self.width * 0.5 - self.contentViewWidth * 0.5f,
                                                 self.height * 0.5 - self.contentViewHeight * 0.5f,
                                                 self.contentViewWidth,
                                                 self.contentViewHeight)];
    [self addSubview:self.contentView];

    CALayer *windowLayer = [CALayer layer];
    UIImage *windowClip =
        narrow ?
            [self.messageImage clipImageWithRect:[self getClipRect:kTutorialTexTypeMessageNarrow]] :
            [self.messageImage clipImageWithRect:[self getClipRect:kTutorialTexTypeMessageWide]];
    windowLayer.contents = (__bridge id)windowClip.CGImage;
    if (narrow) {
        windowLayer.frame = CGRectMake(self.contentViewWidth * 0.5f +
                                           windowClip.size.width * kMessageWindowNarrowOffsetScale,
                                       self.contentViewHeight * 0.5f,
                                       windowClip.size.width,
                                       windowClip.size.height);
    } else {
        windowLayer.frame = CGRectMake(self.contentViewWidth * 0.5f - windowClip.size.width,
                                       self.contentViewHeight * 0.25f + 3.0f,
                                       windowClip.size.width,
                                       windowClip.size.height);
    }
    windowLayer.anchorPoint = CGPointMake(0.0, 1.0);
    windowLayer.opacity = 0.0;
    [self.contentView.layer addSublayer:windowLayer];
    self.messageWindowLayer = windowLayer;

    RBTutorialPastelLayer *pastel = [[RBTutorialPastelLayer alloc] init];
    [pastel setupView:self.messageImage];
    if (narrow) {
        CGRect windowFrame = self.messageWindowLayer.frame;
        pastel.position =
            CGPointMake(windowFrame.origin.x - pastel.frame.size.width / kPastelNarrowInsetDivisor,
                        windowFrame.origin.y + pastel.frame.size.height * kPastelDropScaleNarrow);
    } else {
        CGRect windowFrame = self.messageWindowLayer.frame;
        pastel.position =
            CGPointMake(windowFrame.origin.x,
                        windowFrame.origin.y + pastel.frame.size.height * kPastelDropScaleWide);
    }
    pastel.anchorPoint = CGPointMake(0.5, 1.0);
    pastel.opacity = 0.0;
    [self.contentView.layer addSublayer:pastel];
    self.pastelLayer = pastel;

    CALayer *messageLayer = [CALayer layer];
    messageLayer.anchorPoint = CGPointMake(0.5, 0.5);
    CGRect windowFrame = self.messageWindowLayer.frame;
    if (narrow) {
        CGSize messageSize = g_pTutorialClipRect[kTutorialClipRectMessageNarrow].size;
        messageLayer.frame = CGRectMake(windowFrame.origin.x + kMessageWindowInsetXNarrow,
                                        windowFrame.origin.y + kMessageWindowInsetYNarrow,
                                        messageSize.width * kNarrowClipRectScale,
                                        messageSize.height * kNarrowClipRectScale);
    } else {
        CGSize messageSize = g_pTutorialClipRect[kTutorialClipRectMessageWide].size;
        messageLayer.frame = CGRectMake(windowFrame.origin.x + kMessageWindowInsetXWide,
                                        windowFrame.origin.y + kMessageWindowInsetYWide,
                                        messageSize.width,
                                        messageSize.height);
    }
    messageLayer.contents = (__bridge id)self.messageImage.CGImage;
    messageLayer.opacity = 0.0;
    [self.contentView.layer addSublayer:messageLayer];
    self.messageLayer = messageLayer;

    UIImage *cursorClip =
        [self.messageImage clipImageWithRect:[self getClipRect:kTutorialTexTypeCursor]];
    self.cursorView = [[UIImageView alloc] initWithImage:cursorClip];
    self.cursorView.hidden = YES;
    [self addSubview:self.cursorView];

    UIImage *touchClip =
        [self.messageImage clipImageWithRect:[self getClipRect:kTutorialTexTypeTouch]];
    UIImage *touchFrameClip =
        [self.messageImage clipImageWithRect:[self getClipRect:kTutorialTexTypeTouchFrame]];
    // The frame size comes from the first clip only; the second supplies just an animation image.
    self.touchView = [[UIImageView alloc]
        initWithFrame:CGRectMake(0.0, 0.0, touchClip.size.width, touchClip.size.height)];
    self.touchView.animationImages = @[ touchClip, touchFrameClip ];
    self.touchView.animationDuration = 1.0;
    self.touchView.animationRepeatCount = 0; // The binary never sets x2; 0 is substituted.
    self.touchView.hidden = YES;
    [self addSubview:self.touchView];

    // The grayC* corner layers trim the rounded spotlight-hole edges; the rest are quadrants.
    self.grayTL = [self addGrayLayerToBase];
    self.grayTR = [self addGrayLayerToBase];
    self.grayBL = [self addGrayLayerToBase];
    self.grayBR = [self addGrayLayerToBase];
    self.grayCTL = [self addGrayCornerLayerToBase:kTutorialTexTypeCornerTL];
    self.grayCTR = [self addGrayCornerLayerToBase:kTutorialTexTypeCornerTR];
    self.grayCBL = [self addGrayCornerLayerToBase:kTutorialTexTypeCornerBL];
    self.grayCBR = [self addGrayCornerLayerToBase:kTutorialTexTypeCornerBR];

    // The quadrants start pushed off the overlay so nothing is dimmed until a spotlight exists.
    self.grayTL.frame = CGRectMake(0.0, -self.height, self.width, self.height);
    self.grayTR.frame = CGRectMake(self.width, 0.0, self.width, self.height);
    self.grayBR.frame = CGRectMake(0.0, self.height, self.width, self.height);
    self.grayBL.frame = CGRectMake(-self.width, 0.0, self.width, self.height);
    UIImage *cornerClip =
        [self.messageImage clipImageWithRect:[self getClipRect:kTutorialTexTypeCornerTL]];
    self.grayCTL.frame = CGRectMake(0.0, self.height, cornerClip.size.width, cornerClip.size.width);
    self.grayCTR.frame = CGRectMake(self.width - cornerClip.size.width,
                                    self.height,
                                    cornerClip.size.width,
                                    cornerClip.size.width);
    self.grayCBL.frame = CGRectMake(
        0.0, self.height + cornerClip.size.width, cornerClip.size.width, cornerClip.size.width);
    self.grayCBR.frame = CGRectMake(self.width - cornerClip.size.width,
                                    self.height + cornerClip.size.width,
                                    cornerClip.size.width,
                                    cornerClip.size.width);

    self.fullCoverView = [[UIView alloc] initWithFrame:self.frame];
    self.fullCoverView.backgroundColor = UIColor.blackColor;
    self.fullCoverView.alpha = 0.0;
    self.fullCoverView.autoresizingMask = kAutoresizingMaskFlexibleAll;
    [self addSubview:self.fullCoverView];

    [self addTarget:self action:@selector(tap:) forControlEvents:UIControlEventTouchUpInside];
}

- (CALayer *)addGrayLayerToBase {
    CALayer *layer = [CALayer layer];
    // The original spelled this out as colorWithRed:0 green:0 blue:0 alpha:1.
    layer.backgroundColor = UIColor.blackColor.CGColor;
    [self.baseView.layer addSublayer:layer];
    return layer;
}

- (NSArray<CALayer *> *)grayLayers {
    return @[
        self.grayTL,
        self.grayTR,
        self.grayBL,
        self.grayBR,
        self.grayCTL,
        self.grayCTR,
        self.grayCBL,
        self.grayCBR
    ];
}

- (CALayer *)addGrayCornerLayerToBase:(unsigned int)texType {
    CALayer *layer = [CALayer layer];
    UIImage *cornerClip = [self.messageImage clipImageWithRect:[self getClipRect:texType]];
    layer.contents = (__bridge id)cornerClip.CGImage;
    layer.hidden = YES;
    [self.baseView.layer addSublayer:layer];
    return layer;
}

#pragma mark - Presentation

- (void)showAnimationWithTutorialType:(unsigned int)tutorialType withRootView:(UIView *)rootView {
    /** @ghidraAddress 0x139af8 */
    if (self.animating) {
        return;
    }
    [self.musicMenuView setPastelForTutorialStart];
    self.animating = YES;
    self.clipRootView = rootView;

    __weak RBMenuTutorialView *weakSelf = self;
    [UIView animateWithDuration:kOverlayFadeDuration
        animations:^{
          /** @ghidraAddress 0x139cbc */
          weakSelf.alpha = 1.0;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x139d1c */
          weakSelf.animating = NO;
          weakSelf.alpha = 1.0;
          if (tutorialType != kTutorialStepNone) {
              [weakSelf startTutorialWithType:tutorialType withAnimation:YES];
          }
        }];
}

- (void)hideAnimation {
    /** @ghidraAddress 0x139e04 */
    if (self.animating) {
        return;
    }
    [self.musicMenuView setPastelForTutorialEnd];
    self.animating = YES;

    __weak RBMenuTutorialView *weakSelf = self;
    [UIView animateWithDuration:kOverlayFadeDuration
        animations:^{
          /** @ghidraAddress 0x139f7c */
          weakSelf.alpha = 0.0;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x139fdc */
          [weakSelf teardown];
        }];
}

- (void)teardown {
    /** @ghidraAddress 0x139fdc */
    self.animating = NO;
    self.alpha = 0.0;

    [self.pastelLayer stopAnimation];
    [self animationDelete:self.pastelLayer];
    [self animationDelete:self.messageWindowLayer];
    [self animationDelete:self.messageLayer];
    [self animationDelete:self.layer];
    [self stopCursorAnimation:self];
    [self stopTouchAnimation:self];

    for (CALayer *gray in [self grayLayers]) {
        [self animationDelete:gray];
        gray.contents = nil;
    }
    self.messageWindowLayer.contents = nil;
    self.messageLayer.contents = nil;

    if (static_cast<int>(self.tutorialStatus) == kTutorialStepCloseCustomize) {
        [self.musicMenuView closeCustomize];
    }
    [self.musicMenuView setTutorialView:nil];
    self.contentView.layer.sublayers = nil;
    [self removeFromSuperview];
}

#pragma mark - Taps

- (void)tap:(id)sender {
    /** @ghidraAddress 0x13aac4 */
    if ([RBTutorialManager isTutorialMusicselect]) {
        return;
    }
    if ([RBTutorialManager isTutorialCustomize] &&
        [RBTutorialManager getCurrentStatus] <= kTutorialStepCustomizeItem) {
        return;
    }
    [self hideAnimation];
}

#pragma mark - Tutorial steps

- (void)startTutorialWithType:(unsigned int)tutorialType withRootView:(UIView *)rootView {
    /** @ghidraAddress 0x13b8fc */
    self.clipRootView = rootView;
    [self startTutorialWithType:tutorialType withAnimation:YES];
}

- (void)startTutorialWithType:(unsigned int)tutorialType withAnimation:(BOOL)animation {
    /** @ghidraAddress 0x13ab34 */
    [self stopCursorAnimation:self];
    [self stopTouchAnimation:self];
    self.clipTargetForTouch = NO;

    if (tutorialType == kTutorialStepSettingButton) {
        RBUserSettingData *settings = [RBUserSettingData sharedInstance];
        if ([settings getTutorialStatus:kTutorialStepSettingButton] != kTutorialSeenValue) {
            [[RBExperienceData sharedInstance] addPoint:kCustomizeTutorialRewardPoints];
            [[RBExperienceData sharedInstance] save];
            [settings updateTutorialStatus:kTutorialStepSettingButton value:kTutorialSeenValue];
            SoundEffectManager::GetInstance()->PlayThemedSoundEffect(kSoundEffectDecide);
        }
    }

    self.tutorialStatus = tutorialType;
    [RBTutorialManager updateStatus:static_cast<RBTutorialStatus>(self.tutorialStatus)];
    self.animating = YES;

    // The per-step button getters live on several unrelated provider views with no shared
    // protocol, so the binary dispatches them dynamically through a bare view.
    id clipRoot = self.clipRootView;

    BOOL touchAnim = NO;
    BOOL cursorAnim = NO;
    BOOL stay = NO;
    BOOL laidOut = YES;

    switch (tutorialType) {
    case kTutorialStepMusicSelectA:
    case kTutorialStepMusicSelectB:
        [self layoutBackground:self.clipTargetView withAnimation:animation];
        break;
    case kTutorialStepCollectionView:
        self.clipTargetView = [self.musicMenuView getCollectionView];
        [self layoutBackground:self.clipTargetView withAnimation:animation];
        cursorAnim = YES;
        stay = YES;
        break;
    case kTutorialStepMusicCell:
        self.clipTargetView = [self.musicMenuView getTutorialMusicCell];
        self.clipTargetForTouch = YES;
        [self layoutBackground:self.clipTargetView withAnimation:animation];
        touchAnim = YES;
        break;
    case kTutorialStepDifficultyBasic:
        self.clipTargetView = [clipRoot getDifficultyButton:kDifficultyButtonBasic];
        [self layoutBackground:self.clipTargetView withAnimation:animation];
        cursorAnim = YES;
        break;
    case kTutorialStepDifficultyMedium:
        self.clipTargetView = [clipRoot getDifficultyButton:kDifficultyButtonMedium];
        [self layoutBackground:self.clipTargetView withAnimation:animation];
        cursorAnim = YES;
        break;
    case kTutorialStepDifficultyHard:
        self.clipTargetView = [clipRoot getDifficultyButton:kDifficultyButtonHard];
        [self layoutBackground:self.clipTargetView withAnimation:animation];
        cursorAnim = YES;
        break;
    case kTutorialStepDoubleButton:
        self.clipTargetView = [clipRoot getDoubleButton];
        [self layoutBackground:self.clipTargetView withAnimation:animation];
        cursorAnim = YES;
        break;
    case kTutorialStepDecideButton:
        self.clipTargetView = [clipRoot getDecideButton];
        self.clipTargetForTouch = YES;
        [self layoutBackground:self.clipTargetView withAnimation:animation];
        touchAnim = YES;
        break;
    case kTutorialStepPlayIntro:
    case kTutorialStepReportOnlyFirst:
    case 0x13:
    case 0x14:
    case 0x15:
    case 0x16:
    case kTutorialStepReportOnlyLast:
        self.clipRootView = nil;
        self.clipTargetView = nil;
        laidOut = NO;
        break;
    case kTutorialStepNoTarget:
        self.clipTargetView = nil;
        [self layoutBackground:nil withAnimation:animation];
        break;
    case kTutorialStepFullScreen:
        [self layoutBackground:nil withAnimation:animation];
        break;
    case kTutorialStepSettingButton:
        self.clipTargetView = [self.musicMenuView getSettingButton];
        self.clipTargetForTouch = YES;
        [self layoutBackground:self.clipTargetView withAnimation:animation];
        touchAnim = YES;
        break;
    case kTutorialStepSettingButtonB:
        self.clipTargetView = [self.musicMenuView getSettingButton];
        self.clipTargetForTouch = YES;
        [self layoutBackground:self.clipTargetView withAnimation:animation];
        touchAnim = YES;
        break;
    case kTutorialStepCustomizeButton:
        self.clipTargetView = [clipRoot getCustomizeButtonView];
        self.clipTargetForTouch = YES;
        [self layoutBackground:self.clipTargetView withAnimation:animation];
        break;
    case kTutorialStepUnlockButton:
        self.clipTargetView = [clipRoot getUnlockButtonView];
        self.clipTargetForTouch = YES;
        [self layoutBackground:self.clipTargetView withAnimation:animation];
        touchAnim = YES;
        break;
    case kTutorialStepUnlockItem:
        self.clipTargetView = [clipRoot getUnlockItemView];
        self.clipTargetForTouch = YES;
        [self layoutBackground:self.clipTargetView withAnimation:animation];
        break;
    case kTutorialStepCustomButton:
        self.clipTargetView = [clipRoot getCustomButtonView];
        self.clipTargetForTouch = YES;
        [self layoutBackground:self.clipTargetView withAnimation:animation];
        touchAnim = YES;
        break;
    case kTutorialStepCustomizeItem:
        self.clipTargetView = [clipRoot getCustomizeItemView];
        self.clipTargetForTouch = NO;
        [self layoutBackground:self.clipTargetView withAnimation:animation];
        break;
    case kTutorialStepCloseCustomize:
        self.clipTargetView = nil;
        [self layoutBackground:self.clipTargetView withAnimation:animation];
        break;
    default:
        laidOut = NO;
        break;
    }

    if (laidOut) {
        [self contentViewSettingWithTouchAnim:touchAnim
                                   cursorAnim:cursorAnim
                                         stay:stay
                                 useAnimation:animation];
    }

    [self.superview bringSubviewToFront:self];
    if (!animation) {
        self.animating = NO;
    }
}

#pragma mark - Spotlight layout

- (void)setClipRect {
    /** @ghidraAddress 0x13b974 */
    if (self.clipTargetView == nil) {
        return;
    }
    UIView *superview = self.clipTargetView.superview;
    self.clipRect = [superview convertRect:self.clipTargetView.frame toView:self];
}

- (void)layoutBackground:(UIView *)targetView withAnimation:(BOOL)withAnimation {
    /** @ghidraAddress 0x13ba8c */
    if (targetView == nil) {
        [CATransaction begin];
        // The binary never reads withAnimation; it passes a literal zero duration here.
        [CATransaction setAnimationDuration:0.0];
        [CATransaction
            setAnimationTimingFunction:[CAMediaTimingFunction
                                           functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
        [CATransaction setDisableActions:YES];
        self.baseView.backgroundColor = UIColor.blackColor;
        self.grayTL.hidden = YES;
        self.grayTR.hidden = YES;
        self.grayBL.hidden = YES;
        self.grayBR.hidden = YES;
        self.grayCTL.hidden = YES;
        self.grayCTR.hidden = YES;
        self.grayCBL.hidden = YES;
        self.grayCBR.hidden = YES;
        [CATransaction commit];
        return;
    }

    CGRect targetRect = [targetView.superview convertRect:targetView.frame toView:self];
    CGRect clip = targetRect;
    // The test narrows to single precision and floors (fcvt/frintm) rather than truncating.
    if (static_cast<double>(std::floor(static_cast<float>(targetRect.origin.x))) !=
        targetRect.origin.x) {
        clip.origin.x = targetRect.origin.x - kSpotlightPixelSnap;
        clip.size.width = targetRect.size.width + kSpotlightPixelGrow;
    }
    if (static_cast<double>(std::floor(static_cast<float>(targetRect.origin.y))) !=
        targetRect.origin.y) {
        clip.origin.y = targetRect.origin.y - kSpotlightPixelSnap;
        clip.size.height = targetRect.size.height + kSpotlightPixelGrow;
    }
    self.clipRect = clip;

    [CATransaction begin];
    [CATransaction
        setAnimationTimingFunction:[CAMediaTimingFunction
                                       functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
    [CATransaction setDisableActions:YES];
    self.baseView.backgroundColor = UIColor.clearColor;
    self.grayTL.hidden = NO;
    self.grayTR.hidden = NO;
    self.grayBL.hidden = NO;
    self.grayBR.hidden = NO;
    self.grayCTL.hidden = NO;
    self.grayCTR.hidden = NO;
    self.grayCBL.hidden = NO;
    self.grayCBR.hidden = NO;

    CGRect spot = self.clipRect;
    self.grayTL.frame = CGRectMake(spot.origin.x + spot.size.width - self.width,
                                   spot.origin.y - self.height,
                                   self.width,
                                   self.height);
    self.grayTR.frame = CGRectMake(spot.origin.x + spot.size.width,
                                   spot.origin.y + spot.size.height - self.height,
                                   self.width,
                                   self.height);
    self.grayBL.frame =
        CGRectMake(spot.origin.x, spot.origin.y + spot.size.height, self.width, self.height);
    self.grayBR.frame =
        CGRectMake(spot.origin.x - self.width, spot.origin.y, self.width, self.height);
    self.grayCTL.frame = CGRectMake(spot.origin.x,
                                    spot.origin.y,
                                    self.grayCTL.frame.size.width,
                                    self.grayCTL.frame.size.height);
    self.grayCTR.frame = CGRectMake(spot.origin.x + spot.size.width - self.grayCTR.frame.size.width,
                                    spot.origin.y,
                                    self.grayCTR.frame.size.width,
                                    self.grayCTR.frame.size.height);
    self.grayCBL.frame =
        CGRectMake(spot.origin.x,
                   spot.origin.y + spot.size.height - self.grayCBL.frame.size.height,
                   self.grayCBL.frame.size.width,
                   self.grayCBL.frame.size.height);
    self.grayCBR.frame =
        CGRectMake(spot.origin.x + spot.size.width - self.grayCBR.frame.size.width,
                   spot.origin.y + spot.size.height - self.grayCBR.frame.size.height,
                   self.grayCBR.frame.size.width,
                   self.grayCBR.frame.size.height);
    [CATransaction commit];
}

#pragma mark - Content-view placement

- (void)contentViewSettingWithTouchAnim:(BOOL)touchAnim
                             cursorAnim:(BOOL)cursorAnim
                                   stay:(BOOL)stay
                           useAnimation:(BOOL)useAnimation {
    /** @ghidraAddress 0x13cfe8 */
    CGRect content = self.contentView.frame;
    CGRect spot = self.clipRect;

    // CGRectZero means "no move": -startAnimation:/-resetAnimation: test for it to decide whether
    // to run the move group.
    CGRect placed = CGRectZero;

    if (spot.origin.y <= content.origin.y + content.size.height && !stay &&
        content.origin.y <= spot.origin.y + spot.size.height) {
        CGFloat spotBottom = spot.origin.y + spot.size.height;
        placed = content;
        if (self.height * 0.5 <= (spot.origin.y + spotBottom) * 0.5) {
            placed.origin.y = (spot.origin.y - content.size.height) - kContentViewSpotlightGap;
            if (placed.origin.y < 0.0) {
                placed.origin.y = 0.0;
            }
        } else {
            placed.origin.y = spotBottom + kContentViewSpotlightGap;
            if (self.height < placed.origin.y + content.size.height) {
                placed.origin.y = self.height - content.size.height;
            }
        }
    }

    if (useAnimation) {
        [self startAnimation:placed];
    } else {
        [self resetAnimation:placed];
    }

    if (touchAnim) {
        [self startTouchAnimation:self];
    }
    if (cursorAnim) {
        [self startCursorAnimation:self];
    }
}

#pragma mark - Cursor and touch markers

- (void)startCursorAnimation:(RBMenuTutorialView *)view {
    /** @ghidraAddress 0x13d510 */
    if (view.clipTargetView == nil) {
        return;
    }
    CGRect spot = view.clipRect;
    view.cursorView.frame =
        CGRectMake(spot.origin.x + spot.size.width * 0.5 - view.cursorView.width * 0.5,
                   spot.origin.y + spot.size.height + view.cursorView.height * 0.25,
                   view.cursorView.width,
                   view.cursorView.height);
    view.cursorView.hidden = NO;
    CAKeyframeAnimation *bob =
        [RBAnimationFactory createAnimHereWithDuration:kCursorBobDuration
                                                     Y:view.cursorView.y
                                           repeatCount:kCursorBobRepeatCount];
    [view.cursorView.layer addAnimation:bob forKey:kCursorAnimationKey];
}

- (void)stopCursorAnimation:(RBMenuTutorialView *)view {
    /** @ghidraAddress 0x13d878 */
    if (view.cursorView != nil) {
        view.cursorView.hidden = YES;
    }
}

- (void)startTouchAnimation:(RBMenuTutorialView *)view {
    /** @ghidraAddress 0x13d920 */
    if (view.clipTargetView == nil) {
        return;
    }
    CGRect spot = view.clipRect;
    view.touchView.frame =
        CGRectMake((spot.origin.x + spot.size.width) - view.touchView.width,
                   spot.origin.y + spot.size.height + view.touchView.height * -0.5,
                   view.touchView.width,
                   view.touchView.height);
    view.touchView.hidden = NO;
    [view.touchView startAnimating];
}

- (void)stopTouchAnimation:(RBMenuTutorialView *)view {
    /** @ghidraAddress 0x13dbc4 */
    self.touchView.hidden = YES;
    [self.touchView stopAnimating];
}

#pragma mark - Message reveal animations

- (void)animationDelete:(CALayer *)layer {
    /** @ghidraAddress 0x13dc6c */
    if (layer.animationKeys == nil || layer.animationKeys.count == 0) {
        return;
    }
    for (CALayer *sublayer in layer.sublayers) {
        [sublayer removeAllAnimations];
    }
    [layer removeAllAnimations];
}

- (void)startAnimation:(CGRect)targetFrame {
    /** @ghidraAddress 0x13de2c */
    for (CALayer *sublayer in self.messageLayer.sublayers) {
        if ([sublayer.name isEqualToString:self.showLayerTag]) {
            [sublayer removeAllAnimations];
        }
    }
    [self animationDelete:self.contentView.layer];

    CGRect messageClip = [self getClipRect:[self getTextureType]];
    CGSize atlasSize = self.messageImage.size;
    CGRect windowFrame = self.messageWindowLayer.frame;
    BOOL narrow = !IsPad();
    CGRect fullClip = [self getClipRect:kTutorialClipRectMessageWide];

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.messageLayer.opacity = 0.0;
    self.messageLayer.frame = CGRectMake(
        windowFrame.origin.x + (narrow ? kMessageWindowInsetXNarrow : kMessageWindowInsetXWide),
        (fullClip.size.height - messageClip.size.height) * 0.5 + windowFrame.origin.y +
            (narrow ? kMessageWindowInsetYNarrow : kMessageWindowInsetYWide),
        messageClip.size.width,
        messageClip.size.height);
    self.messageLayer.contentsRect = CGRectMake(messageClip.origin.x / atlasSize.width,
                                                messageClip.origin.y / atlasSize.height,
                                                messageClip.size.width / atlasSize.width,
                                                messageClip.size.height / atlasSize.height);
    [CATransaction commit];

    if (self.tutorialStatus == kTutorialStepMusicSelectA ||
        self.tutorialStatus == kTutorialStepNoTarget) {
        RevealBubbleOnly(self);
    } else if (CGRectEqualToRect(targetFrame, CGRectZero)) {
        RevealBubbleAndMessage(self);
    } else {
        RevealBubbleMessageAndMove(self, targetFrame);
    }
}

static inline void RevealBubbleOnly(RBMenuTutorialView *view) {
    // The pastel group, not the window's, carries the delegate that ends the step.
    CAAnimationGroup *pastelGroup = [CAAnimationGroup animation];
    CAKeyframeAnimation *pastelFade = [RBAnimationFactory createFadeAnimWithFromValue:0.0
                                                                              toValue:1.0
                                                                                delay:0.0
                                                                             duration:0.1];
    CAKeyframeAnimation *pastelScale = [RBAnimationFactory createScaleAnimWithFromValue:0.0
                                                                                toValue:1.0
                                                                                      X:NO
                                                                                      Y:YES
                                                                                  delay:0.0
                                                                               duration:0.2];
    CAKeyframeAnimation *pastelBound = [RBAnimationFactory createBoundAnimWithX:NO
                                                                              Y:YES
                                                                          delay:0.2
                                                                       duration:0.3];
    pastelGroup.animations = @[ pastelFade, pastelScale, pastelBound ];
    pastelGroup.duration = 0.5;
    pastelGroup.removedOnCompletion = NO;
    pastelGroup.fillMode = kCAFillModeForwards;

    CAAnimationGroup *windowGroup = [CAAnimationGroup animation];
    CAKeyframeAnimation *windowFade = [RBAnimationFactory createFadeAnimWithFromValue:0.0
                                                                              toValue:1.0
                                                                                delay:0.0
                                                                             duration:0.1];
    CAKeyframeAnimation *windowScale = [RBAnimationFactory createScaleAnimWithFromValue:0.0
                                                                                toValue:1.0
                                                                                      X:YES
                                                                                      Y:NO
                                                                                  delay:0.0
                                                                               duration:0.2];
    windowGroup.animations = @[ windowFade, windowScale ];
    windowGroup.duration = 0.2;
    windowGroup.removedOnCompletion = NO;
    windowGroup.fillMode = kCAFillModeForwards;

    CAAnimationGroup *messageGroup = [CAAnimationGroup animation];
    CAKeyframeAnimation *messageFade = [RBAnimationFactory createFadeAnimWithFromValue:0.0
                                                                               toValue:1.0
                                                                                 delay:0.2
                                                                              duration:0.1];
    messageGroup.animations = @[ messageFade ];
    // The group must reach 0.2 + 0.1 or the clip drops the fade and the text never appears.
    messageGroup.duration = 0.3;
    messageGroup.removedOnCompletion = NO;
    messageGroup.fillMode = kCAFillModeForwards;

    pastelGroup.delegate = view;
    [view.messageWindowLayer addAnimation:windowGroup forKey:nil];
    [view.pastelLayer addAnimation:pastelGroup forKey:nil];
    [view.messageLayer addAnimation:messageGroup forKey:nil];
}

static inline void RevealBubbleAndMessage(RBMenuTutorialView *view) {
    CAAnimationGroup *messageGroup = [CAAnimationGroup animation];
    CAKeyframeAnimation *messageFadeOut = [RBAnimationFactory createFadeAnimWithFromValue:0.0
                                                                                  toValue:0.0
                                                                                    delay:0.0
                                                                                 duration:0.2];
    CAKeyframeAnimation *messageFadeIn = [RBAnimationFactory createFadeAnimWithFromValue:0.0
                                                                                 toValue:1.0
                                                                                   delay:0.2
                                                                                duration:0.1];
    messageGroup.animations = @[ messageFadeOut, messageFadeIn ];
    messageGroup.duration = 0.3;
    messageGroup.removedOnCompletion = NO;
    messageGroup.fillMode = kCAFillModeForwards;

    CAAnimationGroup *pastelGroup = [CAAnimationGroup animation];
    CAKeyframeAnimation *pastelBound = [RBAnimationFactory createBoundAnimWithX:NO
                                                                              Y:YES
                                                                          delay:0.1
                                                                       duration:0.3];
    pastelGroup.animations = @[ pastelBound ];
    pastelGroup.duration = 0.4;
    pastelGroup.removedOnCompletion = NO;
    pastelGroup.fillMode = kCAFillModeForwards;

    [RBAnimationFactory animationDelete:view.pastelLayer];
    pastelGroup.delegate = view;
    [view.messageLayer addAnimation:messageGroup forKey:nil];
    [view.pastelLayer addAnimation:pastelGroup forKey:nil];
}

static inline void RevealBubbleMessageAndMove(RBMenuTutorialView *view, CGRect targetFrame) {
    CGPoint contentOrigin = CGPointMake(view.contentView.x, view.contentView.y);

    CAAnimationGroup *messageGroup = [CAAnimationGroup animation];
    CAKeyframeAnimation *messageFadeOut = [RBAnimationFactory createFadeAnimWithFromValue:0.0
                                                                                  toValue:0.0
                                                                                    delay:0.0
                                                                                 duration:0.4];
    CAKeyframeAnimation *messageFadeIn = [RBAnimationFactory createFadeAnimWithFromValue:0.0
                                                                                 toValue:1.0
                                                                                   delay:0.6
                                                                                duration:0.1];
    messageGroup.animations = @[ messageFadeOut, messageFadeIn ];
    messageGroup.duration = 0.7;
    messageGroup.removedOnCompletion = NO;
    messageGroup.fillMode = kCAFillModeForwards;

    CAAnimationGroup *pastelGroup = [CAAnimationGroup animation];
    CAKeyframeAnimation *pastelScaleUp = [RBAnimationFactory createScaleAnimWithFromValue:1.0
                                                                                  toValue:0.0
                                                                                        X:NO
                                                                                        Y:YES
                                                                                    delay:0.0
                                                                                 duration:0.2];
    CAKeyframeAnimation *pastelScaleDown = [RBAnimationFactory createScaleAnimWithFromValue:0.0
                                                                                    toValue:1.0
                                                                                          X:NO
                                                                                          Y:YES
                                                                                      delay:0.3
                                                                                   duration:0.2];
    CAKeyframeAnimation *pastelBound = [RBAnimationFactory createBoundAnimWithX:NO
                                                                              Y:YES
                                                                          delay:0.5
                                                                       duration:0.3];
    pastelGroup.animations = @[ pastelScaleUp, pastelScaleDown, pastelBound ];
    // A group clips its children, so this must reach the bound bob's end (0.5 + 0.3) or the
    // forwards fill freezes the bubble shrunk.
    pastelGroup.duration = 0.8;
    pastelGroup.removedOnCompletion = NO;
    pastelGroup.fillMode = kCAFillModeForwards;

    CAAnimationGroup *windowGroup = [CAAnimationGroup animation];
    CAKeyframeAnimation *windowScaleUp = [RBAnimationFactory createScaleAnimWithFromValue:1.0
                                                                                  toValue:0.0
                                                                                        X:YES
                                                                                        Y:NO
                                                                                    delay:0.1
                                                                                 duration:0.2];
    CAKeyframeAnimation *windowScaleDown = [RBAnimationFactory createScaleAnimWithFromValue:0.0
                                                                                    toValue:1.0
                                                                                          X:YES
                                                                                          Y:NO
                                                                                      delay:0.4
                                                                                   duration:0.2];
    windowGroup.animations = @[ windowScaleUp, windowScaleDown ];
    // Must reach 0.4 + 0.2 or the forwards fill leaves the quote box collapsed to zero width.
    windowGroup.duration = 0.6;
    windowGroup.removedOnCompletion = NO;
    windowGroup.fillMode = kCAFillModeForwards;

    CGPoint contentPosition = view.contentView.layer.position;
    CGPoint moveTo = CGPointMake(contentPosition.x - (contentOrigin.x - targetFrame.origin.x),
                                 contentPosition.y - (contentOrigin.y - targetFrame.origin.y));
    [RBMenuTutorialView createAnimWithKeyPath:kContentPositionKeyPath
                                    fromValue:contentPosition
                                      toValue:moveTo
                                        delay:0.0
                                     duration:0.3];
    pastelGroup.delegate = view;
    [view.pastelLayer addAnimation:pastelGroup forKey:nil];
    [view.messageWindowLayer addAnimation:windowGroup forKey:nil];
    [view.messageLayer addAnimation:messageGroup forKey:nil];

    __weak UIView *weakContentView = view.contentView;
    [UIView animateWithDuration:0.01
        delay:0.3
        options:UIViewAnimationOptionCurveLinear
        animations:^{
          /** @ghidraAddress 0x13f784 */
          weakContentView.frame = targetFrame;
        }
        completion:^(BOOL finished) {
          // The binary passes an empty global block here rather than nil.
          (void)finished;
        }];
}

- (void)resetAnimation:(CGRect)targetFrame {
    /** @ghidraAddress 0x13f7f0 */
    for (CALayer *sublayer in self.messageLayer.sublayers) {
        if ([sublayer.name isEqualToString:self.showLayerTag]) {
            [sublayer removeAllAnimations];
        }
    }
    [self animationDelete:self.contentView.layer];

    CGRect messageClip = [self getClipRect:[self getTextureType]];
    CGSize atlasSize = self.messageImage.size;
    CGRect windowFrame = self.messageWindowLayer.frame;
    BOOL narrow = !IsPad();
    CGRect fullClip = [self getClipRect:kTutorialClipRectMessageWide];

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.messageLayer.opacity = 1.0;
    self.messageLayer.frame = CGRectMake(
        windowFrame.origin.x + (narrow ? kMessageWindowInsetXNarrow : kMessageWindowInsetXWide),
        (fullClip.size.height - messageClip.size.height) * 0.5 + windowFrame.origin.y +
            (narrow ? kMessageWindowInsetYNarrow : kMessageWindowInsetYWide),
        messageClip.size.width,
        messageClip.size.height);
    self.messageLayer.contentsRect = CGRectMake(messageClip.origin.x / atlasSize.width,
                                                messageClip.origin.y / atlasSize.height,
                                                messageClip.size.width / atlasSize.width,
                                                messageClip.size.height / atlasSize.height);
    [CATransaction commit];

    if (self.tutorialStatus != kTutorialStepMusicSelectA &&
        self.tutorialStatus != kTutorialStepNoTarget &&
        !CGRectEqualToRect(targetFrame, CGRectZero)) {
        SnapContentViewOpaqueMovingTo(self, targetFrame);
    } else {
        SnapContentViewOpaque(self);
    }
}

static inline void SnapContentViewOpaqueMovingTo(RBMenuTutorialView *view, CGRect targetFrame) {
    CGPoint contentOrigin = CGPointMake(view.contentView.x, view.contentView.y);
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    view.messageWindowLayer.opacity = 1.0;
    view.messageWindowLayer.contentsScale = 1.0;
    view.pastelLayer.opacity = 1.0;
    view.pastelLayer.contentsScale = 1.0;
    CGPoint contentPosition = view.contentView.layer.position;
    view.contentView.layer.position =
        CGPointMake(contentPosition.x - (contentOrigin.x - targetFrame.origin.x),
                    contentPosition.y - (contentOrigin.y - targetFrame.origin.y));
    [CATransaction commit];
    view.contentView.layer.opacity = 1.0;
}

static inline void SnapContentViewOpaque(RBMenuTutorialView *view) {
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    view.messageWindowLayer.opacity = 1.0;
    view.messageWindowLayer.contentsScale = 1.0;
    view.pastelLayer.opacity = 1.0;
    view.pastelLayer.contentsScale = 1.0;
    [CATransaction commit];
    view.contentView.layer.opacity = 1.0;
}

#pragma mark - Clip-rect table

- (unsigned int)getTextureType {
    /** @ghidraAddress 0x14040c */
    switch (self.tutorialStatus) {
    case kTutorialStepMusicSelectA:
    case kTutorialStepMusicSelectB:
    case kTutorialStepCollectionView:
    case kTutorialStepMusicCell:
    case kTutorialStepFullScreen:
    case kTutorialStepDifficultyBasic:
    case kTutorialStepDifficultyMedium:
    case kTutorialStepDifficultyHard:
    case kTutorialStepDoubleButton:
        return static_cast<unsigned int>(self.tutorialStatus);
    case kTutorialStepDecideButton:
        return !IsPad() ? 10 : 9;
    case kTutorialStepNoTarget:
        return 0xb;
    case kTutorialStepSettingButton:
        return 0xc;
    case kTutorialStepSettingButtonB:
        return 0xd;
    case kTutorialStepCustomizeButton:
        return 0xe;
    case kTutorialStepCustomizeMessage:
        return 0xf;
    case kTutorialStepUnlockButton:
        return 0x10;
    case kTutorialStepUnlockItem:
    case kTutorialStepUnlockMessage:
        return 0x11;
    case kTutorialStepCustomButton:
        return 0x12;
    case kTutorialStepCustomizeItem:
        return 0x13;
    case kTutorialStepCloseCustomize:
        return 0x14;
    default:
        return kTutorialStepCloseCustomize;
    }
}

- (CGRect)getClipRect:(unsigned int)texType {
    /** @ghidraAddress 0x140544 */
    CGRect rect = g_pTutorialClipRect[texType];
    if (!IsPad()) {
        rect.origin.x *= 0.5;
        rect.origin.y *= 0.5;
        rect.size.width *= 0.5;
        rect.size.height *= 0.5;
    }
    return rect;
}

#pragma mark - Move animation builder

+ (CAAnimationGroup *)createAnimWithKeyPath:(NSString *)keyPath
                                  fromValue:(CGPoint)fromValue
                                    toValue:(CGPoint)toValue
                                      delay:(double)delay
                                   duration:(double)duration {
    /** @ghidraAddress 0x1405c8 */
    // The keyPath argument is unused; the component key paths are fixed at position.x/position.y.
    CAKeyframeAnimation *xAnim = [CAKeyframeAnimation animationWithKeyPath:@"position.x"];
    xAnim.beginTime = delay;
    xAnim.duration = duration;
    xAnim.repeatCount = 0;
    xAnim.values = @[ @(fromValue.x), @(toValue.x) ];
    xAnim.keyTimes = @[ @0.0f, @1.0f ];
    xAnim.timingFunctions =
        @[ [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn] ];
    xAnim.removedOnCompletion = NO;
    xAnim.fillMode = kCAFillModeForwards;

    CAKeyframeAnimation *yAnim = [CAKeyframeAnimation animationWithKeyPath:@"position.y"];
    yAnim.beginTime = delay;
    yAnim.duration = duration;
    yAnim.repeatCount = 0;
    yAnim.values = @[ @(fromValue.y), @(toValue.y) ];
    yAnim.keyTimes = @[ @0.0f, @1.0f ];
    yAnim.timingFunctions =
        @[ [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn] ];
    yAnim.removedOnCompletion = NO;
    yAnim.fillMode = kCAFillModeForwards;

    CAAnimationGroup *group = [CAAnimationGroup animation];
    group.animations = @[ xAnim, yAnim ];
    group.removedOnCompletion = NO;
    group.fillMode = kCAFillModeForwards;
    return group;
}

#pragma mark - Hit testing

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    /** @ghidraAddress 0x13c8a0 */
    if (self.animating || [RBTutorialManager getCurrentStatus] == kTutorialStepNone ||
        [RBTutorialManager getCurrentStatus] == kTutorialStepCloseCustomize) {
        return self;
    }

    if (self.clipRect.size.width == 0.0) {
        self.tutorialStatus = self.tutorialStatus + 1;
        if (self.tutorialStatus == kTutorialStepSettingButton &&
            [[RBUserSettingData sharedInstance] getTutorialStatus:kTutorialStepSettingButton] ==
                kTutorialSeenValue) {
            self.tutorialStatus = self.tutorialStatus + 1;
        }
        [self startTutorialWithType:self.tutorialStatus withAnimation:YES];
        return self;
    }

    if (!self.clipTargetForTouch) {
        // The phone layout has no DOUBLE-play button, so its step is skipped.
        self.tutorialStatus = self.tutorialStatus + 1;
        if (!IsPad() && self.tutorialStatus == kTutorialStepDoubleButton) {
            self.tutorialStatus = self.tutorialStatus + 1;
        }
        [self startTutorialWithType:self.tutorialStatus withAnimation:YES];
        return self;
    }

    // Returning nil lets a tap inside the spotlight fall through to the highlighted control.
    CGRect spot = self.clipRect;
    BOOL inside = spot.origin.x <= point.x && point.x <= spot.origin.x + spot.size.width &&
                  spot.origin.y <= point.y && point.y <= spot.origin.y + spot.size.height;
    if (inside) {
        return nil;
    }
    return self;
}

#pragma mark - Rotation

- (void)willRotate {
    /** @ghidraAddress 0x13cb4c */
    self.fullCoverView.alpha = kRotationDimAlpha;
    self.baseView.alpha = 0.0;
    self.contentView.alpha = 0.0;

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    for (CALayer *sublayer in self.messageLayer.sublayers) {
        sublayer.opacity = 0.0;
    }
    [CATransaction commit];

    self.animating = YES;
    [self stopCursorAnimation:self];
    [self stopTouchAnimation:self];
}

- (void)didRotate {
    /** @ghidraAddress 0x13cdd4 */
    self.fullCoverView.alpha = 0.0;
    self.baseView.alpha = kRotationDimAlpha;
    self.contentView.frame = CGRectMake(self.width * 0.5 - self.contentViewWidth * 0.5f,
                                        self.height * 0.5 - self.contentViewHeight * 0.5f,
                                        self.contentViewWidth,
                                        self.contentViewHeight);
    self.contentView.alpha = 0.0;
    self.animating = NO;
    [self startTutorialWithType:self.tutorialStatus withAnimation:NO];
}

#pragma mark - Animation delegate

- (void)animationDidStop:(CAAnimation *)animation finished:(BOOL)finished {
    /** @ghidraAddress 0x1405a8 */
    self.animating = NO;
}

@end
