#import "RBMusicExtendNoteView.h"

#import "MusicDataExtend.h"
#import "RBExtendNoteManager.h"
#import "RBUserSettingData.h"
#import "UIImage+RB.h"
#import "UIImageView+RB.h"
#import "UIView+RB.h"
#import "neEngineBridge.h"

// The horizontal offset added on the wide (pad) Colette layout.
static const float kPadLayoutOffset = 8.0f;

// The button-centre metrics. On the wide (pad) layout the centre x is the layout offset plus this
// constant and the centre y is the shared 84-point metric; on the narrow layout both are fixed.
static const float kPadCenterXBias = 89.0f;
static const CGFloat kPadCenterY = 84.0; // Shared engine metric @ghidraAddress 0x2ee9c8.
static const CGFloat kPhoneCenterX = 54.0;
static const CGFloat kPhoneCenterY = 43.0;

// The difficulty level is clamped to this many distinct level-number glyphs (levels 1 through 15).
enum { kMaxDifficultyGlyphIndex = 14 };

// The tag assigned to the difficulty button.
enum { kDifficultyButtonTag = 2 };

// The autoresizing mask applied to the button and its glyphs: all six flexible flags (0x3f).
static const UIViewAutoresizing kExtendNoteAutoresizingMask =
    UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth |
    UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin |
    UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;

// The caption panel and label geometry, in points.
static const CGFloat kCaptionPanelTopY = 40.0;        // Also g_dSliderRowHeightWide.
static const CGFloat kCaptionPanelHeightInset = 80.0; // Trimmed from the badge height.
static const CGFloat kCaptionPanelWhite = 0.5;        // Half-opacity grey panel.
static const CGFloat kCaptionPanelAlpha = 0.5;
static const CGFloat kCaptionFontSize = 15.0;
static const CGFloat kCaptionTextWhite = 0.19607843137254902; // 50/255.

// The difficulty-frame and selected-overlay glyphs, chosen by theme.
static NSString *const kFrameImageClassic = @"02_music_detail/det_dif_3";
static NSString *const kFrameImageThemed = @"02_music_detail/det_dif_10";
static NSString *const kSelectedFrameImageClassic = @"02_music_detail/det_dif_sel_2";
static NSString *const kSelectedFrameImageThemed = @"02_music_detail/det_dif_sel_10";

// The level-number glyphs, indexed by the clamped difficulty (levels 1 through 15).
static NSString *const kDifficultyGlyphNames[] = {
    @"02_music_detail/det_difc_1",
    @"02_music_detail/det_difc_2",
    @"02_music_detail/det_difc_3",
    @"02_music_detail/det_difc_4",
    @"02_music_detail/det_difc_5",
    @"02_music_detail/det_difc_6",
    @"02_music_detail/det_difc_7",
    @"02_music_detail/det_difc_8",
    @"02_music_detail/det_difc_9",
    @"02_music_detail/det_difc_10",
    @"02_music_detail/det_difc_11",
    @"02_music_detail/det_difc_12",
    @"02_music_detail/det_difc_13",
    @"02_music_detail/det_difc_14",
    @"02_music_detail/det_difc_15",
};

// The classic-theme (Classic and Limelight) level-glyph centre offsets, by device idiom.
static const CGFloat kClassicGlyphOffsetXPad = 6.0;
static const CGFloat kClassicGlyphOffsetYPad = 12.0;
static const CGFloat kClassicGlyphOffsetXPhone = 2.0;
static const CGFloat kClassicGlyphOffsetYPhone = 10.0;

@implementation RBMusicExtendNoteView

- (instancetype)initWithFrame:(CGRect)frame
                 ExtendNoteID:(unsigned int)ExtendNoteID
            MusicSelectedBase:(RBMusicView *)MusicSelectedBase {
    self = [super initWithFrame:frame];
    if (self) {
        self.musicSelectedBase = MusicSelectedBase;
        self.extendNoteID = ExtendNoteID;
        if ([RBUserSettingData sharedInstance].thema == RBUserSettingDataThemeColette && IsPad()) {
            self.layoutOffset = kPadLayoutOffset;
        } else {
            self.layoutOffset = 0.0f;
        }
        [self SetupView];
    }
    return self;
}

- (void)SetupView {
    // The difficulty button centre depends on the device idiom: the wide (pad) layout offsets it
    // horizontally by the badge's layout offset and drops it to the shared 84-point line, while the
    // narrow layout uses fixed coordinates.
    CGPoint buttonCenter;
    if (IsPad()) {
        buttonCenter = CGPointMake(self.layoutOffset + kPadCenterXBias, kPadCenterY);
    } else {
        buttonCenter = CGPointMake(kPhoneCenterX, kPhoneCenterY);
    }

    RBExtendNoteManager *manager = [RBExtendNoteManager getInstance];
    MusicDataExtend *extendNote = [manager getExtendNoteData:self.extendNoteID];

    RBUserSettingDataTheme theme = [RBUserSettingData sharedInstance].thema;
    BOOL classicTheme = theme < RBUserSettingDataThemeColette;

    // The difficulty-frame button.
    UIImage *frameImage =
        [UIImage imageWithName:classicTheme ? kFrameImageClassic : kFrameImageThemed];
    CGSize frameSize = frameImage.size;
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button setImage:frameImage forState:UIControlStateNormal];
    [button setImage:frameImage forState:UIControlStateSelected];
    [button setImage:frameImage forState:UIControlStateHighlighted];
    button.bounds = CGRectMake(0.0, 0.0, frameSize.width, frameSize.height);
    button.center = buttonCenter;
    button.tag = kDifficultyButtonTag;
    button.autoresizingMask = kExtendNoteAutoresizingMask;
    [self addSubview:button];
    self.difficultyButton = button;
    button.exclusiveTouch = YES;

    // The selected-frame overlay, centred on the button.
    theme = [RBUserSettingData sharedInstance].thema;
    classicTheme = theme < RBUserSettingDataThemeColette;
    UIImage *selectedImage = [UIImage
        imageWithName:classicTheme ? kSelectedFrameImageClassic : kSelectedFrameImageThemed];
    UIImageView *selectedView = [[UIImageView alloc] initWithImage:selectedImage];
    selectedView.center =
        CGPointMake(button.bounds.size.width * 0.5, button.bounds.size.height * 0.5);
    selectedView.autoresizingMask = kExtendNoteAutoresizingMask;
    [button addSubview:selectedView];
    // The binary reads the theme once more here and discards it before the flash pulse.
    (void)[RBUserSettingData sharedInstance].thema;
    [selectedView SetFlashEffectFast];

    // The level-number glyph, clamped to the available glyphs and only shown for a non-negative
    // difficulty.
    int difficulty = extendNote.difficulty;
    int glyphIndex = difficulty > kMaxDifficultyGlyphIndex ? kMaxDifficultyGlyphIndex : difficulty;
    if (extendNote.difficulty < 0) {
        glyphIndex = 0;
    }
    UIImage *glyphImage = [UIImage imageWithName:kDifficultyGlyphNames[glyphIndex]];
    if (glyphImage != nil) {
        UIImageView *glyphView = [[UIImageView alloc] initWithImage:glyphImage];
        if ([RBUserSettingData sharedInstance].thema < RBUserSettingDataThemeColette) {
            CGFloat offsetX = IsPad() ? kClassicGlyphOffsetXPad : kClassicGlyphOffsetXPhone;
            CGFloat offsetY = IsPad() ? kClassicGlyphOffsetYPad : kClassicGlyphOffsetYPhone;
            glyphView.center = CGPointMake(button.bounds.size.width * 0.5 + offsetX,
                                           button.bounds.size.height * 0.5 + offsetY);
        } else {
            // The themed layout nudges the glyph one point left on iPad only.
            CGFloat offsetX = IsPad() ? -1.0 : 0.0;
            glyphView.center = CGPointMake(button.bounds.size.width * 0.5 + offsetX,
                                           button.bounds.size.height * 0.5 + 0.0);
        }
        glyphView.autoresizingMask = kExtendNoteAutoresizingMask;
        [button addSubview:glyphView];
    }

    (void)self.frame; // Yes, the binary reads the frame here and discards it.

    // The translucent caption panel to the right of the button, and its truncating comment label.
    CGFloat panelX = button.center.x + button.width;
    CGFloat panelWidth = self.width - (button.center.x + button.width + button.width * 0.5);
    CGFloat panelHeight = self.height - kCaptionPanelHeightInset;
    UIView *captionPanel = [[UIView alloc]
        initWithFrame:CGRectMake(panelX, kCaptionPanelTopY, panelWidth, panelHeight)];
    captionPanel.backgroundColor = [UIColor colorWithRed:kCaptionPanelWhite
                                                   green:kCaptionPanelWhite
                                                    blue:kCaptionPanelWhite
                                                   alpha:kCaptionPanelAlpha];

    UILabel *captionLabel =
        [[UILabel alloc] initWithFrame:CGRectMake(0.0, 0.0, panelWidth, panelHeight)];
    captionLabel.backgroundColor = [UIColor colorWithRed:kCaptionPanelWhite
                                                   green:kCaptionPanelWhite
                                                    blue:kCaptionPanelWhite
                                                   alpha:kCaptionPanelAlpha];
    captionLabel.font = [UIFont systemFontOfSize:kCaptionFontSize];
    captionLabel.textColor = [UIColor colorWithWhite:kCaptionTextWhite alpha:1.0];
    captionLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    captionLabel.baselineAdjustment = UIBaselineAdjustmentAlignBaselines;
    captionLabel.numberOfLines = 0;
    captionLabel.text = extendNote.comment;
    [captionLabel sizeToFit];
    captionLabel.frame = CGRectMake(0.0,
                                    panelHeight * 0.5 - captionLabel.height * 0.5,
                                    captionLabel.width,
                                    captionLabel.height);
    [captionPanel addSubview:captionLabel];
    [self addSubview:captionPanel];
}

- (void)SetFlashEffectDuration:(float)SetFlashEffectDuration Start:(float)Start End:(float)End {
}

@end
