#import "RBCreditsView.h"

#import "RBUserSettingData.h"
#import "UIImage+RB.h"

static NSString *const kCreditsTextImageName = @"07_credits/cre_text";

static const CGFloat kNonClassicThemeTopOffset = 32.0;

@implementation RBCreditsView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setMusicMenuPopupViewType:RBMusicMenuPopupViewTypeCredits];
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
