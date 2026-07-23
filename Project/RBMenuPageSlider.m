//
//  RBMenuPageSlider.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RBMenuPageSlider). The
//  initialiser's soft-float track, grip, and label geometry, and the theme-dependent colours, were
//  recovered from the arm64 disassembly (the decompiler folds the CGRect components into
//  pseudo-variables). This is the draggable UIControl page slider wrapped by RBMenuPageSliderView.
//

#import "RBMenuPageSlider.h"

#import "RBUserSettingData.h"
#import "UIImage+RB.h"
#import "neEngineBridge.h"

// The page range always starts at page one.
static const NSUInteger kSliderMinPage = 1;

// The grip texture lives in this atlas; its clip rectangle is g_pGripTextureClipRect scaled by the
// reference screen height.
static NSString *const kSliderGripTextureName = @"00_texture/gm_parts1";

// The normalised grip-texture clip rectangle (x, y, width, height) is scaled by this reference
// screen height, matching the binary's g_fltReferenceScreenHeight (0x100309164).
static const CGFloat kReferenceScreenHeight = 1024.0;

// The normalised grip-texture clip rectangle (x, y, width, height), matching the binary's
// g_pGripTextureClipRect (0x1002ef738). It is scaled by the reference screen height, and
// additionally halved for the default (non-wide) font variant.
static const CGFloat kGripTextureClipRect[] = {0.001953125, 0.08984375, 0.09375, 0.09375};

// The slider row height (grip and track height basis): 20 points for the default font variant, 40
// for the wide variant. Mirrors the binary's lazily-initialised g_dSliderRowHeight (0x1003df4f8).
static const CGFloat kSliderRowHeightNarrow = 20.0;
static const CGFloat kSliderRowHeightWide = 40.0;

// The grip sprite is drawn at this fraction of its source texture size (0x1002ec720).
static const CGFloat kSliderGripScale = 0.4;

// The control's corner radius is the row height times this factor (0x100310630).
static const CGFloat kSliderControlCornerFactor = 0.9;

// The gauge track's vertical inset is the grip height times this factor, halved (0x100310628).
static const CGFloat kSliderGaugeInsetFactor = 1.85;

// The gauge track's height is the grip height times this factor (0x1003010f8).
static const CGFloat kSliderGaugeHeightFactor = 0.15;

// The index label's point size by font variant.
static const CGFloat kSliderIndexFontSizeNarrow = 10.0;
static const CGFloat kSliderIndexFontSizeWide = 16.0;

// The translucent alpha shared by the gauge fill and the index-label background (0x1002ec6a0).
static const CGFloat kSliderTranslucentAlpha = 0.8;

// The index label's initial placeholder text, sized to fit before being cleared.
static NSString *const kSliderIndexLabelSizingText = @"00";

// The clip-rect components.
enum {
    kClipRectX = 0,
    kClipRectY = 1,
    kClipRectWidth = 2,
    kClipRectHeight = 3,
};

@implementation RBMenuPageSlider

- (instancetype)initWithFrame:(CGRect)frame delegate:(id<RBMenuPageSliderDelegate>)delegate {
    BOOL isWideVariant = GetFontVariantFlag() != kFontVariantDefault;
    CGFloat rowHeight = isWideVariant ? kSliderRowHeightWide : kSliderRowHeightNarrow;

    UIImage *gripImage = [UIImage imageWithName:kSliderGripTextureName useCache:NO];
    CGFloat clipScale = isWideVariant ? kReferenceScreenHeight : (kReferenceScreenHeight * 0.5);
    CGRect gripClip = CGRectMake(kGripTextureClipRect[kClipRectX] * clipScale,
                                 kGripTextureClipRect[kClipRectY] * clipScale,
                                 kGripTextureClipRect[kClipRectWidth] * clipScale,
                                 kGripTextureClipRect[kClipRectHeight] * clipScale);
    gripImage = [gripImage clipImageWithRect:gripClip];

    UIImageView *grip = [[UIImageView alloc] initWithImage:gripImage];
    grip.frame = CGRectMake(0.0, 0.0, grip.frame.size.width * kSliderGripScale,
                            grip.frame.size.height * kSliderGripScale);
    CGFloat gripWidth = grip.frame.size.width;
    CGFloat gripHeight = grip.frame.size.height;

    self = [super initWithFrame:CGRectMake(0.0, 0.0, frame.size.width, gripHeight + gripHeight)];
    if (!self) {
        return nil;
    }

    self.layer.cornerRadius = rowHeight * kSliderControlCornerFactor;
    self.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
                            UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;

    UIView *gauge = [[UIView alloc]
        initWithFrame:CGRectMake(rowHeight + gripWidth * 0.5,
                                 gripHeight * kSliderGaugeInsetFactor * 0.5,
                                 (frame.size.width - gripWidth) - rowHeight * 2.0,
                                 gripHeight * kSliderGaugeHeightFactor)];
    gauge.layer.cornerRadius = gauge.frame.size.height * 0.5;
    gauge.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    gauge.userInteractionEnabled = NO;
    [self addSubview:gauge];
    self.slideGaugeView = gauge;

    grip.frame = CGRectMake(gauge.frame.origin.x - gripWidth * 0.5, gripHeight * 0.5, gripWidth,
                            gripHeight);
    grip.userInteractionEnabled = NO;
    [self addSubview:grip];
    self.gripView = grip;

    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0.0, 0.0, 10.0, 10.0)];
    CGFloat fontSize = isWideVariant ? kSliderIndexFontSizeWide : kSliderIndexFontSizeNarrow;
    label.font = [UIFont systemFontOfSize:fontSize];
    label.textAlignment = NSTextAlignmentCenter;
    label.text = kSliderIndexLabelSizingText;
    [label sizeToFit];
    label.text = @"";
    label.layer.cornerRadius = label.frame.size.height * 0.5;
    label.clipsToBounds = YES;
    label.alpha = 0.0;
    [self addSubview:label];
    self.indexLabel = label;

    self.barMin = kSliderMinPage;
    self.barMax = kSliderMinPage;
    self.step = 0.0;
    self.value = 1.0;
    self.delegate = delegate;

    RBUserSettingDataTheme thema = [RBUserSettingData sharedInstance].thema;
    if (thema == RBUserSettingDataThemeClassic) {
        self.backgroundColor = [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:0.5];
        self.slideGaugeView.backgroundColor = [UIColor colorWithRed:1.0
                                                              green:1.0
                                                               blue:1.0
                                                              alpha:kSliderTranslucentAlpha];
        self.indexLabel.textColor = [UIColor blackColor];
        self.indexLabel.backgroundColor = [UIColor colorWithRed:1.0
                                                          green:1.0
                                                           blue:1.0
                                                          alpha:kSliderTranslucentAlpha];
    } else {
        self.backgroundColor = [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.5];
        self.slideGaugeView.backgroundColor = [UIColor colorWithRed:1.0
                                                              green:1.0
                                                               blue:1.0
                                                              alpha:kSliderTranslucentAlpha];
        self.indexLabel.textColor = [UIColor whiteColor];
        self.indexLabel.backgroundColor = [UIColor colorWithRed:1.0
                                                          green:1.0
                                                           blue:1.0
                                                          alpha:kSliderTranslucentAlpha];
    }

    return self;
}

- (void)reset:(NSUInteger)pageMax currentPage:(NSUInteger)currentPage {
    self.barMax = pageMax;
    if (self.barMax == kSliderMinPage) {
        self.step = 0.0;
    } else {
        self.step = self.slideGaugeView.frame.size.width / (CGFloat)(self.barMax - self.barMin);
    }
    self.value = (float)currentPage;
}

- (void)setValue:(float)value {
    if (value <= (float)self.barMin) {
        value = (float)self.barMin;
    }
    if (value > (float)self.barMax) {
        value = (float)self.barMax;
    }
    _value = (float)(int)value;

    CGRect gripFrame = self.gripView.frame;
    CGFloat gaugeX = self.slideGaugeView.frame.origin.x;
    self.gripView.frame = CGRectMake(gaugeX + (CGFloat)(_value - 1.0) * self.step -
                                         gripFrame.size.width * 0.5,
                                     gripFrame.origin.y, gripFrame.size.width,
                                     gripFrame.size.height);

    CGFloat gripX = self.gripView.frame.origin.x;
    CGFloat gripWidth = self.gripView.frame.size.width;
    CGFloat labelWidth = self.indexLabel.frame.size.width;
    CGFloat labelHeight = self.indexLabel.frame.size.height;
    self.indexLabel.frame = CGRectMake(gripX + (gripWidth - labelWidth) * 0.5, labelHeight * -0.5,
                                       gripWidth, labelHeight);
}

- (void)sliderChangeWithTouchPoint:(CGPoint)point isEnd:(BOOL)isEnd {
    CGFloat gaugeX = self.slideGaugeView.frame.origin.x;
    CGFloat page;
    if (self.step == 0.0) {
        page = (CGFloat)self.barMin;
    } else {
        page = (CGFloat)self.barMin + (point.x - gaugeX) / self.step;
    }

    CGFloat posValue = page;
    if (page < (CGFloat)self.barMin || (CGFloat)self.barMax < page) {
        self.value = (float)self.barMax;
        posValue = (CGFloat)self.value;
    } else {
        float snapped = (float)page;
        if (isEnd) {
            snapped = (float)(int)page;
        }
        self.value = snapped;
    }

    if ([self.delegate respondsToSelector:@selector(changePage:)]) {
        NSArray<NSNumber *> *parameters = @[ @((int)self.value), @(posValue), @(isEnd) ];
        [self.delegate performSelector:@selector(changePage:) withObject:parameters];
    }
}

- (BOOL)beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    self.indexLabel.alpha = 1.0;
    CGPoint point = [touch locationInView:touch.view];
    [self sliderChangeWithTouchPoint:point isEnd:NO];
    return YES;
}

- (BOOL)continueTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    CGPoint point = [touch locationInView:touch.view];
    [self sliderChangeWithTouchPoint:point isEnd:NO];
    return YES;
}

- (void)endTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    CGPoint point = [touch locationInView:touch.view];
    [self sliderChangeWithTouchPoint:point isEnd:YES];
    self.indexLabel.alpha = 0.0;
}

@end
