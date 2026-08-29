#import "RBMusicFirstInfoView.h"

#import "UIImage+RB.h"
#import "UIImageView+RB.h"
#import "deviceenvironment.h"
#import "engineglobals.h"

static const CGFloat kOverlayAlphaHidden = 0.0;
static const CGFloat kOverlayAlphaVisible = 1.0;
static const CGFloat kOverlayBackgroundWhite = 0.0;
static const CGFloat kOverlayBackgroundAlpha = 0.699999988; // @0x2ec750

static const UIViewAutoresizing kOverlayAutoresizingMask =
    UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth |
    UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin |
    UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;

static const UIViewAutoresizing kCloseButtonAutoresizingMask =
    UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin;

static const UIViewAutoresizing kCenteredImageAutoresizingMask =
    UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
    UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;

static const UIViewAutoresizing kInfo1AutoresizingMask =
    UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin;

static NSString *const kImageInfoDone = @"11_info/info_done";
static NSString *const kImageInfoDoneEff = @"11_info/info_done_eff";
static NSString *const kImageInfoMusic = @"11_info/info_music";
static NSString *const kImageInfo2 = @"11_info/info_2";
static NSString *const kImageInfo1 = @"11_info/info_1";

static const CGFloat kHalf = 0.5;

static const CGFloat kCloseButtonInsetX = 5.0;
static const CGFloat kCloseButtonPhoneY = 6.0;

static const CGFloat kCloseButtonPadX = 552.0; // @0x301228
static const CGFloat kCloseButtonPadY = 12.0;

static const CGFloat kMusicImagePadX = 18.0;
static const CGFloat kMusicImagePadY = 90.0; // @0x2ee9a0

static const CGFloat kInfo2CenterX = 30.0;
static const CGFloat kInfo2CenterY = 204.0; // @0x301218

static const CGFloat kInfo1CenterX = 90.0;        // @0x2ee9a0
static const CGFloat kInfo1CenterYOffset = -44.0; // @0x301220, added to the view height

static const NSTimeInterval kShowFadeDuration = 0.5;
static const NSTimeInterval kShowFadeDelay = 0.75;

@interface RBMusicFirstInfoView () {
    BOOL m_IsAnimation; // +0x8
}
@end

@implementation RBMusicFirstInfoView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self SetupView];
    }
    return self;
}

- (void)SetupView {
    self.alpha = kOverlayAlphaHidden;
    self.autoresizingMask = kOverlayAutoresizingMask;
    self.backgroundColor = [UIColor colorWithWhite:kOverlayBackgroundWhite
                                             alpha:kOverlayBackgroundAlpha];

    // The close button targets @c selectExit (registered at 0xc9558 and 0xc97b4), which no class
    // in __objc_classlist implements; a category may supply it.
    UIImage *doneImage = [UIImage imageWithName:kImageInfoDone];
    CGSize doneSize = doneImage.size;
    UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeCustom];

    if (!IsPad()) {
        CGRect bounds = self.bounds;
        closeButton.frame = CGRectMake(bounds.size.width - kCloseButtonInsetX - doneSize.width,
                                       kCloseButtonPhoneY,
                                       doneSize.width,
                                       doneSize.height);
        [closeButton setImage:doneImage forState:UIControlStateNormal];
        closeButton.exclusiveTouch = YES;
        [closeButton addTarget:self
                        action:@selector(selectExit)
              forControlEvents:UIControlEventTouchUpInside];
        closeButton.autoresizingMask = kCloseButtonAutoresizingMask;
        [self addSubview:closeButton];

        UIImage *effImage = [UIImage imageWithName:kImageInfoDoneEff];
        UIImageView *effView = [[UIImageView alloc] initWithImage:effImage];
        CGRect buttonBounds = closeButton.bounds;
        effView.center =
            CGPointMake(buttonBounds.size.width * kHalf, buttonBounds.size.height * kHalf);
        [closeButton addSubview:effView];
        [effView SetFlashEffectFast];

        UIImage *musicImage = [UIImage imageWithName:kImageInfoMusic];
        UIImageView *musicView = [[UIImageView alloc] initWithImage:musicImage];
        CGRect selfBounds = self.bounds;
        musicView.center =
            CGPointMake(selfBounds.size.width * kHalf, selfBounds.size.height * kHalf);
        musicView.autoresizingMask = kCenteredImageAutoresizingMask;
        [self addSubview:musicView];

        UIImage *info2Image = [UIImage imageWithName:kImageInfo2];
        UIImageView *info2View = [[UIImageView alloc] initWithImage:info2Image];
        info2View.center = CGPointMake(kInfo2CenterX, kInfo2CenterY);
        info2View.autoresizingMask = kCenteredImageAutoresizingMask;
        [musicView addSubview:info2View];

        UIImage *info1Image = [UIImage imageWithName:kImageInfo1];
        UIImageView *info1View = [[UIImageView alloc] initWithImage:info1Image];
        CGRect info1Bounds = self.bounds;
        info1View.center =
            CGPointMake(kInfo1CenterX, info1Bounds.size.height + kInfo1CenterYOffset);
        info1View.autoresizingMask = kInfo1AutoresizingMask;
        [self addSubview:info1View];
    } else {
        closeButton.frame =
            CGRectMake(kCloseButtonPadX, kCloseButtonPadY, doneSize.width, doneSize.height);
        [closeButton setImage:doneImage forState:UIControlStateNormal];
        closeButton.exclusiveTouch = YES;
        [closeButton addTarget:self
                        action:@selector(selectExit)
              forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:closeButton];

        UIImage *effImage = [UIImage imageWithName:kImageInfoDoneEff];
        UIImageView *effView = [[UIImageView alloc] initWithImage:effImage];
        CGRect buttonBounds = closeButton.bounds;
        effView.center =
            CGPointMake(buttonBounds.size.width * kHalf, buttonBounds.size.height * kHalf);
        [closeButton addSubview:effView];
        [effView SetFlashEffectFast];

        UIImage *musicImage = [UIImage imageWithName:kImageInfoMusic];
        UIImageView *musicView = [[UIImageView alloc] initWithImage:musicImage];
        CGSize musicSize = musicView.frame.size;
        musicView.frame =
            CGRectMake(kMusicImagePadX, kMusicImagePadY, musicSize.width, musicSize.height);
        [self addSubview:musicView];
    }

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                          action:@selector(tap:)];
    [self addGestureRecognizer:tap];
}

- (void)tap:(UITapGestureRecognizer *)tap {
    [self hideAnimation];
}

- (void)showAnimation {
    if (m_IsAnimation) {
        return;
    }
    m_IsAnimation = YES;
    __weak RBMusicFirstInfoView *weakSelf0 = self;
    __weak RBMusicFirstInfoView *weakSelf1 = self;
    [UIView animateWithDuration:kShowFadeDuration
        delay:kShowFadeDelay
        options:UIViewAnimationOptionLayoutSubviews
        animations:^{
          /** @ghidraAddress 0xc9d04 (ShowCapturedViewAlpha3BlockInvoke) */
          weakSelf0.alpha = kOverlayAlphaVisible;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0xc9d28 (ShowFirstInfoViewBlockInvoke) */
          RBMusicFirstInfoView *strongSelf = weakSelf1;
          strongSelf.alpha = kOverlayAlphaVisible;
          strongSelf->m_IsAnimation = NO;
        }];
}

- (void)hideAnimation {
    if (m_IsAnimation) {
        return;
    }
    m_IsAnimation = YES;
    __weak RBMusicFirstInfoView *weakSelf0 = self;
    __weak RBMusicFirstInfoView *weakSelf1 = self;
    [UIView animateWithDuration:g_dAudioManagerResumeFadeInTime
        animations:^{
          /** @ghidraAddress 0xc9e68 (HideFirstInfoViewAlphaBlockInvoke) */
          weakSelf0.alpha = kOverlayAlphaHidden;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0xc9e8c (HideAndRemoveFirstInfoViewBlockInvoke) */
          RBMusicFirstInfoView *strongSelf = weakSelf1;
          strongSelf.alpha = kOverlayAlphaHidden;
          strongSelf->m_IsAnimation = NO;
          [strongSelf removeFromSuperview];
        }];
}

@end
