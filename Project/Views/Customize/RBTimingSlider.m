#import "RBTimingSlider.h"

#import "RBUserSettingData.h"
#import "UIImage+RB.h"
#import "deviceenvironment.h"
#import "engineglobals.h"

static NSString *const kTimingSliderTrackImageName = @"04_customize/cus_vol_3";
static NSString *const kTimingSliderGripImageName = @"02_music_detail/det_col_br_5";

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

static const NSUInteger kTimingSliderMinusImageIndex = 10;

static const int kTimingSliderBarMin = -10;
static const int kTimingSliderBarMax = 10;

static const CGFloat kTimingSliderVerticalOffset = 6.0;

static const CGFloat kTimingSliderBarOriginXNarrow = 19.0;
static const CGFloat kTimingSliderBarOriginYNarrow = 21.0;
static const CGFloat kTimingSliderBarWidthNarrow = 210.0;
static const CGFloat kTimingSliderBarOriginXWide = 40.0;
static const CGFloat kTimingSliderBarOriginYWide = 33.0;
static const CGFloat kTimingSliderBarWidthWide = 315.0;

// "LowTheme" is the classic/limelight group, which shares one readout layout.
static const CGFloat kTimingSliderReadoutOriginXLowThemeNarrow = 140.0; // 0x1002ec6c0
static const CGFloat kTimingSliderReadoutOriginXLowThemeWide = 212.0;   // 0x100301850
static const CGFloat kTimingSliderReadoutOriginYLowThemeNarrow = 10.0;
static const CGFloat kTimingSliderReadoutOriginYLowThemeWide = 16.5;   // 0x10030dde0
static const CGFloat kTimingSliderReadoutOriginXColetteNarrow = 138.0; // 0x10030ddd8
static const CGFloat kTimingSliderReadoutOriginXColetteWide = 220.0;   // 0x1003011b8
static const CGFloat kTimingSliderReadoutOriginYColetteNarrow = 10.0;
static const CGFloat kTimingSliderReadoutOriginYColetteWide = 14.0;

static const CGFloat kTimingSliderColetteSignYAdjust = 0.5;

static const CGFloat kTimingSliderDigitGap = 1.0;

static const NSUInteger kTimingSliderReadoutCapacity = 3;

static const int kTimingSliderDecimalBase = 10;

enum {
    kTimingSliderColetteThemaThreshold = 2,
    kTimingSliderColetteThema = 2,
};

enum {
    kRectOriginX = 0,
    kRectOriginY = 1,
    kRectWidth = 2,
    kRectHeight = 3,
};

@implementation RBTimingSlider

// The overridden accessors suppress auto-synthesis; the binary keeps the backing ivar.
@synthesize value = _value;

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
    CGRect baseFrame = self.baseView.frame;
    self.frame = CGRectMake(selfFrame.origin.x,
                            selfFrame.origin.y + kTimingSliderVerticalOffset,
                            baseFrame.size.width,
                            baseFrame.size.height);

    self.value = (float)[RBUserSettingData sharedInstance].delayFrame;
    self.barMin = kTimingSliderBarMin;
    self.barMax = kTimingSliderBarMax;
    self.step = (float)(self.barRect.size.width / (CGFloat)(self.barMax - self.barMin));

    CGSize digitGlyphSize = CGSizeZero;
    CGSize signGlyphSize = CGSizeZero;
    self.numImages = [[NSMutableArray alloc] initWithCapacity:kTimingSliderMinusImageIndex + 1];
    for (NSUInteger i = 0; i <= kTimingSliderMinusImageIndex; ++i) {
        UIImage *glyphImage = [UIImage imageWithName:kTimingSliderDigitImageNames[i]];
        [self.numImages addObject:glyphImage];
        if (i == 0) {
            digitGlyphSize = glyphImage.size;
        } else if (i == kTimingSliderMinusImageIndex) {
            signGlyphSize = glyphImage.size;
        }
    }

    self.numImageViews = [[NSMutableArray alloc] initWithCapacity:kTimingSliderReadoutCapacity];

    CGFloat readoutOriginX = 0.0;
    CGFloat readoutOriginY = 0.0;

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

    // numImageViews[0] is the least significant place; the sign column lands last at index digit.
    CGFloat readoutOriginXWithGap = signGlyphSize.width + kTimingSliderDigitGap + readoutOriginX;
    for (int iteration = -1; iteration < digit; ++iteration) {
        int column = digit - 2 - iteration;
        UIImageView *glyph = [[UIImageView alloc] init];
        if (iteration == digit - 1) {
            // Only the classic/limelight group and colette position the sign column at all.
            RBUserSettingDataTheme signThema = [RBUserSettingData sharedInstance].thema;
            if (signThema < kTimingSliderColetteThemaThreshold) {
                glyph.frame = CGRectMake(
                    readoutOriginX, readoutOriginY, signGlyphSize.width, signGlyphSize.height);
            } else if (signThema == kTimingSliderColetteThema && isPad) {
                glyph.frame = CGRectMake(readoutOriginX,
                                         readoutOriginY + kTimingSliderColetteSignYAdjust,
                                         signGlyphSize.width,
                                         signGlyphSize.height);
            }
        } else {
            glyph.frame = CGRectMake((CGFloat)column + readoutOriginXWithGap +
                                         digitGlyphSize.width * (CGFloat)column,
                                     readoutOriginY,
                                     digitGlyphSize.width,
                                     digitGlyphSize.height);
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
    if (point.x < bar.origin.x) {
        newValue = self.barMin;
    } else if (point.x > bar.origin.x + bar.size.width) {
        newValue = self.barMax;
    } else {
        newValue = (int)((float)((point.x - bar.origin.x) + bar.size.width * -0.5) / self.step);
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
