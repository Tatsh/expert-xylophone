#import "RBEffectSizeSlider.h"

#include <assert.h>
#include <math.h>

#import "RBUserSettingData.h"
#import "UIImage+RB.h"
#import "deviceenvironment.h"

static NSString *const kEffectSizeSliderTrackImageName = @"04_customize/cus_vol_4";
static NSString *const kEffectSizeSliderGripImageName = @"02_music_detail/det_col_br_5";

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

static const NSUInteger kEffectSizeSliderPointImageIndex = 10;

static const int kEffectSizeSliderBarMin = 0;
static const int kEffectSizeSliderBarMax = 3;

static const float kEffectSizeSliderStepValue = 0.5f;

static const CGFloat kEffectSizeSliderVerticalOffset = 6.0;

static const CGFloat kEffectSizeSliderBarOriginXNarrow = 19.0;
static const CGFloat kEffectSizeSliderBarOriginYNarrow = 21.0;
static const CGFloat kEffectSizeSliderBarWidthNarrow = 210.0;
static const CGFloat kEffectSizeSliderBarOriginXWide = 38.0;
static const CGFloat kEffectSizeSliderBarOriginYWide = 33.0;
static const CGFloat kEffectSizeSliderBarWidthWide = 318.0; // @ghidraAddress 0x2eeeb0

static const CGFloat kEffectSizeSliderReadoutOriginXLowThemeNarrow = 152.0;
static const CGFloat kEffectSizeSliderReadoutOriginXLowThemeWide = 225.0;
static const CGFloat kEffectSizeSliderReadoutOriginYLowThemeNarrow = 10.0;
static const CGFloat kEffectSizeSliderReadoutOriginYLowThemeWide = 17.0;
static const CGFloat kEffectSizeSliderReadoutOriginXColetteNarrow = 144.0;
static const CGFloat kEffectSizeSliderReadoutOriginXColetteWide = 246.0;
static const CGFloat kEffectSizeSliderReadoutOriginYColetteNarrow = 10.0;
static const CGFloat kEffectSizeSliderReadoutOriginYColetteWide = 14.5;

static const CGFloat kEffectSizeSliderWideFractionGap = 1.0;

static const int kEffectSizeSliderStepsPerUnit = 2;

static const int kEffectSizeSliderDecimalBase = 10;

static const NSUInteger kEffectSizeSliderReadoutCapacity = 3;

static const int kEffectSizeSliderColetteThemaThreshold = 2;

@implementation RBEffectSizeSlider

// The overridden accessors suppress auto-synthesis; the binary keeps the backing ivar.
@synthesize value = _value;

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
    CGRect trackBounds = self.baseView.frame;
    self.frame = CGRectMake(selfFrame.origin.x,
                            selfFrame.origin.y + kEffectSizeSliderVerticalOffset,
                            trackBounds.size.width,
                            trackBounds.size.height);

    self.stepValue = kEffectSizeSliderStepValue;
    self.value = [RBUserSettingData sharedInstance].boundsEffectSize;
    self.barMin = kEffectSizeSliderBarMin;
    self.barMax = kEffectSizeSliderBarMax;
    self.step = (float)(self.barRect.size.width /
                        (CGFloat)((self.barMax - self.barMin) * kEffectSizeSliderStepsPerUnit));

    self.numImages = [[NSMutableArray alloc] initWithCapacity:kEffectSizeSliderPointImageIndex + 1];
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
    // The binary reads barRect afresh for each field rather than caching it, so this does too.
    if (point.x < self.barRect.origin.x) {
        newValue = (float)self.barMin;
    } else if (point.x > self.barRect.origin.x + self.barRect.size.width) {
        newValue = (float)self.barMax;
    } else {
        float touchOffset = (float)(point.x - self.barRect.origin.x);
        int doubledSteps = (int)roundf((touchOffset + touchOffset) / self.step);
        newValue = self.stepValue * (float)(doubledSteps / 2);
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
