#import "StoreButtonView.h"

#import <UIKit/UIKit.h>

// The title colour and shadow alphas the binary applies in -initWithFrame:.
static const CGFloat kTitleShadowAlpha = 0.7;            // Normal- and disabled-state shadow alpha.
static const CGFloat kHighlightedTitleWhite = 0.8;       // Highlighted title colour brightness.
static const CGFloat kHighlightedTitleShadowAlpha = 0.8; // Highlighted title shadow alpha.
static const CGFloat kSelectedTitleShadowAlpha = 0.6;    // Selected title shadow alpha.
static const CGFloat kRetinaTitleShadowHeight = -0.5;    // Title shadow offset height on retina.
static const CGFloat kNonRetinaTitleShadowHeight = -1.0; // Title shadow offset height otherwise.
static const CGFloat kRetinaScaleThreshold = 2.0;        // Screen scale treated as retina.

// The fill-gradient parameters used in -drawRect:. The base fill is darkened by a state-dependent
// factor, then four stops brighten it towards white.
static const CGFloat kFillFactorNormal = 0.8;      // Base darkening factor when not highlighted.
static const CGFloat kFillFactorHighlighted = 0.6; // Base darkening factor when highlighted.
static const CGFloat kGradientFactors[] = {0.0, 0.16, 0.32, 0.48};
static const CGFloat kGradientLocations[] = {0.0, 0.45, 0.55, 1.0};

// The grey inner-shadow border parameters used in -drawRect:.
static const CGFloat kShadowBlurNormal = 2.0;      // Border shadow blur when not highlighted.
static const CGFloat kShadowBlurHighlighted = 3.0; // Border shadow blur when highlighted.
static const CGFloat kShadowBlurDisabled = 2.0;    // Border shadow blur while disabled.
static const CGFloat kShadowOffsetNormal = 1.0; // Border shadow base offset when not highlighted.
static const CGFloat kShadowOffsetHighlighted = 2.0; // Border shadow base offset when highlighted.
static const CGFloat kShadowOffsetDisabled = 1.0;    // Border shadow base offset while disabled.
static const CGFloat kBorderInset = -4.0;            // Outward inset of the even-odd border rect.
static const CGFloat kShadowOffsetNudge = 0.1;       // Rounding nudge applied to the border shadow.

// The number of components a fully specified RGBA colour reports.
static const int kRGBAComponentCount = 4;

@interface StoreButtonView ()
/**
 * @brief Blends a straight RGBA colour towards white and returns it as a @c UIColor.
 * @param components A four-element RGBA array, each channel in the range [0, 1].
 * @param factor The blend amount towards white; 0 keeps the colour, 1 yields white.
 * @return The blended colour.
 * @ghidraAddress 0xc300
 */
- (UIColor *)highlightColor:(const CGFloat *)components factor:(CGFloat)factor;
@end

@implementation StoreButtonView

/** @ghidraAddress 0xbddc */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        CGFloat shadowHeight = [UIScreen mainScreen].scale >= kRetinaScaleThreshold ?
                                   kRetinaTitleShadowHeight :
                                   kNonRetinaTitleShadowHeight;
        self.titleLabel.shadowOffset = CGSizeMake(0.0, shadowHeight);
        [self setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [self setTitleShadowColor:[UIColor colorWithWhite:0.0 alpha:kTitleShadowAlpha]
                         forState:UIControlStateNormal];
        [self setTitleColor:[UIColor colorWithWhite:kHighlightedTitleWhite alpha:1.0]
                   forState:UIControlStateHighlighted];
        [self setTitleShadowColor:[UIColor colorWithWhite:0.0 alpha:kHighlightedTitleShadowAlpha]
                         forState:UIControlStateHighlighted];
        [self setTitleColor:[UIColor colorWithWhite:1.0 alpha:kTitleShadowAlpha]
                   forState:UIControlStateSelected];
        [self setTitleShadowColor:[UIColor colorWithWhite:0.0 alpha:kSelectedTitleShadowAlpha]
                         forState:UIControlStateSelected];
        self.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
        self.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    }
    return self;
}

#pragma mark - Colour and geometry accessors

/** @ghidraAddress 0xc138 */
- (UIColor *)buttonColor {
    if (_buttonColor == nil) {
        _buttonColor = [UIColor blueColor];
    }
    return _buttonColor;
}

/** @ghidraAddress 0xc194 */
- (void)setButtonColor:(UIColor *)buttonColor {
    _buttonColor = buttonColor;
    [self setNeedsDisplay];
}

/** @ghidraAddress 0xc208 */
- (UIColor *)disabledColor {
    if (_disabledColor == nil) {
        _disabledColor = [UIColor grayColor];
    }
    return _disabledColor;
}

/** @ghidraAddress 0xc264 */
- (void)setDisabledColor:(UIColor *)disabledColor {
    _disabledColor = disabledColor;
    [self setNeedsDisplay];
}

/** @ghidraAddress 0xc2d8 */
- (CGFloat)cornerRadius {
    return _cornerRadius;
}

/** @ghidraAddress 0xc2e8 */
- (void)setCornerRadius:(CGFloat)cornerRadius {
    _cornerRadius = cornerRadius;
    [self setNeedsDisplay];
}

#pragma mark - State overrides

/** @ghidraAddress 0xc348 */
- (void)setHighlighted:(BOOL)highlighted {
    BOOL wasHighlighted = super.highlighted;
    super.highlighted = highlighted;
    if (wasHighlighted != highlighted) {
        [self setNeedsDisplay];
    }
}

/** @ghidraAddress 0xc3d4 */
- (void)setSelected:(BOOL)selected {
    BOOL wasSelected = super.selected;
    super.selected = selected;
    if (wasSelected != selected) {
        [self setNeedsDisplay];
    }
}

#pragma mark - Drawing

- (UIColor *)highlightColor:(const CGFloat *)components factor:(CGFloat)factor {
    CGFloat keep = 1.0 - factor;
    return [UIColor colorWithRed:keep * components[0] + factor
                           green:keep * components[1] + factor
                            blue:keep * components[2] + factor
                           alpha:keep * components[3] + factor];
}

/** @ghidraAddress 0xc460 */
- (void)drawRect:(CGRect)rect {
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextClearRect(context, rect);

    UIBezierPath *roundedPath = [UIBezierPath bezierPathWithRoundedRect:rect
                                                           cornerRadius:self.cornerRadius];
    CGContextSaveGState(context);

    CGFloat shadowBlur;
    CGFloat shadowOffset;
    if (self.state == UIControlStateDisabled) {
        [self.disabledColor setFill];
        [roundedPath fill];
        shadowBlur = kShadowBlurDisabled;
        shadowOffset = kShadowOffsetDisabled;
    } else {
        BOOL highlighted = self.state == UIControlStateHighlighted;
        shadowOffset = highlighted ? kShadowOffsetHighlighted : kShadowOffsetNormal;
        shadowBlur = highlighted ? kShadowBlurHighlighted : kShadowBlurNormal;

        // Read the fill colour's straight RGBA components. Older UIColor builds lack
        // -getRed:green:blue:alpha:, so fall back to reading the component array of the CGColor.
        CGFloat red;
        CGFloat green;
        CGFloat blue;
        CGFloat alpha;
        if ([UIColor instancesRespondToSelector:@selector(getRed:green:blue:alpha:)]) {
            [self.buttonColor getRed:&red green:&green blue:&blue alpha:&alpha];
        } else {
            const CGFloat *components = CGColorGetComponents(self.buttonColor.CGColor);
            red = components[0];
            if (CGColorGetNumberOfComponents(self.buttonColor.CGColor) == kRGBAComponentCount) {
                green = components[1];
                blue = components[2];
                alpha = components[3];
            } else {
                // A monochrome CGColor reports {white, alpha}; splay it across the RGB channels.
                green = red;
                blue = red;
                alpha = components[1];
            }
        }

        CGFloat fillFactor = highlighted ? kFillFactorHighlighted : kFillFactorNormal;
        CGFloat base[] = {fillFactor * red,
                          fillFactor * green,
                          fillFactor * blue,
                          (1.0 - fillFactor) + fillFactor * alpha};

        NSArray *colors = @[
            (__bridge id)[self highlightColor:base factor:kGradientFactors[0]].CGColor,
            (__bridge id)[self highlightColor:base factor:kGradientFactors[1]].CGColor,
            (__bridge id)[self highlightColor:base factor:kGradientFactors[2]].CGColor,
            (__bridge id)[self highlightColor:base factor:kGradientFactors[3]].CGColor
        ];
        CGGradientRef gradient =
            CGGradientCreateWithColors(colorSpace, (__bridge CFArrayRef)colors, kGradientLocations);
        [roundedPath addClip];
        CGContextDrawLinearGradient(
            context, gradient, CGPointZero, CGPointMake(0.0, CGRectGetMaxY(rect)), 0);
        CGGradientRelease(gradient);
    }

    CGContextRestoreGState(context);

    // Paint a grey inner shadow by filling an even-odd ring (an outward-inset rect minus the
    // rounded path), clipped to the rounded path and translated off to one side so its cast
    // shadow falls back inside the button.
    CGColorRef blackColor = [UIColor blackColor].CGColor;
    CGRect outerRect = CGRectInset(
        CGRectOffset(CGRectInset(roundedPath.bounds, -shadowBlur, -shadowBlur), -shadowOffset, 0.0),
        kBorderInset,
        kBorderInset);
    outerRect = CGRectInset(CGRectUnion(outerRect, roundedPath.bounds), kBorderInset, kBorderInset);

    UIBezierPath *borderPath = [UIBezierPath bezierPathWithRect:outerRect];
    [borderPath appendPath:roundedPath];
    borderPath.usesEvenOddFillRule = YES;

    CGContextSaveGState(context);
    CGFloat translation = round(outerRect.size.width);
    // The shadow offset and blur are derived from the SIMD-garbled disassembly: the ring is shifted
    // by its own rounded width and its shadow, nudged by 0.1, is cast back through the clip.
    CGContextSetShadowWithColor(
        context,
        CGSizeMake(translation + copysign(kShadowOffsetNudge, translation), shadowBlur),
        shadowOffset + copysign(kShadowOffsetNudge, shadowOffset),
        blackColor);
    [roundedPath addClip];
    [borderPath applyTransform:CGAffineTransformMakeTranslation(-translation, 0.0)];
    [[UIColor grayColor] setFill];
    [borderPath fill];
    CGContextRestoreGState(context);

    CGColorSpaceRelease(colorSpace);
}

#pragma mark - Lifecycle

/** @ghidraAddress 0xcc08 */
- (void)dealloc {
    self.buttonColor = nil;
    self.disabledColor = nil;
}

@end

// The compiler-generated -.cxx_destruct (@ghidraAddress 0xcca0) that clears _disabledColor and
// _buttonColor is provided automatically by ARC.
