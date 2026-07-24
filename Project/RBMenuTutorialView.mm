//
//  RBMenuTutorialView.mm
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RBMenuTutorialView). Verified
//  against the arm64 disassembly: the soft-float spotlight geometry, the per-step clip-target
//  selection, and the reveal/reset keyframe groups were recovered from the register moves the
//  decompiler folds into pseudo-variables. This is an Objective-C++ file because the customize-item
//  reward path plays a themed sound effect through the C++ SoundEffectManager engine singleton.
//

#import "RBMenuTutorialView.h"

#import "RBAnimationFactory.h"
#import "RBExperienceData.h"
#import "RBMenuView.h"
#import "RBTutorialManager.h"
#import "RBTutorialPastelLayer.h"
#import "RBUserSettingData.h"
#import "UIImage+RB.h"
#import "deviceenvironment.h"
#import "soundeffectmanager.h"

// The per-texture-type source rectangles into the tutorial artwork atlas, read by -getClipRect:.
// @ghidraAddress 0x3de058 (g_pTutorialClipRect)
extern "C" const CGRect g_pTutorialClipRect[];

// The tutorial message artwork atlas the per-step message and marker clips are cut from.
static NSString *const kTutorialArtworkImageName = @"10_tutorial/tu_tex01";

// The key under which the bouncing cursor's stay-in-place bob is attached to the cursor layer.
static NSString *const kCursorAnimationKey = @"here";

// The layer key path the content-view move animation is built on.
static NSString *const kContentPositionKeyPath = @"position";

// The message content-view dimensions, chosen by the iPad idiom. The default (narrow) variant
// uses a smaller bubble than the wide variant.
constexpr CGFloat kContentWidthNarrow = 300.0;
constexpr CGFloat kContentHeightNarrow = 100.0;
constexpr CGFloat kContentWidthWide = 640.0;
constexpr CGFloat kContentHeightWide = 300.0;

// The experience points granted once, the first time the customize-item tutorial step is reached.
constexpr float kCustomizeTutorialRewardPoints = 1000.0f;

// The value the persisted tutorial-status map stores once a step has been seen.
constexpr unsigned int kTutorialSeenValue = 1;

// The themed sound-effect slot played when the customize-item reward is first granted.
constexpr int kSoundEffectDecide = 9;

// Clip-target texture-type identifiers, indexing the per-step message-artwork rectangle table read
// by -getClipRect:. The message, cursor, and touch-marker clips share this table.
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

// Tutorial step identifiers, as mirrored into -tutorialStatus. The music-select steps occupy the
// low range, the in-play steps the middle range, and the customize steps the high range. The step
// value selects which control the spotlight points at in -startTutorialWithType:withAnimation:.
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

// The three difficulty buttons the in-play tutorial highlights, in order.
enum {
    kDifficultyButtonBasic = 0,
    kDifficultyButtonMedium = 1,
    kDifficultyButtonHard = 2,
};

// The fade-in/fade-out overlay animation duration.
constexpr NSTimeInterval kOverlayFadeDuration = 0.25;

// Rotation dims the whole overlay to half opacity behind the black cover.
constexpr CGFloat kRotationDimAlpha = 0.5;

// The spotlight rectangle is snapped a half-pixel out when its origin is not already pixel-aligned.
constexpr CGFloat kSpotlightPixelSnap = 0.5;
constexpr CGFloat kSpotlightPixelGrow = 1.0;

// The message-window layer is inset within the content view by a idiom-dependent margin.
constexpr CGFloat kMessageWindowInsetXWide = 20.0;
constexpr CGFloat kMessageWindowInsetXNarrow = 26.0;
constexpr CGFloat kMessageWindowInsetYWide = 16.0;
constexpr CGFloat kMessageWindowInsetYNarrow = 8.0;
constexpr CGFloat kMessageWindowBaseInsetY = 20.0;

// The bouncing cursor's stay-in-place bob runs for half a second and never repeats.
constexpr CGFloat kCursorBobDuration = 0.5;
constexpr int kCursorBobRepeatCount = 0;

// The overlay and its full-cover tap target flex in every direction.
// @ghidraAddress 0x310450 (g_dwAutoresizingMaskFlexibleAll)
constexpr UIViewAutoresizing kAutoresizingMaskFlexibleAll =
    UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth |
    UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin |
    UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;

@implementation RBMenuTutorialView

#pragma mark - Lifecycle

- (instancetype)initWithFrame:(CGRect)frame {
    /** @ghidraAddress 0x37b0c */
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
    // The binary's -dealloc only chains to [super dealloc], which ARC does automatically. The
    // strong subview ivars and the weak layer/view references are cleared by the compiler-generated
    // .cxx_destruct (0x141334).
}

#pragma mark - Layout

- (void)setupView {
    /** @ghidraAddress 0x37bfc */
    self.alpha = 0.0;
    self.backgroundColor = UIColor.clearColor;
    self.autoresizingMask = kAutoresizingMaskFlexibleAll;

    BOOL narrow = !IsPad();

    // The dimming base fills the whole overlay at half opacity and hosts the eight grey layers.
    self.baseView = [[UIImageView alloc] initWithFrame:self.frame];
    self.baseView.autoresizingMask =
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.baseView.alpha = kRotationDimAlpha;
    [self addSubview:self.baseView];

    self.messageImage = [UIImage imageWithName:kTutorialArtworkImageName useCache:NO];

    // The message content view is centred in the overlay at its idiom-derived size.
    self.contentView =
        [[UIView alloc] initWithFrame:CGRectMake(self.width * 0.5 - self.contentViewWidth * 0.5,
                                                 self.height * 0.5 - self.contentViewHeight * 0.5,
                                                 self.contentViewWidth,
                                                 self.contentViewHeight)];
    [self addSubview:self.contentView];

    // The framed message-window layer holds the message artwork window.
    CALayer *windowLayer = [CALayer layer];
    UIImage *windowClip =
        narrow ?
            [self.messageImage clipImageWithRect:[self getClipRect:kTutorialTexTypeMessageNarrow]] :
            [self.messageImage clipImageWithRect:[self getClipRect:kTutorialTexTypeMessageWide]];
    windowLayer.contents = (__bridge id)windowClip.CGImage;
    if (narrow) {
        windowLayer.frame = CGRectMake(self.contentViewWidth * 0.5 + windowClip.size.width,
                                       self.contentViewHeight * 0.5,
                                       windowClip.size.width,
                                       windowClip.size.height);
    } else {
        windowLayer.frame = CGRectMake(self.contentViewWidth * 0.5 - windowClip.size.width,
                                       self.contentViewHeight * 0.25 + 3.0,
                                       windowClip.size.width,
                                       windowClip.size.height);
    }
    windowLayer.anchorPoint = CGPointMake(0.0, 1.0);
    windowLayer.opacity = 0.0;
    [self.contentView.layer addSublayer:windowLayer];
    self.messageWindowLayer = windowLayer;

    // The pastel speech bubble sits beside the window layer.
    RBTutorialPastelLayer *pastel = [[RBTutorialPastelLayer alloc] init];
    [pastel setupView:self.messageImage];
    if (narrow) {
        CGRect windowFrame = self.messageWindowLayer.frame;
        pastel.position = CGPointMake(windowFrame.origin.x - pastel.frame.size.width / 3.0,
                                      1.0 + windowFrame.size.height * 0.5);
    } else {
        CGRect windowFrame = self.messageWindowLayer.frame;
        pastel.position = CGPointMake(windowFrame.origin.x, 1.0 + windowFrame.size.height * 1.5);
    }
    pastel.anchorPoint = CGPointMake(0.5, 1.0);
    pastel.opacity = 0.0;
    [self.contentView.layer addSublayer:pastel];
    self.pastelLayer = pastel;

    // The message-text layer sits inside the window layer, inset by a iPad idiom margin.
    CALayer *messageLayer = [CALayer layer];
    messageLayer.anchorPoint = CGPointMake(0.5, 0.5);
    CGRect windowFrame = self.messageWindowLayer.frame;
    if (narrow) {
        messageLayer.frame = CGRectMake(windowFrame.origin.x + kMessageWindowInsetXNarrow,
                                        windowFrame.origin.y + kMessageWindowInsetYNarrow,
                                        windowFrame.size.width * 0.5,
                                        windowFrame.size.height * 0.5);
    } else {
        messageLayer.frame = CGRectMake(windowFrame.origin.x + kMessageWindowInsetXWide,
                                        windowFrame.origin.y + kMessageWindowInsetYWide,
                                        windowFrame.size.width,
                                        windowFrame.size.height);
    }
    messageLayer.contents = (__bridge id)self.messageImage.CGImage;
    messageLayer.opacity = 0.0;
    [self.contentView.layer addSublayer:messageLayer];
    self.messageLayer = messageLayer;

    // The bouncing cursor image marks the highlighted control.
    UIImage *cursorClip =
        [self.messageImage clipImageWithRect:[self getClipRect:kTutorialTexTypeCursor]];
    self.cursorView = [[UIImageView alloc] initWithImage:cursorClip];
    self.cursorView.hidden = YES;
    [self addSubview:self.cursorView];

    // The pulsing touch marker alternates between two frames.
    UIImage *touchClip =
        [self.messageImage clipImageWithRect:[self getClipRect:kTutorialTexTypeTouch]];
    UIImage *touchFrameClip =
        [self.messageImage clipImageWithRect:[self getClipRect:kTutorialTexTypeTouchFrame]];
    self.touchView = [[UIImageView alloc]
        initWithFrame:CGRectMake(0.0, 0.0, touchClip.size.width, touchFrameClip.size.height)];
    self.touchView.animationImages = @[ touchClip, touchFrameClip ];
    self.touchView.animationDuration = 1.0;
    self.touchView.animationRepeatCount = 0;
    self.touchView.hidden = YES;
    [self addSubview:self.touchView];

    // The eight grey layers dim everything but the spotlight hole. The four quadrant layers cover
    // the outer regions; the four corner layers trim the rounded hole edges.
    self.grayTL = [self addGrayLayerToBase];
    self.grayTR = [self addGrayLayerToBase];
    self.grayBL = [self addGrayLayerToBase];
    self.grayBR = [self addGrayLayerToBase];
    self.grayCTL = [self addGrayCornerLayerToBase:kTutorialTexTypeCornerTL];
    self.grayCTR = [self addGrayCornerLayerToBase:kTutorialTexTypeCornerTR];
    self.grayCBL = [self addGrayCornerLayerToBase:kTutorialTexTypeCornerBL];
    self.grayCBR = [self addGrayCornerLayerToBase:kTutorialTexTypeCornerBR];

    // The four quadrant layers start pushed fully off the overlay, so nothing is dimmed until a
    // spotlight is laid out.
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

    // The opaque black full-cover tap target sits on top and absorbs the tap that advances a step.
    self.fullCoverView = [[UIView alloc] initWithFrame:self.frame];
    self.fullCoverView.backgroundColor = UIColor.blackColor;
    self.fullCoverView.alpha = 0.0;
    self.fullCoverView.autoresizingMask = kAutoresizingMaskFlexibleAll;
    [self addSubview:self.fullCoverView];

    [self addTarget:self action:@selector(tap:) forControlEvents:UIControlEventTouchUpInside];
}

// Build a flat grey quadrant layer and add it to the base view's layer.
- (CALayer *)addGrayLayerToBase {
    CALayer *layer = [CALayer layer];
    layer.backgroundColor = [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:1.0].CGColor;
    [self.baseView.layer addSublayer:layer];
    return layer;
}

// The grey spotlight layers, in the order the teardown clears them.
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

// Build a rounded-corner grey trim layer from the given artwork clip and add it to the base view's
// layer, starting hidden.
- (CALayer *)addGrayCornerLayerToBase:(unsigned int)texType {
    CALayer *layer = [CALayer layer];
    UIImage *cornerClip = [self.messageImage clipImageWithRect:[self getClipRect:texType]];
    layer.contents = (__bridge id)cornerClip.CGImage;
    layer.hidden = YES;
    [self.baseView.layer addSublayer:layer];
    return layer;
}

#pragma mark - Presentation

- (void)showAnimationWithTutorialType:(NSUInteger)tutorialType withRootView:(UIView *)rootView {
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

// Fully tear the overlay down after the fade-out completes: stop and delete every layer, clear the
// grey layers' contents, close the customize popup if that was the final step, detach from the menu
// hub, and remove from the superview.
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
    // A tap dismisses the overlay only outside the music-select walkthrough and outside the running
    // customize walkthrough (up to its final visible step).
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

- (void)startTutorialWithType:(NSUInteger)tutorialType withRootView:(UIView *)rootView {
    /** @ghidraAddress 0x13b8fc */
    self.clipRootView = rootView;
    [self startTutorialWithType:tutorialType withAnimation:YES];
}

- (void)startTutorialWithType:(NSUInteger)tutorialType withAnimation:(BOOL)animation {
    /** @ghidraAddress 0x13ab34 */
    [self stopCursorAnimation:self];
    [self stopTouchAnimation:self];
    self.clipTargetForTouch = NO;

    // The customize-item step grants a one-off experience reward and plays the decide sound the
    // first time it is reached.
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
    [[RBTutorialManager getInstance] updateStatus:self.tutorialStatus];
    self.animating = YES;

    // The clip-root view is one of several step-specific provider views (the difficulty selector,
    // the customize popup, and so on). The binary messages its per-step button getters through a
    // bare view with no shared protocol, so they are dispatched dynamically here too.
    id clipRoot = self.clipRootView;

    // touchAnim shows the pulsing touch marker; cursorAnim shows the bouncing cursor; stay keeps the
    // content view where it is rather than nudging it clear of the spotlight.
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

// Convert the highlighted control's frame into this view's coordinates and store it as the
// spotlight clip rectangle. Called only when a clip target exists.
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
        // No spotlight: dim the whole overlay opaque and hide the grey cut-out layers.
        [CATransaction begin];
        [CATransaction setAnimationDuration:(withAnimation ? kOverlayFadeDuration : 0.0)];
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

    // Convert the highlighted control's frame into this view's coordinates, snapping any fractional
    // origin a half-pixel out so the spotlight aligns to the pixel grid.
    CGRect targetRect = [targetView.superview convertRect:targetView.frame toView:self];
    CGRect clip = targetRect;
    // Snap only when the origin is not already on an integral pixel boundary.
    if (static_cast<double>(static_cast<float>(static_cast<int>(targetRect.origin.x))) !=
        targetRect.origin.x) {
        clip.origin.x = targetRect.origin.x - kSpotlightPixelSnap;
        clip.size.width = targetRect.size.width + kSpotlightPixelGrow;
    }
    if (static_cast<double>(static_cast<float>(static_cast<int>(targetRect.origin.y))) !=
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
    // The four quadrant layers butt against the four spotlight edges; the four corner layers trim
    // the rounded hole corners.
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
    self.grayCTL.frame =
        CGRectMake(spot.origin.x, spot.origin.y, spot.size.width, self.grayCTL.frame.size.height);
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
    CGPoint origin = content.origin;

    // When the content view would overlap the spotlight (and the step does not force it to stay),
    // slide it clear to the side with the most room, clamped to the overlay bounds.
    if (spot.origin.y <= content.origin.y + content.size.height && !stay &&
        content.origin.y <= spot.origin.y + spot.size.height) {
        CGFloat spotCentreY = spot.origin.y + spot.size.height;
        if (content.size.width * 0.5 <= (spot.origin.y + spotCentreY) * 0.5) {
            origin.y = (spot.origin.y - content.size.height) - 10.0;
            if (origin.y < 0.0) {
                origin.y = 0.0;
            }
        } else {
            origin.y = spotCentreY + 10.0;
            if (self.height < origin.y + content.size.height) {
                origin.y = self.height - content.size.height;
            }
        }
    }

    CGRect placed = content;
    placed.origin = origin;
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

// Remove the animations from a layer and each of its sublayers, then wipe the layer's own
// animations. Does nothing when the layer has no animation keys.
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
    // Clear any previous message-layer animations tagged for removal, then rebuild the reveal.
    for (CALayer *sublayer in self.messageLayer.sublayers) {
        if ([sublayer.name isEqualToString:self.showLayerTag]) {
            [sublayer removeAllAnimations];
        }
    }
    [self animationDelete:self.contentView.layer];

    // Position the message layer for the current step's message clip within the window layer.
    CGRect messageClip = [self getClipRect:[self getTextureType]];
    CGSize atlasSize = self.messageImage.size;
    CGRect windowFrame = self.messageWindowLayer.frame;
    BOOL narrow = !IsPad();
    CGRect fullClip = [self getClipRect:kTutorialStepDecideButton];

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.messageLayer.opacity = 0.0;
    self.messageLayer.frame = CGRectMake(
        windowFrame.origin.x + (narrow ? kMessageWindowInsetXNarrow : kMessageWindowInsetXWide),
        (fullClip.size.height - messageClip.size.height) * 0.5 + kMessageWindowBaseInsetY +
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
        [self revealBubbleOnly];
    } else if (CGRectEqualToRect(targetFrame, CGRectZero)) {
        [self revealBubbleAndMessage];
    } else {
        [self revealBubbleMessageAndMove:targetFrame];
    }
}

// The message-select intro and the no-target step just pop the pastel bubble, window, and message
// in with a bound-scale group; no content-view move.
- (void)revealBubbleOnly {
    /** @ghidraAddress 0x13de2c */
    CAAnimationGroup *windowGroup = [CAAnimationGroup animation];
    CAKeyframeAnimation *windowFade = [RBAnimationFactory createFadeAnimWithFromValue:0.0
                                                                              toValue:1.0
                                                                                delay:0.0
                                                                             duration:0.5];
    CAKeyframeAnimation *windowScale = [RBAnimationFactory createScaleAnimWithFromValue:0.0
                                                                                toValue:1.0
                                                                                      X:NO
                                                                                      Y:YES
                                                                                  delay:0.0
                                                                               duration:0.3];
    CAKeyframeAnimation *windowBound = [RBAnimationFactory createBoundAnimWithX:NO
                                                                              Y:YES
                                                                          delay:0.3
                                                                       duration:0.2];
    windowGroup.animations = @[ windowFade, windowScale, windowBound ];
    windowGroup.duration = 0.5;
    windowGroup.removedOnCompletion = NO;
    windowGroup.fillMode = kCAFillModeForwards;

    CAAnimationGroup *pastelGroup = [CAAnimationGroup animation];
    CAKeyframeAnimation *pastelFade = [RBAnimationFactory createFadeAnimWithFromValue:0.0
                                                                              toValue:1.0
                                                                                delay:0.0
                                                                             duration:0.3];
    CAKeyframeAnimation *pastelScale = [RBAnimationFactory createScaleAnimWithFromValue:0.0
                                                                                toValue:1.0
                                                                                      X:YES
                                                                                      Y:NO
                                                                                  delay:0.0
                                                                               duration:0.3];
    pastelGroup.animations = @[ pastelFade, pastelScale ];
    pastelGroup.duration = 0.3;
    pastelGroup.removedOnCompletion = NO;
    pastelGroup.fillMode = kCAFillModeForwards;

    CAAnimationGroup *messageGroup = [CAAnimationGroup animation];
    CAKeyframeAnimation *messageFade = [RBAnimationFactory createFadeAnimWithFromValue:0.0
                                                                               toValue:1.0
                                                                                 delay:0.3
                                                                              duration:0.2];
    messageGroup.animations = @[ messageFade ];
    messageGroup.duration = 0.3;
    messageGroup.removedOnCompletion = NO;
    messageGroup.fillMode = kCAFillModeForwards;

    windowGroup.delegate = self;
    [self.messageWindowLayer addAnimation:windowGroup forKey:nil];
    [self.pastelLayer addAnimation:pastelGroup forKey:nil];
    [self.messageLayer addAnimation:messageGroup forKey:nil];
}

// A step whose content-view move is zero: fade the message layer in with a bound bob on the pastel
// bubble.
- (void)revealBubbleAndMessage {
    /** @ghidraAddress 0x13de2c */
    CAAnimationGroup *messageGroup = [CAAnimationGroup animation];
    CAKeyframeAnimation *messageFadeOut = [RBAnimationFactory createFadeAnimWithFromValue:0.0
                                                                                  toValue:0.0
                                                                                    delay:0.0
                                                                                 duration:0.3];
    CAKeyframeAnimation *messageFadeIn = [RBAnimationFactory createFadeAnimWithFromValue:0.0
                                                                                 toValue:1.0
                                                                                   delay:0.3
                                                                                duration:0.2];
    messageGroup.animations = @[ messageFadeOut, messageFadeIn ];
    messageGroup.duration = 0.5;
    messageGroup.removedOnCompletion = NO;
    messageGroup.fillMode = kCAFillModeForwards;

    CAAnimationGroup *pastelGroup = [CAAnimationGroup animation];
    CAKeyframeAnimation *pastelBound = [RBAnimationFactory createBoundAnimWithX:NO
                                                                              Y:YES
                                                                          delay:0.2
                                                                       duration:0.2];
    pastelGroup.animations = @[ pastelBound ];
    pastelGroup.duration = 0.5;
    pastelGroup.removedOnCompletion = NO;
    pastelGroup.fillMode = kCAFillModeForwards;

    [RBAnimationFactory animationDelete:self.pastelLayer];
    pastelGroup.delegate = self;
    [self.messageLayer addAnimation:messageGroup forKey:nil];
    [self.pastelLayer addAnimation:pastelGroup forKey:nil];
}

// A step that also slides the content view to its new place: run the fade/scale groups and move the
// content-view layer from its current position to the target frame.
- (void)revealBubbleMessageAndMove:(CGRect)targetFrame {
    /** @ghidraAddress 0x13de2c */
    CGPoint contentOrigin = CGPointMake(self.contentView.x, self.contentView.y);

    CAAnimationGroup *messageGroup = [CAAnimationGroup animation];
    CAKeyframeAnimation *messageFadeOut = [RBAnimationFactory createFadeAnimWithFromValue:0.0
                                                                                  toValue:0.0
                                                                                    delay:0.0
                                                                                 duration:0.3];
    CAKeyframeAnimation *messageFadeIn = [RBAnimationFactory createFadeAnimWithFromValue:0.0
                                                                                 toValue:1.0
                                                                                   delay:0.2
                                                                                duration:0.2];
    messageGroup.animations = @[ messageFadeOut, messageFadeIn ];
    messageGroup.duration = 0.5;
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
    pastelGroup.duration = 0.3;
    pastelGroup.removedOnCompletion = NO;
    pastelGroup.fillMode = kCAFillModeForwards;

    CAAnimationGroup *windowGroup = [CAAnimationGroup animation];
    CAKeyframeAnimation *windowScaleUp = [RBAnimationFactory createScaleAnimWithFromValue:1.0
                                                                                  toValue:0.0
                                                                                        X:YES
                                                                                        Y:NO
                                                                                    delay:0.2
                                                                                 duration:0.2];
    CAKeyframeAnimation *windowScaleDown = [RBAnimationFactory createScaleAnimWithFromValue:0.0
                                                                                    toValue:1.0
                                                                                          X:YES
                                                                                          Y:NO
                                                                                      delay:0.5
                                                                                   duration:0.2];
    windowGroup.animations = @[ windowScaleUp, windowScaleDown ];
    windowGroup.duration = 0.3;
    windowGroup.removedOnCompletion = NO;
    windowGroup.fillMode = kCAFillModeForwards;

    CGPoint contentPosition = self.contentView.layer.position;
    CGPoint moveTo = CGPointMake(contentPosition.x - (contentOrigin.x - targetFrame.origin.x),
                                 contentPosition.y - (contentOrigin.y - targetFrame.origin.y));
    [self createAnimWithKeyPath:kContentPositionKeyPath
                      fromValue:contentPosition
                        toValue:moveTo
                          delay:0.0
                       duration:0.3];
    pastelGroup.delegate = self;
    [self.pastelLayer addAnimation:pastelGroup forKey:nil];
    [self.messageWindowLayer addAnimation:windowGroup forKey:nil];
    [self.messageLayer addAnimation:messageGroup forKey:nil];

    // Move the content view itself to the target frame after a short delay.
    __weak UIView *weakContentView = self.contentView;
    [UIView animateWithDuration:0.3
                          delay:0.5
                        options:UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
                       /** @ghidraAddress 0x13f784 */
                       weakContentView.frame = targetFrame;
                     }
                     completion:nil];
}

- (void)resetAnimation:(CGRect)targetFrame {
    /** @ghidraAddress 0x13f7f0 */
    // The no-animation counterpart of -startAnimation:; snap every layer straight to its final,
    // fully opaque state.
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
    CGRect fullClip = [self getClipRect:kTutorialStepDecideButton];

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.messageLayer.opacity = 1.0;
    self.messageLayer.frame = CGRectMake(
        windowFrame.origin.x + (narrow ? kMessageWindowInsetXNarrow : kMessageWindowInsetXWide),
        (fullClip.size.height - messageClip.size.height) * 0.5 + kMessageWindowBaseInsetY +
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
        [self snapContentViewOpaqueMovingTo:targetFrame];
    } else {
        [self snapContentViewOpaque];
    }
}

// Snap the window and pastel layers fully opaque and unscaled, moving the content-view layer to the
// target frame's origin without animation.
- (void)snapContentViewOpaqueMovingTo:(CGRect)targetFrame {
    /** @ghidraAddress 0x13f7f0 */
    CGPoint contentOrigin = CGPointMake(self.contentView.x, self.contentView.y);
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.messageWindowLayer.opacity = 1.0;
    self.messageWindowLayer.contentsScale = 1.0;
    self.pastelLayer.opacity = 1.0;
    self.pastelLayer.contentsScale = 1.0;
    CGPoint contentPosition = self.contentView.layer.position;
    self.contentView.layer.position =
        CGPointMake(contentPosition.x - (contentOrigin.x - targetFrame.origin.x),
                    contentPosition.y - (contentOrigin.y - targetFrame.origin.y));
    [CATransaction commit];
    self.contentView.layer.opacity = 1.0;
}

// Snap the window and pastel layers fully opaque and unscaled without moving the content view.
- (void)snapContentViewOpaque {
    /** @ghidraAddress 0x13f7f0 */
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.messageWindowLayer.opacity = 1.0;
    self.messageWindowLayer.contentsScale = 1.0;
    self.pastelLayer.opacity = 1.0;
    self.pastelLayer.contentsScale = 1.0;
    [CATransaction commit];
    self.contentView.layer.opacity = 1.0;
}

#pragma mark - Clip-rect table

- (unsigned int)getTextureType {
    /** @ghidraAddress 0x14040c */
    // Map the live tutorial step to the message-artwork texture-type index. The decide step splits
    // by device idiom; the rest are a fixed remap.
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
    // Look up the artwork rectangle for the texture type in the per-step clip table. On the narrow
    // iPad idiom every rectangle is halved.
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

- (CAAnimationGroup *)createAnimWithKeyPath:(NSString *)keyPath
                                  fromValue:(CGPoint)fromValue
                                    toValue:(CGPoint)toValue
                                      delay:(double)delay
                                   duration:(double)duration {
    /** @ghidraAddress 0x1405c8 */
    // Build a grouped keyframe move: an ease-in position.x and position.y keyframe pair driving the
    // content-view layer from fromValue to toValue. The keyPath argument names the group; the two
    // component key paths are fixed at position.x and position.y.
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
        // No spotlight: any tap advances the step.
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
        // A spotlight that does not pass touches through: any tap advances the step, skipping the
        // double-button step on the iPad (wide) layout.
        self.tutorialStatus = self.tutorialStatus + 1;
        if (IsPad() && self.tutorialStatus == kTutorialStepDoubleButton) {
            self.tutorialStatus = self.tutorialStatus + 1;
        }
        [self startTutorialWithType:self.tutorialStatus withAnimation:YES];
        return self;
    }

    // A spotlight that passes touches through: swallow the tap only when it lands inside the
    // spotlight (so the highlighted control receives it).
    CGRect spot = self.clipRect;
    if (spot.origin.x <= point.x && point.x <= spot.origin.x + spot.size.width &&
        spot.origin.y <= point.y && point.y <= spot.origin.y + spot.size.height) {
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
    self.contentView.frame = CGRectMake(self.width * 0.5 - self.contentViewWidth * 0.5,
                                        self.height * 0.5 - self.contentViewHeight * 0.5,
                                        self.contentViewWidth,
                                        self.contentViewHeight);
    self.contentView.alpha = kRotationDimAlpha;
    self.animating = NO;
    [self startTutorialWithType:self.tutorialStatus withAnimation:NO];
}

#pragma mark - Animation delegate

- (void)animationDidStop:(CAAnimation *)animation finished:(BOOL)finished {
    /** @ghidraAddress 0x1405a8 */
    self.animating = NO;
}

@end
