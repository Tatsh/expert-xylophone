//
//  RBCreditsView.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RBCreditsView). Verified against
//  the arm64 disassembly: -setupView's centring and frame maths were recovered from the soft-float
//  register moves that the decompiler folds into pseudo-variables.
//

#import "RBCreditsView.h"

#import "RBUserSettingData.h"
#import "UIImage+RB.h"

// The credits variant of the music-menu popup passed to -setMusicMenuPopupViewType:.
static const NSInteger kMusicMenuPopupViewTypeCredits = 3;

// The credits-text artwork laid out in the popup content view.
static NSString *const kCreditsTextImageName = @"07_credits/cre_text";

// The vertical offset applied to the credits text below the top of the content view for every
// theme other than Classic.
static const CGFloat kNonClassicThemeTopOffset = 32.0;

@implementation RBCreditsView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setMusicMenuPopupViewType:kMusicMenuPopupViewTypeCredits];
        [self setupView];
    }
    return self;
}

- (void)setupView {
    [super setupView];

    CGFloat topOffset = 0.0;
    if ([RBUserSettingData sharedInstance].thema != RBUserSettingDataThemeClassic) {
        topOffset = kNonClassicThemeTopOffset;
    }

    UIImageView *creditsText =
        [[UIImageView alloc] initWithImage:[UIImage imageWithName:kCreditsTextImageName]];
    CGFloat contentWidth = self.contentView.bounds.size.width;
    CGFloat contentHeight = self.contentView.bounds.size.height;
    creditsText.center =
        CGPointMake(contentWidth * 0.5, topOffset + (contentHeight - topOffset) * 0.5);
    creditsText.autoresizingMask =
        UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth |
        UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin |
        UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;
    [self.contentView addSubview:creditsText];

    CGRect frame = creditsText.frame;
    creditsText.frame = CGRectMake((CGFloat)(int)frame.origin.x,
                                   (CGFloat)(int)frame.origin.y,
                                   frame.size.width,
                                   frame.size.height);
}

@end
