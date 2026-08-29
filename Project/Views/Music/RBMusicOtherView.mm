#import "RBMusicOtherView.h"

#import "RBMusicView.h"
#import "RBUserSettingData.h"
#import "UIImage+RB.h"
#import "UIView+RB.h"
#import "deviceenvironment.h"
#import "engineglobals.h"
#import "soundeffectmanager.h"

namespace {

constexpr unsigned int kSoundHandleNone = 0xffffffff;

constexpr int kSoundEffectSwitchToggle = 2;

constexpr int kThemeWhite = 0;

constexpr int kGhostStyleOff = 0;
constexpr int kGhostStyleOn = 1;

constexpr int kToggleColumnCountWide = 4;
constexpr int kToggleColumnCountNarrow = 3;

constexpr double kColumnWidthFactorWide = 0.25;
constexpr double kColumnWidthFactorNarrow = 0.33;
constexpr double kColumnTopFactor = 0.2;
constexpr double kColumnHeightFactor = 0.6;
constexpr double kBaseImageTopFactor = 0.1;
constexpr double kHalf = 0.5;

// The phone idiom takes the narrower pair, the pad the wider.
constexpr double kBarRestLeftDefault = 11.0;
constexpr double kBarRestLeftVariant = 18.0;
constexpr double kBarWidthAdjustDefault = -22.0;
constexpr double kBarWidthAdjustVariant = -36.0;

static NSString *const kBaseImageNames[] = {
    @"02_music_detail/det_oth_psm",
    @"02_music_detail/det_oth_gsm",
    @"02_music_detail/det_oth_jrm",
    @"02_music_detail/det_oth_fcm",
};

static NSString *const kFrameImageNames[] = {
    @"02_music_detail/det_psm_btn",
    @"02_music_detail/det_gsm_btn",
    @"02_music_detail/det_jrm_btn",
    @"02_music_detail/det_fcm_btn",
};

static NSString *const kBarImageName = @"02_music_detail/det_oth_bar";

constexpr UIViewAutoresizing kContainerAutoresizing =
    UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth |
    UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin |
    UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;

} // namespace

@implementation RBMusicOtherView {
    unsigned int m_PrevSound;
}

#pragma mark Lifecycle

/** @ghidraAddress 0x1a477c */
- (instancetype)initWithFrame:(CGRect)frame MusicSelectedBase:(RBMusicView *)MusicSelectedBase {
    self = [super initWithFrame:frame];
    if (self) {
        self.musicSelectedBase = MusicSelectedBase;
        BOOL fcOn = [RBUserSettingData sharedInstance].userFullCombo ?
                        [RBUserSettingData sharedInstance].cpuFullCombo :
                        NO;
        self.isFcMode = fcOn;
        self.isJrMode = [RBUserSettingData sharedInstance].fullJustReflec;
        m_PrevSound = kSoundHandleNone;
        if ([RBUserSettingData sharedInstance].thema == kThemeWhite) {
            [RBUserSettingData sharedInstance].vsPastel = NO;
        }
        [self SetupView];
    }
    return self;
}

#pragma mark View construction

/** @ghidraAddress 0x1a4a38 */
- (void)SetupView {
    self.userInteractionEnabled = YES;

    NSArray<NSString *> *baseImageNames = [NSArray arrayWithObjects:kBaseImageNames
                                                              count:kToggleColumnCountWide];
    NSArray<NSString *> *frameImageNames = [NSArray arrayWithObjects:kFrameImageNames
                                                               count:kToggleColumnCountWide];

    if ([RBUserSettingData sharedInstance].thema != kThemeWhite) {
        for (int column = 0; column < kToggleColumnCountWide; ++column) {
            [self buildToggleColumnAtIndex:column
                               columnCount:kToggleColumnCountWide
                                 imageName:baseImageNames[column]
                            frameImageName:frameImageNames[column]
                                switchType:static_cast<RBMusicOtherSwitchType>(column)];
        }
    } else {
        for (int column = 0; column < kToggleColumnCountNarrow; ++column) {
            int imageIndex = column + 1;
            [self buildToggleColumnAtIndex:column
                               columnCount:kToggleColumnCountNarrow
                                 imageName:baseImageNames[imageIndex]
                            frameImageName:frameImageNames[imageIndex]
                                switchType:static_cast<RBMusicOtherSwitchType>(imageIndex)];
        }
    }
}

- (void)buildToggleColumnAtIndex:(int)column
                     columnCount:(int)columnCount
                       imageName:(NSString *)imageName
                  frameImageName:(NSString *)frameImageName
                      switchType:(RBMusicOtherSwitchType)switchType {
    double columnWidthFactor =
        columnCount == kToggleColumnCountWide ? kColumnWidthFactorWide : kColumnWidthFactorNarrow;

    UIView *container = [[UIView alloc] init];
    UIImageView *labelImage = [[UIImageView alloc] initWithImage:[UIImage imageWithName:imageName]];
    UIImageView *barTrack =
        [[UIImageView alloc] initWithImage:[UIImage imageWithName:kBarImageName]];
    UIImageView *knob = [[UIImageView alloc] initWithImage:[UIImage imageWithName:frameImageName]];

    CGFloat selfWidth = self.width;
    CGFloat selfHeight = self.height;
    container.frame = CGRectMake(static_cast<int>(column * columnWidthFactor * selfWidth),
                                 static_cast<int>(selfHeight * kColumnTopFactor),
                                 static_cast<int>(selfWidth * columnWidthFactor),
                                 static_cast<int>(selfHeight * kColumnHeightFactor));

    CGFloat containerWidth = container.width;
    CGFloat containerHeight = container.height;
    if (!IsPad()) {
        labelImage.frame =
            CGRectMake(static_cast<int>(containerWidth * kHalf - labelImage.width * kHalf),
                       static_cast<int>(containerHeight * kBaseImageTopFactor),
                       labelImage.width,
                       labelImage.height);
        barTrack.frame =
            CGRectMake(static_cast<int>((containerWidth - barTrack.width) / 2),
                       static_cast<int>(containerHeight * kHalf - barTrack.height * kHalf),
                       barTrack.width,
                       barTrack.height);
    } else {
        labelImage.frame =
            CGRectMake(static_cast<int>(containerWidth * kHalf - labelImage.width * kHalf),
                       static_cast<int>(containerHeight * kBaseImageTopFactor),
                       labelImage.width,
                       labelImage.height);
        barTrack.frame =
            CGRectMake(static_cast<int>(containerWidth * kHalf - barTrack.width * kHalf),
                       static_cast<int>(containerHeight * kHalf - barTrack.height * kHalf),
                       barTrack.width,
                       barTrack.height);
    }

    [container addSubview:labelImage];
    barTrack.userInteractionEnabled = YES;
    [container addSubview:barTrack];
    container.autoresizingMask = kContainerAutoresizing;
    [self addSubview:container];

    // The binary branches on the theme here, but every branch picks by idiom alone.
    (void)[RBUserSettingData sharedInstance].thema;
    BOOL fontDefault = !IsPad();
    double barRestLeft = fontDefault ? kBarRestLeftDefault : kBarRestLeftVariant;
    double barWidthAdjust = fontDefault ? kBarWidthAdjustDefault : kBarWidthAdjustVariant;
    // The travel rectangle spans the bar track, so its width is the distance the knob moves.
    CGRect barRect = CGRectMake(barRestLeft, 0.0, barTrack.width + barWidthAdjust, barTrack.height);

    knob.frame =
        CGRectMake(static_cast<int>(barRestLeft) - static_cast<int>(knob.width) / 2,
                   static_cast<int>(barTrack.height) / 2 - static_cast<int>(knob.height) / 2,
                   knob.width,
                   knob.height);
    knob.autoresizingMask = kContainerAutoresizing;
    [barTrack addSubview:knob];

    switch (switchType) {
    case RBMusicOtherSwitchTypePastel:
        self.pastelView = container;
        self.pastelSelectedImage = knob;
        self.pastelBarRect = barRect;
        [barTrack addGestureRecognizer:[[UITapGestureRecognizer alloc]
                                           initWithTarget:self
                                                   action:@selector(tapPastel:)]];
        break;
    case RBMusicOtherSwitchTypeGhost:
        self.ghostView = container;
        self.ghostSelectedImage = knob;
        self.ghostBarRect = barRect;
        [barTrack addGestureRecognizer:[[UITapGestureRecognizer alloc]
                                           initWithTarget:self
                                                   action:@selector(tapGhost:)]];
        break;
    case RBMusicOtherSwitchTypeJustReflec:
        self.jrView = container;
        self.jrSelectedImage = knob;
        self.jrBarRect = barRect;
        [barTrack
            addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self
                                                                         action:@selector(tapJr:)]];
        break;
    case RBMusicOtherSwitchTypeFullCombo:
        self.fcView = container;
        self.fcSelectedImage = knob;
        self.fcBarRect = barRect;
        [barTrack
            addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self
                                                                         action:@selector(tapFc:)]];
        break;
    }

    (void)[RBUserSettingData sharedInstance].thema; // Yes, the binary re-reads and discards this.
    [self updateSwitchWithType:switchType];
}

/** @ghidraAddress 0x1a6d00 */
- (void)updateSwitchWithType:(RBMusicOtherSwitchType)updateSwitchWithType {
    BOOL on = NO;
    CGRect barRect = CGRectZero;
    UIImageView *selectedImage = nil;
    switch (updateSwitchWithType) {
    case RBMusicOtherSwitchTypePastel:
        on = [RBUserSettingData sharedInstance].vsPastel;
        barRect = self.pastelBarRect;
        selectedImage = self.pastelSelectedImage;
        break;
    case RBMusicOtherSwitchTypeGhost:
        on = [RBUserSettingData sharedInstance].ghostStyle == kGhostStyleOn;
        barRect = self.ghostBarRect;
        selectedImage = self.ghostSelectedImage;
        break;
    case RBMusicOtherSwitchTypeJustReflec:
        on = [RBUserSettingData sharedInstance].fullJustReflec;
        barRect = self.jrBarRect;
        selectedImage = self.jrSelectedImage;
        break;
    case RBMusicOtherSwitchTypeFullCombo:
        on = [RBUserSettingData sharedInstance].userFullCombo;
        barRect = self.fcBarRect;
        selectedImage = self.fcSelectedImage;
        break;
    }

    CGRect frame = selectedImage.frame;
    CGFloat baseX = barRect.origin.x;
    CGFloat offset = barRect.size.width;
    CGFloat frameY = frame.origin.y;
    CGFloat frameWidth = frame.size.width;
    CGFloat frameHeight = frame.size.height;
    if (on) {
        [UIView
            animateWithDuration:g_dMascotMessageAnimDuration
                     animations:^{
                       /** @ghidraAddress 0x1a7340 */
                       selectedImage.frame = CGRectMake(
                           baseX + offset - frameWidth * kHalf, frameY, frameWidth, frameHeight);
                     }];
    } else {
        [UIView animateWithDuration:g_dMascotMessageAnimDuration
                         animations:^{
                           /** @ghidraAddress 0x1a73c0 */
                           selectedImage.frame = CGRectMake(
                               baseX - frameWidth * kHalf, frameY, frameWidth, frameHeight);
                         }];
    }
}

#pragma mark Toggle handlers

- (void)playToggleSound {
    SoundEffectManager *manager = SoundEffectManager::GetInstance();
    if (m_PrevSound == kSoundHandleNone || !manager->IsPlaying(m_PrevSound)) {
        m_PrevSound = manager->PlayThemedSoundEffect(kSoundEffectSwitchToggle);
    }
}

/** @ghidraAddress 0x1a62c0 */
- (void)tapFc:(UITapGestureRecognizer *)tapFc {
    BOOL wasOn = [RBUserSettingData sharedInstance].userFullCombo ?
                     [RBUserSettingData sharedInstance].cpuFullCombo :
                     NO;
    [RBUserSettingData sharedInstance].userFullCombo = !wasOn;
    [RBUserSettingData sharedInstance].cpuFullCombo = !wasOn;
    [self updateSwitchWithType:RBMusicOtherSwitchTypeFullCombo];
    if (!wasOn) {
        [RBUserSettingData sharedInstance].ghostStyle = kGhostStyleOff;
        [RBUserSettingData sharedInstance].vsPastel = NO;
        [self updateSwitchWithType:RBMusicOtherSwitchTypeGhost];
        [self updateSwitchWithType:RBMusicOtherSwitchTypePastel];
    }
    [self playToggleSound];
    [self.musicSelectedBase updateDecideButton];
}

/** @ghidraAddress 0x1a652c */
- (void)tapJr:(UITapGestureRecognizer *)tapJr {
    [RBUserSettingData sharedInstance].fullJustReflec =
        ![RBUserSettingData sharedInstance].fullJustReflec;
    [self updateSwitchWithType:RBMusicOtherSwitchTypeJustReflec];
    if ([RBUserSettingData sharedInstance].fullJustReflec) {
        [RBUserSettingData sharedInstance].ghostStyle = kGhostStyleOff;
        [RBUserSettingData sharedInstance].vsPastel = NO;
        [self updateSwitchWithType:RBMusicOtherSwitchTypeGhost];
        [self updateSwitchWithType:RBMusicOtherSwitchTypePastel];
    }
    [self playToggleSound];
    [self.musicSelectedBase updateDecideButton];
}

/** @ghidraAddress 0x1a6758 */
- (void)tapGhost:(UITapGestureRecognizer *)tapGhost {
    if ([RBUserSettingData sharedInstance].ghostStyle == kGhostStyleOff) {
        [RBUserSettingData sharedInstance].ghostStyle = kGhostStyleOn;
    } else if ([RBUserSettingData sharedInstance].ghostStyle == kGhostStyleOn) {
        [RBUserSettingData sharedInstance].ghostStyle = kGhostStyleOff;
    }
    [self updateSwitchWithType:RBMusicOtherSwitchTypeGhost];
    if ([RBUserSettingData sharedInstance].ghostStyle == kGhostStyleOn) {
        [RBUserSettingData sharedInstance].userFullCombo = NO;
        [RBUserSettingData sharedInstance].cpuFullCombo = NO;
        [RBUserSettingData sharedInstance].fullJustReflec = NO;
        [RBUserSettingData sharedInstance].vsPastel = NO;
        [self updateSwitchWithType:RBMusicOtherSwitchTypeFullCombo];
        [self updateSwitchWithType:RBMusicOtherSwitchTypeJustReflec];
        [self updateSwitchWithType:RBMusicOtherSwitchTypePastel];
    }
    [self playToggleSound];
    [self.musicSelectedBase updateDecideButton];
}

/** @ghidraAddress 0x1a6a5c */
- (void)tapPastel:(UITapGestureRecognizer *)tapPastel {
    [RBUserSettingData sharedInstance].vsPastel = ![RBUserSettingData sharedInstance].vsPastel;
    [self updateSwitchWithType:RBMusicOtherSwitchTypePastel];
    if ([RBUserSettingData sharedInstance].vsPastel) {
        [RBUserSettingData sharedInstance].userFullCombo = NO;
        [RBUserSettingData sharedInstance].cpuFullCombo = NO;
        [RBUserSettingData sharedInstance].fullJustReflec = NO;
        [RBUserSettingData sharedInstance].ghostStyle = kGhostStyleOff;
        [self updateSwitchWithType:RBMusicOtherSwitchTypeFullCombo];
        [self updateSwitchWithType:RBMusicOtherSwitchTypeJustReflec];
        [self updateSwitchWithType:RBMusicOtherSwitchTypeGhost];
    }
    [self playToggleSound];
    [self.musicSelectedBase updateDecideButton];
}

@end
