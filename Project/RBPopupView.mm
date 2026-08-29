#import "RBPopupView.h"

#import "engineglobals.h"
#import "soundeffectmanager.h"

constexpr NSTimeInterval kPopupAnimationDuration = 0.25;

constexpr int kSoundEffectCancel = 4;

constexpr UIViewAutoresizing kAutoresizingFull =
    UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth |
    UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin |
    UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;

@implementation RBPopupView

#pragma mark - Lifecycle

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // @ghidraAddress 0x3cff88
        self.backgroundColor = g_pPaletteDimmingCoverColor;
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
