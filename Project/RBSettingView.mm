#import "RBSettingView.h"

#import "AppDelegate.h"
#import "RBMacros.h"
#import "RBMenuTutorialView.h"
#import "RBMenuView.h"
#import "RBSettingMenuButton.h"
#import "RBTutorialManager.h"
#import "RBUserSettingData.h"
#import "deviceenvironment.h"
#import "engineglobals.h"
#import "soundeffectmanager.h"

constexpr int kSoundEffectDecide = 1;
constexpr int kSoundEffectCancel = 4;
constexpr int kSoundEffectSettingOpenClassic = 3;
constexpr int kSoundEffectSettingOpen = 12;

constexpr UIViewAutoresizing kAutoresizingFull =
    UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth |
    UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin |
    UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;
constexpr UIViewAutoresizing kAutoresizingPanel = UIViewAutoresizingFlexibleWidth |
                                                  UIViewAutoresizingFlexibleRightMargin |
                                                  UIViewAutoresizingFlexibleTopMargin;
constexpr UIViewAutoresizing kAutoresizingButton =
    UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;

constexpr NSTimeInterval kSettingAnimationDuration = 0.25;

// Pool: 0x1003016a0 (background RGB), 0x1003016b8 (border width), 0x1003016c0 (border RGB).
constexpr CGFloat kColetteBackgroundRed = 0.945;
constexpr CGFloat kColetteBackgroundGreen = 0.882353;
constexpr CGFloat kColetteBackgroundBlue = 0.7647;
constexpr CGFloat kColetteBorderRed = 0.7962;
constexpr CGFloat kColetteBorderGreen = 0.749020;
constexpr CGFloat kColetteBorderBlue = 0.6470;
constexpr CGFloat kThemedBorderWidth = 1.3;

constexpr CGFloat kLimelightCornerRadius = 10.0;

// Pool: 0x1003017d0 (default) and 0x1003017dc (region, used when IsPad() == 0).
constexpr CGFloat kSettingCornerRadiusDefault[] = {22.0, 22.0, 33.0};
constexpr CGFloat kSettingCornerRadiusRegion[] = {14.0, 14.0, 14.0};

typedef struct SettingButtonLayout {
    CGFloat originX;
    CGFloat originY;
    CGFloat step;
} SettingButtonLayout;

typedef struct SettingMenuEntry {
    int filename;
    SEL action;
} SettingMenuEntry;

constexpr CGFloat kOpaqueAlpha = 1.0;
constexpr CGFloat kTransparentAlpha = 0.0;

constexpr NSInteger kTutorialTypeCustomize = 27;

@implementation RBSettingView {
    RBUserSettingDataTheme _thema;
    BOOL m_Animating;
    float m_DefaultHeight;
    float m_NeedMenuHeight;
}

#pragma mark Lifecycle

- (instancetype)initWithFrame:(CGRect)frame ButtonFrame:(CGRect)buttonFrame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupView:buttonFrame];
    }
    return self;
}

#pragma mark Panel construction

- (void)setupView:(CGRect)buttonFrame {
    BOOL isPad = IsPad();
    RBUserSettingDataTheme thema = [RBUserSettingData sharedInstance].thema;
    _thema = thema;

    self.backgroundColor = g_pPaletteDimmingCoverColor;
    self.autoresizingMask = kAutoresizingFull;

    self.baseView = [[UIView alloc] initWithFrame:buttonFrame];
    self.baseView.clipsToBounds = YES;
    self.baseView.autoresizingMask = kAutoresizingPanel;
    [self addSubview:self.baseView];

    m_DefaultHeight = (float)CGRectGetHeight(self.baseView.frame);

    const CGFloat *cornerRadii =
        (isPad == 0) ? kSettingCornerRadiusRegion : kSettingCornerRadiusDefault;
    if (thema == RBUserSettingDataThemeColette) {
        self.baseView.backgroundColor = [UIColor colorWithRed:kColetteBackgroundRed
                                                        green:kColetteBackgroundGreen
                                                         blue:kColetteBackgroundBlue
                                                        alpha:kOpaqueAlpha];
        self.baseView.layer.borderWidth = kThemedBorderWidth;
        self.baseView.layer.borderColor = [UIColor colorWithRed:kColetteBorderRed
                                                          green:kColetteBorderGreen
                                                           blue:kColetteBorderBlue
                                                          alpha:kOpaqueAlpha]
                                              .CGColor;
        self.baseView.layer.cornerRadius = cornerRadii[thema];
    } else if (thema == RBUserSettingDataThemeLimelight) {
        self.baseView.backgroundColor = UIColor.whiteColor;
        self.baseView.layer.cornerRadius = kLimelightCornerRadius;
    } else if (thema == RBUserSettingDataThemeClassic) {
        self.baseView.backgroundColor = UIColor.blackColor;
        self.baseView.layer.borderWidth = kThemedBorderWidth;
        self.baseView.layer.borderColor = UIColor.whiteColor.CGColor;
        self.baseView.layer.cornerRadius = cornerRadii[thema];
    }

    // Rows 0 and 1 are identical: each `stp q0,q0` store writes one pool value into two rows.
    // @ghidraAddress 0xec450
    static const SettingButtonLayout defaultLayout[] = {
        {13.0, 30.0, 26.0},
        {13.0, 30.0, 26.0},
        {13.0, 10.0, 2.0},
    };
    static const SettingButtonLayout regionLayout[] = {
        {5.0, 14.0, 13.0},
        {5.0, 14.0, 13.0},
        {5.0, 5.0, 4.0},
    };
    SettingButtonLayout layout = (isPad == 0) ? regionLayout[thema] : defaultLayout[thema];

    // Artwork index 4 is skipped, and the terms button overwrites infoButton with the information
    // button already stored there, exactly as the binary does.
    const int kEntryCustom = 1;
    const int kEntryThema = 2;
    const int kEntrySearch = 3;
    const int kEntryInfo = 4;
    const int kEntryApplilink = 5;
    const int kEntryTerm = 6;
    SettingMenuEntry entries[] = {
        {0, @selector(SelectHowToPlayButton)},
        {1, @selector(SelectCustomizeButton)},
        {2, @selector(selectThema:)},
        {3, @selector(selectMap:)},
        {5, @selector(SelectInfoButton)},
        {6, @selector(SelectApplilinkButton)},
        {7, @selector(SelectTermButton)},
    };

    CGFloat panelWidth = CGRectGetWidth(self.baseView.bounds);
    CGFloat horizontalInset = layout.originX + layout.originX;
    CGFloat buttonWidth = panelWidth - horizontalInset;
    CGFloat y = layout.originY;
    CGFloat previousHeight = 0.0;
    for (int i = 0; i < (int)ARRAY_SIZE(entries); ++i) {
        RBSettingMenuButton *button =
            [[RBSettingMenuButton alloc] initWithFilename:entries[i].filename];
        CGFloat buttonHeight = CGRectGetHeight(button.bounds);
        if (i != 0) {
            y = layout.step + y + previousHeight;
        }
        button.frame = CGRectMake(layout.originX, y, buttonWidth, buttonHeight);
        button.autoresizingMask = kAutoresizingButton;
        [self.baseView addSubview:button];
        if (i == 0) {
            self.howToButton = button;
        } else if (i == kEntryCustom) {
            self.customButton = button;
        } else if (i == kEntryThema) {
            self.themaButton = button;
        } else if (i == kEntrySearch) {
            self.searchButton = button;
        } else if (i == kEntryInfo || i == kEntryTerm) {
            self.infoButton = button;
        } else if (i == kEntryApplilink) {
            self.applilinkButton = button;
        }
        button.button.exclusiveTouch = YES;
        [button.button addTarget:self
                          action:entries[i].action
                forControlEvents:UIControlEventTouchUpInside];
        previousHeight = buttonHeight;
    }

    m_NeedMenuHeight = (float)(layout.step + y + previousHeight);

    if ([RBUserSettingData sharedInstance].newCustomItem) {
        [self.customButton setFlashEffect];
    }
    if (![RBUserSettingData sharedInstance].howtoFirstInfo) {
        [self.howToButton setFlashEffect];
    }
    if ([RBUserSettingData sharedInstance].newThema) {
        [self.themaButton setFlashEffect];
    }
    if ([AppDelegate appDelegate].unreadRecommendCount > 0) {
        [self.applilinkButton setFlashEffect];
    }
}

#pragma mark Opening and closing

- (void)OpenView {
    if (_thema == RBUserSettingDataThemeColette || _thema == RBUserSettingDataThemeLimelight) {
        SoundEffectManager::GetInstance()->PlayThemedSoundEffect(kSoundEffectSettingOpen);
    } else if (_thema == RBUserSettingDataThemeClassic) {
        SoundEffectManager::GetInstance()->PlayThemedSoundEffect(kSoundEffectSettingOpenClassic);
    }
    [self showAnimation];
}

- (void)CloseView {
    if (m_Animating) {
        return;
    }
    SoundEffectManager::GetInstance()->PlayThemedSoundEffect(kSoundEffectCancel);
    [self hideAnimation];
}

- (void)showAnimation {
    if (m_Animating) {
        return;
    }
    CGRect panelFrame = self.baseView.frame;
    m_Animating = YES;
    self.alpha = kTransparentAlpha;

    __weak RBSettingView *weakSelf = self;
    [UIView animateWithDuration:kSettingAnimationDuration
        animations:^{
          /** @ghidraAddress 0xeb378 */
          self.alpha = kOpaqueAlpha;
          CGFloat grownHeight = (CGFloat)self->m_DefaultHeight + (CGFloat)self->m_NeedMenuHeight;
          self.baseView.frame =
              CGRectMake(CGRectGetMinX(panelFrame),
                         (CGRectGetMinY(panelFrame) + CGRectGetHeight(panelFrame)) - grownHeight,
                         CGRectGetWidth(panelFrame),
                         grownHeight);
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0xeb4c4 */
          if ([RBUserSettingData sharedInstance].thema == RBUserSettingDataThemeColette &&
              [RBTutorialManager isTutorialCustomize]) {
              // The root view must be this setting view: it is sent -getCustomizeButtonView, which
              // RBMenuView does not implement.
              [weakSelf.parentView.tutorialView startTutorialWithType:kTutorialTypeCustomize
                                                         withRootView:weakSelf];
          }
          self->m_Animating = NO;
        }];
}

- (void)hideAnimation {
    if (m_Animating) {
        return;
    }
    self.howToButton.enabled = NO;
    self.customButton.enabled = NO;
    self.searchButton.enabled = NO;
    self.infoButton.enabled = NO;
    self.applilinkButton.enabled = NO;
    m_Animating = YES;

    CGRect panelFrame = self.baseView.frame;
    [UIView beginAnimations:nil context:nil];
    [UIView setAnimationDuration:kSettingAnimationDuration];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(hideAnimationEnd)];
    self.alpha = kTransparentAlpha; // The binary passes zero here, not full opacity.
    self.baseView.frame = CGRectMake(CGRectGetMinX(panelFrame),
                                     (CGRectGetMinY(panelFrame) + CGRectGetHeight(panelFrame)) -
                                         (CGFloat)m_DefaultHeight,
                                     CGRectGetWidth(panelFrame),
                                     CGRectGetHeight(panelFrame));
    [UIView commitAnimations];
}

- (void)hideAnimationEnd {
    [self.parentView showInfomation];
    [self removeFromSuperview];
    self.parentView.settingView = nil;
}

#pragma mark Touch handling

/** @ghidraAddress 0xeb9c0 */
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    // The overlay only acts on touch-up; began, moved, and cancelled are empty in the binary too.
}

/** @ghidraAddress 0xeb9c4 */
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    if (m_Animating) {
        return;
    }
    for (UITouch *touch in [event touchesForView:self]) {
        CGPoint location = [touch locationInView:self];
        CGRect bounds =
            CGRectMake(0.0, 0.0, CGRectGetWidth(self.frame), CGRectGetHeight(self.frame));
        if (location.x >= 0.0 && location.x <= CGRectGetWidth(bounds) && location.y >= 0.0 &&
            location.y <= CGRectGetHeight(bounds)) {
            [self CloseView];
            return;
        }
    }
}

/** @ghidraAddress 0xebbbc */
- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
}

#pragma mark Menu actions

- (void)SelectCustomizeButton {
    SoundEffectManager::GetInstance()->PlayThemedSoundEffect(kSoundEffectDecide);
    [self.parentView showCustomizeView];
    [RBUserSettingData sharedInstance].newCustomItem = NO;
    [[RBUserSettingData sharedInstance] save];
    [self.customButton removeFlashEffect];
    [self hideAnimation];
}

- (void)selectThema:(id)sender {
    SoundEffectManager::GetInstance()->PlayThemedSoundEffect(kSoundEffectDecide);
    [RBUserSettingData sharedInstance].newThema = NO;
    [[RBUserSettingData sharedInstance] save];
    [self.parentView showThema];
    [self hideAnimation];
}

- (void)SelectHowToPlayButton {
    SoundEffectManager::GetInstance()->PlayThemedSoundEffect(kSoundEffectDecide);
    [self.parentView showHowToView];
    [RBUserSettingData sharedInstance].howtoFirstInfo = YES;
    [[RBUserSettingData sharedInstance] save];
    [self.howToButton removeFlashEffect];
    [self hideAnimation];
}

- (void)SelectInfoButton {
    SoundEffectManager::GetInstance()->PlayThemedSoundEffect(kSoundEffectDecide);
    [self.parentView showNotificationPageView];
    [self hideAnimation];
}

- (void)SelectTermButton {
    SoundEffectManager::GetInstance()->PlayThemedSoundEffect(kSoundEffectDecide);
    [self.parentView showTermView];
    [self hideAnimation];
}

- (void)SelectApplilinkButton {
    SoundEffectManager::GetInstance()->PlayThemedSoundEffect(kSoundEffectDecide);
    [self.parentView showApplilinkView];
    [AppDelegate appDelegate].unreadRecommendCount = 0;
    [self hideAnimation];
}

- (void)SelectExitButton {
    if (m_Animating) {
        return;
    }
    [self hideAnimation];
}

- (void)selectMap:(id)sender {
    SoundEffectManager::GetInstance()->PlayThemedSoundEffect(kSoundEffectDecide);
    [self.parentView showSearchView];
    [self hideAnimation];
}

#pragma mark Accessors

/** @ghidraAddress 0xec164 */
- (RBSettingMenuButton *)getCustomizeButtonView {
    return self.customButton;
}

@end
