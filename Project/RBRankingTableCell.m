//
//  RBRankingTableCell.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RBRankingTableCell). The
//  -initWithStyle:reuseIdentifier: label geometry and fonts and the -drawRect: CoreGraphics path
//  geometry were recovered from the arm64 disassembly, where the decompiler folds the soft-float
//  register moves and scrambles the CoreGraphics argument order. This class uses only Objective-C,
//  CoreGraphics, and the C iPad idiom helper, so it is a plain Objective-C (.m) file.
//

#import "RBRankingTableCell.h"

#import <CoreGraphics/CoreGraphics.h>
#import <UIKit/UIKit.h>

#import "neEngineBridge.h"

#pragma mark - Label geometry

// The rank column occupies the left of the row; its origin, width, and height differ by device.
static const CGFloat kRankLabelXPad = 5.0;
static const CGFloat kRankLabelXPhone = 18.0;
static const CGFloat kRankLabelYPad = 6.0;
static const CGFloat kRankLabelYPhone = 5.0;
static const CGFloat kRankLabelWidthPad = 55.0;
static const CGFloat kRankLabelWidthPhone = 42.0;
static const CGFloat kRankLabelHeight = 20.0;
static const CGFloat kRankFontSizePad = 18.0;
static const CGFloat kRankFontSizePhone = 15.0;
static const CGFloat kRankMinScalePad = 8.0;
static const CGFloat kRankMinScalePhone = 7.0;

// The name column sits in the middle of the row.
static const CGFloat kNameLabelXPad = 80.0;
static const CGFloat kNameLabelXPhone = 70.0;
static const CGFloat kNameLabelYPad = 5.0;
static const CGFloat kNameLabelYPhone = 4.0;
static const CGFloat kNameLabelWidthPad = 250.0;
static const CGFloat kNameLabelWidthPhone = 118.0;
static const CGFloat kNameLabelHeightPad = 24.0;
static const CGFloat kNameLabelHeightPhone = 22.0;
static const CGFloat kNameFontSizePad = 18.0;
static const CGFloat kNameFontSizePhone = 16.0;
static const CGFloat kNameMinScalePad = 18.0;
static const CGFloat kNameMinScalePhone = 13.0;

// The score column is right-aligned, anchored to the row's trailing edge by a negative inset from
// the cell width and left-margin autoresizing.
static const CGFloat kScoreLabelXInsetPad = -160.0;
static const CGFloat kScoreLabelXInsetPhone = -112.0;
static const CGFloat kScoreLabelYPad = 6.0;
static const CGFloat kScoreLabelYPhone = 5.0;
static const CGFloat kScoreLabelWidthPad = 130.0;
static const CGFloat kScoreLabelWidthPhone = 93.0;
static const CGFloat kScoreLabelHeight = 20.0;
static const CGFloat kScoreFontSizePad = 16.0;
static const CGFloat kScoreFontSizePhone = 13.0;

#pragma mark - Background geometry

// The x of the divider between the name and score columns, differing by device.
static const CGFloat kColumnDividerXPad = 66.0;
static const CGFloat kColumnDividerXPhone = 61.0;

// The outline stroke is one point wide; corners are rounded to this radius on the top or bottom
// row. The stroked path is inset half a point from the row edges so the one-point line stays crisp.
static const CGFloat kStrokeLineWidth = 1.0;
static const CGFloat kCornerRadius = 6.0;
static const CGFloat kEdgeInset = 0.5;

// Half-scale factor used to take the row's horizontal and vertical midpoints.
static const CGFloat kHalfScale = 0.5;

@implementation RBRankingTableCell {
    // Whether the cell draws with the wider iPad geometry and fonts, captured from the iPad idiom
    // flag at construction. It is not a property; the binary keeps only this backing ivar and reads
    // it directly.
    BOOL isPad;
}

#pragma mark - Lifecycle

- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        isPad = IsPad();

        // The rank label: bold, centred, auto-shrinking to fit.
        CGRect rankFrame =
            isPad ?
                CGRectMake(kRankLabelXPad, kRankLabelYPad, kRankLabelWidthPad, kRankLabelHeight) :
                CGRectMake(
                    kRankLabelXPhone, kRankLabelYPhone, kRankLabelWidthPhone, kRankLabelHeight);
        self.labelRank = [[UILabel alloc] initWithFrame:rankFrame];
        self.labelRank.backgroundColor = [UIColor clearColor];
        self.labelRank.textColor = [UIColor whiteColor];
        self.labelRank.font =
            [UIFont boldSystemFontOfSize:isPad ? kRankFontSizePad : kRankFontSizePhone];
        self.labelRank.adjustsFontSizeToFitWidth = YES;
        self.labelRank.minimumScaleFactor = isPad ? kRankMinScalePad : kRankMinScalePhone;
        self.labelRank.textAlignment = NSTextAlignmentCenter;
        self.labelRank.baselineAdjustment = UIBaselineAdjustmentAlignCenters;

        // The name label: bold, left-aligned, truncating its tail.
        CGRect nameFrame =
            isPad ? CGRectMake(
                        kNameLabelXPad, kNameLabelYPad, kNameLabelWidthPad, kNameLabelHeightPad) :
                    CGRectMake(kNameLabelXPhone,
                               kNameLabelYPhone,
                               kNameLabelWidthPhone,
                               kNameLabelHeightPhone);
        self.labelName = [[UILabel alloc] initWithFrame:nameFrame];
        self.labelName.backgroundColor = [UIColor clearColor];
        self.labelName.textColor = [UIColor whiteColor];
        self.labelName.font =
            [UIFont boldSystemFontOfSize:isPad ? kNameFontSizePad : kNameFontSizePhone];
        self.labelName.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
        self.labelName.adjustsFontSizeToFitWidth = YES;
        self.labelName.minimumScaleFactor = isPad ? kNameMinScalePad : kNameMinScalePhone;
        self.labelName.lineBreakMode = NSLineBreakByTruncatingTail;

        // The score label: right-aligned against the row's trailing edge.
        CGFloat scoreX =
            self.frame.size.width + (isPad ? kScoreLabelXInsetPad : kScoreLabelXInsetPhone);
        CGRect scoreFrame =
            isPad ? CGRectMake(scoreX, kScoreLabelYPad, kScoreLabelWidthPad, kScoreLabelHeight) :
                    CGRectMake(scoreX, kScoreLabelYPhone, kScoreLabelWidthPhone, kScoreLabelHeight);
        self.labelScore = [[UILabel alloc] initWithFrame:scoreFrame];
        self.labelScore.backgroundColor = [UIColor clearColor];
        self.labelScore.textColor = [UIColor whiteColor];
        self.labelScore.font =
            [UIFont systemFontOfSize:isPad ? kScoreFontSizePad : kScoreFontSizePhone];
        self.labelScore.textAlignment = NSTextAlignmentRight;
        self.labelScore.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
        self.labelScore.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;

        [self addSubview:self.labelRank];
        [self addSubview:self.labelName];
        [self addSubview:self.labelScore];

        self.fillColor = [UIColor whiteColor];
        self.strokeColor = [UIColor whiteColor];
    }
    return self;
}

- (void)dealloc {
    // The base cell's teardown runs through super.
}

#pragma mark - Drawing

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    BOOL drawIsPad = isPad; // Yes, the binary re-reads the ivar even though it is fixed at init.
    CGFloat width = CGRectGetWidth(rect);
    CGFloat height = CGRectGetHeight(rect);

    CGContextSetLineWidth(context, kStrokeLineWidth);
    CGContextSetStrokeColorWithColor(context, self.strokeColor.CGColor);

    CGFloat dividerX = drawIsPad ? kColumnDividerXPad : kColumnDividerXPhone;
    CGFloat midY = height * kHalfScale;

    // Three paths: the outline is stroked, the middle (name) and right (score) columns are filled.
    CGMutablePathRef outlinePath = CGPathCreateMutable();
    CGMutablePathRef namePath = CGPathCreateMutable();
    CGMutablePathRef scorePath = CGPathCreateMutable();

    CGPathMoveToPoint(outlinePath, NULL, 0, midY);
    CGPathMoveToPoint(namePath, NULL, 0, midY);
    CGPathMoveToPoint(scorePath, NULL, dividerX, midY);

    if (self.isTop) {
        CGFloat midX = width * kHalfScale;
        CGPathAddArcToPoint(outlinePath, NULL, 0, kEdgeInset, midX, kEdgeInset, kCornerRadius);
        CGPathAddArcToPoint(outlinePath, NULL, width, kEdgeInset, width, midY, kCornerRadius);
        CGPathAddArcToPoint(namePath, NULL, 0, kEdgeInset, dividerX, kEdgeInset, kCornerRadius);
        CGPathAddLineToPoint(namePath, NULL, dividerX, kEdgeInset);
        CGPathAddLineToPoint(namePath, NULL, dividerX, midY);
        CGPathAddLineToPoint(scorePath, NULL, dividerX, kEdgeInset);
        CGPathAddArcToPoint(scorePath, NULL, width, kEdgeInset, width, midY, kCornerRadius);
    } else {
        CGPathAddLineToPoint(outlinePath, NULL, 0, 0);
        CGPathAddLineToPoint(outlinePath, NULL, width, 0);
        CGPathAddLineToPoint(outlinePath, NULL, width, midY);
        CGPathAddLineToPoint(namePath, NULL, 0, 0);
        CGPathAddLineToPoint(namePath, NULL, dividerX, 0);
        CGPathAddLineToPoint(namePath, NULL, dividerX, midY);
        CGPathAddLineToPoint(scorePath, NULL, dividerX, 0);
        CGPathAddLineToPoint(scorePath, NULL, width, 0);
        CGPathAddLineToPoint(scorePath, NULL, width, midY);
    }

    CGFloat bottomY = height - kEdgeInset;
    if (self.isLast) {
        CGFloat midX = width * kHalfScale;
        CGPathAddArcToPoint(outlinePath, NULL, width, bottomY, midX, bottomY, kCornerRadius);
        CGPathAddArcToPoint(outlinePath, NULL, 0, bottomY, 0, midY, kCornerRadius);
        CGPathAddLineToPoint(outlinePath, NULL, 0, midY);
        CGPathAddLineToPoint(namePath, NULL, dividerX, bottomY);
        CGPathAddArcToPoint(namePath, NULL, 0, bottomY, 0, midY, kCornerRadius);
        CGPathAddLineToPoint(namePath, NULL, 0, midY);
        CGPathAddArcToPoint(scorePath, NULL, width, bottomY, dividerX, bottomY, kCornerRadius);
        CGPathAddLineToPoint(scorePath, NULL, dividerX, bottomY);
        CGPathAddLineToPoint(scorePath, NULL, dividerX, midY);
    } else {
        CGPathAddLineToPoint(outlinePath, NULL, width, height);
        CGPathAddLineToPoint(outlinePath, NULL, 0, height);
        CGPathAddLineToPoint(outlinePath, NULL, 0, midY);
        CGPathAddLineToPoint(namePath, NULL, dividerX, height);
        CGPathAddLineToPoint(namePath, NULL, 0, height);
        CGPathAddLineToPoint(namePath, NULL, 0, midY);
        CGPathAddLineToPoint(scorePath, NULL, width, height);
        CGPathAddLineToPoint(scorePath, NULL, dividerX, height);
        CGPathAddLineToPoint(scorePath, NULL, dividerX, midY);
    }

    // The divider line down the middle of the outline path, from the top-edge inset to the bottom.
    CGPathMoveToPoint(outlinePath, NULL, dividerX, kEdgeInset);
    CGPathAddLineToPoint(outlinePath, NULL, dividerX, bottomY);

    CGPathCloseSubpath(outlinePath);
    CGPathCloseSubpath(namePath);
    CGPathCloseSubpath(scorePath);

    CGContextSetFillColorWithColor(context, self.fillColor.CGColor);
    CGContextBeginPath(context);
    CGContextAddPath(context, namePath);
    CGContextFillPath(context);

    CGContextSetFillColorWithColor(context, self.fillColor.CGColor);
    CGContextBeginPath(context);
    CGContextAddPath(context, scorePath);
    CGContextFillPath(context);

    CGContextBeginPath(context);
    CGContextAddPath(context, outlinePath);
    CGContextStrokePath(context);

    CGPathRelease(outlinePath);
    CGPathRelease(namePath);
    CGPathRelease(scorePath);

    [super drawRect:rect];
}

@end
