#import "RBMenuButton.h"

#import "RBUserSettingData.h"
#import "UIImage+RB.h"
#import "UIImageView+RB.h"
#import "deviceenvironment.h"

static const CGFloat kMenuButtonWidthNarrow = 30.0;
static const CGFloat kMenuButtonHeightNarrow = 42.0;
static const CGFloat kMenuButtonWidthWide = 92.0;
static const CGFloat kMenuButtonHeightWide = 72.0;

static const NSInteger kMenuButtonWideArtworkTheme = 2;

// The 0x12 mask the binary sets at 0x9dda0 and 0x9df9c.
static const UIViewAutoresizing kMenuButtonAutoresizingMask =
    UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

// The 0x2d mask the binary sets at 0x9e128.
static const UIViewAutoresizing kMenuButtonEffectTextAutoresizingMask =
    UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
    UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;

// An fmov immediate at 0x9dcb0, not a pool slot, so it carries no @ghidraAddress. Ghidra prints it
// as -0x4010000000000000, but the imm8 field 0xf0 decodes to -1.0, not -4.0.
static const CGFloat kMenuButtonCapInsetMargin = 1.0;

// Only the first four of the binary's five slots per type are used; the fifth is a fallback.
static const NSUInteger kMenuButtonImageNamesPerType = 4;

static NSString *const kMenuButtonImageNames[][kMenuButtonImageNamesPerType] = {
    {@"01_music_select/sel_b_set_1",
     @"01_music_select/sel_b_set_3",
     @"01_music_select/sel_b_set_eff_1",
     @"01_music_select/sel_b_set_eff_3"},
    {@"01_music_select/sel_b_rank_1",
     @"01_music_select/sel_b_rank_3",
     @"01_music_select/sel_b_rank_eff_1",
     @"01_music_select/sel_b_rank_eff_3"},
    {@"01_music_select/sel_b_stor_1",
     @"01_music_select/sel_b_stor_3",
     @"01_music_select/sel_b_stor_eff_1",
     @"01_music_select/sel_b_stor_eff_3"},
    {@"01_music_select/sel_b_add_del_1",
     @"01_music_select/sel_b_add_3",
     @"01_music_select/sel_b_set_eff_1",
     @"01_music_select/sel_b_add_eff_3"},
    {@"01_music_select/sel_b_add_del_1",
     @"01_music_select/sel_b_del_3",
     @"01_music_select/sel_b_set_eff_1",
     @"01_music_select/sel_b_del_eff_3"},
    {@"01_music_select/sel_b_fin_1",
     @"01_music_select/sel_b_fin_3",
     @"01_music_select/sel_b_stor_eff_1",
     @"01_music_select/sel_b_fin_eff_3"},
};

enum {
    kMenuButtonImageBackground = 0,
    kMenuButtonImageIcon = 1,
    kMenuButtonImageFlashBackground = 2,
    kMenuButtonImageFlashIcon = 3,
};

@implementation RBMenuButton

- (instancetype)initWithType:(RBMenuButtonType)type {
    self = [super init];
    if (self) {
        [self setupView:type];
    }
    return self;
}

- (void)setupView:(RBMenuButtonType)type {
    BOOL isPad = IsPad();
    CGFloat width = isPad ? kMenuButtonWidthWide : kMenuButtonWidthNarrow;
    CGFloat height = isPad ? kMenuButtonHeightWide : kMenuButtonHeightNarrow;
    self.bounds = CGRectMake(0.0, 0.0, width, height);

    self.button = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.button setExclusiveTouch:YES];
    [self addSubview:self.button];

    NSString *const *imageNames = kMenuButtonImageNames[type];

    // The binary selects the background image through the theme and iPad idiom, but every branch
    // resolves to the same name, so the outcome does not depend on either.
    NSString *backgroundName = imageNames[kMenuButtonImageBackground];
    UIImage *background = nil;
    if ([RBUserSettingData sharedInstance].thema < kMenuButtonWideArtworkTheme) {
        background = [UIImage imageWithName:backgroundName];
    } else if (!isPad) {
        background = [UIImage imageWithName:backgroundName];
    } else {
        background = [UIImage imageWithName:backgroundName];
    }
    // Both horizontal caps come from the width (0x9dc94 and 0x9dca4), never the height.
    background = [background
        resizableImageWithCapInsets:UIEdgeInsetsMake(
                                        0.0,
                                        background.size.width * 0.5 - kMenuButtonCapInsetMargin,
                                        0.0,
                                        background.size.width * 0.5 - kMenuButtonCapInsetMargin)];
    [self.button setBackgroundImage:background forState:UIControlStateNormal];
    self.button.frame = self.bounds;
    self.button.autoresizingMask = kMenuButtonAutoresizingMask;

    UIImage *icon = [UIImage imageWithName:imageNames[kMenuButtonImageIcon]];
    [self.button setImage:icon forState:UIControlStateNormal];

    UIImage *flashBackground = [UIImage imageWithName:imageNames[kMenuButtonImageFlashBackground]];
    // The same shape again at 0x9de70 and 0x9de7c: both caps from the width.
    flashBackground = [flashBackground
        resizableImageWithCapInsets:UIEdgeInsetsMake(0.0,
                                                     flashBackground.size.width * 0.5 -
                                                         kMenuButtonCapInsetMargin,
                                                     0.0,
                                                     flashBackground.size.width * 0.5 -
                                                         kMenuButtonCapInsetMargin)];
    self.effectImageView = [[UIImageView alloc] initWithImage:flashBackground];
    self.effectImageView.hidden = YES;
    self.effectImageView.frame = self.bounds;
    self.effectImageView.autoresizingMask = kMenuButtonAutoresizingMask;
    [self.button addSubview:self.effectImageView];

    UIImage *flashIcon = [UIImage imageWithName:imageNames[kMenuButtonImageFlashIcon]];
    self.effectTextImageView = [[UIImageView alloc] initWithImage:flashIcon];
    self.effectTextImageView.center = self.effectImageView.center;
    self.effectTextImageView.hidden = YES;
    self.effectTextImageView.autoresizingMask = kMenuButtonEffectTextAutoresizingMask;
    [self.button addSubview:self.effectTextImageView];
}

- (void)layoutSubviews {
    [super layoutSubviews];
}

- (void)setFlashEffect {
    self.effectImageView.hidden = NO;
    [self.effectImageView SetFlashEffectFast];
    self.effectTextImageView.hidden = NO;
    [self.effectTextImageView SetFlashEffectFast];
}

- (void)removeFlashEffect {
    self.effectImageView.hidden = YES;
    [self.effectImageView RemoveFlashEffect];
    self.effectTextImageView.hidden = YES;
    [self.effectTextImageView RemoveFlashEffect];
}

- (void)setEnabled:(BOOL)enabled {
    self.button.enabled = enabled;
}

@end
