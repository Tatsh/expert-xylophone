#import "RBMusicDifficultyView.h"

#import "AudioManager.h"
#import "MusicData.h"
#import "MusicDataExtend.h"
#import "RBMusicView.h"
#import "RBUserSettingData.h"
#import "UIImage+RB.h"
#import "UIImageView+RB.h"
#import "neEngineBridge.h"

// The four difficulty slots hosted by this selector.
enum {
    kDifficultyBasic = 0,
    kDifficultyMedium = 1,
    kDifficultyHard = 2,
    kDifficultyExtended = 3,
};

// The Colette theme adds the animated background; on it the button icons switch to their alternate
// artwork and the number images take a themed centre offset. Themes below it (Classic and
// Limelight) use the ordinary artwork.
static const NSInteger kThemaColette = RBUserSettingDataThemeColette;

// The layout offset applied to the buttons on the font-variant Colette layout (0x41500000).
static const float kColetteLayoutOffset = 13.0f;

// The autoresizing mask applied to every button and overlay: the four flexible margins.
static const UIViewAutoresizing kButtonAutoresizingMask =
    UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
    UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;

// The opaque and translucent button alphas for the selected and unselected difficulties. The
// translucent value is the shared g_dTranslucentAlpha global (@0x1002ec6a0, 0.8); it is cached
// here rather than re-declared as a shared extern until the palette globals are recovered.
static const CGFloat kButtonAlphaSelected = 1.0;
static const CGFloat kButtonAlphaTranslucent = 0.8;

// The centre of a button's overlay is half its bounds.
static const CGFloat kOverlayHalf = 0.5;

// The button vertical centre on the default (non-font-variant) and font-variant layouts.
static const CGFloat kButtonCenterYDefault = 43.0; // DAT_1002eeee8
static const CGFloat kButtonCenterYVariant = 84.0; // g_dLayoutMetricEightyFour

// The extended button's centre on the default layout (built only when the song has an extended
// chart, so its slot is always the four-button layout).
static const CGFloat kExtendedCenterXDefault = 255.0; // DAT_100300f98
static const CGFloat kExtendedCenterYDefault = 43.0;  // DAT_1002eeee8

// The default-layout button horizontal centres, indexed by whether the song lacks an extended
// chart (index 0: four-button layout with the extended slot; index 1: three-button layout).
static const CGFloat kHardCenterXDefault[] = {185.0, 245.0};   // DAT_1003011d0
static const CGFloat kMediumCenterXDefault[] = {115.0, 150.0}; // DAT_1003011e0
static const CGFloat kBasicCenterXDefault[] = {45.0, 54.0};    // DAT_1003011f0

// The font-variant button horizontal centres, added to the layout offset. The three-button layout
// (no extended chart) and the four-button layout use different columns.
static const CGFloat kBasicCenterXVariantThree = 89.0;    // DAT_1002eef00
static const CGFloat kMediumCenterXVariantThree = 228.0;  // DAT_10030120c
static const CGFloat kHardCenterXVariantThree = 367.0;    // DAT_100301210
static const CGFloat kBasicCenterXVariantFour = 63.0;     // DAT_100301200
static const CGFloat kMediumCenterXVariantFour = 173.0;   // DAT_100301174
static const CGFloat kHardCenterXVariantFour = 283.0;     // DAT_100301204
static const CGFloat kExtendedCenterXVariantFour = 393.0; // DAT_100301208

// The number-image centre offsets added to the button centre on the non-Colette themes, keyed by
// the font variant (decoded from the guard-initialised globals at 0x1003dc6e0/0x1003dc6f0, sourced
// from 0x1002eef10/0x1002eef20).
static const CGFloat kNumberOffsetXVariant = 6.0;
static const CGFloat kNumberOffsetYVariant = 12.0;
static const CGFloat kNumberOffsetXDefault = 2.0;
static const CGFloat kNumberOffsetYDefault = 10.0;

// The themed voice loaded when a difficulty is picked is the difficulty index plus this base.
static const int kThemedVoiceDifficultyBase = 10;

// The themed sound effect played when the extended difficulty is picked.
static const int kExtendedSoundEffect = 15;

// The largest difficulty-level image index (levels above this clamp to the last image).
enum { kMaxDifficultyLevelIndex = 14 };

// The base difficulty icon, indexed by difficulty slot, on the ordinary (non-Colette) themes.
static NSString *const kDifficultyIconNames[] = {
    @"02_music_detail/det_dif_0",
    @"02_music_detail/det_dif_1",
    @"02_music_detail/det_dif_2",
    @"02_music_detail/det_dif_3",
};

// The alternate difficulty icon, indexed by difficulty slot, on the default layout of a song that
// has an extended chart.
static NSString *const kDifficultyIconAltNames[] = {
    @"02_music_detail/det_dif_10",
    @"02_music_detail/det_dif_11",
    @"02_music_detail/det_dif_12",
    @"02_music_detail/det_dif_13",
};

// The base difficulty icon used on the Colette themes.
static NSString *const kDifficultyIconColette = @"02_music_detail/det_dif";

// The selected-state flash overlay, indexed by difficulty slot, on the ordinary themes.
static NSString *const kDifficultySelectedNames[] = {
    @"02_music_detail/det_dif_sel_0",
    @"02_music_detail/det_dif_sel_1",
    @"02_music_detail/det_dif_sel_2",
    @"02_music_detail/det_dif_sel_3",
};

// The alternate selected-state flash overlay for the extended-chart default layout.
static NSString *const kDifficultySelectedAltNames[] = {
    @"02_music_detail/det_dif_sel_10",
    @"02_music_detail/det_dif_sel_11",
    @"02_music_detail/det_dif_sel_12",
    @"02_music_detail/det_dif_sel_13",
};

// The selected-state flash overlay used on the Colette themes.
static NSString *const kDifficultySelectedColette = @"02_music_detail/det_dif_sel";

// The difficulty-level number images, one table per difficulty slot, indexed by the clamped level.
static NSString *const kBasicLevelNames[] = {
    @"02_music_detail/det_difa_1",
    @"02_music_detail/det_difa_2",
    @"02_music_detail/det_difa_3",
    @"02_music_detail/det_difa_4",
    @"02_music_detail/det_difa_5",
    @"02_music_detail/det_difa_6",
    @"02_music_detail/det_difa_7",
    @"02_music_detail/det_difa_8",
    @"02_music_detail/det_difa_9",
    @"02_music_detail/det_difa_10",
    @"02_music_detail/det_difa_11",
    @"02_music_detail/det_difa_12",
    @"02_music_detail/det_difa_13",
    @"02_music_detail/det_difa_14",
    @"02_music_detail/det_difa_15",
};
static NSString *const kMediumLevelNames[] = {
    @"02_music_detail/det_difb_1",
    @"02_music_detail/det_difb_2",
    @"02_music_detail/det_difb_3",
    @"02_music_detail/det_difb_4",
    @"02_music_detail/det_difb_5",
    @"02_music_detail/det_difb_6",
    @"02_music_detail/det_difb_7",
    @"02_music_detail/det_difb_8",
    @"02_music_detail/det_difb_9",
    @"02_music_detail/det_difb_10",
    @"02_music_detail/det_difb_11",
    @"02_music_detail/det_difb_12",
    @"02_music_detail/det_difb_13",
    @"02_music_detail/det_difb_14",
    @"02_music_detail/det_difb_15",
};
static NSString *const kHardLevelNames[] = {
    @"02_music_detail/det_difc_1",
    @"02_music_detail/det_difc_2",
    @"02_music_detail/det_difc_3",
    @"02_music_detail/det_difc_4",
    @"02_music_detail/det_difc_5",
    @"02_music_detail/det_difc_6",
    @"02_music_detail/det_difc_7",
    @"02_music_detail/det_difc_8",
    @"02_music_detail/det_difc_9",
    @"02_music_detail/det_difc_10",
    @"02_music_detail/det_difc_11",
    @"02_music_detail/det_difc_12",
    @"02_music_detail/det_difc_13",
    @"02_music_detail/det_difc_14",
    @"02_music_detail/det_difc_15",
};
static NSString *const kExtendedLevelNames[] = {
    @"02_music_detail/det_difd_1",
    @"02_music_detail/det_difd_2",
    @"02_music_detail/det_difd_3",
    @"02_music_detail/det_difd_4",
    @"02_music_detail/det_difd_5",
    @"02_music_detail/det_difd_6",
    @"02_music_detail/det_difd_7",
    @"02_music_detail/det_difd_8",
    @"02_music_detail/det_difd_9",
    @"02_music_detail/det_difd_10",
    @"02_music_detail/det_difd_11",
    @"02_music_detail/det_difd_12",
    @"02_music_detail/det_difd_13",
    @"02_music_detail/det_difd_14",
    @"02_music_detail/det_difd_15",
};

@implementation RBMusicDifficultyView

#pragma mark Lifecycle

- (instancetype)initWithFrame:(CGRect)frame MusicSelectedBase:(RBMusicView *)MusicSelectedBase {
    self = [super initWithFrame:frame];
    if (self) {
        self.musicSelectedBase = MusicSelectedBase;
        self.difficulty = [RBUserSettingData sharedInstance].difficulty;
        if ([RBUserSettingData sharedInstance].thema == kThemaColette &&
            GetFontVariantFlag() != kFontVariantDefault) {
            self.layoutOffset = kColetteLayoutOffset;
        } else {
            self.layoutOffset = 0.0f;
        }
        [self SetupView];
        [self ShowSelectDifficulty];
    }
    return self;
}

#pragma mark View construction

- (void)SetupView {
    MusicData *musicData = self.musicSelectedBase.musicData;
    MusicDataExtend *extend = musicData.spData;
    BOOL hasExtended = extend != nil;
    BOOL fontVariant = GetFontVariantFlag() != kFontVariantDefault;

    CGFloat basicX;
    CGFloat mediumX;
    CGFloat hardX;
    CGFloat buttonY;
    CGFloat extendedX = 0.0;
    CGFloat extendedY = 0.0;

    if (!fontVariant) {
        // The three horizontal-centre tables are indexed by whether the song lacks its extended
        // chart.
        NSUInteger column = hasExtended ? 0 : 1;
        basicX = kBasicCenterXDefault[column];
        mediumX = kMediumCenterXDefault[column];
        hardX = kHardCenterXDefault[column];
        buttonY = kButtonCenterYDefault;
        if (hasExtended) {
            extendedX = kExtendedCenterXDefault;
            extendedY = kExtendedCenterYDefault;
        }
    } else {
        CGFloat offset = self.layoutOffset;
        buttonY = kButtonCenterYVariant;
        if (!hasExtended) {
            basicX = offset + kBasicCenterXVariantThree;
            mediumX = offset + kMediumCenterXVariantThree;
            hardX = offset + kHardCenterXVariantThree;
        } else {
            basicX = offset + kBasicCenterXVariantFour;
            mediumX = offset + kMediumCenterXVariantFour;
            hardX = offset + kHardCenterXVariantFour;
            extendedX = offset + kExtendedCenterXVariantFour;
            extendedY = kButtonCenterYVariant;
        }
    }

    self.difficultySelectedImages = [NSMutableArray arrayWithCapacity:kDifficultyExtended + 1];
    self.difficultyNumberImages = [NSMutableArray arrayWithCapacity:kDifficultyExtended + 1];
    self.difficultyButtons = [NSMutableArray arrayWithCapacity:kDifficultyExtended + 1];

    [self CreateButton:kDifficultyBasic
              Position:CGPointMake(basicX, buttonY)
                Number:self.musicSelectedBase.musicData.difficultyBasic];
    [self CreateButton:kDifficultyMedium
              Position:CGPointMake(mediumX, buttonY)
                Number:self.musicSelectedBase.musicData.difficultyMedium];
    [self CreateButton:kDifficultyHard
              Position:CGPointMake(hardX, buttonY)
                Number:self.musicSelectedBase.musicData.difficultyHard];

    if (self.musicSelectedBase.musicData.spData == nil) {
        return;
    }
    [self CreateButton:kDifficultyExtended
              Position:CGPointMake(extendedX, extendedY)
                Number:self.musicSelectedBase.musicData.ExtMusicData.difficultyBasic];
}

- (void)CreateButton:(int)CreateButton Position:(CGPoint)Position Number:(int)Number {
    int thema = [RBUserSettingData sharedInstance].thema;
    BOOL hasExtended = self.musicSelectedBase.musicData.spData != nil;
    BOOL fontVariant = GetFontVariantFlag() != kFontVariantDefault;

    NSString *iconName = kDifficultyIconColette;
    if (thema < kThemaColette) {
        if (!fontVariant && hasExtended) {
            iconName = kDifficultyIconAltNames[CreateButton];
        } else {
            iconName = kDifficultyIconNames[CreateButton];
        }
    }
    UIImage *iconImage = [UIImage imageWithName:iconName];
    CGSize iconSize = iconImage.size;

    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button setImage:iconImage forState:UIControlStateNormal];
    [button setImage:iconImage forState:UIControlStateSelected];
    [button setImage:iconImage forState:UIControlStateHighlighted];
    button.bounds = CGRectMake(0.0, 0.0, iconSize.width, iconSize.height);
    button.center = Position;
    button.tag = CreateButton;
    button.autoresizingMask = kButtonAutoresizingMask;
    [self addSubview:button];
    [self.difficultyButtons addObject:button];
    button.exclusiveTouch = YES;
    [button addTarget:self
                  action:@selector(SelectDifficultyButton:)
        forControlEvents:UIControlEventTouchUpInside];

    NSString *selectedName = kDifficultySelectedColette;
    if (thema < kThemaColette) {
        if (!fontVariant && hasExtended) {
            selectedName = kDifficultySelectedAltNames[CreateButton];
        } else {
            selectedName = kDifficultySelectedNames[CreateButton];
        }
    }
    UIImage *selectedImage = [UIImage imageWithName:selectedName];
    UIImageView *selectedView = [[UIImageView alloc] initWithImage:selectedImage];
    CGSize selectedSize = selectedImage.size;
    selectedView.frame = CGRectMake(0.0, 0.0, selectedSize.width, selectedSize.height);
    selectedView.center = CGPointMake(button.bounds.size.width * kOverlayHalf,
                                      button.bounds.size.height * kOverlayHalf);
    selectedView.autoresizingMask = kButtonAutoresizingMask;
    [button addSubview:selectedView];
    // The binary reads the theme here but discards it; the flash is applied unconditionally.
    (void)[RBUserSettingData sharedInstance].thema;
    [selectedView SetFlashEffectFast];
    [self.difficultySelectedImages addObject:selectedView];

    NSString *const *levelNames;
    switch (CreateButton) {
    case kDifficultyMedium:
        levelNames = kMediumLevelNames;
        break;
    case kDifficultyHard:
        levelNames = kHardLevelNames;
        break;
    case kDifficultyExtended:
        levelNames = kExtendedLevelNames;
        break;
    default:
        levelNames = kBasicLevelNames;
        break;
    }
    // The level indexes the table directly: a level at or below zero takes the first image and a
    // level above the last clamps to it.
    int levelIndex = Number > kMaxDifficultyLevelIndex ? kMaxDifficultyLevelIndex : Number;
    if (Number < 0) {
        levelIndex = 0;
    }

    UIImage *levelImage = [UIImage imageWithName:levelNames[levelIndex]];
    if (levelImage != nil) {
        UIImageView *levelView = [[UIImageView alloc] initWithImage:levelImage];
        CGSize levelSize = levelImage.size;
        levelView.frame = CGRectMake(0.0, 0.0, levelSize.width, levelSize.height);
        if ([RBUserSettingData sharedInstance].thema < kThemaColette) {
            CGFloat offsetX = fontVariant ? kNumberOffsetXVariant : kNumberOffsetXDefault;
            CGFloat offsetY = fontVariant ? kNumberOffsetYVariant : kNumberOffsetYDefault;
            levelView.center = CGPointMake(button.bounds.size.width * kOverlayHalf + offsetX,
                                           button.bounds.size.height * kOverlayHalf + offsetY);
        } else {
            // On the Colette themes the number nudges one point left on the font variant.
            CGFloat offsetX = -static_cast<CGFloat>(fontVariant ? 1 : 0);
            levelView.center = CGPointMake(button.bounds.size.width * kOverlayHalf + offsetX,
                                           button.bounds.size.height * kOverlayHalf);
        }
        levelView.autoresizingMask = kButtonAutoresizingMask;
        [button addSubview:levelView];
        [self.difficultyNumberImages addObject:levelView];
    }
}

#pragma mark Selection

- (void)ShowSelectDifficulty {
    for (NSUInteger i = 0; i < self.difficultyButtons.count; ++i) {
        if (i == static_cast<NSUInteger>(self.difficulty)) {
            [self.difficultySelectedImages[i] setHidden:NO];
            [self.difficultyButtons[i] setAlpha:kButtonAlphaSelected];
            [self.difficultyNumberImages[i] setAlpha:kButtonAlphaSelected];
        } else {
            [self.difficultySelectedImages[i] setHidden:YES];
            [self.difficultyButtons[i] setAlpha:kButtonAlphaTranslucent];
            [self.difficultyNumberImages[i] setAlpha:kButtonAlphaTranslucent];
        }
    }
}

- (void)SelectDifficultyButton:(UIButton *)SelectDifficultyButton {
    int difficulty = static_cast<int>(SelectDifficultyButton.tag);
    if (self.difficulty == difficulty) {
        return;
    }
    [[AudioManager sharedManager] releaseVoice];
    if (difficulty == kDifficultyExtended) {
        SoundEffectManager::GetInstance()->PlayThemedSoundEffect(kExtendedSoundEffect);
    } else {
        SoundEffectManager::GetInstance()->LoadAndSetThemedVoice(difficulty +
                                                                 kThemedVoiceDifficultyBase);
    }
    self.difficulty = difficulty;
    [self ShowSelectDifficulty];
    if (self.musicSelectedBase != nil) {
        [self.musicSelectedBase ShowSelectDifficulty];
    }
}

- (void)setEnableButton:(BOOL)enableButton {
    for (NSUInteger i = 0; i < self.difficultyButtons.count; ++i) {
        [self.difficultyButtons[i] setEnabled:enableButton];
    }
}

- (UIButton *)getDifficultyButton:(int)getDifficultyButton {
    return self.difficultyButtons[getDifficultyButton];
}

- (void)SetFlashEffectDuration:(float)SetFlashEffectDuration Start:(float)Start End:(float)End {
    // Empty in this build.
}

@end
