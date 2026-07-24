//
//  RBMenuButton.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RBMenuButton). Verified against the
//  arm64 disassembly: -setupView:'s bounds sizing, the resizable-image cap insets, and the per-type
//  image-name table were recovered from the soft-float register moves and the [type * 5] table index
//  that the decompiler folds into pseudo-variables.
//

#import "RBMenuButton.h"

#import "RBUserSettingData.h"
#import "UIImage+RB.h"
#import "UIImageView+RB.h"
#import "deviceenvironment.h"

// The inner button's bounds, chosen by the active iPad idiom. The wide variant uses a larger
// button to fit the wider glyphs.
static const CGFloat kMenuButtonWidthNarrow = 30.0;
static const CGFloat kMenuButtonHeightNarrow = 42.0;
static const CGFloat kMenuButtonWidthWide = 92.0;
static const CGFloat kMenuButtonHeightWide = 72.0;

// The theme index below which the button always uses the narrow artwork regardless of iPad idiom.
static const NSInteger kMenuButtonWideArtworkTheme = 2;

// The autoresizing mask applied to the button and its flash background: flexible right and bottom
// margins so the button stays pinned to the top-left of the footer cell.
static const UIViewAutoresizing kMenuButtonAutoresizingMask =
    UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;

// The autoresizing mask applied to the flash icon overlay, which additionally keeps flexible width
// and height so it scales with the button.
static const UIViewAutoresizing kMenuButtonEffectTextAutoresizingMask =
    UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleWidth |
    UIViewAutoresizingFlexibleBottomMargin;

// The cap-inset inset applied when stretching the background and flash images: the resizable region
// is a single centre pixel, so the caps are half the image size less one pixel.
static const CGFloat kMenuButtonCapInsetMargin = 1.0;

// The number of image-name slots per button type in the setup table. Only the first four are used;
// the fifth is a shared fallback image name.
static const NSUInteger kMenuButtonImageNamesPerType = 4;

// The background, icon, flash-background, and flash-icon image names for each RBMenuButtonType, in
// type order. The playlist add and delete buttons share the add/delete background and the settings
// flash background; the finish button shares the store flash background.
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

// The slot index within a type's image-name row.
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
    background = [background
        resizableImageWithCapInsets:UIEdgeInsetsMake(
                                        0.0,
                                        background.size.width * 0.5 - kMenuButtonCapInsetMargin,
                                        0.0,
                                        background.size.height * 0.5 - kMenuButtonCapInsetMargin)];
    [self.button setBackgroundImage:background forState:UIControlStateNormal];
    self.button.frame = self.bounds;
    self.button.autoresizingMask = kMenuButtonAutoresizingMask;

    UIImage *icon = [UIImage imageWithName:imageNames[kMenuButtonImageIcon]];
    [self.button setImage:icon forState:UIControlStateNormal];

    UIImage *flashBackground = [UIImage imageWithName:imageNames[kMenuButtonImageFlashBackground]];
    flashBackground = [flashBackground
        resizableImageWithCapInsets:UIEdgeInsetsMake(0.0,
                                                     flashBackground.size.width * 0.5 -
                                                         kMenuButtonCapInsetMargin,
                                                     0.0,
                                                     flashBackground.size.height * 0.5 -
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
