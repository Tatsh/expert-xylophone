//
//  RBMusicCPUView.mm
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RBMusicCPUView). Verified against
//  the arm64 disassembly: -SetupView's per-theme, per-idiom slider and container geometry was
//  recovered from the soft-float register moves and constant-pool loads that the decompiler folds
//  into pseudo-variables, and the marker-glide animation was confirmed against the block literal the
//  decompiler emits. This is an Objective-C++ file because -SelectLevel: reaches the C++
//  SoundEffectManager engine singleton.
//

#import "RBMusicCPUView.h"

#import "RBMusicView.h"
#import "RBUserSettingData.h"
#import "UIImage+RB.h"
#import "neEngineBridge.h"

// The number of CPU-rival LEVEL slots the bar is divided into. The marker glides across nine equal
// slots and LEVEL is clamped to zero through nine.
constexpr int kLevelSlotCount = 9;
constexpr int kLevelMax = 9;

// The themed sound-effect slot played when the LEVEL changes.
constexpr int kSoundEffectLevelChange = 2;

// The sentinel stored in m_PrevSound before any level-change sound effect has played.
constexpr unsigned int kNoSoundHandle = 0xffffffff;

// The Colette theme selects the wide (iPad) slider layout.
constexpr int kThemeColette = 2;

// The slider-type variants written by -initWithFrame:MusicSelectedBase:.
constexpr int kSliderTypeDefault = 0;
constexpr int kSliderTypeColetteWide = 1;

// The full flexible autoresizing mask (all four margins plus flexible width and height).
constexpr UIViewAutoresizing kAutoresizingFlexibleAll =
    UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth |
    UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin |
    UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;

// The slider bar and level marker image names.
static NSString *const kSliderBarImageName = @"02_music_detail/det_lev_bar";
static NSString *const kLevelMarkerImageName = @"02_music_detail/det_lev_sel";

// The slider bar frame per (theme, idiom). The Colette theme's wide bar spans the whole view
// width with x zero and a themed top inset; every other combination uses a fixed constant-pool
// rectangle. Decoded from the constant pool at 0x1002fcfd8 (280), 0x100301158 (36), 0x1002ec6e0
// (50), 0x100301198 (274), 0x1002ec6c8 (80), and 0x1002eecd8 (64), plus the inline immediate values.
constexpr CGFloat kSliderBarColetteTopInset = 80.0;
constexpr CGFloat kSliderBarWideTopInset = 64.0;
constexpr CGFloat kSliderBarColetteDefaultX = 10.0;
constexpr CGFloat kSliderBarColetteDefaultY = 36.0;
constexpr CGFloat kSliderBarColetteDefaultWidth = 280.0;
constexpr CGFloat kSliderBarColetteDefaultHeight = 30.0;
constexpr CGFloat kSliderBarDefaultX = 15.0;
constexpr CGFloat kSliderBarDefaultY = 27.0;
constexpr CGFloat kSliderBarDefaultWidth = 274.0;
constexpr CGFloat kSliderBarDefaultHeight = 50.0;

// The bar-container frame per (theme, idiom). Decoded from the constant pool at 0x1002eeef0
// (54), 0x1003011b0 (41), 0x1003011c0 (378), 0x1003011b8 (220), 0x1003011c8 (82), 0x1002ec6e0 (50),
// 0x1002ee9a8 (42), 0x1002ee950 (40), 0x1003011a8 (370), 0x1003011a0 (261), 0x1002eea00 (68), and
// 0x1002ef170 (56), plus the 0.0, 12.0, 9.0, and 19.0 inline immediate values.
constexpr CGFloat kBarBaseColetteWideX = 54.0;
constexpr CGFloat kBarBaseColetteWideY = 12.0;
constexpr CGFloat kBarBaseColetteWideWidth = 378.0;
constexpr CGFloat kBarBaseColetteWideHeight = 82.0;
constexpr CGFloat kBarBaseColetteX = 41.0;
constexpr CGFloat kBarBaseColetteY = 0.0;
constexpr CGFloat kBarBaseColetteWidth = 220.0;
constexpr CGFloat kBarBaseColetteHeight = 50.0;
constexpr CGFloat kBarBaseWideX = 42.0;
constexpr CGFloat kBarBaseWideY = 40.0;
constexpr CGFloat kBarBaseWideWidth = 370.0;
constexpr CGFloat kBarBaseWideHeight = 68.0;
constexpr CGFloat kBarBaseDefaultX = 19.0;
constexpr CGFloat kBarBaseDefaultY = 9.0;
constexpr CGFloat kBarBaseDefaultWidth = 261.0;
constexpr CGFloat kBarBaseDefaultHeight = 56.0;

// Half a bar, used to centre the marker within the container and to centre the wide slider bar.
constexpr CGFloat kHalf = 0.5;

// The tap dead-zone at each end of the bar, per (theme, idiom): a tap within this margin of
// the left edge selects LEVEL zero, and one within it of the right edge selects LEVEL nine.
constexpr CGFloat kTapDeadZoneColetteWide = 56.0;
constexpr CGFloat kTapDeadZoneColetteDefault = 30.0;
constexpr CGFloat kTapDeadZoneWide = 30.0;
constexpr CGFloat kTapDeadZoneDefault = 20.0;

// The eight interior LEVEL steps between the two dead zones (LEVEL one through eight span the bar
// interior; a tap maps to floor((x - deadZone) / stepWidth) + 1).
constexpr CGFloat kInteriorStepDivisor = 8.0;

@interface RBMusicCPUView () {
    // Named exactly as in the binary's ivar list. The previous level-change sound-effect play handle,
    // or kNoSoundHandle when none has played.
    unsigned int m_PrevSound; // +0x8
}
@end

@implementation RBMusicCPUView

#pragma mark Lifecycle

- (instancetype)initWithFrame:(CGRect)frame MusicSelectedBase:(RBMusicView *)MusicSelectedBase {
    self = [super initWithFrame:frame];
    if (self) {
        self.musicSelectedBase = MusicSelectedBase;
        self.level = [RBUserSettingData sharedInstance].cpuLevel;
        self->m_PrevSound = kNoSoundHandle;
        if ([RBUserSettingData sharedInstance].thema == kThemeColette) {
            if (IsPad()) {
                self.sliderType = kSliderTypeColetteWide;
            }
        } else {
            self.sliderType = kSliderTypeDefault;
        }
        [self SetupView];
    }
    return self;
}

#pragma mark View construction

- (void)SetupView {
    self.userInteractionEnabled = YES;

    self.sliderView =
        [[UIImageView alloc] initWithImage:[UIImage imageWithName:kSliderBarImageName]];

    BOOL colette = [RBUserSettingData sharedInstance].thema == kThemeColette;
    BOOL isPad = IsPad();

    CGRect sliderFrame;
    if (colette) {
        if (isPad) {
            // The Colette wide bar spans the whole view width, pinned to a fixed top inset. The
            // binary reads the slider view's frame three times here and discards each result.
            CGRect bounds = self.bounds;
            sliderFrame =
                CGRectMake(0.0, kSliderBarColetteTopInset, bounds.size.width, bounds.size.height);
        } else {
            sliderFrame = CGRectMake(kSliderBarColetteDefaultX,
                                     kSliderBarColetteDefaultY,
                                     kSliderBarColetteDefaultWidth,
                                     kSliderBarColetteDefaultHeight);
        }
    } else {
        if (isPad) {
            CGRect bounds = self.bounds;
            sliderFrame =
                CGRectMake(0.0, kSliderBarWideTopInset, bounds.size.width, bounds.size.height);
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

    BOOL coletteAgain = [RBUserSettingData sharedInstance].thema == kThemeColette;
    isPad = IsPad(); // Re-read, as the binary does; the value is unchanged.

    CGRect barFrame;
    if (coletteAgain) {
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
    self.barBase.backgroundColor = [UIColor clearColor];
    self.barBase.userInteractionEnabled = NO;
    [self addSubview:self.barBase];

    self.selectedImage =
        [[UIImageView alloc] initWithImage:[UIImage imageWithName:kLevelMarkerImageName]];
    CGFloat barWidth = self.barBase.frame.size.width;
    CGFloat barHeight = self.barBase.frame.size.height;
    self.selectedImage.center =
        CGPointMake((barWidth / kLevelSlotCount) * self.level, barHeight * kHalf);
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
    if ([RBUserSettingData sharedInstance].thema == kThemeColette) {
        deadZone = IsPad() ? kTapDeadZoneColetteWide : kTapDeadZoneColetteDefault;
    } else {
        deadZone = IsPad() ? kTapDeadZoneWide : kTapDeadZoneDefault;
    }

    CGFloat barWidth = tap.view.frame.size.width;
    int level;
    if (location.x < deadZone) {
        level = 0;
    } else if (location.x > barWidth - deadZone) {
        level = kLevelMax;
    } else {
        CGFloat stepWidth = (barWidth - (deadZone + deadZone)) / kInteriorStepDivisor;
        level = static_cast<int>((location.x - deadZone) / stepWidth + 1.0);
    }
    [self SelectLevel:level];
}

- (void)SelectLevel:(int)SelectLevel {
    int level = SelectLevel;
    if (level > kLevelMax) {
        level = kLevelMax;
    }
    if (level < 0) {
        level = 0;
    }
    if (self.level == level) {
        return;
    }
    self.level = level;

    __weak RBMusicCPUView *weakSelf = self;
    [UIView animateWithDuration:g_dMascotMessageAnimDuration
                     animations:^{
                       /** @ghidraAddress 0xc7730 */
                       RBMusicCPUView *strongSelf = weakSelf;
                       CGFloat barWidth = strongSelf.barBase.bounds.size.width;
                       (void)strongSelf.selectedImage
                           .center; // Yes, the binary reads the marker's centre and discards it.
                       CGRect markerFrame = strongSelf.selectedImage.frame;
                       CGFloat x = (barWidth / kLevelSlotCount) * strongSelf.level -
                                   markerFrame.size.width * kHalf;
                       markerFrame.origin.x = static_cast<int>(x);
                       strongSelf.selectedImage.frame = markerFrame;
                     }];

    SoundEffectManager *soundManager = SoundEffectManager::GetInstance();
    if (m_PrevSound == kNoSoundHandle) {
        m_PrevSound = soundManager->PlayThemedSoundEffect(kSoundEffectLevelChange);
    } else {
        if (soundManager->IsPlaying(m_PrevSound)) {
            return;
        }
        m_PrevSound = soundManager->PlayThemedSoundEffect(kSoundEffectLevelChange);
    }
}

@end
