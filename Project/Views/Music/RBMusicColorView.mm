#import "RBMusicColorView.h"

#import "RBMusicColorBar.h"
#import "RBMusicView.h"
#import "RBUserSettingData.h"
#import "UIImage+RB.h"
#import "UIImageView+RB.h"
#import "UIView+RB.h"
#import "neEngineBridge.h"

// The three play-colour slots this selector builds a button for.
enum { kColorSlotCount = 3 };

// The play-colour values. Colour 0 and colour 1 are the two concrete colours; any other value is
// the "both" slot the hosting view later resolves to a colour with a coin flip.
enum {
    kColorSlot0 = 0,
    kColorSlot1 = 1,
};

// The user theme (RBUserSettingData.thema); the brown theme (2) uses the flash-highlighted layout.
enum { kThemeBrown = 2 };

// The layout-offset the font-variant Colette layout seeds for the brown theme (8.0, the
// 0x41000000 single-precision literal written by the initialiser).
static const float kBrownLayoutOffset = 8.0f;

// The themed selection sound-effect slot played when a colour button is tapped.
enum { kSoundEffectSelect = 1 };

// The fully-opaque overlay opacity. The selected colour's name overlay is shown at the current
// rival alpha instead, so the others use this value.
static const CGFloat kOverlayAlphaOpaque = 1.0;

// The rival-alpha clamp range.
static const float kRivalAlphaMin = 0.0f;
static const float kRivalAlphaMax = 1.0f;

// The autoresizing mask applied to the colour buttons and their image layers: the four flexible
// margins (0x3f = flexible left, right, top, bottom, width, and height).
static const UIViewAutoresizing kColorAutoresizingMask =
    UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
    UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin |
    UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

// The half factor (the 0x3fe0000000000000 literal, d8) used to centre image layers over a button.
static const CGFloat kHalf = 0.5;
// The two-point vertical nudge applied to the base and name overlays.
static const CGFloat kOverlayNudge = 2.0;

// The colour-button image name tables, indexed by colour slot. Decoded from the CFString tables at
// @0x35ae18 (base), @0x35ae30 (name), @0x35ae60 (you), and @0x35ae78 (rival).
static NSString *const kColorBaseImageNames[] = {
    @"02_music_detail/det_col_1a",
    @"02_music_detail/det_col_2a",
    @"02_music_detail/det_col_0a",
};
static NSString *const kColorNameImageNames[] = {
    @"02_music_detail/det_col_1",
    @"02_music_detail/det_col_2",
    @"02_music_detail/det_col_0",
};
static NSString *const kColorYouImageNames[] = {
    @"02_music_detail/det_col_you_1",
    @"02_music_detail/det_col_you_2",
    @"02_music_detail/det_col_random",
};
static NSString *const kColorRivalImageNames[] = {
    @"02_music_detail/det_col_rival_1",
    @"02_music_detail/det_col_rival_2",
    @"02_music_detail/det_col_you_1",
};

// The selected-state image table used on every non-brown theme, indexed by colour slot
// (@0x35ae48); the brown theme instead uses the single det_dif_sel_10 image for every slot.
static NSString *const kColorSelectedImageNames[] = {
    @"02_music_detail/det_col_sel_1",
    @"02_music_detail/det_col_sel_2",
    @"02_music_detail/det_col_sel_0",
};
static NSString *const kBrownSelectedImageName = @"02_music_detail/det_dif_sel_10";

// The toggle-button and first-info image names.
static NSString *const kToAlphaButtonImageName = @"02_music_detail/det_col_br_1";
static NSString *const kToColorButtonImageName = @"02_music_detail/det_col_br_2";
static NSString *const kFirstInfoImageName = @"02_music_detail/det_col_br_3";

// The number of image layers created by the initialiser's alpha branches.
enum {
    kAlphaLayerFirst = 0,
    kAlphaLayerSecond = 1,
    kAlphaLayerThird = 2,
};

// ---- SetupView geometry, decoded from the .const pools referenced by @0xc2efc ----

// The colour-button horizontal origins on the compact (non-variant) layout, decoded from the guard
// table at @0x301180 (g_flColorButtonX table): {16, 194, 105}.
static const CGFloat kCompactButtonX[] = {16.0, 194.0, 105.0};
// The compact colour-button frame: origin y then size (0x4022... = 9.0, g_dLayoutMetricNinety =
// 90.0, and g_dCustomizeArtworkWideLimelightX = 68.0).
static const CGFloat kCompactButtonY = 9.0;
static const CGFloat kCompactButtonWidth = 90.0;
static const CGFloat kCompactButtonHeight = 68.0;
// The compact alpha-change base-image frame (g_dSliderRowHeightWide = 40.0, 0x4037... = 23.0,
// g_dMenuButtonHeightNarrow = 42.0, and DAT_1002eec40 = 44.0).
static const CGFloat kCompactAlphaChangeX = 40.0;
static const CGFloat kCompactAlphaChangeY = 23.0;
static const CGFloat kCompactAlphaChangeWidth = 42.0;
static const CGFloat kCompactAlphaChangeHeight = 44.0;
// The compact toggle-button frame (4.0, DAT_100301140 = 74.0, 0x403e... = 30.0, 0x4035... = 21.0).
static const CGFloat kCompactToggleX = 4.0;
static const CGFloat kCompactToggleY = 74.0;
static const CGFloat kCompactToggleWidth = 30.0;
static const CGFloat kCompactToggleHeight = 21.0;
// The compact colour-bar frame (g_dPopupBaseOriginXWide = 112.0, 0x4039... = 25.0,
// DAT_1003010b0 = 158.0, and DAT_1002eeec0 = 38.0).
static const CGFloat kCompactColorBarX = 112.0;
static const CGFloat kCompactColorBarY = 25.0;
static const CGFloat kCompactColorBarWidth = 158.0;
static const CGFloat kCompactColorBarHeight = 38.0;

// The font-variant (Colette) layout is laid out relative to layoutOffset. The colour-button
// horizontal offsets per slot (added to layoutOffset), decoded from the LAB_1000c34fc arms:
// slot 0 = g_flCollectionStartYNarrow (34.0), slot 1 = DAT_100301178 (312.0),
// slot 2 = DAT_100301174 (173.0).
static const CGFloat kVariantButtonXOffset[] = {34.0, 312.0, 173.0};
// The variant colour-button frame origin y then square size (0x4039... = 25.0 and
// DAT_1002eece0 = 110.0).
static const CGFloat kVariantButtonY = 25.0;
static const CGFloat kVariantButtonSize = 110.0;
// The variant alpha-change base-image frame: x = layoutOffset + DAT_1002fcf90 (58.0), then
// DAT_100301160 (51.0) and g_dCustomizeArtworkNarrowSize (62.0) for the square size.
static const CGFloat kVariantAlphaChangeXOffset = 58.0;
static const CGFloat kVariantAlphaChangeY = 51.0;
static const CGFloat kVariantAlphaChangeSize = 62.0;
// The variant toggle-button frame: x = layoutOffset + (brown ? -4.0 : 2.0), y from a theme pair
// (brown = DAT_100301150 = 148.0, else DAT_100301148 = 153.0), size g_dUnlockFrameCapInsetWide
// (36.0) and 0x4038... (24.0).
static const CGFloat kVariantToggleXBrownOffset = -4.0;
static const CGFloat kVariantToggleXOffset = 2.0;
static const CGFloat kVariantToggleYBrown = 148.0;
static const CGFloat kVariantToggleY = 153.0;
static const CGFloat kVariantToggleWidth = 36.0;
static const CGFloat kVariantToggleHeight = 24.0;
// The variant colour-bar frame: x = layoutOffset + DAT_100301170 (176.0), then DAT_1002ec6e0
// (50.0), g_dMenuButtonHeightWide (230.0), and DAT_1002eecd8 (64.0).
static const CGFloat kVariantColorBarXOffset = 176.0;
static const CGFloat kVariantColorBarY = 50.0;
static const CGFloat kVariantColorBarWidth = 230.0;
static const CGFloat kVariantColorBarHeight = 64.0;

// The first-info flash effect timing (0x3e800000 = 0.25 duration, 0x3f800000 = 1.0 start, and
// g_flFlashMinOpacity = 0.2 end).
static const CGFloat kFirstInfoFlashDuration = 0.25;
static const CGFloat kFirstInfoFlashStart = 1.0;
static const CGFloat kFirstInfoFlashEnd = 0.2;

// One layout leg's decoded geometry.
namespace {
struct ColorGeometry {
    CGFloat buttonX;
    CGFloat buttonY;
    CGFloat buttonWidth;
    CGFloat buttonHeight;
    CGFloat alphaChangeX;
    CGFloat alphaChangeY;
    CGFloat alphaChangeWidth;
    CGFloat alphaChangeHeight;
    CGFloat toggleX;
    CGFloat toggleY;
    CGFloat toggleWidth;
    CGFloat toggleHeight;
    CGFloat colorBarX;
    CGFloat colorBarY;
    CGFloat colorBarWidth;
    CGFloat colorBarHeight;
};
} // namespace

@interface RBMusicColorView ()
// De-inlined SetupView tail; the binary emits it in-line after the third loop iteration and it is
// not a distinct selector.
- (void)buildToggleButtonsAndColorBar:(const ColorGeometry &)geometry;
@end

@implementation RBMusicColorView

#pragma mark Lifecycle

- (instancetype)initWithFrame:(CGRect)frame MusicSelectedBase:(RBMusicView *)MusicSelectedBase {
    self = [super initWithFrame:frame];
    if (self) {
        self.musicSelectedBase = MusicSelectedBase;
        self.color = [RBUserSettingData sharedInstance].playerColor;
        self.rivalAlpha = [RBUserSettingData sharedInstance].rivalAlpha;
        if ([RBUserSettingData sharedInstance].thema == kThemeBrown) {
            if (GetFontVariantFlag() != kFontVariantDefault) {
                self.layoutOffset = kBrownLayoutOffset;
            }
        } else {
            self.layoutOffset = 0.0f;
        }
        [self SetupView];
        [self ShowSelect];
    }
    return self;
}

#pragma mark View construction

- (void)SetupView {
    self.buttons = [NSMutableArray arrayWithCapacity:kColorSlotCount];
    self.buttonImages = [NSMutableArray arrayWithCapacity:kColorSlotCount];
    self.buttonImageBases = [NSMutableArray arrayWithCapacity:kColorSlotCount];
    self.selectedImages = [NSMutableArray arrayWithCapacity:kColorSlotCount];
    self.youImages = [NSMutableArray arrayWithCapacity:kColorSlotCount];
    self.rivalImages = [NSMutableArray arrayWithCapacity:kColorSlotCount];
    self.alphaChangeImages = [NSMutableArray arrayWithCapacity:kColorSlotCount];
    self.alphaChangeImageBases = [NSMutableArray arrayWithCapacity:kColorSlotCount];

    int thema = [RBUserSettingData sharedInstance].thema;
    BOOL fontVariant = GetFontVariantFlag() != kFontVariantDefault;

    for (int i = 0; i < kColorSlotCount; ++i) {
        ColorGeometry geometry;
        if (fontVariant) {
            CGFloat offset = self.layoutOffset;
            geometry.buttonX = offset + kVariantButtonXOffset[i];
            geometry.buttonY = kVariantButtonY;
            geometry.buttonWidth = kVariantButtonSize;
            geometry.buttonHeight = kVariantButtonSize;
            geometry.alphaChangeX = offset + kVariantAlphaChangeXOffset;
            geometry.alphaChangeY = kVariantAlphaChangeY;
            geometry.alphaChangeWidth = kVariantAlphaChangeSize;
            geometry.alphaChangeHeight = kVariantAlphaChangeSize;
            geometry.toggleX = offset + (thema == kThemeBrown ? kVariantToggleXBrownOffset :
                                                                kVariantToggleXOffset);
            geometry.toggleY = thema == kThemeBrown ? kVariantToggleYBrown : kVariantToggleY;
            geometry.toggleWidth = kVariantToggleWidth;
            geometry.toggleHeight = kVariantToggleHeight;
            geometry.colorBarX = offset + kVariantColorBarXOffset;
            geometry.colorBarY = kVariantColorBarY;
            geometry.colorBarWidth = kVariantColorBarWidth;
            geometry.colorBarHeight = kVariantColorBarHeight;
        } else {
            geometry.buttonX = kCompactButtonX[i];
            geometry.buttonY = kCompactButtonY;
            geometry.buttonWidth = kCompactButtonWidth;
            geometry.buttonHeight = kCompactButtonHeight;
            geometry.alphaChangeX = kCompactAlphaChangeX;
            geometry.alphaChangeY = kCompactAlphaChangeY;
            geometry.alphaChangeWidth = kCompactAlphaChangeWidth;
            geometry.alphaChangeHeight = kCompactAlphaChangeHeight;
            geometry.toggleX = kCompactToggleX;
            geometry.toggleY = kCompactToggleY;
            geometry.toggleWidth = kCompactToggleWidth;
            geometry.toggleHeight = kCompactToggleHeight;
            geometry.colorBarX = kCompactColorBarX;
            geometry.colorBarY = kCompactColorBarY;
            geometry.colorBarWidth = kCompactColorBarWidth;
            geometry.colorBarHeight = kCompactColorBarHeight;
        }

        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.backgroundColor = [UIColor clearColor];
        button.frame = CGRectMake(
            geometry.buttonX, geometry.buttonY, geometry.buttonWidth, geometry.buttonHeight);
        button.autoresizingMask = kColorAutoresizingMask;
        button.tag = i;
        button.exclusiveTouch = YES;
        [button addTarget:self
                      action:@selector(SelectButton:)
            forControlEvents:UIControlEventTouchUpInside];
        [self.buttons addObject:button];

        UIImage *baseImage = [UIImage imageWithName:kColorBaseImageNames[i]];
        UIImageView *baseView = [[UIImageView alloc] initWithImage:baseImage];
        CGFloat centerX = button.frame.origin.x + button.frame.size.width * kHalf;
        CGFloat centerY = button.frame.origin.y + button.frame.size.height * kHalf + kOverlayNudge;
        baseView.center = CGPointMake(centerX, centerY);
        baseView.autoresizingMask = kColorAutoresizingMask;
        [self addSubview:baseView];
        [self.buttonImageBases addObject:baseView];

        [self addSubview:button];
        // The stacked overlays are subviews of the button, centred within its own bounds at half
        // its width and height (the binary reads the button's frame size back twice for this).
        CGRect buttonFrame = button.frame;
        CGFloat layerCenterX = buttonFrame.size.width * kHalf;
        CGFloat layerCenterY = buttonFrame.size.height * kHalf;

        UIImage *selectedImage;
        if ([RBUserSettingData sharedInstance].thema == kThemeBrown) {
            selectedImage = [UIImage imageWithName:kBrownSelectedImageName];
        } else {
            selectedImage = [UIImage imageWithName:kColorSelectedImageNames[i]];
        }
        UIImageView *selectedView = [[UIImageView alloc] initWithImage:selectedImage];
        selectedView.center = CGPointMake(layerCenterX, layerCenterY);
        selectedView.autoresizingMask = kColorAutoresizingMask;
        [button addSubview:selectedView];
        [self.selectedImages addObject:selectedView];
        if ([RBUserSettingData sharedInstance].thema == kThemeBrown && !fontVariant) {
            // On the compact brown layout the selected overlay starts fully transparent instead of
            // flashing.
            selectedView.alpha = 0.0;
        } else {
            [selectedView SetFlashEffectFast];
        }

        UIImage *nameImage = [UIImage imageWithName:kColorNameImageNames[i]];
        UIImageView *nameView = [[UIImageView alloc] initWithImage:nameImage];
        nameView.center = CGPointMake(layerCenterX, layerCenterY + kOverlayNudge);
        nameView.autoresizingMask = kColorAutoresizingMask;
        [button addSubview:nameView];
        [self.buttonImages addObject:nameView];

        UIImage *youImage = [UIImage imageWithName:kColorYouImageNames[i]];
        UIImageView *youView = [[UIImageView alloc] initWithImage:youImage];
        youView.center = CGPointMake(layerCenterX, layerCenterY);
        youView.autoresizingMask = kColorAutoresizingMask;
        [button addSubview:youView];
        [self.youImages addObject:youView];

        UIImage *rivalImage = [UIImage imageWithName:kColorRivalImageNames[i]];
        UIImageView *rivalView = [[UIImageView alloc] initWithImage:rivalImage];
        rivalView.center = CGPointMake(layerCenterX, layerCenterY);
        rivalView.autoresizingMask = kColorAutoresizingMask;
        [button addSubview:rivalView];
        [self.rivalImages addObject:rivalView];

        UIImage *alphaBaseImage = [UIImage imageWithName:kColorBaseImageNames[i]];
        UIImageView *alphaBaseView = [[UIImageView alloc] initWithImage:alphaBaseImage];
        alphaBaseView.frame = CGRectMake(geometry.alphaChangeX,
                                         geometry.alphaChangeY,
                                         geometry.alphaChangeWidth,
                                         geometry.alphaChangeHeight);
        alphaBaseView.hidden = YES;
        [self addSubview:alphaBaseView];
        [self.alphaChangeImageBases addObject:alphaBaseView];

        UIImage *alphaNameImage = [UIImage imageWithName:kColorNameImageNames[i]];
        UIImageView *alphaNameView = [[UIImageView alloc] initWithImage:alphaNameImage];
        alphaNameView.frame = CGRectMake(geometry.alphaChangeX,
                                         geometry.alphaChangeY,
                                         geometry.alphaChangeWidth,
                                         geometry.alphaChangeHeight);
        alphaNameView.hidden = YES;
        [self addSubview:alphaNameView];
        [self.alphaChangeImages addObject:alphaNameView];

        if (i == kColorSlotCount - 1) {
            [self buildToggleButtonsAndColorBar:geometry];
        }
    }
}

// De-inlined tail of SetupView (the binary emits it in-line after the third loop iteration): the
// alpha toggle button with its optional first-info hint, the colour toggle button, and the colour
// bar. It runs once, using the final iteration's decoded geometry.
- (void)buildToggleButtonsAndColorBar:(const ColorGeometry &)geometry {
    CGRect toggleFrame =
        CGRectMake(geometry.toggleX, geometry.toggleY, geometry.toggleWidth, geometry.toggleHeight);

    UIButton *alphaButton = [UIButton buttonWithType:UIButtonTypeCustom];
    alphaButton.frame = toggleFrame;
    alphaButton.autoresizingMask = kColorAutoresizingMask;
    [alphaButton addTarget:self
                    action:@selector(selectAlphaButton:)
          forControlEvents:UIControlEventTouchDown];
    UIImage *alphaImage = [UIImage imageWithName:kToAlphaButtonImageName];
    [alphaButton setImage:alphaImage forState:UIControlStateNormal];
    [self addSubview:alphaButton];

    if (![RBUserSettingData sharedInstance].brightnessFirstInfo) {
        UIImage *infoImage = [UIImage imageWithName:kFirstInfoImageName];
        UIImageView *infoView = [[UIImageView alloc] initWithImage:infoImage];
        infoView.center = CGPointMake(alphaButton.bounds.size.width * kHalf,
                                      alphaButton.bounds.size.height * kHalf);
        [alphaButton addSubview:infoView];
        [infoView SetFlashEffectDuration:kFirstInfoFlashDuration
                                   Start:kFirstInfoFlashStart
                                     End:kFirstInfoFlashEnd];
        self.firstInfo = infoView;
        [alphaButton SetFlashEffectDuration:kFirstInfoFlashDuration
                                      Start:kFirstInfoFlashStart
                                        End:kFirstInfoFlashEnd];
    }
    self.toAlphaButton = alphaButton;

    UIButton *colorButton = [UIButton buttonWithType:UIButtonTypeCustom];
    colorButton.frame = toggleFrame;
    colorButton.autoresizingMask = kColorAutoresizingMask;
    [colorButton addTarget:self
                    action:@selector(selectColorButton:)
          forControlEvents:UIControlEventTouchDown];
    UIImage *colorImage = [UIImage imageWithName:kToColorButtonImageName];
    [colorButton setImage:colorImage forState:UIControlStateNormal];
    [self addSubview:colorButton];
    colorButton.hidden = YES;
    self.toColorButton = colorButton;

    self.colorBar = [[RBMusicColorBar alloc] initWithFrame:CGRectMake(geometry.colorBarX,
                                                                      geometry.colorBarY,
                                                                      geometry.colorBarWidth,
                                                                      geometry.colorBarHeight)
                                        MusicSelectedColor:self];
    self.colorBar.hidden = YES;
    self.colorBar.autoresizingMask = kColorAutoresizingMask;
    [self addSubview:self.colorBar];
}

#pragma mark Selection

- (void)ShowSelect {
    if (self.color == kColorSlot1) {
        [self.buttonImages[kAlphaLayerFirst] setAlpha:self.rivalAlpha];
        [self.buttonImages[kAlphaLayerSecond] setAlpha:kOverlayAlphaOpaque];
        [self.selectedImages[kAlphaLayerFirst] setHidden:YES];
        [self.selectedImages[kAlphaLayerSecond] setHidden:NO];
        [self.selectedImages[kAlphaLayerThird] setHidden:NO];
        [self.youImages[kAlphaLayerFirst] setHidden:NO];
        [self.youImages[kAlphaLayerSecond] setHidden:YES];
        [self.youImages[kAlphaLayerThird] setHidden:NO];
        [self.rivalImages[kAlphaLayerFirst] setHidden:YES];
        [self.rivalImages[kAlphaLayerSecond] setHidden:NO];
        [self.rivalImages[kAlphaLayerThird] setHidden:NO];
        [self.buttonImageBases[kAlphaLayerFirst] setHidden:YES];
        [self.buttonImageBases[kAlphaLayerSecond] setHidden:NO];
        [self.buttonImageBases[kAlphaLayerThird] setHidden:NO];
    } else if (self.color == kColorSlot0) {
        [self.buttonImages[kAlphaLayerFirst] setAlpha:kOverlayAlphaOpaque];
        [self.buttonImages[kAlphaLayerSecond] setAlpha:self.rivalAlpha];
        [self.selectedImages[kAlphaLayerFirst] setHidden:NO];
        [self.selectedImages[kAlphaLayerSecond] setHidden:YES];
        [self.selectedImages[kAlphaLayerThird] setHidden:YES];
        [self.youImages[kAlphaLayerFirst] setHidden:YES];
        [self.youImages[kAlphaLayerSecond] setHidden:NO];
        [self.youImages[kAlphaLayerThird] setHidden:NO];
        [self.rivalImages[kAlphaLayerFirst] setHidden:NO];
        [self.rivalImages[kAlphaLayerSecond] setHidden:YES];
        [self.rivalImages[kAlphaLayerThird] setHidden:NO];
        [self.buttonImageBases[kAlphaLayerFirst] setHidden:NO];
        [self.buttonImageBases[kAlphaLayerSecond] setHidden:YES];
        [self.buttonImageBases[kAlphaLayerThird] setHidden:NO];
    } else {
        [self.buttonImages[kAlphaLayerFirst] setAlpha:self.rivalAlpha];
        [self.buttonImages[kAlphaLayerSecond] setAlpha:self.rivalAlpha];
        [self.selectedImages[kAlphaLayerFirst] setHidden:YES];
        [self.selectedImages[kAlphaLayerSecond] setHidden:YES];
        [self.selectedImages[kAlphaLayerThird] setHidden:NO];
        [self.youImages[kAlphaLayerFirst] setHidden:NO];
        [self.youImages[kAlphaLayerSecond] setHidden:NO];
        [self.youImages[kAlphaLayerThird] setHidden:NO];
        [self.rivalImages[kAlphaLayerFirst] setHidden:NO];
        [self.rivalImages[kAlphaLayerSecond] setHidden:NO];
        [self.rivalImages[kAlphaLayerThird] setHidden:YES];
        [self.buttonImageBases[kAlphaLayerFirst] setHidden:NO];
        [self.buttonImageBases[kAlphaLayerSecond] setHidden:NO];
        [self.buttonImageBases[kAlphaLayerThird] setHidden:YES];
    }
    [self.colorBar setAlphaValue:self.rivalAlpha];
}

- (void)SelectButton:(UIButton *)SelectButton {
    if (self.color != static_cast<int>(SelectButton.tag)) {
        self.color = static_cast<int>(SelectButton.tag);
        [self ShowSelect];
        PlayThemedSoundEffect(SoundEffectManager::GetInstance(), kSoundEffectSelect);
    }
}

- (void)selectAlphaButton:(UIButton *)selectAlphaButton {
    if (self.firstInfo != nil) {
        [RBUserSettingData sharedInstance].brightnessFirstInfo = YES;
        self.firstInfo.hidden = YES;
        [self.toAlphaButton RemoveFlashEffect];
    }
    self.toAlphaButton.hidden = YES;
    self.toColorButton.hidden = NO;
    for (int i = 0; i < kColorSlotCount; ++i) {
        [self.buttons[i] setHidden:YES];
        [self.buttonImageBases[i] setHidden:YES];
        [self.alphaChangeImages[i] setAlpha:self.rivalAlpha];
    }
    if (self.color == kColorSlot1) {
        [self.alphaChangeImages[kAlphaLayerFirst] setHidden:NO];
        [self.alphaChangeImages[kAlphaLayerSecond] setHidden:YES];
        [self.alphaChangeImages[kAlphaLayerThird] setHidden:YES];
        [self.alphaChangeImageBases[kAlphaLayerFirst] setHidden:NO];
        [self.alphaChangeImageBases[kAlphaLayerSecond] setHidden:YES];
        [self.alphaChangeImageBases[kAlphaLayerThird] setHidden:YES];
    } else if (self.color == kColorSlot0) {
        [self.alphaChangeImages[kAlphaLayerFirst] setHidden:YES];
        [self.alphaChangeImages[kAlphaLayerSecond] setHidden:NO];
        [self.alphaChangeImages[kAlphaLayerThird] setHidden:YES];
        [self.alphaChangeImageBases[kAlphaLayerFirst] setHidden:YES];
        [self.alphaChangeImageBases[kAlphaLayerSecond] setHidden:NO];
        [self.alphaChangeImageBases[kAlphaLayerThird] setHidden:YES];
    } else {
        [self.alphaChangeImages[kAlphaLayerFirst] setHidden:YES];
        [self.alphaChangeImages[kAlphaLayerSecond] setHidden:YES];
        [self.alphaChangeImages[kAlphaLayerThird] setHidden:NO];
        [self.alphaChangeImageBases[kAlphaLayerFirst] setHidden:YES];
        [self.alphaChangeImageBases[kAlphaLayerSecond] setHidden:YES];
        [self.alphaChangeImageBases[kAlphaLayerThird] setHidden:NO];
    }
    [self.colorBar setHidden:NO];
    if (self.musicSelectedBase != nil) {
        [self.musicSelectedBase setScrollable:NO];
    }
}

- (void)selectColorButton:(UIButton *)selectColorButton {
    self.toAlphaButton.hidden = NO;
    self.toColorButton.hidden = YES;
    for (int i = 0; i < kColorSlotCount; ++i) {
        [self.buttons[i] setHidden:NO];
        [self.alphaChangeImages[i] setHidden:YES];
        [self.alphaChangeImageBases[i] setHidden:YES];
    }
    [self.colorBar setHidden:YES];
    if (self.musicSelectedBase != nil) {
        [self.musicSelectedBase setScrollable:YES];
    }
    [self ShowSelect];
}

#pragma mark Rival alpha

- (void)setRivalAlpha:(float)rivalAlpha {
    if (rivalAlpha <= kRivalAlphaMin) {
        rivalAlpha = kRivalAlphaMin;
    }
    if (rivalAlpha > kRivalAlphaMax) {
        rivalAlpha = kRivalAlphaMax;
    }
    _rivalAlpha = rivalAlpha;

    if (self.color == kColorSlot1) {
        [self.buttonImages[kAlphaLayerFirst] setAlpha:self.rivalAlpha];
        [self.buttonImages[kAlphaLayerSecond] setAlpha:kOverlayAlphaOpaque];
    } else if (self.color == kColorSlot0) {
        [self.buttonImages[kAlphaLayerFirst] setAlpha:kOverlayAlphaOpaque];
        [self.buttonImages[kAlphaLayerSecond] setAlpha:self.rivalAlpha];
    } else {
        [self.buttonImages[kAlphaLayerFirst] setAlpha:self.rivalAlpha];
        [self.buttonImages[kAlphaLayerSecond] setAlpha:self.rivalAlpha];
    }
    for (int i = 0; i < kColorSlotCount; ++i) {
        [self.alphaChangeImages[i] setAlpha:self.rivalAlpha];
    }
}

@end
