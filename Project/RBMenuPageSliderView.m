#import "RBMenuPageSliderView.h"

#import "RBMenuPageSlider.h"
#import "RBPopupView.h"

static const UIViewAutoresizing kSliderAutoresizingMask =
    UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;

// The shared menu-view animation duration.
// @ghidraAddress 0x2ec718
static const NSTimeInterval kSliderRotationFadeDuration = 0.3;

@implementation RBMenuPageSliderView

- (instancetype)initWithFrame:(CGRect)frame delegate:(id<RBMenuPageSliderDelegate>)delegate {
    self = [super initWithFrame:frame];
    if (self) {
        [self setAnimating:NO];
        self.autoresizingMask = kSliderAutoresizingMask;
        self.baseView.autoresizingMask = kSliderAutoresizingMask;
        self.contentView.autoresizingMask = kSliderAutoresizingMask;

        RBMenuPageSlider *slider = [[RBMenuPageSlider alloc] initWithFrame:frame delegate:delegate];
        self.slider = slider;
        [self addSubview:slider];
    }
    return self;
}

- (void)showView:(CGRect)frame pageMax:(NSUInteger)pageMax currentPage:(NSUInteger)currentPage {
    [self.slider reset:pageMax currentPage:currentPage];
    self.slider.frame = CGRectMake(self.slider.frame.origin.x,
                                   frame.origin.y + frame.size.height,
                                   self.slider.frame.size.width,
                                   self.slider.frame.size.height);
    [super showAnimation];
}

- (void)willRotate {
    self.slider.alpha = 0.0;
    [self setAnimating:YES];
}

- (void)reset:(NSUInteger)pageMax currentPage:(NSUInteger)currentPage {
    [self.slider reset:pageMax currentPage:currentPage];
}

- (void)hideAnimation {
    self.slider.delegate = nil;
    [super hideAnimation];
}

- (void)didRotate {
    [UIView animateWithDuration:kSliderRotationFadeDuration
        animations:^{
          /** @ghidraAddress 0x1c06c0 */
          self.slider.alpha = 1.0;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x1c072c */
          [self setAnimating:NO];
        }];
}

@end
