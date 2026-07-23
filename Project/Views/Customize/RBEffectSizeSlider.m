//
//  RBEffectSizeSlider.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RBEffectSizeSlider). The
//  initialiser's soft-float sprite, grip, track, and digit-readout geometry, and the theme- and
//  iPad idiom dependent layout, were recovered from the arm64 disassembly (the decompiler folds
//  the CGRect components into pseudo-variables). This is the explosion (bounds-effect-size) slider
//  created by RBCustomSelectCollectionView.
//

#import "RBEffectSizeSlider.h"

#include <assert.h>

#import "RBUserSettingData.h"
#import "UIImage+RB.h"
#import "neEngineBridge.h"

// The track sprite (base view) and grip sprite texture names.
static NSString *const kEffectSizeSliderTrackImageName = @"04_customize/cus_vol_4";
static NSString *const kEffectSizeSliderGripImageName = @"02_music_detail/det_col_br_5";

// The readout glyphs are cus_nms_0 ... cus_nms_9 followed by the decimal point. A value place
// indexes this array directly, and the point column uses the last entry.
static NSString *const kEffectSizeSliderDigitImageNames[] = {@"04_customize/cus_nms_0",
                                                             @"04_customize/cus_nms_1",
                                                             @"04_customize/cus_nms_2",
                                                             @"04_customize/cus_nms_3",
                                                             @"04_customize/cus_nms_4",
                                                             @"04_customize/cus_nms_5",
                                                             @"04_customize/cus_nms_6",
                                                             @"04_customize/cus_nms_7",
                                                             @"04_customize/cus_nms_8",
                                                             @"04_customize/cus_nms_9",
                                                             @"04_customize/cus_nms_dot"};

// The index of the decimal-point glyph within numImages (also the count of digit glyphs, base
// ten).
static const NSUInteger kEffectSizeSliderPointImageIndex = 10;

// The value range: a bounds-effect size from 0 to 3 inclusive, selected in half-unit steps.
static const int kEffectSizeSliderBarMin = 0;
static const int kEffectSizeSliderBarMax = 3;

// The value increment per grip step: half a unit.
static const float kEffectSizeSliderStepValue = 0.5f;

// Every child sprite (track, grip, and the control itself) is nudged down by this many points from
// its natural origin.
static const CGFloat kEffectSizeSliderVerticalOffset = 6.0;

// The track rectangle (the grip's travel) by device idiom: origin x/y, then width. Its height is
// taken from the track sprite's own frame. Narrow mirrors the default font, wide the large font.
static const CGFloat kEffectSizeSliderBarOriginXNarrow = 19.0;
static const CGFloat kEffectSizeSliderBarOriginYNarrow = 21.0;
static const CGFloat kEffectSizeSliderBarWidthNarrow = 210.0;
static const CGFloat kEffectSizeSliderBarOriginXWide = 38.0;
static const CGFloat kEffectSizeSliderBarOriginYWide = 33.0;
static const CGFloat kEffectSizeSliderBarWidthWide = 315.0;

// The digit readout's origin varies by the active theme and iPad idiom. The binary groups the
// themes by their raw stored value: values below the colette threshold (the classic and limelight
// themes) share one readout origin, the colette theme its own, and any further theme leaves the
// readout at the zero origin.
static const CGFloat kEffectSizeSliderReadoutOriginXLowThemeNarrow = 152.0;
static const CGFloat kEffectSizeSliderReadoutOriginXLowThemeWide = 225.0;
static const CGFloat kEffectSizeSliderReadoutOriginYLowThemeNarrow = 10.0;
static const CGFloat kEffectSizeSliderReadoutOriginYLowThemeWide = 17.0;
static const CGFloat kEffectSizeSliderReadoutOriginXColetteNarrow = 144.0;
static const CGFloat kEffectSizeSliderReadoutOriginXColetteWide = 246.0;
static const CGFloat kEffectSizeSliderReadoutOriginYColetteNarrow = 10.0;
static const CGFloat kEffectSizeSliderReadoutOriginYColetteWide = 14.5;

// The classic and colette themes widen the gap before the fractional digit by one point in the
// large font; the limelight theme does not.
static const CGFloat kEffectSizeSliderWideFractionGap = 1.0;

// The two grip-travel divisions per unit value (the value range is walked in half-unit steps, so
// the pixels-per-step denominator is the unit span doubled).
static const int kEffectSizeSliderStepsPerUnit = 2;

// The decimal base used to peel digit places off the value.
static const int kEffectSizeSliderDecimalBase = 10;

// The number of readout image views held before growth (whole digit, decimal point, and fractional
// digit).
static const NSUInteger kEffectSizeSliderReadoutCapacity = 3;

// The stored theme value at and above which the colette readout layout applies; below it the
// low-theme (classic and limelight) layout applies.
enum {
    kEffectSizeSliderColetteThemaThreshold = 2,
};

@implementation RBEffectSizeSlider

- (instancetype)initWithDigit:(int)digit {
    self = [super init];
    if (!self) {
        return nil;
    }

    BOOL isPad = IsPad();
    self.digit = digit;

    UIImage *trackImage = [UIImage imageWithName:kEffectSizeSliderTrackImageName];
    UIImageView *track = [[UIImageView alloc] initWithImage:trackImage];
    self.baseView = track;
    CGRect trackFrame = self.baseView.frame;
    self.baseView.frame = CGRectMake(trackFrame.origin.x,
                                     trackFrame.origin.y + kEffectSizeSliderVerticalOffset,
                                     trackFrame.size.width,
                                     trackFrame.size.height);
    [self addSubview:self.baseView];

    UIImageView *grip =
        [[UIImageView alloc] initWithImage:[UIImage imageWithName:kEffectSizeSliderGripImageName]];
    self.gripView = grip;
    CGRect gripFrame = self.gripView.frame;
    self.gripView.frame = CGRectMake(gripFrame.origin.x,
                                     gripFrame.origin.y + kEffectSizeSliderVerticalOffset,
                                     gripFrame.size.width,
                                     gripFrame.size.height);
    [self addSubview:self.gripView];

    CGFloat trackHeight = self.baseView.frame.size.height;
    if (isPad) {
        self.barRect = CGRectMake(kEffectSizeSliderBarOriginXWide,
                                  kEffectSizeSliderBarOriginYWide,
                                  kEffectSizeSliderBarWidthWide,
                                  trackHeight);
    } else {
        self.barRect = CGRectMake(kEffectSizeSliderBarOriginXNarrow,
                                  kEffectSizeSliderBarOriginYNarrow,
                                  kEffectSizeSliderBarWidthNarrow,
                                  trackHeight);
    }

    CGRect selfFrame = self.frame;
    self.frame = CGRectMake(selfFrame.origin.x,
                            selfFrame.origin.y + kEffectSizeSliderVerticalOffset,
                            selfFrame.size.width,
                            selfFrame.size.height);

    self.stepValue = kEffectSizeSliderStepValue;
    self.value = [RBUserSettingData sharedInstance].boundsEffectSize;
    self.barMin = kEffectSizeSliderBarMin;
    self.barMax = kEffectSizeSliderBarMax;
    self.step = (float)(self.barRect.size.width /
                        (CGFloat)((self.barMax - self.barMin) * kEffectSizeSliderStepsPerUnit));

    self.numImages = [[NSMutableArray alloc] initWithCapacity:kEffectSizeSliderPointImageIndex + 1];
    // The point glyph is appended in the last iteration; the digit glyphs before it. The first
    // digit glyph and the point glyph are also measured, giving the readout its cell sizes.
    CGSize digitGlyphSize = CGSizeZero;
    CGSize pointGlyphSize = CGSizeZero;
    for (NSUInteger i = 0; i <= kEffectSizeSliderPointImageIndex; ++i) {
        UIImage *glyphImage = [UIImage imageWithName:kEffectSizeSliderDigitImageNames[i]];
        [self.numImages addObject:glyphImage];
        if (i == 0) {
            digitGlyphSize = glyphImage.size;
        } else if (i == kEffectSizeSliderPointImageIndex) {
            pointGlyphSize = glyphImage.size;
        }
    }

    self.numImageViews = [[NSMutableArray alloc] initWithCapacity:kEffectSizeSliderReadoutCapacity];

    CGPoint readoutOrigin = CGPointZero;
    RBUserSettingDataTheme thema = [RBUserSettingData sharedInstance].thema;
    if (thema < kEffectSizeSliderColetteThemaThreshold) {
        if (isPad) {
            readoutOrigin = CGPointMake(kEffectSizeSliderReadoutOriginXLowThemeWide,
                                        kEffectSizeSliderReadoutOriginYLowThemeWide);
        } else {
            readoutOrigin = CGPointMake(kEffectSizeSliderReadoutOriginXLowThemeNarrow,
                                        kEffectSizeSliderReadoutOriginYLowThemeNarrow);
        }
    } else if (thema == kEffectSizeSliderColetteThemaThreshold) {
        if (isPad) {
            readoutOrigin = CGPointMake(kEffectSizeSliderReadoutOriginXColetteWide,
                                        kEffectSizeSliderReadoutOriginYColetteWide);
        } else {
            readoutOrigin = CGPointMake(kEffectSizeSliderReadoutOriginXColetteNarrow,
                                        kEffectSizeSliderReadoutOriginYColetteNarrow);
        }
    }

    // The whole-digit column sits at the readout origin, the decimal-point column immediately
    // after it, and the fractional-digit column after that. The classic (0) and colette (2) themes
    // add a one-point gap before the fractional digit in the large font; the limelight (1) theme
    // does not, so its column abuts the point directly.
    CGFloat pointColumnX = readoutOrigin.x + digitGlyphSize.width;
    CGFloat fractionColumnX = pointColumnX + pointGlyphSize.width;
    switch ([RBUserSettingData sharedInstance].thema) {
    case RBUserSettingDataThemeClassic:
    case RBUserSettingDataThemeColette:
        if (isPad) {
            fractionColumnX += kEffectSizeSliderWideFractionGap;
        }
        break;
    case RBUserSettingDataThemeLimelight:
        break;
    default:
        assert(0);
        break;
    }

    UIImageView *wholeDigitView = [[UIImageView alloc] init];
    wholeDigitView.frame =
        CGRectMake(readoutOrigin.x, readoutOrigin.y, digitGlyphSize.width, digitGlyphSize.height);
    [self addSubview:wholeDigitView];
    [self.numImageViews addObject:wholeDigitView];

    UIImageView *pointView = [[UIImageView alloc] init];
    pointView.frame =
        CGRectMake(pointColumnX, readoutOrigin.y, pointGlyphSize.width, pointGlyphSize.height);
    [self addSubview:pointView];
    [self.numImageViews addObject:pointView];

    UIImageView *fractionDigitView = [[UIImageView alloc] init];
    fractionDigitView.frame =
        CGRectMake(fractionColumnX, readoutOrigin.y, digitGlyphSize.width, digitGlyphSize.height);
    [self addSubview:fractionDigitView];
    [self.numImageViews addObject:fractionDigitView];

    return self;
}

- (void)setValue:(float)value {
    if (value <= (float)self.barMin) {
        value = (float)self.barMin;
    }
    if (value <= (float)self.barMax) {
        _value = value;
    } else {
        _value = (float)self.barMax;
    }

    CGRect bar = self.barRect;
    CGRect gripFrame = self.gripView.frame;
    self.gripView.frame =
        CGRectMake(bar.origin.x + (CGFloat)((_value / self.stepValue) * self.step),
                   bar.origin.y,
                   gripFrame.size.width,
                   gripFrame.size.height);

    int scaledValue = (int)(self.value * (float)kEffectSizeSliderDecimalBase);
    int wholeDigit = (scaledValue / kEffectSizeSliderDecimalBase) % kEffectSizeSliderDecimalBase;
    self.numImageViews[0].image = self.numImages[wholeDigit];
    self.numImageViews[1].image = self.numImages[kEffectSizeSliderPointImageIndex];
    self.numImageViews[2].image = self.numImages[scaledValue % kEffectSizeSliderDecimalBase];
}

- (void)sliderChangeWithTouchPoint:(CGPoint)point {
    float newValue;
    CGRect bar = self.barRect;
    if (point.x >= bar.origin.x && point.x <= bar.origin.x + bar.size.width) {
        // Snap the touch offset to a whole half-unit: convert to doubled steps, truncate toward
        // zero, halve back to a step count, then scale by the per-step value.
        float touchOffset = (float)(point.x - bar.origin.x);
        int doubledSteps = (int)((touchOffset + touchOffset) / self.step);
        if (doubledSteps < 0) {
            ++doubledSteps; // The +1 makes the truncation round toward zero for negative offsets.
        }
        newValue = self.stepValue * (float)(doubledSteps >> 1);
    } else {
        newValue = (float)self.barMax;
    }
    [self setValue:newValue];
}

- (BOOL)beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    [self sliderChangeWithTouchPoint:[touch locationInView:touch.view]];
    return YES;
}

- (BOOL)continueTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    [self sliderChangeWithTouchPoint:[touch locationInView:touch.view]];
    return YES;
}

- (void)endTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    [self sliderChangeWithTouchPoint:[touch locationInView:touch.view]];
}

@end
