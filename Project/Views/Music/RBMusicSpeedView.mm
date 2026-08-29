#import "RBMusicSpeedView.h"

#include <cmath>

#import "RBMusicView.h"
#import "RBUserSettingData.h"
#import "UIImage+RB.h"
#import "deviceenvironment.h"
#import "soundeffectmanager.h"

// @ghidraAddress 0x2eedc0
extern const double g_dMascotMessageAnimDuration;

constexpr int kSpeedSlotCount = 10;
constexpr int kSpeedMax = 10;

constexpr int kSoundEffectSpeedChange = 2;

constexpr unsigned int kNoSoundHandle = 0xffffffff;

constexpr int kThemeLimelight = 1;
constexpr int kThemeColette = 2;

// Seeded by the initialiser; the field is otherwise unused by this view.
constexpr int kSliderTypeDefault = 0;

constexpr UIViewAutoresizing kAutoresizingFlexibleAll =
    UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth |
    UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin |
    UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;

static NSString *const kSliderBarImageName = @"02_music_detail/det_spd_bar_1";
static NSString *const kSpeedMarkerImageName = @"02_music_detail/det_spd_bar_2";

// Decoded from the constant pool at 0x100301198 (274), 0x1002ec6e0 (50), 0x1002eeef0 (54),
// 0x1002fcfd8 (280), 0x100301158 (36), and 0x1002ee948 (60).
constexpr CGFloat kSliderBarDefaultX = 15.0;
constexpr CGFloat kSliderBarDefaultY = 27.0;
constexpr CGFloat kSliderBarDefaultWidth = 274.0;
constexpr CGFloat kSliderBarDefaultHeight = 50.0;
constexpr CGFloat kSliderBarWideTopInset = 54.0;
constexpr CGFloat kSliderBarColetteDefaultX = 10.0;
constexpr CGFloat kSliderBarColetteDefaultY = 36.0;
constexpr CGFloat kSliderBarColetteDefaultWidth = 280.0;
constexpr CGFloat kSliderBarColetteDefaultHeight = 30.0;
constexpr CGFloat kSliderBarColetteWideTopInset = 60.0;

// Decoded from the constant pool at 0x1003011b0 (41), 0x1002eeee8 (43), 0x100302480 (402),
// 0x1003011b8 (220), 0x1003011c8 (82), 0x1002ec6e0 (50), 0x1002eeec0 (38), 0x1003011a0 (261),
// and 0x1002ef170 (56).
constexpr CGFloat kBarBaseColetteWideX = 43.0;
constexpr CGFloat kBarBaseColetteWideY = 41.0;
constexpr CGFloat kBarBaseColetteWideWidth = 402.0;
constexpr CGFloat kBarBaseColetteWideHeight = 82.0;
constexpr CGFloat kBarBaseColetteX = 41.0;
constexpr CGFloat kBarBaseColetteY = 43.0;
constexpr CGFloat kBarBaseColetteWidth = 220.0;
constexpr CGFloat kBarBaseColetteHeight = 50.0;
constexpr CGFloat kBarBaseWideX = 27.0;
constexpr CGFloat kBarBaseWideY = 38.0;
constexpr CGFloat kBarBaseWideWidth = 402.0;
constexpr CGFloat kBarBaseWideHeight = 82.0;
constexpr CGFloat kBarBaseDefaultX = 19.0;
constexpr CGFloat kBarBaseDefaultY = 9.0;
constexpr CGFloat kBarBaseDefaultWidth = 261.0;
constexpr CGFloat kBarBaseDefaultHeight = 56.0;

constexpr CGFloat kHalf = 0.5;

constexpr CGFloat kTapDeadZoneLimelightWide = 30.0;
constexpr CGFloat kTapDeadZoneLimelightDefault = 20.0;
constexpr CGFloat kTapDeadZoneColetteWide = 25.0;
constexpr CGFloat kTapDeadZoneColetteDefault = 30.0;
constexpr CGFloat kTapDeadZoneWide = 27.0;
constexpr CGFloat kTapDeadZoneDefault = 20.0;

@interface RBMusicSpeedView () {
    unsigned int m_PrevSound; // +0x8
}
@end

@implementation RBMusicSpeedView

#pragma mark Lifecycle

- (instancetype)initWithFrame:(CGRect)frame MusicSelectedBase:(RBMusicView *)MusicSelectedBase {
    self = [super initWithFrame:frame];
    if (self) {
        self.musicSelectedBase = MusicSelectedBase;
        self.speed = [RBUserSettingData sharedInstance].speedType;
        self->m_PrevSound = kNoSoundHandle;
        // Yes, the binary reads the theme here and discards it.
        (void)[RBUserSettingData sharedInstance].thema;
        self.sliderType = kSliderTypeDefault;
        [self SetupView];
    }
    return self;
}

#pragma mark View construction

- (void)SetupView {
    self.userInteractionEnabled = YES;

    self.sliderView =
        [[UIImageView alloc] initWithImage:[UIImage imageWithName:kSliderBarImageName]];

    int thema = [RBUserSettingData sharedInstance].thema;
    BOOL isPad = IsPad();

    CGRect sliderFrame;
    if (thema == kThemeColette) {
        if (isPad) {
            CGFloat selfWidth = self.frame.size.width;
            CGSize sliderSize = self.sliderView.frame.size;
            sliderFrame = CGRectMake((selfWidth - sliderSize.width) * kHalf,
                                     kSliderBarColetteWideTopInset,
                                     sliderSize.width,
                                     sliderSize.height);
        } else {
            sliderFrame = CGRectMake(kSliderBarColetteDefaultX,
                                     kSliderBarColetteDefaultY,
                                     kSliderBarColetteDefaultWidth,
                                     kSliderBarColetteDefaultHeight);
        }
    } else {
        if (isPad) {
            CGFloat selfWidth = self.frame.size.width;
            CGSize sliderSize = self.sliderView.frame.size;
            sliderFrame = CGRectMake((selfWidth - sliderSize.width) * kHalf,
                                     kSliderBarWideTopInset,
                                     sliderSize.width,
                                     sliderSize.height);
        } else {
            sliderFrame = CGRectMake(kSliderBarDefaultX,
                                     kSliderBarDefaultY,
                                     kSliderBarDefaultWidth,
                                     kSliderBarDefaultHeight);
        }
    }
    self.sliderView.frame = sliderFrame;
    self.sliderView.autoresizingMask = kAutoresizingFlexibleAll;
    [self addSubview:self.sliderView];
    self.sliderView.userInteractionEnabled = YES;

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                          action:@selector(tap:)];
    [self.sliderView addGestureRecognizer:tap];

    int themaAgain = [RBUserSettingData sharedInstance].thema;
    isPad = IsPad(); // Re-read, as the binary does; the value is unchanged.

    CGRect barFrame;
    if (themaAgain == kThemeColette) {
        barFrame = isPad ? CGRectMake(kBarBaseColetteWideX,
                                      kBarBaseColetteWideY,
                                      kBarBaseColetteWideWidth,
                                      kBarBaseColetteWideHeight) :
                           CGRectMake(kBarBaseColetteX,
                                      kBarBaseColetteY,
                                      kBarBaseColetteWidth,
                                      kBarBaseColetteHeight);
    } else {
        barFrame =
            isPad ?
                CGRectMake(kBarBaseWideX, kBarBaseWideY, kBarBaseWideWidth, kBarBaseWideHeight) :
                CGRectMake(kBarBaseDefaultX,
                           kBarBaseDefaultY,
                           kBarBaseDefaultWidth,
                           kBarBaseDefaultHeight);
    }
    self.barBase = [[UIView alloc] initWithFrame:barFrame];
    self.barBase.autoresizingMask = kAutoresizingFlexibleAll;
    self.barBase.backgroundColor = UIColor.clearColor;
    self.barBase.userInteractionEnabled = NO;
    [self addSubview:self.barBase];

    self.selectedImage =
        [[UIImageView alloc] initWithImage:[UIImage imageWithName:kSpeedMarkerImageName]];
    CGFloat barWidth = self.barBase.frame.size.width;
    CGFloat barHeight = self.barBase.frame.size.height;
    self.selectedImage.center =
        CGPointMake((barWidth / kSpeedSlotCount) * self.speed, barHeight * kHalf);
    self.selectedImage.autoresizingMask = kAutoresizingFlexibleAll;
    [self.barBase addSubview:self.selectedImage];

    CGRect markerFrame = self.selectedImage.frame;
    markerFrame.origin.x = static_cast<int>(markerFrame.origin.x);
    markerFrame.origin.y = static_cast<int>(markerFrame.origin.y);
    self.selectedImage.frame = markerFrame;
}

#pragma mark Interaction

- (void)tap:(UITapGestureRecognizer *)tap {
    CGPoint location = [tap locationInView:tap.view];

    CGFloat deadZone;
    if ([RBUserSettingData sharedInstance].thema == kThemeLimelight) {
        deadZone = IsPad() ? kTapDeadZoneLimelightWide : kTapDeadZoneLimelightDefault;
    } else if ([RBUserSettingData sharedInstance].thema == kThemeColette) {
        deadZone = IsPad() ? kTapDeadZoneColetteWide : kTapDeadZoneColetteDefault;
    } else {
        deadZone = IsPad() ? kTapDeadZoneWide : kTapDeadZoneDefault;
    }

    CGFloat barWidth = tap.view.frame.size.width;
    int speed;
    if (location.x < deadZone) {
        speed = 0;
    } else if (location.x > barWidth - deadZone) {
        speed = kSpeedMax;
    } else {
        CGFloat stepWidth = (barWidth - (deadZone + deadZone)) / kSpeedSlotCount;
        // The binary narrows to float and rounds to nearest, ties away from zero.
        speed =
            static_cast<int>(std::lroundf(static_cast<float>((location.x - deadZone) / stepWidth)));
    }
    [self SelectSpeed:speed];
}

- (void)SelectSpeed:(int)SelectSpeed {
    int speed = SelectSpeed;
    if (speed > kSpeedMax) {
        speed = kSpeedMax + 1; // Yes, the binary clamps the high overflow to eleven, not ten.
    }
    if (speed < 0) {
        speed = 0;
    }
    if (self.speed != speed) {
        self.speed = speed;
        [RBUserSettingData sharedInstance].speedType = speed;

        __weak RBMusicSpeedView *weakSelf = self;
        [UIView animateWithDuration:g_dMascotMessageAnimDuration
                         animations:^{
                           /** @ghidraAddress 0x10ef4c */
                           RBMusicSpeedView *strongSelf = weakSelf;
                           CGFloat barWidth = strongSelf.barBase.bounds.size.width;
                           // Yes, the binary reads the marker's centre here and discards it.
                           (void)strongSelf.selectedImage.center;
                           CGRect markerFrame = strongSelf.selectedImage.frame;
                           CGFloat x = (barWidth / kSpeedSlotCount) * strongSelf.speed -
                                       markerFrame.size.width * kHalf;
                           markerFrame.origin.x = static_cast<int>(x);
                           strongSelf.selectedImage.frame = markerFrame;
                         }];

        SoundEffectManager *soundManager = SoundEffectManager::GetInstance();
        // The binary jumps to the shared tail, so the decide button is refreshed either way.
        if (m_PrevSound == kNoSoundHandle || !soundManager->IsPlaying(m_PrevSound)) {
            m_PrevSound = soundManager->PlayThemedSoundEffect(kSoundEffectSpeedChange);
        }
    }

    [self.musicSelectedBase updateDecideButton];
}

@end
