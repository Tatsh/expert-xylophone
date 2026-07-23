//
//  RBMusicSpeedView.mm
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RBMusicSpeedView). Verified
//  against the arm64 disassembly: -SetupView's per-theme, per-font-variant slider and container
//  geometry was recovered from the soft-float register moves and constant-pool loads that the
//  decompiler folds into pseudo-variables, and the marker-glide animation was confirmed against the
//  block literal the decompiler emits. This is an Objective-C++ file because -SelectSpeed: reaches
//  the C++ SoundEffectManager engine singleton.
//

#import "RBMusicSpeedView.h"

#import "RBMusicView.h"
#import "RBUserSettingData.h"
#import "UIImage+RB.h"
#import "neEngineBridge.h"

// The number of speed steps the bar is divided into. The marker glides across ten equal slots and
// SPEED is clamped to zero through ten.
constexpr int kSpeedSlotCount = 10;
constexpr int kSpeedMax = 10;

// The themed sound-effect slot played when the SPEED changes.
constexpr int kSoundEffectSpeedChange = 2;

// The sentinel stored in m_PrevSound before any speed-change sound effect has played.
constexpr unsigned int kNoSoundHandle = 0xffffffff;

// The Limelight and Colette theme identifiers; every other theme uses the default (Classic) layout.
constexpr int kThemeLimelight = 1;
constexpr int kThemeColette = 2;

// The slider-type variant written by -initWithFrame:MusicSelectedBase:. The initialiser always
// seeds the default; the field is otherwise unused by this view.
constexpr int kSliderTypeDefault = 0;

// The full flexible autoresizing mask (all four margins plus flexible width and height).
constexpr UIViewAutoresizing kAutoresizingFlexibleAll =
    UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth |
    UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin |
    UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;

// The slider bar and speed marker image names.
static NSString *const kSliderBarImageName = @"02_music_detail/det_spd_bar_1";
static NSString *const kSpeedMarkerImageName = @"02_music_detail/det_spd_bar_2";

// The slider bar frame per (theme, font variant). The font-variant bar is centred horizontally
// within the view at a themed top inset and keeps the bar image's natural size; every default
// combination uses a fixed constant-pool rectangle. Decoded from the constant pool at 0x100301198
// (274), 0x1002ec6e0 (50), 0x1002eeef0 (54), 0x1002fcfd8 (280), 0x100301158 (36), and 0x1002ee948
// (60), plus the 15.0 and 27.0 inline immediate values.
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

// The bar-container frame per (theme, font variant). Decoded from the constant pool at 0x1003011b0
// (41), 0x1002eeee8 (43), 0x100302480 (402), 0x1003011b8 (220), 0x1003011c8 (82), 0x1002ec6e0 (50),
// 0x1002eeec0 (38), 0x1003011a0 (261), and 0x1002ef170 (56), plus the 19.0, 27.0, and 9.0
// inline immediate values.
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

// Half a bar, used to centre the marker within the container and to centre the wide slider bar.
constexpr CGFloat kHalf = 0.5;

// The tap dead-zone at each end of the bar, per (theme, font variant): a tap within this margin of
// the left edge selects SPEED zero, and one within it of the right edge selects SPEED ten.
constexpr CGFloat kTapDeadZoneLimelightWide = 30.0;
constexpr CGFloat kTapDeadZoneLimelightDefault = 20.0;
constexpr CGFloat kTapDeadZoneColetteWide = 25.0;
constexpr CGFloat kTapDeadZoneColetteDefault = 30.0;
constexpr CGFloat kTapDeadZoneWide = 27.0;
constexpr CGFloat kTapDeadZoneDefault = 20.0;

@interface RBMusicSpeedView () {
    // Named exactly as in the binary's ivar list. The previous speed-change sound-effect play
    // handle, or kNoSoundHandle when none has played.
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
    BOOL fontVariant = GetFontVariantFlag() != kFontVariantDefault;

    CGRect sliderFrame;
    if (thema == kThemeColette) {
        if (fontVariant) {
            // The Colette wide bar is centred horizontally at a fixed top inset and keeps the bar
            // image's natural size. The binary reads the view's frame and the slider view's frame
            // to derive the centred origin.
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
        if (fontVariant) {
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
    BOOL fontVariantAgain = GetFontVariantFlag() != kFontVariantDefault;

    CGRect barFrame;
    if (themaAgain == kThemeColette) {
        barFrame = fontVariantAgain ? CGRectMake(kBarBaseColetteWideX,
                                                 kBarBaseColetteWideY,
                                                 kBarBaseColetteWideWidth,
                                                 kBarBaseColetteWideHeight) :
                                      CGRectMake(kBarBaseColetteX,
                                                 kBarBaseColetteY,
                                                 kBarBaseColetteWidth,
                                                 kBarBaseColetteHeight);
    } else {
        barFrame =
            fontVariantAgain ?
                CGRectMake(kBarBaseWideX, kBarBaseWideY, kBarBaseWideWidth, kBarBaseWideHeight) :
                CGRectMake(kBarBaseDefaultX,
                           kBarBaseDefaultY,
                           kBarBaseDefaultWidth,
                           kBarBaseDefaultHeight);
    }
    self.barBase = [[UIView alloc] initWithFrame:barFrame];
    self.barBase.autoresizingMask = kAutoresizingFlexibleAll;
    self.barBase.backgroundColor = [UIColor clearColor];
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

    // The marker's origin is truncated to whole pixels.
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
        deadZone = GetFontVariantFlag() != kFontVariantDefault ? kTapDeadZoneLimelightWide :
                                                                 kTapDeadZoneLimelightDefault;
    } else if ([RBUserSettingData sharedInstance].thema == kThemeColette) {
        deadZone = GetFontVariantFlag() != kFontVariantDefault ? kTapDeadZoneColetteWide :
                                                                 kTapDeadZoneColetteDefault;
    } else {
        deadZone =
            GetFontVariantFlag() != kFontVariantDefault ? kTapDeadZoneWide : kTapDeadZoneDefault;
    }

    CGFloat barWidth = tap.view.frame.size.width;
    int speed;
    if (location.x < deadZone) {
        speed = 0;
    } else if (location.x > barWidth - deadZone) {
        speed = kSpeedMax;
    } else {
        CGFloat stepWidth = (barWidth - (deadZone + deadZone)) / kSpeedSlotCount;
        speed = static_cast<int>((location.x - deadZone) / stepWidth);
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
                           /** @ghidraAddress 0xef4c */
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
        // The sound only replays when the previous handle is idle; either way the decide button is
        // refreshed below (the binary jumps to the shared tail, not past it).
        if (m_PrevSound == kNoSoundHandle || !soundManager->IsPlaying(m_PrevSound)) {
            m_PrevSound = soundManager->PlayThemedSoundEffect(kSoundEffectSpeedChange);
        }
    }

    [self.musicSelectedBase updateDecideButton];
}

@end
