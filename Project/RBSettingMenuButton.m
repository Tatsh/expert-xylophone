#import "RBSettingMenuButton.h"

#import "RBUserSettingData.h"
#import "UIImage+RB.h"
#import "UIImageView+RB.h"
#import "deviceenvironment.h"

static UIEdgeInsets CapInsetsForImage(UIImage *image);

// The binary's table has a fifth column, the shared plain sel_set_button background, that nothing
// reads. @ghidraAddress 0x10035a7e0
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
    // Yes, the credits row really takes the search row's two effect images; the binary's table at
    // 0x35a7e0 repeats the sea_ pair here.
    {@"01_music_select/sel_set_cre_1",
     @"01_music_select/sel_set_cre_2",
     @"01_music_select/sel_set_sea_eff",
     @"01_music_select/sel_set_sea_eff_1"},
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

static const CGFloat kButtonHeightClassicLimelightWide = 32.0;
static const CGFloat kButtonHeightColetteWide = 60.0;
static const CGFloat kButtonHeightNarrow = 22.0;
static const CGFloat kButtonWidthClassicLimelightWide = 60.0;
static const CGFloat kButtonWidthColetteWide = 192.0;
static const CGFloat kButtonWidthNarrow = 40.0;

static const CGFloat kCapInsetHalf = 0.5;
static const CGFloat kCapInsetBorder = 1.0;

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
    // The binary ignores the requested state and always disables the inner button.
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
    // Yes, the binary stops the flash on the effect-text image twice and never on the effect image.
    [self.effectTextImageView RemoveFlashEffect];
    [self.effectTextImageView RemoveFlashEffect];
}

@end

static UIEdgeInsets CapInsetsForImage(UIImage *image) {
    CGSize size = image.size;
    return UIEdgeInsetsMake(0.0,
                            size.width * kCapInsetHalf - kCapInsetBorder,
                            0.0,
                            size.width * kCapInsetHalf - kCapInsetBorder);
}
