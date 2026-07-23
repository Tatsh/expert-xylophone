//
//  ShadeView.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class ShadeView). This is a plain
//  Objective-C file: a small UIView subclass that reaches its delegate through an ordinary message
//  send, with no C++.
//

#import "ShadeView.h"

#import <UIKit/UIKit.h>

// The grey level applied to each of the backdrop's red, green, and blue components. The binary
// reuses a shared 0.2 double literal here (Ghidra labels it g_dMascotMessageAnimDuration @0x2eedc0).
static const CGFloat kShadeBackdropGrey = 0.2;

// The backdrop's alpha, leaving the screen dimmed but still faintly visible. The binary reuses a
// shared 0.8 double literal here (Ghidra labels it g_dTranslucentAlpha @0x2ec6a0).
static const CGFloat kShadeBackdropAlpha = 0.8;

@implementation ShadeView

/** @ghidraAddress 0x22b498 */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.userInteractionEnabled = YES;
        self.backgroundColor = [UIColor colorWithRed:kShadeBackdropGrey
                                               green:kShadeBackdropGrey
                                                blue:kShadeBackdropGrey
                                               alpha:kShadeBackdropAlpha];
    }
    return self;
}

/** @ghidraAddress 0x22b55c */
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    if (self.delegate && [self.delegate respondsToSelector:@selector(closeShadeView)]) {
        [self.delegate closeShadeView];
    }
}

@end
