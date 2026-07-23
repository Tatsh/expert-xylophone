//
//  RBVolumeSlider.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RBVolumeSlider). The
//  initialiser's soft-float bar-rectangle geometry, and the setValue: gauge-fill frame maths, were
//  recovered from the arm64 disassembly (the decompiler folds the CGRect components into
//  pseudo-variables). This is the shot-volume slider created by RBCustomSelectCollectionView.
//

#import "RBVolumeSlider.h"

#import "UIImage+RB.h"
#import "neEngineBridge.h"

// The track sprite (base view) and gauge (fill) sprite texture names.
static NSString *const kVolumeSliderTrackImageName = @"04_customize/cus_vol_1";
static NSString *const kVolumeSliderGaugeImageName = @"04_customize/cus_vol_2";

// The lowest and highest selectable normalised volume.
static const float kVolumeSliderMinValue = 0.0f;
static const float kVolumeSliderMaxValue = 1.0f;

// The bar rectangle (the gauge's full-value extent) by device idiom: origin x/y, then width and
// height. Narrow mirrors the default font, wide the large font.
static const CGFloat kVolumeSliderBarOriginXNarrow = 16.0;
static const CGFloat kVolumeSliderBarOriginYNarrow = 9.0;
static const CGFloat kVolumeSliderBarWidthNarrow = 90.0;
static const CGFloat kVolumeSliderBarHeightNarrow = 4.0;
static const CGFloat kVolumeSliderBarOriginXWide = 39.0;
static const CGFloat kVolumeSliderBarOriginYWide = 29.0;
static const CGFloat kVolumeSliderBarWidthWide = 120.0;
static const CGFloat kVolumeSliderBarHeightWide = 6.0;

@implementation RBVolumeSlider

- (instancetype)init {
    self = [super init];
    if (!self) {
        return nil;
    }

    UIImageView *track =
        [[UIImageView alloc] initWithImage:[UIImage imageWithName:kVolumeSliderTrackImageName]];
    self.baseView = track;
    [self addSubview:self.baseView];
    self.frame = self.baseView.bounds;

    UIImageView *gauge =
        [[UIImageView alloc] initWithImage:[UIImage imageWithName:kVolumeSliderGaugeImageName]];
    self.gaugeView = gauge;
    [self addSubview:self.gaugeView];

    if (IsPad()) {
        self.barRect = CGRectMake(kVolumeSliderBarOriginXWide,
                                  kVolumeSliderBarOriginYWide,
                                  kVolumeSliderBarWidthWide,
                                  kVolumeSliderBarHeightWide);
    } else {
        self.barRect = CGRectMake(kVolumeSliderBarOriginXNarrow,
                                  kVolumeSliderBarOriginYNarrow,
                                  kVolumeSliderBarWidthNarrow,
                                  kVolumeSliderBarHeightNarrow);
    }

    self.gaugeView.frame = self.barRect;
    self.value = kVolumeSliderMinValue;

    return self;
}

- (void)setValue:(float)value {
    if (value <= kVolumeSliderMinValue) {
        value = kVolumeSliderMinValue;
    }
    if (kVolumeSliderMaxValue < value) {
        value = kVolumeSliderMaxValue;
    }
    _value = value;

    CGRect gaugeFrame = self.gaugeView.frame;
    self.gaugeView.frame = CGRectMake(gaugeFrame.origin.x,
                                      gaugeFrame.origin.y,
                                      (CGFloat)_value * self.barRect.size.width,
                                      gaugeFrame.size.height);
}

- (void)sliderChangeWithTouchPoint:(CGPoint)point {
    float value;
    CGRect bar = self.barRect;
    if (point.x < bar.origin.x) {
        value = kVolumeSliderMinValue;
    } else if (point.x <= bar.origin.x + bar.size.width) {
        value = (float)((CGFloat)(float)(point.x - bar.origin.x) / bar.size.width);
    } else {
        value = kVolumeSliderMaxValue;
    }
    [self setValue:value];
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
