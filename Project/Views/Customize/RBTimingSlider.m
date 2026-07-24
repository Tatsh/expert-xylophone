//
//  RBTimingSlider.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RBTimingSlider). The
//  initialiser's soft-float sprite, grip, track, and digit-readout geometry, and the theme- and
//  iPad idiom dependent layout, were recovered from the arm64 disassembly (the decompiler folds
//  the CGRect components into pseudo-variables). This is the delay-frame slider created by
//  RBCustomSelectCollectionView.
//

#import "RBTimingSlider.h"

#import "RBUserSettingData.h"
#import "UIImage+RB.h"
#import "deviceenvironment.h"
#import "engineglobals.h"

// The track sprite (base view) and grip sprite texture names.
static NSString *const kTimingSliderTrackImageName = @"04_customize/cus_vol_3";
static NSString *const kTimingSliderGripImageName = @"02_music_detail/det_col_br_5";

// The digit glyphs are cus_nms_0 ... cus_nms_9 followed by the minus sign; a value place indexes
// this array directly, and the sign slot uses the last entry.
static NSString *const kTimingSliderDigitImageNames[] = {@"04_customize/cus_nms_0",
                                                         @"04_customize/cus_nms_1",
                                                         @"04_customize/cus_nms_2",
                                                         @"04_customize/cus_nms_3",
                                                         @"04_customize/cus_nms_4",
                                                         @"04_customize/cus_nms_5",
                                                         @"04_customize/cus_nms_6",
                                                         @"04_customize/cus_nms_7",
                                                         @"04_customize/cus_nms_8",
                                                         @"04_customize/cus_nms_9",
                                                         @"04_customize/cus_nms_minus"};

// The index of the minus-sign glyph within numImages (also the digit-count of glyphs, base ten).
static const NSUInteger kTimingSliderMinusImageIndex = 10;

// The value range: a delay-frame offset from -10 to 10 inclusive.
static const int kTimingSliderBarMin = -10;
static const int kTimingSliderBarMax = 10;

// Every child sprite (track, grip, and the control itself) is nudged down by this many points from
// its natural origin.
static const CGFloat kTimingSliderVerticalOffset = 6.0;

// The track rectangle (the grip's travel) by device idiom: origin x/y, then width. Its height is
// taken from the track sprite's own frame. Narrow mirrors the default font, wide the large font.
static const CGFloat kTimingSliderBarOriginXNarrow = 19.0;
static const CGFloat kTimingSliderBarOriginYNarrow = 21.0;
static const CGFloat kTimingSliderBarWidthNarrow = 210.0;
static const CGFloat kTimingSliderBarOriginXWide = 40.0;
static const CGFloat kTimingSliderBarOriginYWide = 33.0;
static const CGFloat kTimingSliderBarWidthWide = 315.0;

// The digit readout's origin and glyph metrics vary by the active theme and iPad idiom. The
// binary groups the themes by their raw stored value: values below the colette threshold (the
// classic and limelight themes) share one readout layout, the colette theme its own, and any
// further theme leaves the readout at the zero origin. The suffixes below name those two groups.
static const CGFloat kTimingSliderReadoutOriginXLowThemeNarrow = 141.0; // 0x1002ec6c0
static const CGFloat kTimingSliderReadoutOriginXLowThemeWide = 213.0;   // 0x100301850
static const CGFloat kTimingSliderReadoutOriginYLowThemeNarrow = 10.0;
static const CGFloat kTimingSliderReadoutOriginYLowThemeWide = 138.0;  // 0x10030dde0
static const CGFloat kTimingSliderReadoutOriginXColetteNarrow = 138.0; // 0x10030ddd8
static const CGFloat kTimingSliderReadoutOriginXColetteWide = 221.0;   // 0x1003011b8
static const CGFloat kTimingSliderReadoutOriginYColetteNarrow = 10.0;
static const CGFloat kTimingSliderReadoutOriginYColetteWide = 14.0;

// The colette theme nudges the sign glyph down by half a point in the large font.
static const CGFloat kTimingSliderColetteSignYAdjust = 0.5;

// Per-digit horizontal advance and its +1 point inter-glyph gap.
static const CGFloat kTimingSliderDigitGap = 1.0;

// The glyph cell width, height, and step share the track-rectangle metrics per device idiom.
static const CGFloat kTimingSliderCellWidthNarrow = 19.0;
static const CGFloat kTimingSliderCellHeightNarrow = 21.0;
static const CGFloat kTimingSliderCellStepNarrow = 210.0;
static const CGFloat kTimingSliderCellWidthWide = 40.0; // g_dSliderRowHeightWide
static const CGFloat kTimingSliderCellHeightWide = 33.0;
static const CGFloat kTimingSliderCellStepWide = 315.0;

// The number of digit-image views held before growth.
static const NSUInteger kTimingSliderReadoutCapacity = 3;

// The decimal base used to peel digit places off the value.
static const int kTimingSliderDecimalBase = 10;

// The stored theme value at and above which the colette readout layout applies; below it the
// low-theme (classic and limelight) layout applies.
enum {
    kTimingSliderColetteThemaThreshold = 2,
    kTimingSliderColetteThema = 2,
};

// The CGRect component order used when unpacking a frame.
enum {
    kRectOriginX = 0,
    kRectOriginY = 1,
    kRectWidth = 2,
    kRectHeight = 3,
};

@implementation RBTimingSlider

- (instancetype)initWithDigit:(int)digit {
    self = [super init];
    if (!self) {
        return nil;
    }

    BOOL isPad = IsPad();
    self.digit = digit;

    UIImageView *track =
        [[UIImageView alloc] initWithImage:[UIImage imageWithName:kTimingSliderTrackImageName]];
    self.baseView = track;
    CGRect trackFrame = self.baseView.frame;
    CGFloat trackY = trackFrame.origin.y + kTimingSliderVerticalOffset;
    self.baseView.frame =
        CGRectMake(trackFrame.origin.x, trackY, trackFrame.size.width, trackFrame.size.height);
    [self addSubview:self.baseView];

    UIImageView *grip =
        [[UIImageView alloc] initWithImage:[UIImage imageWithName:kTimingSliderGripImageName]];
    self.gripView = grip;
    CGRect gripFrame = self.gripView.frame;
    self.gripView.frame = CGRectMake(gripFrame.origin.x,
                                     gripFrame.origin.y + kTimingSliderVerticalOffset,
                                     gripFrame.size.width,
                                     gripFrame.size.height);
    [self addSubview:self.gripView];

    CGFloat trackHeight = self.baseView.frame.size.height;
    if (isPad) {
        self.barRect = CGRectMake(kTimingSliderBarOriginXWide,
                                  kTimingSliderBarOriginYWide,
                                  kTimingSliderBarWidthWide,
                                  trackHeight);
    } else {
        self.barRect = CGRectMake(kTimingSliderBarOriginXNarrow,
                                  kTimingSliderBarOriginYNarrow,
                                  kTimingSliderBarWidthNarrow,
                                  trackHeight);
    }

    CGRect selfFrame = self.frame;
    self.frame = CGRectMake(selfFrame.origin.x,
                            selfFrame.origin.y + kTimingSliderVerticalOffset,
                            selfFrame.size.width,
                            selfFrame.size.height);

    self.value = (float)[RBUserSettingData sharedInstance].delayFrame;
    self.barMin = kTimingSliderBarMin;
    self.barMax = kTimingSliderBarMax;
    self.step = (float)(self.barRect.size.width / (CGFloat)(self.barMax - self.barMin));

    self.numImages = [[NSMutableArray alloc] initWithCapacity:kTimingSliderMinusImageIndex + 1];
    for (NSUInteger i = 0; i <= kTimingSliderMinusImageIndex; ++i) {
        [self.numImages addObject:[UIImage imageWithName:kTimingSliderDigitImageNames[i]]];
    }

    self.numImageViews = [[NSMutableArray alloc] initWithCapacity:kTimingSliderReadoutCapacity];

    CGFloat readoutOriginX = 0.0;
    CGFloat readoutOriginY = 0.0;
    CGFloat cellWidth = isPad ? kTimingSliderCellWidthWide : kTimingSliderCellWidthNarrow;
    CGFloat cellHeight = isPad ? kTimingSliderCellHeightWide : kTimingSliderCellHeightNarrow;
    CGFloat cellStep = isPad ? kTimingSliderCellStepWide : kTimingSliderCellStepNarrow;

    RBUserSettingDataTheme thema = [RBUserSettingData sharedInstance].thema;
    if (thema < kTimingSliderColetteThemaThreshold) {
        if (isPad) {
            readoutOriginX = kTimingSliderReadoutOriginXLowThemeWide;
            readoutOriginY = kTimingSliderReadoutOriginYLowThemeWide;
        } else {
            readoutOriginX = kTimingSliderReadoutOriginXLowThemeNarrow;
            readoutOriginY = kTimingSliderReadoutOriginYLowThemeNarrow;
        }
    } else if (thema == kTimingSliderColetteThema) {
        if (isPad) {
            readoutOriginX = kTimingSliderReadoutOriginXColetteWide;
            readoutOriginY = kTimingSliderReadoutOriginYColetteWide;
        } else {
            readoutOriginX = kTimingSliderReadoutOriginXColetteNarrow;
            readoutOriginY = kTimingSliderReadoutOriginYColetteNarrow;
        }
    }

    // The readout holds one view per digit place plus a trailing sign column, so digit + 1 views
    // in all. They are appended most-significant-position first: numImageViews[i] is drawn at
    // column (digit - 1 - i), so numImageViews[0] is the rightmost (least significant) place and
    // the sign column is appended last at numImageViews[digit]. The final iteration builds the
    // sign column, the earlier ones the digit places.
    CGFloat readoutOriginXWithGap = cellWidth + kTimingSliderDigitGap + readoutOriginX;
    for (int iteration = -1; iteration < digit; ++iteration) {
        int column = digit - 2 - iteration;
        UIImageView *glyph = [[UIImageView alloc] init];
        if (iteration == digit - 1) {
            // The sign column; only the low-theme (classic/limelight) group and the colette theme
            // position it, the latter with a half-point vertical nudge in the large font.
            RBUserSettingDataTheme signThema = [RBUserSettingData sharedInstance].thema;
            if (signThema < kTimingSliderColetteThemaThreshold) {
                glyph.frame = CGRectMake(readoutOriginX, readoutOriginY, cellWidth, cellHeight);
            } else if (signThema == kTimingSliderColetteThema && isPad) {
                glyph.frame = CGRectMake(readoutOriginX,
                                         readoutOriginY + kTimingSliderColetteSignYAdjust,
                                         cellWidth,
                                         cellHeight);
            }
        } else {
            glyph.frame =
                CGRectMake((CGFloat)column + readoutOriginXWithGap + cellStep * (CGFloat)column,
                           readoutOriginY,
                           cellStep,
                           cellHeight);
        }
        [self addSubview:glyph];
        [self.numImageViews addObject:glyph];
    }

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
        CGRectMake(bar.origin.x + bar.size.width * 0.5 + (CGFloat)(_value * self.step),
                   bar.origin.y,
                   gripFrame.size.width,
                   gripFrame.size.height);

    if (self.value >= 0.0) {
        self.numImageViews[self.digit].hidden = YES;
    } else {
        UIImageView *signView = self.numImageViews[self.digit];
        signView.image = self.numImages[kTimingSliderMinusImageIndex];
        signView.hidden = NO;
    }

    int magnitude = (int)fabsf(self.value);
    for (int i = 0; i < self.digit; ++i) {
        UIImageView *place = self.numImageViews[i];
        place.image = self.numImages[magnitude % kTimingSliderDecimalBase];
        magnitude /= kTimingSliderDecimalBase;
    }
}

- (void)sliderChangeWithTouchPoint:(CGPoint)point {
    int newValue;
    CGRect bar = self.barRect;
    if (point.x >= bar.origin.x && point.x <= bar.origin.x + bar.size.width) {
        newValue = (int)((float)((point.x - bar.origin.x) + bar.size.width * -0.5) / self.step);
    } else {
        newValue = self.barMax;
    }
    [self setValue:(float)newValue];
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
