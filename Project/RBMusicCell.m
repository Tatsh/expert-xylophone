//
//  RBMusicCell.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RBMusicCell). The soft-float
//  subview and layer geometry of -SetupView and the button frames of -initWithFrame: were recovered
//  from the arm64 disassembly at 0xbaa1c/0xbb064, where the decompiler folds the floating-point
//  register moves into pseudo-variables and drops the zero-valued origin arguments of -setFrame:.
//

#import "RBMusicCell.h"

#import "RBUserSettingData.h"
#import "ScoreData.h"
#import "UIImage+RB.h"
#import "neEngineBridge.h"

// The frame-bonus background images, indexed by ScoreDataFrameBonusType (None, Bronze, and Gold).
static NSString *const kBgImageNames[] = {
    @"01_music_select/sel_mbg_d",
    @"01_music_select/sel_mbg_g",
    @"01_music_select/sel_mbg_p",
};

// The clear-rank base images per difficulty, indexed by the difficulty slot.
static NSString *const kRankBaseImageNames[] = {
    @"01_music_select/sel_cl_bg_1",
    @"01_music_select/sel_cl_bg_2",
    @"01_music_select/sel_cl_bg_3",
    @"01_music_select/sel_cl_bg_7",
};

// The full-combo base images per difficulty, indexed by the difficulty slot.
static NSString *const kClearBaseImageNames[] = {
    @"01_music_select/sel_cl_bg_4",
    @"01_music_select/sel_cl_bg_5",
    @"01_music_select/sel_cl_bg_6",
    @"01_music_select/sel_cl_bg_8",
};

// The clear-rank indicator images, indexed by the clear-rank tier returned by GetClearRank (highest
// tier first).
static NSString *const kRankImageNames[] = {
    @"01_music_select/sel_cl_5", @"01_music_select/sel_cl_4", @"01_music_select/sel_cl_3",
    @"01_music_select/sel_cl_2", @"01_music_select/sel_cl_1", @"01_music_select/sel_cl_0",
};

// The full-combo indicator images, indexed by the derived full-combo tier (0 through 3).
static NSString *const kClearImageNames[] = {
    @"01_music_select/sel_cl_6",
    @"01_music_select/sel_cl_7",
    @"01_music_select/sel_cl_8",
    @"01_music_select/sel_cl_8",
};

// The "add to playlist" and "remove from playlist" button images.
static NSString *const kAddButtonImageName = @"01_music_select/sel_add";
static NSString *const kRemoveButtonImageName = @"01_music_select/sel_remove";

// The cell shows four difficulty slots.
enum {
    kDifficultyCount = 4,
};

// The add and remove buttons share a fixed 29x29 frame; the narrow-font variant nudges it up and to
// the left.
static const CGFloat kPlaylistButtonSize = 29.0;
static const CGFloat kPlaylistButtonOriginXNarrow = -3.0;
static const CGFloat kPlaylistButtonOriginYNarrow = -2.0;

// The artwork square, its top-left origin, and both are chosen by font variant.
static const CGFloat kArtworkOriginXNarrow = 7.0;
static const CGFloat kArtworkOriginXWide = 14.0;
static const CGFloat kArtworkOriginYNarrow = 8.0;
static const CGFloat kArtworkOriginYWide = 15.0;
static const CGFloat kArtworkSizeNarrow = 78.0;
static const CGFloat kArtworkSizeWide = 156.0;

// The clear-rank and full-combo indicator columns start at these x positions, chosen by font
// variant. The clear column sits at the artwork's left edge; the rank column is offset rightwards.
static const CGFloat kClearColumnXNarrow = 7.0;
static const CGFloat kClearColumnXWide = 14.0;
static const CGFloat kRankColumnXNarrow = 64.0;
static const CGFloat kRankColumnXWide = 143.0;

// The indicator rows, top to bottom, for each of the four difficulties, chosen by font variant.
static const CGFloat kIndicatorRowsNarrow[] = {75.0, 64.0, 53.0, 42.0};
static const CGFloat kIndicatorRowsWide[] = {152.0, 134.0, 114.0, 95.0};

// The title label metrics for the wide-font variant.
static const CGFloat kTitleOriginXWide = 18.0;
static const CGFloat kTitleOriginYWide = 182.0;
static const CGFloat kTitleWidthWide = 146.0;
static const CGFloat kTitleHeightWide = 18.0;

// The title label metrics for the narrow-font variant, sized relative to the cell's own frame. The
// bottom inset differs by one point between the Classic/Limelight themes and the Colette theme.
static const CGFloat kTitleOriginXNarrow = 5.0;
static const CGFloat kTitleBottomInsetClassic = 23.0;
static const CGFloat kTitleBottomInsetColette = 22.0;
static const CGFloat kTitleWidthInsetNarrow = 10.0;
static const CGFloat kTitleHeightNarrow = 15.0;

// The artist label and its scrim, present only in the wide-font variant. Both sit below the title
// at a shared origin and width; the scrim is one point tall.
static const CGFloat kArtistOriginXWide = 18.0;
static const CGFloat kArtistOriginYWide = 197.0;
static const CGFloat kArtistWidthWide = 146.0;
static const CGFloat kArtistHeightWide = 18.0;
static const CGFloat kArtistScrimHeight = 1.0;
// Yes, this exceeds 1.0; the binary sets it verbatim (a normal scale factor is <= 1.0).
static const CGFloat kArtistMinimumScaleFactor = 5.0;

// The title font point size, chosen by font variant, and the fixed artist font point size.
static const CGFloat kTitleFontSizeNarrow = 12.0;
static const CGFloat kTitleFontSizeWide = 14.0;
static const CGFloat kArtistFontSize = 12.0;

// The Colette and Limelight themes draw the labels in black at this opacity; the Classic theme uses
// white.
static const CGFloat kDarkThemeTextAlpha = 0.7;

// The wide-font scrim behind the title is a half-opaque white (Classic) or black (Limelight) fill;
// the Colette theme leaves it clear.
static const CGFloat kTitleScrimAlpha = 0.5;

// The cross-fade duration shared by -show and -hide.
static const NSTimeInterval kCrossFadeDuration = 0.15;

// Private helpers de-inlined from the repeated indicator-layer construction and label-colouring
// blocks of -SetupView.
@interface RBMusicCell ()
- (CALayer *)addIndicatorLayerWithImageName:(NSString *)imageName
                                    originX:(CGFloat)originX
                                    originY:(CGFloat)originY;
- (void)applyThemeTextColor:(RBUserSettingDataTheme)thema toLabel:(UILabel *)label;
@end

@implementation RBMusicCell {
    // The cached clear-rank and full-combo tier last applied to each difficulty's indicator layer,
    // so a refresh only swaps a layer's contents when its tier changes.
    int m_RankType[kDifficultyCount];
    int m_ClearType[kDifficultyCount];
}

#pragma mark Lifecycle

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self SetupView];

        CGRect buttonFrame;
        if (GetFontVariantFlag() == kFontVariantDefault) {
            buttonFrame = CGRectMake(kPlaylistButtonOriginXNarrow, kPlaylistButtonOriginYNarrow,
                                     kPlaylistButtonSize, kPlaylistButtonSize);
        } else {
            buttonFrame = CGRectMake(0.0, 0.0, kPlaylistButtonSize, kPlaylistButtonSize);
        }

        self.addButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [self.addButton setImage:[UIImage imageWithName:kAddButtonImageName]
                        forState:UIControlStateNormal];
        self.addButton.hidden = YES;
        self.addButton.frame = buttonFrame;
        [self.contentView addSubview:self.addButton];

        self.removeButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [self.removeButton setImage:[UIImage imageWithName:kRemoveButtonImageName]
                           forState:UIControlStateNormal];
        self.removeButton.hidden = YES;
        self.removeButton.frame = buttonFrame;
        [self.contentView addSubview:self.removeButton];
    }
    return self;
}

#pragma mark View setup

- (void)SetupView {
    RBUserSettingDataTheme thema = [RBUserSettingData sharedInstance].thema;

    self.backgroundColor = [UIColor clearColor];

    // The frame-bonus background layer, sized to its image and pinned to the cell's top-left.
    self.bgType = ScoreDataFrameBonusTypeNone;
    UIImage *bgImage = [UIImage imageWithName:kBgImageNames[self.bgType]];
    self.bgImageLayer = [CALayer layer];
    self.bgImageLayer.frame = CGRectMake(0.0, 0.0, bgImage.size.width, bgImage.size.height);
    self.bgImageLayer.contents = (__bridge id)bgImage.CGImage;
    [self.contentView.layer addSublayer:self.bgImageLayer];

    BOOL wide = GetFontVariantFlag() != kFontVariantDefault;

    // The artwork view.
    self.artworkImageView = [[UIImageView alloc] init];
    self.artworkImageView.backgroundColor = [UIColor clearColor];
    self.artworkImageView.frame = CGRectMake(
        wide ? kArtworkOriginXWide : kArtworkOriginXNarrow,
        wide ? kArtworkOriginYWide : kArtworkOriginYNarrow,
        wide ? kArtworkSizeWide : kArtworkSizeNarrow, wide ? kArtworkSizeWide : kArtworkSizeNarrow);
    [self.contentView addSubview:self.artworkImageView];

    // Build the four indicator layers for each difficulty: full-combo base, full-combo, clear-rank
    // base, and clear-rank. The clear-rank type and full-combo type caches start cleared.
    NSMutableArray<CALayer *> *rankBase = [NSMutableArray arrayWithCapacity:kDifficultyCount];
    NSMutableArray<CALayer *> *rank = [NSMutableArray arrayWithCapacity:kDifficultyCount];
    NSMutableArray<CALayer *> *clearBase = [NSMutableArray arrayWithCapacity:kDifficultyCount];
    NSMutableArray<CALayer *> *clear = [NSMutableArray arrayWithCapacity:kDifficultyCount];

    CGFloat clearColumnX = wide ? kClearColumnXWide : kClearColumnXNarrow;
    CGFloat rankColumnX = wide ? kRankColumnXWide : kRankColumnXNarrow;

    for (NSInteger i = 0; i < kDifficultyCount; ++i) {
        CGFloat rowY = wide ? kIndicatorRowsWide[i] : kIndicatorRowsNarrow[i];

        CALayer *clearBaseLayer =
            [self addIndicatorLayerWithImageName:kClearBaseImageNames[i] originX:clearColumnX
                                         originY:rowY];
        [clearBase addObject:clearBaseLayer];
        m_ClearType[i] = 0;

        CALayer *clearLayer =
            [self addIndicatorLayerWithImageName:kClearImageNames[0] originX:clearColumnX
                                         originY:rowY];
        [clear addObject:clearLayer];

        CALayer *rankBaseLayer =
            [self addIndicatorLayerWithImageName:kRankBaseImageNames[i] originX:rankColumnX
                                         originY:rowY];
        [rankBase addObject:rankBaseLayer];
        m_RankType[i] = 0;

        CALayer *rankLayer =
            [self addIndicatorLayerWithImageName:kRankImageNames[0] originX:rankColumnX
                                         originY:rowY];
        [rank addObject:rankLayer];
    }
    self.rankBaseImageLayers = [NSArray arrayWithArray:rankBase];
    self.rankImageLayers = [NSArray arrayWithArray:rank];
    self.clearBaseImageLayers = [NSArray arrayWithArray:clearBase];
    self.clearImageLayers = [NSArray arrayWithArray:clear];

    // The title label. The wide-font variant uses a fixed frame; the narrow-font variant sizes the
    // label from the cell's own frame. Only the Classic, Limelight, and Colette themes create it.
    if (wide) {
        self.titleLabel = [[UILabel alloc]
            initWithFrame:CGRectMake(kTitleOriginXWide, kTitleOriginYWide, kTitleWidthWide,
                                     kTitleHeightWide)];
    } else if (thema == RBUserSettingDataThemeClassic || thema == RBUserSettingDataThemeLimelight) {
        self.titleLabel = [[UILabel alloc]
            initWithFrame:CGRectMake(kTitleOriginXNarrow,
                                     self.frame.size.height - kTitleBottomInsetClassic,
                                     self.frame.size.width - kTitleWidthInsetNarrow,
                                     kTitleHeightNarrow)];
    } else if (thema == RBUserSettingDataThemeColette) {
        self.titleLabel = [[UILabel alloc]
            initWithFrame:CGRectMake(kTitleOriginXNarrow,
                                     self.frame.size.height - kTitleBottomInsetColette,
                                     self.frame.size.width - kTitleWidthInsetNarrow,
                                     kTitleHeightNarrow)];
    }

    self.titleLabel.text = @"";
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.backgroundColor = [UIColor clearColor];
    [self applyThemeTextColor:thema toLabel:self.titleLabel];
    self.titleLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    self.titleLabel.font =
        [UIFont systemFontOfSize:(wide ? kTitleFontSizeWide : kTitleFontSizeNarrow)];
    [self.contentView addSubview:self.titleLabel];

    // The artist label and its scrim exist only in the wide-font variant.
    if (!wide) {
        return;
    }

    UIView *scrim = [[UIView alloc]
        initWithFrame:CGRectMake(kArtistOriginXWide, kArtistOriginYWide, kArtistWidthWide,
                                 kArtistScrimHeight)];
    if (thema == RBUserSettingDataThemeClassic) {
        scrim.backgroundColor = [UIColor colorWithWhite:1.0 alpha:kTitleScrimAlpha];
    } else if (thema == RBUserSettingDataThemeColette) {
        scrim.backgroundColor = [UIColor clearColor];
    } else if (thema == RBUserSettingDataThemeLimelight) {
        scrim.backgroundColor = [UIColor colorWithWhite:0.0 alpha:kTitleScrimAlpha];
    }
    [self.contentView addSubview:scrim];

    self.artistLabel = [[UILabel alloc]
        initWithFrame:CGRectMake(kArtistOriginXWide, kArtistOriginYWide, kArtistWidthWide,
                                 kArtistHeightWide)];
    self.artistLabel.text = @"";
    self.artistLabel.textAlignment = NSTextAlignmentCenter;
    self.artistLabel.minimumScaleFactor = kArtistMinimumScaleFactor;
    self.artistLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    self.artistLabel.font = [UIFont systemFontOfSize:kArtistFontSize];
    self.artistLabel.backgroundColor = [UIColor clearColor];
    [self applyThemeTextColor:thema toLabel:self.artistLabel];
    [self.contentView addSubview:self.artistLabel];
}

// Create a hidden indicator layer for the given image, sized to the image and positioned at the
// given origin, add it to the content layer, and return it.
- (CALayer *)addIndicatorLayerWithImageName:(NSString *)imageName
                                    originX:(CGFloat)originX
                                    originY:(CGFloat)originY {
    UIImage *image = [UIImage imageWithName:imageName];
    CALayer *layer = [CALayer layer];
    layer.frame = CGRectMake(originX, originY, image.size.width, image.size.height);
    layer.backgroundColor = [UIColor clearColor].CGColor;
    layer.contents = (__bridge id)image.CGImage;
    layer.hidden = YES;
    [self.contentView.layer addSublayer:layer];
    return layer;
}

// Colour a label for the current theme: white for Classic, and black at reduced opacity for
// Limelight and Colette.
- (void)applyThemeTextColor:(RBUserSettingDataTheme)thema toLabel:(UILabel *)label {
    if (thema == RBUserSettingDataThemeClassic) {
        label.textColor = [UIColor whiteColor];
    } else if (thema == RBUserSettingDataThemeColette || thema == RBUserSettingDataThemeLimelight) {
        label.textColor = [[UIColor blackColor] colorWithAlphaComponent:kDarkThemeTextAlpha];
    }
}

#pragma mark Score data

- (void)updateScoreData:(ScoreData *)scoreData {
    [self updateScoreData:scoreData spData:nil];
}

- (void)updateScoreData:(ScoreData *)scoreData spData:(ScoreData *)spData {
    ScoreDataFrameBonusType bonusType =
        scoreData ? [scoreData getFrameBonusType] : ScoreDataFrameBonusTypeNone;
    if (self.bgType != bonusType) {
        self.bgType = bonusType;
    }

    ScoreDataFrameBonusType bgBonusType =
        scoreData ? [scoreData getFrameBonusType] : ScoreDataFrameBonusTypeNone;
    UIImage *bgImage = [UIImage imageWithName:kBgImageNames[bgBonusType]];
    self.bgImageLayer.contents = (__bridge id)bgImage.CGImage;

    // The binary keeps the cell's origin but resizes it to the background image.
    self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y, bgImage.size.width,
                            bgImage.size.height);

    for (NSInteger i = 0; i < kDifficultyCount; ++i) {
        // Read the difficulty's achievement rate, full-combo flag, and personal clear count. The
        // fourth (Special) slot comes from spData; the three-argument entry point passes no spData,
        // so its fourth slot falls through to the never-played branch.
        float achievementRate = 0.0f;
        BOOL fullCombo = NO;
        int playCount = 0;
        if (scoreData) {
            switch (i) {
                case 0:
                    achievementRate = scoreData.arBas.floatValue;
                    fullCombo = scoreData.fcBas.boolValue;
                    playCount = scoreData.pcBas.intValue;
                    break;
                case 1:
                    achievementRate = scoreData.arMed.floatValue;
                    fullCombo = scoreData.fcMed.boolValue;
                    playCount = scoreData.pcMed.intValue;
                    break;
                case 2:
                    achievementRate = scoreData.arHar.floatValue;
                    fullCombo = scoreData.fcHar.boolValue;
                    playCount = scoreData.pcHar.intValue;
                    break;
                case 3:
                    if (spData) {
                        achievementRate = spData.arBas.floatValue;
                        fullCombo = spData.fcBas.boolValue;
                        playCount = spData.pcBas.intValue;
                    }
                    break;
                default:
                    break;
            }
        }

        // The achievement rate classifies the clear rank.
        int clearRank = GetClearRank(achievementRate);

        if (clearRank == 0 && playCount == 0) {
            // Never played: hide every indicator for this difficulty.
            self.rankBaseImageLayers[i].hidden = YES;
            self.rankImageLayers[i].hidden = YES;
            self.clearBaseImageLayers[i].hidden = YES;
            self.clearImageLayers[i].hidden = YES;
            continue;
        }

        self.rankBaseImageLayers[i].hidden = NO;
        self.rankImageLayers[i].hidden = NO;
        if (m_RankType[i] != clearRank) {
            m_RankType[i] = clearRank;
            UIImage *rankImage = [UIImage imageWithName:kRankImageNames[clearRank]];
            self.rankImageLayers[i].contents = (__bridge id)rankImage.CGImage;
        }

        // Derive the full-combo indicator tier from the clear rank and the full-combo flag. A clear
        // rank that is neither zero nor one, with no full combo, gives tier one; a full combo gives
        // tier two; and a full combo at such a clear rank gives tier three.
        BOOL rankAboveOne = (clearRank != 1) && (clearRank != 0);
        int comboTier = fullCombo ? 2 : (rankAboveOne ? 1 : 0);
        if (fullCombo && rankAboveOne) {
            comboTier = 3;
        }

        self.clearBaseImageLayers[i].hidden = NO;
        self.clearImageLayers[i].hidden = NO;
        if (m_ClearType[i] != comboTier) {
            m_ClearType[i] = comboTier;
            UIImage *comboImage = [UIImage imageWithName:kClearImageNames[comboTier]];
            self.clearImageLayers[i].contents = (__bridge id)comboImage.CGImage;
        }
    }
}

#pragma mark Cross-fade

- (void)show {
    self.alpha = 0.0;
    self.hidden = NO;
    [UIView animateWithDuration:kCrossFadeDuration
                     animations:^{
                       /** @ghidraAddress 0xbde08 */
                       self.alpha = 1.0;
                     }];
}

- (void)hide {
    self.alpha = 1.0;
    [UIView animateWithDuration:kCrossFadeDuration
        animations:^{
          /** @ghidraAddress 0xbdf1c */
          self.alpha = 0.0;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0xbdf40 */
          self.hidden = YES;
        }];
}

@end
