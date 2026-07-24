//
//  ApplilinkIndicator.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class ApplilinkIndicator). Verified
//  against the arm64 disassembly: the soft-float indicator frame in -initWithFrame: (an 80x80 square
//  at the origin) and half-opacity alpha, and the bounds-centre computation in -layoutSubviews were
//  recovered from the register moves the decompiler folds into pseudo-variables. This is a plain
//  Objective-C file because the class subclasses UIView and only sends ordinary UIKit messages,
//  with no C++.
//

#import "ApplilinkIndicator.h"

// The activity indicator is an 80x80 square, sharing the shared eighty-point layout metric.
extern const double g_dLayoutMetricEighty; // @ghidraAddress 0x2ec6c8 (80.0)

// The overlay dims its black background to half opacity, and each bounds axis is halved to centre
// the spinner.
static const CGFloat kOverlayAlpha = 0.5;
static const CGFloat kCentreFactor = 0.5;

@implementation ApplilinkIndicator

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.indicator = [[UIActivityIndicatorView alloc]
            initWithFrame:CGRectMake(0, 0, g_dLayoutMetricEighty, g_dLayoutMetricEighty)];
        [self.indicator setActivityIndicatorViewStyle:UIActivityIndicatorViewStyleWhiteLarge];
        self.backgroundColor = UIColor.blackColor;
        self.alpha = kOverlayAlpha;
        [self addSubview:self.indicator];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if (self.indicator) {
        [self.indicator setCenter:CGPointMake(self.bounds.size.width * kCentreFactor,
                                              self.bounds.size.height * kCentreFactor)];
    }
}

- (void)show {
    self.hidden = NO;
    if (self.indicator) {
        [self.indicator startAnimating];
    }
}

- (void)close {
    self.hidden = YES;
    if (self.indicator) {
        [self.indicator stopAnimating];
        self.indicator = nil;
    }
}

- (void)touchEventActived {
    self.backgroundColor = UIColor.clearColor;
    self.userInteractionEnabled = NO;
}

- (void)dealloc {
}

@end
