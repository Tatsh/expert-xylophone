//
//  RBCustomView.mm
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RBCustomView). Verified against
//  the arm64 disassembly: -setupView's theme- and idiom-dependent button geometry and the
//  slide-in/out and reveal/hide transitions were recovered from the soft-float register moves that
//  the decompiler folds into pseudo-variables. This is an Objective-C++ file because the
//  mode-toggle and reward-list handlers reach the C++ SoundEffectManager engine singleton.
//

#import "RBCustomView.h"

#import "RBMenuView.h"
#import "RBTutorialManager.h"
#import "RBUserSettingData.h"
#import "UIImage+RB.h"
#import "UIImageView+RB.h"
#import "neEngineBridge.h"

// The customize popup transitions all run over three tenths of a second.
constexpr NSTimeInterval kCustomizeSlideAnimationDuration = 0.3;

// The themed sound-effect slot played when a mode toggle or the reward list is used.
constexpr int kSoundEffectDecide = 1;

// The tutorial types launched once the pickers are on screen: the experience tutorial follows the
// customize picker sliding out, the customize tutorial follows the experience picker sliding in.
constexpr NSInteger kTutorialTypeCustomize = 0x1e;
constexpr NSInteger kTutorialTypeExperience = 0x21;

// The mode-toggle effect overlay pulses from full to dim opacity over the default flash duration.
// @ghidraAddress 0x2fefb8 (g_flFlashDefaultDuration)
constexpr CGFloat kFlashDefaultDuration = 0.333333343;
// @ghidraAddress 0x2ec6b4 (g_flFlashMinOpacity)
constexpr CGFloat kFlashMinOpacity = 0.2;
constexpr CGFloat kFlashFullOpacity = 1.0;

// The image assets for the themed customize layout: the gradient frame behind the mode toggles,
// the two mode-toggle button faces, and the flashing effect overlay.
static NSString *const kSetGradientImageName = @"04_customize/set_grad_down";
static NSString *const kSetModeButtonImageName = @"04_customize/cus_mode_bt_0";
static NSString *const kUnlockModeButtonImageName = @"04_customize/cus_mode_bt_1";
static NSString *const kModeButtonEffectImageName = @"04_customize/cus_mode_bt_eff";

// The mode toggles straddle the horizontal centre of the gradient frame. The set button sits to
// the left by its own width less a hairline; the unlock button sits to the right by a fixed inset.
// Both rest a hairline above the bottom of the content view.
constexpr CGFloat kModeButtonCentreFactor = 0.5;
constexpr CGFloat kSetButtonRightHairline = 0.21875;
constexpr CGFloat kUnlockButtonLeftInset = 20.0;
constexpr CGFloat kModeButtonBottomHairline = 0.5;

// The effect overlay is nudged off the toggle it decorates by a idiom- and theme-dependent
// amount, recovered from the disassembly's soft-float immediate operands. The horizontal nudge is
// shared by the initial layout and the mode-toggle repositioning; the vertical nudge differs
// between them.
constexpr CGFloat kEffectHorizontalNudgeWide = 0.625;
constexpr CGFloat kEffectHorizontalNudgeNarrow = 1.0;
constexpr CGFloat kEffectSetupVerticalNudgeWideLimelight = 1.5;
constexpr CGFloat kEffectSetupVerticalNudgeWideColette = 2.0;
constexpr CGFloat kEffectSetupVerticalNudgeNarrow = 4.0;
constexpr CGFloat kEffectToggleVerticalNudgeWide = 2.0;
constexpr CGFloat kEffectToggleVerticalNudgeNarrow = 4.0;

@implementation RBCustomView

#pragma mark Lifecycle

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setMusicMenuPopupViewType:RBMusicMenuPopupViewTypeCustomize];
        [self setupView];
    }
    return self;
}

// The binary's -dealloc (0x966f0) only chains to [super dealloc]; under ARC that chaining is
// automatic, so no override is reconstructed. The strong subview ivars and the weak settingView
// reference are cleared by the compiler-generated .cxx_destruct (0x99de8).

#pragma mark Layout

- (void)setupView {
    [super setupView];

    BOOL isPad = IsPad();
    RBUserSettingDataTheme thema = [RBUserSettingData sharedInstance].thema;

    // The customize picker always fills the content view.
    self.customizeItemView = [[RBCustomSelectView alloc] initWithFrame:self.contentView.bounds];
    self.customizeItemView.exclusiveTouch = YES;
    [self.contentView addSubview:self.customizeItemView];

    // The experience picker, the mode toggles, and the reward list are only built on the themed
    // (Limelight and Colette) layouts.
    if (thema != RBUserSettingDataThemeLimelight && thema != RBUserSettingDataThemeColette) {
        return;
    }

    CGRect contentFrame = self.contentView.frame;

    // The experience picker fills the content view but starts translated one content width to the
    // right, so the set-mode toggle can slide it in from off screen.
    self.experienceItemView = [[RBUnlockView alloc] initWithFrame:self.contentView.bounds];
    self.experienceItemView.transform =
        CGAffineTransformMakeTranslation(contentFrame.size.width, 0.0);
    self.experienceItemView.exclusiveTouch = YES;
    [self.contentView addSubview:self.experienceItemView];
    self.experienceItemView.parentView = self;

    // The gradient frame sits flush against the bottom of the content view.
    UIImage *gradientImage = [UIImage imageWithName:kSetGradientImageName];
    self.experienceButtonFrameView = [[UIImageView alloc] initWithImage:gradientImage];
    self.experienceButtonFrameView.frame =
        CGRectMake(0.0,
                   contentFrame.size.height - gradientImage.size.height,
                   gradientImage.size.width,
                   gradientImage.size.height);
    self.experienceButtonFrameView.exclusiveTouch = YES;
    [self.contentView addSubview:self.experienceButtonFrameView];

    // The set-mode toggle switches back to the customize picker. It sits just left of the frame's
    // horizontal centre and a hairline above the content view's bottom.
    self.experienceSetButton = [UIButton buttonWithType:UIButtonTypeCustom];
    UIImage *setImage = [UIImage imageWithName:kSetModeButtonImageName];
    [self.experienceSetButton setImage:setImage forState:UIControlStateNormal];
    self.experienceSetButton.frame =
        CGRectMake(gradientImage.size.width * kModeButtonCentreFactor - setImage.size.width -
                       kSetButtonRightHairline,
                   contentFrame.size.height - setImage.size.height - kModeButtonBottomHairline,
                   setImage.size.width,
                   setImage.size.height);
    [self.experienceSetButton addTarget:self
                                 action:@selector(toCustomize:)
                       forControlEvents:UIControlEventTouchUpInside];
    self.experienceSetButton.exclusiveTouch = YES;
    self.experienceSetButton.enabled = NO;
    [self.contentView addSubview:self.experienceSetButton];

    // The unlock-mode toggle switches to the experience picker. It sits just right of the frame's
    // horizontal centre.
    self.experienceUnlockButton = [UIButton buttonWithType:UIButtonTypeCustom];
    UIImage *unlockImage = [UIImage imageWithName:kUnlockModeButtonImageName];
    [self.experienceUnlockButton setImage:unlockImage forState:UIControlStateNormal];
    self.experienceUnlockButton.frame =
        CGRectMake(gradientImage.size.width * kModeButtonCentreFactor + kUnlockButtonLeftInset,
                   contentFrame.size.height - unlockImage.size.height - kModeButtonBottomHairline,
                   unlockImage.size.width,
                   unlockImage.size.height);
    [self.experienceUnlockButton addTarget:self
                                    action:@selector(toUnlock:)
                          forControlEvents:UIControlEventTouchUpInside];
    self.experienceUnlockButton.exclusiveTouch = YES;
    [self.contentView addSubview:self.experienceUnlockButton];

    // The effect overlay flashes under whichever toggle is active. It starts over the set button,
    // nudged off it by a idiom- and theme-dependent amount, and pulses continuously.
    UIImage *effectImage = [UIImage imageWithName:kModeButtonEffectImageName];
    self.experienceButtonEffectView = [[UIImageView alloc] initWithImage:effectImage];
    CGRect setButtonFrame = self.experienceSetButton.frame;
    CGFloat effectHorizontalNudge =
        (!isPad) ? kEffectHorizontalNudgeNarrow : kEffectHorizontalNudgeWide;
    CGFloat effectVerticalNudge;
    if (!isPad) {
        effectVerticalNudge = kEffectSetupVerticalNudgeNarrow;
    } else if (thema == RBUserSettingDataThemeColette) {
        effectVerticalNudge = kEffectSetupVerticalNudgeWideColette;
    } else {
        effectVerticalNudge = kEffectSetupVerticalNudgeWideLimelight;
    }
    self.experienceButtonEffectView.frame =
        CGRectMake(setButtonFrame.origin.x - effectHorizontalNudge,
                   setButtonFrame.origin.y - effectVerticalNudge,
                   effectImage.size.width,
                   effectImage.size.height);
    [self.contentView addSubview:self.experienceButtonEffectView];
    [self.experienceButtonEffectView SetFlashEffectDuration:kFlashDefaultDuration
                                                      Start:kFlashFullOpacity
                                                        End:kFlashMinOpacity];

    // The reward list fills the content view but starts translated off screen and hidden; the
    // reward action fades it in over the pickers.
    self.rewardListView = [[RBRewardListView alloc] initWithFrame:self.contentView.bounds];
    self.rewardListView.transform = CGAffineTransformMakeTranslation(contentFrame.size.width, 0.0);
    self.rewardListView.exclusiveTouch = YES;
    self.rewardListView.backgroundColor = UIColor.whiteColor;
    self.rewardListView.alpha = 0.0;
    self.rewardListView.hidden = YES;
    [self.contentView addSubview:self.rewardListView];
    self.rewardListView.parentView = self;
}

#pragma mark Presentation

- (void)showAnimation {
    [super showAnimation];
    [[RBUserSettingData sharedInstance] save];
}

- (void)hideAnimation {
    [self.rewardListView hideAnimation];
    [[RBUserSettingData sharedInstance] save];
    [super hideAnimation];
}

#pragma mark Mode toggles

- (void)toCustomize:(id)sender {
    if (self.animating) {
        return;
    }
    SoundEffectManager::GetInstance()->PlayThemedSoundEffect(kSoundEffectDecide);

    // Snap the effect overlay onto the set button before sliding the customize picker back in.
    [self placeEffectOverlayOverButton:self.experienceSetButton];
    [self.customizeItemView reloadData];

    [UIView animateWithDuration:kCustomizeSlideAnimationDuration
        animations:^{
          /** @ghidraAddress 0x99190 */
          self.customizeItemView.transform = CGAffineTransformIdentity;
          self.experienceItemView.transform =
              CGAffineTransformMakeTranslation(self.contentView.frame.size.width, 0.0);
          self.animating = YES;
          self.experienceSetButton.enabled = NO;
          [self.experienceButtonEffectView SetFlashEffectDuration:kFlashDefaultDuration
                                                            Start:kFlashFullOpacity
                                                              End:kFlashMinOpacity];
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x99370 */
          self.animating = NO;
          self.experienceUnlockButton.enabled = YES;
          if ([RBTutorialManager isTutorialCustomize]) {
              [self.musicMenuView.tutorialView startTutorialWithType:kTutorialTypeExperience
                                                       withAnimation:YES];
          }
        }];
}

- (void)toUnlock:(id)sender {
    if (self.animating) {
        return;
    }
    SoundEffectManager::GetInstance()->PlayThemedSoundEffect(kSoundEffectDecide);

    // Snap the effect overlay onto the unlock button before sliding the experience picker in.
    [self placeEffectOverlayOverButton:self.experienceUnlockButton];
    [self.experienceItemView request];

    [UIView animateWithDuration:kCustomizeSlideAnimationDuration
        animations:^{
          /** @ghidraAddress 0x98b00 */
          self.customizeItemView.transform =
              CGAffineTransformMakeTranslation(-self.contentView.frame.size.width, 0.0);
          self.experienceItemView.transform = CGAffineTransformIdentity;
          self.animating = YES;
          self.experienceUnlockButton.enabled = NO;
          [self.experienceButtonEffectView SetFlashEffectDuration:kFlashDefaultDuration
                                                            Start:kFlashFullOpacity
                                                              End:kFlashMinOpacity];
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x98cd4 */
          self.animating = NO;
          self.experienceSetButton.enabled = YES;
          if ([RBUserSettingData sharedInstance].thema == RBUserSettingDataThemeColette &&
              [RBTutorialManager isTutorialCustomize]) {
              [self.musicMenuView.tutorialView startTutorialWithType:kTutorialTypeCustomize
                                                        withRootView:self.experienceItemView];
              self.experienceSetButton.enabled = NO;
          }
        }];
}

// Position the flashing effect overlay over the given mode-toggle button. The mode toggles use a
// idiom-dependent nudge that does not vary with the theme, unlike the initial layout.
- (void)placeEffectOverlayOverButton:(UIButton *)button {
    BOOL isPad = IsPad();
    CGRect buttonFrame = button.frame;
    CGFloat horizontalNudge = (!isPad) ? kEffectHorizontalNudgeNarrow : kEffectHorizontalNudgeWide;
    CGFloat verticalNudge =
        (!isPad) ? kEffectToggleVerticalNudgeNarrow : kEffectToggleVerticalNudgeWide;
    CGRect effectFrame = self.experienceButtonEffectView.frame;
    self.experienceButtonEffectView.frame = CGRectMake(buttonFrame.origin.x - horizontalNudge,
                                                       buttonFrame.origin.y - verticalNudge,
                                                       effectFrame.size.width,
                                                       effectFrame.size.height);
}

#pragma mark Reward list

- (void)toRewardList:(id)sender {
    if (self.animating) {
        return;
    }
    SoundEffectManager::GetInstance()->PlayThemedSoundEffect(kSoundEffectDecide);

    [UIView animateWithDuration:kCustomizeSlideAnimationDuration
        animations:^{
          /** @ghidraAddress 0x99598 */
          self.animating = YES;
          self.titleImageView.hidden = YES;
          self.gradationImageView.hidden = YES;
          self.rewardListView.alpha = 1.0;
          self.rewardListView.hidden = NO;
          [self.experienceButtonEffectView SetFlashEffectDuration:kFlashDefaultDuration
                                                            Start:kFlashFullOpacity
                                                              End:kFlashMinOpacity];
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x99720 */
          self.animating = NO;
          [self.rewardListView loadStart];
        }];
}

- (void)hideRewardList {
    if (self.animating) {
        return;
    }
    SoundEffectManager::GetInstance()->PlayThemedSoundEffect(kSoundEffectDecide);

    [UIView animateWithDuration:kCustomizeSlideAnimationDuration
        animations:^{
          /** @ghidraAddress 0x9989c */
          self.animating = YES;
          self.titleImageView.hidden = NO;
          self.gradationImageView.hidden = NO;
          self.rewardListView.alpha = 0.0;
          [self.experienceButtonEffectView SetFlashEffectDuration:kFlashDefaultDuration
                                                            Start:kFlashFullOpacity
                                                              End:kFlashMinOpacity];
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x999e8 */
          self.animating = NO;
          self.rewardListView.hidden = YES;
        }];
}

#pragma mark Tutorial accessors

- (UIButton *)getUnlockButtonView {
    return self.experienceUnlockButton;
}

- (UIButton *)getCustomButtonView {
    return self.experienceSetButton;
}

- (RBCustomSelectView *)getCustomizeItemView {
    return self.customizeItemView;
}

@end
