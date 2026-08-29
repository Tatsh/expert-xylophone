#import "ShadeView.h"

#import <UIKit/UIKit.h>

// The binary reuses the shared literal Ghidra labels g_dMascotMessageAnimDuration @0x2eedc0 here.
static const CGFloat kShadeBackdropGray = 0.2;

static const CGFloat kShadeBackdropAlpha = 0.8;

@implementation ShadeView

/** @ghidraAddress 0x22b498 */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.userInteractionEnabled = YES;
        self.backgroundColor = [UIColor colorWithRed:kShadeBackdropGray
                                               green:kShadeBackdropGray
                                                blue:kShadeBackdropGray
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
