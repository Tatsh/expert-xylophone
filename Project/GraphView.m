#import "GraphView.h"

#import "RBMacros.h"

static const CGFloat kDefaultStartX = 30.0;
static const CGFloat kBottomMargin = 10.0;

static const CGFloat kPlotVerticalMargin = 10.0;

static const CGFloat kLineDashPattern[] = {5.0, 2.0};

static const CGFloat kDotDiameter = 4.0;
static const CGFloat kDotRadius = 2.0;

static const CGFloat kWideEndInset = 30.0;
static const CGFloat kFewPointEndFraction = 5.0;

static const CGFloat kLabelFontSize = 10.0;
static const CGFloat kLabelWidth = 20.0;
static const CGFloat kLabelHeight = 10.0;
static const CGFloat kTopLabelY = 10.0;
static const CGFloat kBottomLabelInset = 20.0;

static const CGFloat kLabelColorComponent = 0.0;
static const CGFloat kLabelColorAlpha = 1.0;

static const CGFloat kVisibleAlpha = 1.0;

// Cached copy of the cross-file palette global g_dTranslucentAlpha (near 0x1002ee6a0).
static const CGFloat kTranslucentAlpha = 0.8;

static const NSUInteger kSinglePointCount = 1;
static const NSUInteger kFewPointLowerCount = 2;
static const NSUInteger kFewPointUpperCount = 3;

static const double kSnapTolerance = 0.001;
static const float kMinLineSnapThresholds[] = {
    0.0f, 25.0f, 50.0f, 60.0f, 70.0f, 80.0f, 90.0f, 95.0f, 100.0f};

@implementation GraphView

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
    maxLabel.textColor = [UIColor colorWithRed:kLabelColorComponent
                                         green:kLabelColorComponent
                                          blue:kLabelColorComponent
                                         alpha:kLabelColorAlpha];
    maxLabel.textAlignment = NSTextAlignmentRight;
    [self addSubview:maxLabel];

    UILabel *minLabel =
        [[UILabel alloc] initWithFrame:CGRectMake(0,
                                                  self.frame.size.height - kBottomLabelInset,
                                                  kLabelWidth,
                                                  kLabelHeight)];
    minLabel.font = [UIFont systemFontOfSize:kLabelFontSize];
    minLabel.text = [NSString stringWithFormat:@"%d", (int)self.minValue];
    minLabel.textColor = [UIColor colorWithRed:kLabelColorComponent
                                         green:kLabelColorComponent
                                          blue:kLabelColorComponent
                                         alpha:kLabelColorAlpha];
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
