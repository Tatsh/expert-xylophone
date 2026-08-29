#import "RBCustomView.h"

#import "RBMenuTutorialView.h"
#import "RBMenuView.h"
#import "RBTutorialManager.h"
#import "RBUserSettingData.h"
#import "UIImage+RB.h"
#import "UIImageView+RB.h"
#import "deviceenvironment.h"
#import "engineglobals.h"
#import "soundeffectmanager.h"

constexpr NSTimeInterval kCustomizeSlideAnimationDuration = 0.3;

constexpr int kSoundEffectDecide = 1;

// The binary crosses these over: sliding the customize picker out starts the experience tutorial.
constexpr NSInteger kTutorialTypeCustomize = 0x1e;
constexpr NSInteger kTutorialTypeExperience = 0x21;

// @ghidraAddress 0x2fefb8 (g_flFlashDefaultDuration)
constexpr CGFloat kFlashDefaultDuration = 0.333333343;
// @ghidraAddress 0x2ec6b4 (g_flFlashMinOpacity)
constexpr CGFloat kFlashMinOpacity = 0.2;
constexpr CGFloat kFlashFullOpacity = 1.0;

static NSString *const kSetGradientImageName = @"04_customize/set_grad_down";
static NSString *const kSetModeButtonImageName = @"04_customize/cus_mode_bt_0";
static NSString *const kUnlockModeButtonImageName = @"04_customize/cus_mode_bt_1";
static NSString *const kModeButtonEffectImageName = @"04_customize/cus_mode_bt_eff";

constexpr CGFloat kModeButtonCenterFactor = 0.5;
constexpr CGFloat kModeButtonCenterGap = 20.0;
constexpr CGFloat kModeButtonBottomGap = 8.0;

constexpr CGFloat kEffectHorizontalNudgeWide = 7.0;
constexpr CGFloat kEffectHorizontalNudgeNarrow = 4.0;
constexpr CGFloat kEffectSetupVerticalNudgeWideLimelight = 3.0;
constexpr CGFloat kEffectSetupVerticalNudgeWideColette = 2.0;
constexpr CGFloat kEffectSetupVerticalNudgeNarrow = 1.0;
constexpr CGFloat kEffectToggleVerticalNudgeWide = 2.0;
constexpr CGFloat kEffectToggleVerticalNudgeNarrow = 1.0;

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

// ARC covers the binary's -dealloc (0x966f0), which only chains to super, and its .cxx_destruct
// (0x99de8).

#pragma mark Layout

- (void)setupView {
    [super setupView];

    BOOL isPad = IsPad();
    RBUserSettingDataTheme thema = [RBUserSettingData sharedInstance].thema;

    self.customizeItemView = [[RBCustomSelectView alloc] initWithFrame:self.contentView.bounds];
    self.customizeItemView.exclusiveTouch = YES;
    [self.contentView addSubview:self.customizeItemView];

    if (thema != RBUserSettingDataThemeLimelight && thema != RBUserSettingDataThemeColette) {
        return;
    }

    CGRect contentFrame = self.contentView.frame;

    self.experienceItemView = [[RBUnlockView alloc] initWithFrame:self.contentView.bounds];
    self.experienceItemView.transform =
        CGAffineTransformMakeTranslation(contentFrame.size.width, 0.0);
    self.experienceItemView.exclusiveTouch = YES;
    [self.contentView addSubview:self.experienceItemView];
    self.experienceItemView.parentView = self;

    UIImage *gradientImage = [UIImage imageWithName:kSetGradientImageName];
    self.experienceButtonFrameView = [[UIImageView alloc] initWithImage:gradientImage];
    self.experienceButtonFrameView.frame =
        CGRectMake(0.0,
                   contentFrame.size.height - gradientImage.size.height,
                   gradientImage.size.width,
                   gradientImage.size.height);
    self.experienceButtonFrameView.exclusiveTouch = YES;
    [self.contentView addSubview:self.experienceButtonFrameView];

    self.experienceSetButton = [UIButton buttonWithType:UIButtonTypeCustom];
    UIImage *setImage = [UIImage imageWithName:kSetModeButtonImageName];
    [self.experienceSetButton setImage:setImage forState:UIControlStateNormal];
    self.experienceSetButton.frame =
        CGRectMake(contentFrame.size.width * kModeButtonCenterFactor - setImage.size.width -
                       kModeButtonCenterGap,
                   contentFrame.size.height - setImage.size.height - kModeButtonBottomGap,
                   setImage.size.width,
                   setImage.size.height);
    [self.experienceSetButton addTarget:self
                                 action:@selector(toCustomize:)
                       forControlEvents:UIControlEventTouchUpInside];
    self.experienceSetButton.exclusiveTouch = YES;
    self.experienceSetButton.enabled = NO;
    [self.contentView addSubview:self.experienceSetButton];

    self.experienceUnlockButton = [UIButton buttonWithType:UIButtonTypeCustom];
    UIImage *unlockImage = [UIImage imageWithName:kUnlockModeButtonImageName];
    [self.experienceUnlockButton setImage:unlockImage forState:UIControlStateNormal];
    self.experienceUnlockButton.frame =
        CGRectMake(contentFrame.size.width * kModeButtonCenterFactor + kModeButtonCenterGap,
                   contentFrame.size.height - unlockImage.size.height - kModeButtonBottomGap,
                   unlockImage.size.width,
                   unlockImage.size.height);
    [self.experienceUnlockButton addTarget:self
                                    action:@selector(toUnlock:)
                          forControlEvents:UIControlEventTouchUpInside];
    self.experienceUnlockButton.exclusiveTouch = YES;
    [self.contentView addSubview:self.experienceUnlockButton];

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

// This nudge depends on the idiom only, unlike the initial layout's, which also varies by theme.
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
