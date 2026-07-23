//
//  RBPopupView.mm
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RBPopupView). Verified against the
//  arm64 disassembly: the animation duration and the autoresizing and control-event masks were read
//  from the immediate register moves the decompiler folds away. This is an Objective-C++ file
//  because -hideAnimation reaches the C++ SoundEffectManager engine singleton.
//

#import "RBPopupView.h"

#import "neEngineBridge.h"

// The popup fades over a quarter second.
constexpr NSTimeInterval kPopupAnimationDuration = 0.25;

// The themed sound-effect slot played when the popup is dismissed.
constexpr int kSoundEffectCancel = 4;

// The control fills its superview and follows it as it resizes.
constexpr UIViewAutoresizing kAutoresizingFull =
    UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth |
    UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin |
    UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;

@implementation RBPopupView

#pragma mark - Lifecycle

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setBackgroundColor:nil];
        self.autoresizingMask = kAutoresizingFull;
        [self addTarget:self action:@selector(tap:) forControlEvents:UIControlEventTouchUpInside];
    }
    return self;
}

#pragma mark - Animation

- (void)showAnimation {
    if (self.animating) {
        return;
    }
    self.animating = YES;
    __weak RBPopupView *weakSelf = self;
    [UIView animateWithDuration:kPopupAnimationDuration
        animations:^{
          /** @ghidraAddress 0x19b9fc */
          weakSelf.alpha = 1.0;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x19ba20 */
          weakSelf.alpha = 1.0;
          weakSelf.animating = NO;
        }];
}

- (void)hideAnimation {
    if (self.animating) {
        return;
    }
    SoundEffectManager::GetInstance()->PlayThemedSoundEffect(kSoundEffectCancel);
    self.animating = YES;
    __weak RBPopupView *weakSelf = self;
    [UIView animateWithDuration:kPopupAnimationDuration
        animations:^{
          /** @ghidraAddress 0x19bb7c */
          weakSelf.alpha = 0.0;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x19bba0 */
          weakSelf.alpha = 0.0;
          [weakSelf removeFromSuperview];
          weakSelf.animating = NO;
        }];
}

- (void)tap:(id)sender {
    [self hideAnimation];
}

@end
