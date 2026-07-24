//
//  RBSettingMenuButton.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RBSettingMenuButton). Verified
//  against the arm64 disassembly: -setupView:'s bounds sizing and resizable-image cap insets were
//  recovered from the soft-float register moves the decompiler folds into pseudo-variables, and the
//  per-menu-entry artwork names were read from the constant table at 0x10035a7e0 (five CFString
//  columns per entry). This is a plain Objective-C file: every method dispatches only to UIKit and
//  to the UIImageView(RB) flash-effect category, with no C++ engine calls.
//

#import "RBSettingMenuButton.h"

#import "RBUserSettingData.h"
#import "UIImage+RB.h"
#import "UIImageView+RB.h"
#import "deviceenvironment.h"

// Build the resizable-image cap insets for a themed asset (defined below).
static UIEdgeInsets CapInsetsForImage(UIImage *image);

// Per-menu-entry themed artwork, indexed by the filename argument. Each entry names four assets
// under 01_music_select: the inner button's background (_1) and foreground (_2) images, the
// effect-text overlay image (_eff), and the flashing effect image (_eff_1). These mirror the
// binary's five-column CFString table at 0x10035a7e0 (the unused fifth column is the shared plain
// sel_set_button background). Entry 4 (credits) is present for completeness; the settings overlay
// never builds it.
typedef struct SettingMenuArtwork {
    NSString *__unsafe_unretained backgroundImageName;
    NSString *__unsafe_unretained foregroundImageName;
    NSString *__unsafe_unretained effectTextImageName;
    NSString *__unsafe_unretained effectImageName;
} SettingMenuArtwork;

static const SettingMenuArtwork kSettingMenuArtwork[] = {
    {@"01_music_select/sel_set_how_1",
     @"01_music_select/sel_set_how_2",
     @"01_music_select/sel_set_how_eff",
     @"01_music_select/sel_set_how_eff_1"},
    {@"01_music_select/sel_set_cus_1",
     @"01_music_select/sel_set_cus_2",
     @"01_music_select/sel_set_cus_eff",
     @"01_music_select/sel_set_cus_eff_1"},
    {@"01_music_select/sel_set_the_1",
     @"01_music_select/sel_set_the_2",
     @"01_music_select/sel_set_the_eff",
     @"01_music_select/sel_set_the_eff_1"},
    {@"01_music_select/sel_set_sea_1",
     @"01_music_select/sel_set_sea_2",
     @"01_music_select/sel_set_sea_eff",
     @"01_music_select/sel_set_sea_eff_1"},
    {@"01_music_select/sel_set_cre_1",
     @"01_music_select/sel_set_cre_2",
     @"01_music_select/sel_set_cre_eff",
     @"01_music_select/sel_set_cre_eff_1"},
    {@"01_music_select/sel_set_info_1",
     @"01_music_select/sel_set_info_2",
     @"01_music_select/sel_set_info_eff",
     @"01_music_select/sel_set_info_eff_1"},
    {@"01_music_select/sel_set_applilink_1",
     @"01_music_select/sel_set_applilink_2",
     @"01_music_select/sel_set_applilink_eff",
     @"01_music_select/sel_set_applilink_eff_1"},
    {@"01_music_select/sel_set_tos_1",
     @"01_music_select/sel_set_tos_2",
     @"01_music_select/sel_set_tos_eff",
     @"01_music_select/sel_set_tos_eff_1"},
};

// The button bounds sized per theme and iPad idiom. The iPad (wide) layout (IsPad()
// non-zero) uses a 32-point-tall button for the Classic and Limelight themes and a 60-point-tall
// button for Colette; its width is 60 points (Classic, Limelight) or 192 points (Colette). The
// narrow iPad idiom uses a 22-point height and a 40-point width for every theme.
static const CGFloat kButtonHeightClassicLimelightWide = 32.0;
static const CGFloat kButtonHeightColetteWide = 60.0;
static const CGFloat kButtonHeightNarrow = 22.0;
static const CGFloat kButtonWidthClassicLimelightWide = 60.0;
static const CGFloat kButtonWidthColetteWide = 192.0;
static const CGFloat kButtonWidthNarrow = 40.0;

// The resizable-image cap insets keep a one-pixel border and stretch the rest, so the left and
// right insets are derived from half the source image's dimensions less one point.
static const CGFloat kCapInsetHalf = 0.5;
static const CGFloat kCapInsetBorder = 1.0;

// The autoresizing masks: the inner button and the flashing effect image stretch with the button
// and stay anchored to its top edge; the effect-text image keeps its size and floats centred.
static const UIViewAutoresizing kButtonAutoresizing =
    UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
static const UIViewAutoresizing kEffectTextAutoresizing =
    UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
    UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;

@implementation RBSettingMenuButton

#pragma mark Lifecycle

- (instancetype)initWithFilename:(NSInteger)filename {
    self = [super init];
    if (self) {
        [self setupView:filename];
    }
    return self;
}

#pragma mark Construction

- (void)setupView:(NSInteger)filename {
    BOOL isPad = IsPad();
    RBUserSettingDataTheme thema = [RBUserSettingData sharedInstance].thema;

    CGFloat width;
    CGFloat height;
    if (thema < RBUserSettingDataThemeColette) {
        height = kButtonHeightClassicLimelightWide;
        width = (isPad == 0) ? kButtonWidthNarrow : kButtonWidthClassicLimelightWide;
    } else {
        height = kButtonHeightColetteWide;
        width = (isPad == 0) ? kButtonWidthNarrow : kButtonWidthColetteWide;
    }
    if (isPad == 0) {
        height = kButtonHeightNarrow;
    }
    self.bounds = CGRectMake(0.0, 0.0, width, height);

    const SettingMenuArtwork artwork = kSettingMenuArtwork[filename];

    self.button = [UIButton buttonWithType:UIButtonTypeCustom];
    self.button.exclusiveTouch = YES;
    [self addSubview:self.button];

    UIImage *background = [UIImage imageWithName:artwork.backgroundImageName];
    [self.button
        setBackgroundImage:[background resizableImageWithCapInsets:CapInsetsForImage(background)]
                  forState:UIControlStateNormal];
    self.button.frame = self.bounds;
    self.button.autoresizingMask = kButtonAutoresizing;
    [self.button setImage:[UIImage imageWithName:artwork.foregroundImageName]
                 forState:UIControlStateNormal];

    UIImage *effectImage = [UIImage imageWithName:artwork.effectImageName];
    self.effectImageView = [[UIImageView alloc]
        initWithImage:[effectImage resizableImageWithCapInsets:CapInsetsForImage(effectImage)]];
    self.effectImageView.hidden = YES;
    self.effectImageView.frame = self.bounds;
    self.effectImageView.autoresizingMask = kButtonAutoresizing;
    [self.button addSubview:self.effectImageView];

    self.effectTextImageView =
        [[UIImageView alloc] initWithImage:[UIImage imageWithName:artwork.effectTextImageName]];
    self.effectTextImageView.center = self.button.center;
    self.effectTextImageView.autoresizingMask = kEffectTextAutoresizing;
    self.effectTextImageView.hidden = YES;
    [self.button addSubview:self.effectTextImageView];
}

#pragma mark UIControl

- (void)setEnabled:(BOOL)enabled {
    // The binary ignores the requested state and always disables the inner button; this quirk is
    // preserved deliberately.
    self.button.enabled = NO;
}

#pragma mark Flash effect

- (void)setFlashEffect {
    self.effectTextImageView.hidden = NO;
    self.effectImageView.hidden = NO;
    [self.effectTextImageView SetFlashEffectFast];
    [self.effectImageView SetFlashEffectFast];
}

- (void)removeFlashEffect {
    self.effectTextImageView.hidden = YES;
    self.effectImageView.hidden = YES;
    // The binary stops the flash on the effect-text image only, leaving the effect image's
    // animation running behind its now-hidden view; this quirk is preserved deliberately.
    [self.effectTextImageView RemoveFlashEffect];
    [self.effectTextImageView RemoveFlashEffect];
}

@end

// Build the resizable-image cap insets for a themed asset: a one-pixel border on the left and right
// edges, derived from half the image's width and height less a point. The top and bottom insets are
// zero so the artwork stretches only horizontally through its centre.
static UIEdgeInsets CapInsetsForImage(UIImage *image) {
    CGSize size = image.size;
    return UIEdgeInsetsMake(0.0,
                            size.width * kCapInsetHalf - kCapInsetBorder,
                            0.0,
                            size.height * kCapInsetHalf - kCapInsetBorder);
}
