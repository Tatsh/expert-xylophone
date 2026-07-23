//
//  RBMenuPageSliderView.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RBMenuPageSliderView). The popup
//  wrapper that embeds an RBMenuPageSlider; the show and reposition soft-float geometry was recovered
//  from the arm64 disassembly (the decompiler folds the CGRect components into pseudo-variables).
//

#import "RBMenuPageSliderView.h"

#import "RBMenuPageSlider.h"
#import "RBPopupView.h"

// The base, content, and wrapper views resize with a flexible width and a flexible top margin so the
// slider stays pinned to the bottom edge as the layout changes (the binary's 0x12 mask).
static const UIViewAutoresizing kSliderAutoresizingMask =
    UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;

// The duration of the post-rotation fade that restores the slider to full opacity. This is the
// shared 0.3 second animation duration used across the menu views (0x1002ec718).
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
