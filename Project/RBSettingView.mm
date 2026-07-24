//
//  RBSettingView.mm
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RBSettingView). Verified against the
//  arm64 disassembly: -setupView:'s per-theme panel styling and the vertical button-stack maths were
//  recovered from the soft-float register moves that the decompiler folds into pseudo-variables, and
//  the open/close frame animations were confirmed against the block literals the decompiler emits.
//  This is an Objective-C++ file because several handlers reach the C++ SoundEffectManager engine
//  singleton.
//

#import "RBSettingView.h"

#import "AppDelegate.h"
#import "RBMacros.h"
#import "RBMusicView.h"
#import "RBSettingMenuButton.h"
#import "RBTutorialManager.h"
#import "RBUserSettingData.h"
#import "neEngineBridge.h"

// Themed sound-effect slots. The panel plays a theme-specific slot when it opens: the Classic theme
// uses its own slot, and the Limelight and Colette themes share another. Dismissal and every
// sub-screen selection reuse the shared cancel and decide slots.
constexpr int kSoundEffectDecide = 1;
constexpr int kSoundEffectCancel = 4;
constexpr int kSoundEffectSettingOpenClassic = 3;
constexpr int kSoundEffectSettingOpen = 12;

// Autoresizing masks. The overlay itself stays pinned to the whole screen; the panel keeps its width
// and stays anchored to the top; each button keeps its width and stays anchored to the bottom of the
// panel so the column grows downward.
constexpr UIViewAutoresizing kAutoresizingFull =
    UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth |
    UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin |
    UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;
constexpr UIViewAutoresizing kAutoresizingPanel = UIViewAutoresizingFlexibleWidth |
                                                  UIViewAutoresizingFlexibleRightMargin |
                                                  UIViewAutoresizingFlexibleTopMargin;
constexpr UIViewAutoresizing kAutoresizingButton =
    UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;

// The panel fades and slides over a quarter second.
constexpr NSTimeInterval kSettingAnimationDuration = 0.25;

// Colette-theme (thema == 2) panel background and border colours, and the shared border width used by
// the Classic and Colette themes. Read from the binary's constant pool at 0x1003016a0 (background
// RGB), 0x1003016c0 (border RGB), and 0x1003016b8 (border width).
constexpr CGFloat kColetteBackgroundRed = 0.945;
constexpr CGFloat kColetteBackgroundGreen = 0.9420;
constexpr CGFloat kColetteBackgroundBlue = 0.7647;
constexpr CGFloat kColetteBorderRed = 0.7962;
constexpr CGFloat kColetteBorderGreen = 0.7803;
constexpr CGFloat kColetteBorderBlue = 0.6470;
constexpr CGFloat kThemedBorderWidth = 1.3;

// The Limelight theme (thema == 1) uses a plain white panel with a fixed corner radius.
constexpr CGFloat kLimelightCornerRadius = 10.0;

// Per-theme panel corner radii, indexed by RBUserSettingData.thema. The default table is used for the
// iPad (wide) layout; the region table (IsPad() == 0) is used otherwise. Values read from
// the binary's constant pool at 0x1003017d0 and 0x1003017dc.
constexpr CGFloat kSettingCornerRadiusDefault[] = {22.0, 22.0, 33.0};
constexpr CGFloat kSettingCornerRadiusRegion[] = {14.0, 14.0, 14.0};

// The panel button-column origin (x, y of the first button, in panel coordinates) and the vertical
// gap inserted before each subsequent button, both indexed by theme and iPad idiom. These mirror
// the layout tables InitializeSettingLayoutGlobals (0xec450) builds at 0x1003dc8d0/0x1003dc900
// (origin) and 0x1003dc930/0x1003dc960 (step, whose y component is the gap).
typedef struct SettingButtonLayout {
    CGFloat originX;
    CGFloat originY;
    CGFloat step;
} SettingButtonLayout;

// The menu buttons in column order, with the artwork index passed to
// -[RBSettingMenuButton initWithFilename:] and the action each button's inner control triggers. The
// artwork index 4 is intentionally skipped, and the terms button is the eighth entry.
typedef struct SettingMenuEntry {
    int filename;
    SEL action;
} SettingMenuEntry;

// The panel background is fully opaque and the borders are drawn at full alpha.
constexpr CGFloat kOpaqueAlpha = 1.0;

// The customise tutorial identifier passed to -startTutorialWithType:withRootView:.
constexpr NSInteger kTutorialTypeCustomize = 27;

@implementation RBSettingView {
    // The active theme, cached from RBUserSettingData when the panel is built.
    RBUserSettingDataTheme _thema;
    // Whether an open or close animation is currently running.
    BOOL m_Animating;
    // The panel's collapsed height (before the button column is stacked).
    float m_DefaultHeight;
    // The additional height the button column adds when the panel is open.
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

    self.backgroundColor = nil;
    self.autoresizingMask = kAutoresizingFull;

    self.baseView = [[UIView alloc] initWithFrame:buttonFrame];
    self.baseView.clipsToBounds = YES;
    self.baseView.autoresizingMask = kAutoresizingPanel;
    [self addSubview:self.baseView];

    // The panel's outer height, captured before the buttons are stacked, is used by the close
    // animation to shrink the panel back to the top edge.
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

    // The button-column origin and step gap, built by InitializeSettingLayoutGlobals (0xec450) into
    // the layout tables at 0x1003dc8d0/0x1003dc900 (origin) and 0x1003dc930/0x1003dc960 (step). The
    // region tables apply when IsPad() == 0, the default tables otherwise; both are
    // indexed by theme.
    static const SettingButtonLayout defaultLayout[] = {
        {13.0, 30.0, 26.0},
        {13.0, 10.0, 26.0},
        {5.0, 14.0, 13.0},
    };
    static const SettingButtonLayout regionLayout[] = {
        {5.0, 14.0, 13.0},
        {5.0, 14.0, 13.0},
        {5.0, 14.0, 13.0},
    };
    SettingButtonLayout layout = (isPad == 0) ? regionLayout[thema] : defaultLayout[thema];

    // The menu buttons in column order, each with the artwork index passed to
    // -[RBSettingMenuButton initWithFilename:] and the action its inner control triggers. Artwork
    // index 4 is skipped; the terms button (index 7) is stored into infoButton, overwriting the
    // information button (index 5) that also went there, exactly as the binary does.
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
        // Every button after the first is separated from the previous one by the theme's step gap.
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

    // The total stacked height (final button's bottom edge) is what the open animation grows the
    // panel by.
    m_NeedMenuHeight = (float)(layout.step + y + previousHeight);

    // Flash the buttons whose sub-screens have new content to advertise.
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
    self.alpha = 1.0;

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
          // The Colette theme launches the customise tutorial the first time the panel closes.
          if ([RBUserSettingData sharedInstance].thema == RBUserSettingDataThemeColette &&
              [RBTutorialManager isTutorialCustomize]) {
              [weakSelf.parentView.tutorialView startTutorialWithType:kTutorialTypeCustomize
                                                         withRootView:weakSelf.parentView];
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
    self.alpha = 1.0;
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

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    if (m_Animating) {
        return;
    }
    // Any tap that reaches the overlay (the buttons take exclusive touches of their own) dismisses
    // the panel: the touch is closed when its location falls within the overlay's own bounds.
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

@end
