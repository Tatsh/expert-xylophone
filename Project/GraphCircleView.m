#import "GraphCircleView.h"

#import "RBMacros.h"

// The default starting point: the first plotted point sits this far in from the left edge, and the
// plot content is inset from the bottom of the view by this margin.
static const CGFloat kDefaultStartX = 30.0;
static const CGFloat kBottomMargin = 10.0;

// The plot content is inset from the top and bottom by this margin when mapping values to y.
static const CGFloat kPlotVerticalMargin = 10.0;

// The dashed polyline pattern (a five-point dash followed by a two-point gap) and its length.
static const CGFloat kLineDashPattern[] = {5.0, 2.0};

// Each per-point marker is a small circle of this diameter, drawn centred on the point.
static const CGFloat kDotDiameter = 4.0;
static const CGFloat kDotRadius = 2.0;

// The horizontal inset applied at each end of the plot when four or more points are shown, and the
// fraction of the width used to inset the ends when two or three points are shown.
static const CGFloat kWideEndInset = 30.0;
static const CGFloat kFewPointEndFraction = 5.0;

// The value labels use this system font size, occupy a box of this width and height, and are laid
// out flush right. The top label sits at this y; the bottom label sits this far above the bottom
// edge.
static const CGFloat kLabelFontSize = 10.0;
static const CGFloat kLabelWidth = 20.0;
static const CGFloat kLabelHeight = 10.0;
static const CGFloat kTopLabelY = 10.0;
static const CGFloat kBottomLabelInset = 20.0;

// The value labels are drawn in fully-opaque black.

// After drawing, the plot reveals itself at full opacity.
static const CGFloat kVisibleAlpha = 1.0;

// The shared translucent-panel background alpha (g_dTranslucentAlpha @0x1002ee6a0-adjacent, 0.8).
// It is a cross-file palette global; it is cached here rather than re-declared as a shared external
// constant until that global is recovered.
static const CGFloat kTranslucentAlpha = 0.8;

// The point-count thresholds selecting how the horizontal layout is derived.
static const NSUInteger kSinglePointCount = 1;
static const NSUInteger kFewPointLowerCount = 2;
static const NSUInteger kFewPointUpperCount = 3;

// The comparison tolerance and the descending round thresholds the movable minimum line snaps down
// to. The first threshold that the minimum value is not below (within tolerance) is used.
static const double kSnapTolerance = 0.001;
static const float kMinLineSnapThresholds[] = {
    0.0f, 25.0f, 50.0f, 60.0f, 70.0f, 80.0f, 90.0f, 95.0f, 100.0f};

@implementation GraphCircleView

#pragma mark Lifecycle

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.pointArray = [[NSMutableArray alloc] init];
        [self CreateView];
    }
    return self;
}

#pragma mark View construction

- (void)CreateView {
    self.startPos = CGPointMake(kDefaultStartX, self.frame.size.height - kBottomMargin);
    self.hidden = YES;
    self.alpha = 0.0;
    self.backgroundColor = [UIColor colorWithWhite:kTranslucentAlpha alpha:kTranslucentAlpha];
}

#pragma mark Styling

- (void)setOption:(UIColor *)option
          dotSize:(float)dotSize
        lineColor:(UIColor *)lineColor
         lineSize:(float)lineSize {
    self.dotColor = [UIColor colorWithCGColor:option.CGColor];
    self.dotSize = dotSize;
    self.lineColor = [UIColor colorWithCGColor:lineColor.CGColor];
    self.lineSize = lineSize;
}

#pragma mark Data

- (void)setData:(NSArray *)data maxValue:(float)maxValue {
    [self setData:data maxValue:maxValue isMovableMinLine:NO];
}

- (void)setData:(NSArray *)data maxValue:(float)maxValue isMovableMinLine:(BOOL)isMovableMinLine {
    if (data != nil && [data count] != 0) {
        self.dataArray = [[NSMutableArray alloc] initWithArray:data];
    }
    if (self.dataArray == nil || [self.dataArray count] == 0) {
        return;
    }

    self.maxValue = maxValue;
    self.minValue = 0.0f;

    if (isMovableMinLine) {
        for (NSNumber *value in self.dataArray) {
            if (self.minValue == 0.0f) {
                self.minValue = value.floatValue;
            } else if (value.floatValue < self.minValue) {
                self.minValue = value.floatValue;
            }
        }
        for (int i = 0; i < (int)ARRAY_SIZE(kMinLineSnapThresholds); ++i) {
            float threshold = kMinLineSnapThresholds[i];
            if ((double)fabsf(threshold - self.minValue) < kSnapTolerance) {
                break;
            }
            if (self.minValue < threshold) {
                self.minValue = kMinLineSnapThresholds[i];
                break;
            }
        }
    }

    CGFloat width = self.frame.size.width;
    NSUInteger count = [self.dataArray count];
    if (count == kFewPointLowerCount || count == kFewPointUpperCount) {
        self.startPos =
            CGPointMake(width / kFewPointEndFraction + self.startPos.x, self.startPos.y);
        self.dotIntervalX =
            (float)(width - width / kFewPointEndFraction - width / kFewPointEndFraction) /
            (float)(count - 1);
    } else if (count == kSinglePointCount) {
        self.startPos = CGPointMake(width * 0.5 + self.startPos.x, self.startPos.y);
        self.dotIntervalX = 0.0f;
    } else {
        self.dotIntervalX = (float)((width - kWideEndInset - kWideEndInset) / (double)(count - 1));
    }

    UILabel *maxLabel =
        [[UILabel alloc] initWithFrame:CGRectMake(0, kTopLabelY, kLabelWidth, kLabelHeight)];
    maxLabel.frame = CGRectMake(0, kTopLabelY, kLabelWidth, kLabelHeight);
    maxLabel.font = [UIFont systemFontOfSize:kLabelFontSize];
    maxLabel.text = [NSString stringWithFormat:@"%d", (int)self.maxValue];
    // The binary builds this with colorWithRed:0 green:0 blue:0 alpha:1.
    maxLabel.textColor = UIColor.blackColor;
    maxLabel.textAlignment = NSTextAlignmentRight;
    [self addSubview:maxLabel];

    UILabel *minLabel =
        [[UILabel alloc] initWithFrame:CGRectMake(0,
                                                  self.frame.size.height - kBottomLabelInset,
                                                  kLabelWidth,
                                                  kLabelHeight)];
    minLabel.font = [UIFont systemFontOfSize:kLabelFontSize];
    minLabel.text = [NSString stringWithFormat:@"%d", (int)self.minValue];
    // The binary builds this with colorWithRed:0 green:0 blue:0 alpha:1.
    minLabel.textColor = UIColor.blackColor;
    minLabel.textAlignment = NSTextAlignmentRight;
    [self addSubview:minLabel];

    [self setNeedsDisplay];
}

#pragma mark Drawing

- (void)drawRect:(CGRect)rect {
    CGFloat height = self.frame.size.height;
    float span = self.maxValue - self.minValue;

    for (long i = 0; i + 1 < (long)[self.dataArray count]; ++i) {
        float startValue = [self.dataArray[i] floatValue];
        float endValue = [self.dataArray[i + 1] floatValue];

        CGFloat x0 = self.startPos.x + (float)(int)i * self.dotIntervalX;
        CGFloat y0 = (1.0 - (double)((startValue - self.minValue) / span)) *
                         (height - kPlotVerticalMargin - kPlotVerticalMargin) +
                     kPlotVerticalMargin;
        CGFloat x1 = self.startPos.x + (float)((int)i + 1) * self.dotIntervalX;
        CGFloat y1 = (1.0 - (double)((endValue - self.minValue) / span)) *
                         (height - kPlotVerticalMargin - kPlotVerticalMargin) +
                     kPlotVerticalMargin;

        UIBezierPath *segment = [UIBezierPath bezierPath];
        [segment setLineDash:kLineDashPattern count:ARRAY_SIZE(kLineDashPattern) phase:0];
        [segment moveToPoint:CGPointMake(x0, y0)];
        [segment addLineToPoint:CGPointMake(x1, y1)];
        [self.lineColor setStroke];
        segment.lineWidth = self.lineSize;
        [segment stroke];
    }

    for (NSUInteger i = 0; i < [self.dataArray count]; ++i) {
        float value = [self.dataArray[i] floatValue];
        CGFloat x = self.startPos.x + (float)(int)i * self.dotIntervalX;
        CGFloat y = (1.0 - (double)((value - self.minValue) / span)) *
                        (height - kPlotVerticalMargin - kPlotVerticalMargin) +
                    kPlotVerticalMargin;

        UIBezierPath *dot = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(x - kDotRadius,
                                                                              y - kDotRadius,
                                                                              kDotDiameter,
                                                                              kDotDiameter)];
        [self.dotColor setFill];
        [self.dotColor setStroke];
        dot.lineWidth = self.dotSize;
        [dot stroke];
    }

    self.alpha = kVisibleAlpha;
    self.hidden = NO;
}

#pragma mark Reset

- (void)reset {
    if (self.dataArray != nil && [self.dataArray count] != 0) {
        [self.dataArray removeAllObjects];
    }
    if (self.pointArray != nil && [self.pointArray count] != 0) {
        [self.pointArray removeAllObjects];
    }
    self.startPos = CGPointMake(kDefaultStartX, self.frame.size.height - kBottomMargin);
    self.dotIntervalX = 0.0f;
    self.maxValue = 0.0f;
    self.minValue = 0.0f;
    [self setNeedsDisplay];
}

@end
