//
//  RBMenuButton.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RBMenuButton). Verified against
//  the arm64 disassembly: -setupView:'s bounds sizing, the resizable-image cap insets, and the
//  per-type image-name table were recovered from the soft-float register moves and the [type * 5]
//  table index that the decompiler folds into pseudo-variables.
//

#import "RBMenuButton.h"

#import "RBUserSettingData.h"
#import "UIImage+RB.h"
#import "UIImageView+RB.h"
#import "deviceenvironment.h"
#import "neDebugLog.h"

// The inner button's bounds, chosen by the active iPad idiom. The wide variant uses a larger
// button to fit the wider glyphs.
static const CGFloat kMenuButtonWidthNarrow = 30.0;
static const CGFloat kMenuButtonHeightNarrow = 42.0;
static const CGFloat kMenuButtonWidthWide = 92.0;
static const CGFloat kMenuButtonHeightWide = 72.0;

// The theme index below which the button always uses the narrow artwork regardless of iPad idiom.
static const NSInteger kMenuButtonWideArtworkTheme = 2;

// The autoresizing mask applied to the button and its flash background: 0x12 at 0x9dda0 and
// 0x9df9c, which is flexible width and height, so both follow the container when the menu bar
// widens it from the 92 points set here to the width of a footer cell.
static const UIViewAutoresizing kMenuButtonAutoresizingMask =
    UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

// The autoresizing mask applied to the flash icon overlay: 0x2d at 0x9e128, which is all four
// flexible margins and no flexible size, so the overlay keeps its own size and stays centred while
// the margins absorb the change.
static const UIViewAutoresizing kMenuButtonEffectTextAutoresizingMask =
    UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
    UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;

// The cap-inset inset applied when stretching the background and flash images: the resizable region
// is a single centre pixel, so the caps are half the image size less one pixel.
// The fmov at 0x9dcb0 is an instruction immediate, not a pool slot, so it carries no
// @ghidraAddress: the audit tool would read the instruction bytes as a float. Its word is
// 0x1e7e100a, whose imm8 field (bits 20:13) is 0xf0, and VFPExpandImm(0xf0) is -1.0. Ghidra
// renders this one as -0x4010000000000000, which would be -4.0 and is wrong; it prints the
// positive immediates in this function correctly.
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
    // Both horizontal caps come from the WIDTH. The binary sends -size twice and takes d0, the
    // width, from each (0x9dc94 and 0x9dca4), so the left inset at 0x9dcb4 and the right at 0x9dcbc
    // are the same expression. Taking the right one from the height makes the two caps exceed the
    // image whenever it is taller than it is wide, which leaves an invalid resizable image that
    // draws as a flat block rather than a stretched button face.
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

    // RBPDBG: the side-menu buttons do not respond to taps. Record the container's frame and the
    // inner button's, since setting bounds rather than frame leaves the origin at minus half the
    // size and a container outside its parent is never hit-tested.
    if (NE_DBG_FIRST(6)) {
        // The buttons still draw as flat grey with no transparent border, which is what a nil
        // background image looks like, so record whether the art actually resolved and at what
        // size the caps were computed from.
        neDebugLog("menuButton type=%ld bg=%s bgSize=%.0fx%.0f icon=%s name=%s",
                   (long)type,
                   background ? "ok" : "NIL",
                   background.size.width,
                   background.size.height,
                   icon ? "ok" : "NIL",
                   backgroundName.UTF8String);
        neDebugLog("menuButton type=%ld self=(%.0f,%.0f %.0fx%.0f) button=(%.0f,%.0f %.0fx%.0f)",
                   (long)type,
                   self.frame.origin.x,
                   self.frame.origin.y,
                   self.frame.size.width,
                   self.frame.size.height,
                   self.button.frame.origin.x,
                   self.button.frame.origin.y,
                   self.button.frame.size.width,
                   self.button.frame.size.height);
    }

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
