#import "ApplilinkIndicator.h"

#import "engineglobals.h"

static const CGFloat kOverlayAlpha = 0.5;
static const CGFloat kCenterFactor = 0.5;

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
        [self.indicator setCenter:CGPointMake(self.bounds.size.width * kCenterFactor,
                                              self.bounds.size.height * kCenterFactor)];
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
