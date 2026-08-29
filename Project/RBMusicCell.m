#import "RBMusicCell.h"

#import "RBUserSettingData.h"
#import "ScoreData.h"
#import "UIImage+RB.h"
#import "deviceenvironment.h"
#import "engineruntime.h"

static NSString *const kBgImageNames[] = {
    @"01_music_select/sel_mbg_d",
    @"01_music_select/sel_mbg_g",
    @"01_music_select/sel_mbg_p",
};

static NSString *const kRankBaseImageNames[] = {
    @"01_music_select/sel_cl_bg_1",
    @"01_music_select/sel_cl_bg_2",
    @"01_music_select/sel_cl_bg_3",
    @"01_music_select/sel_cl_bg_7",
};

static NSString *const kClearBaseImageNames[] = {
    @"01_music_select/sel_cl_bg_4",
    @"01_music_select/sel_cl_bg_5",
    @"01_music_select/sel_cl_bg_6",
    @"01_music_select/sel_cl_bg_8",
};

// Indexed by the GetClearRank tier, highest tier first.
static NSString *const kRankImageNames[] = {
    @"01_music_select/sel_cl_5",
    @"01_music_select/sel_cl_4",
    @"01_music_select/sel_cl_3",
    @"01_music_select/sel_cl_2",
    @"01_music_select/sel_cl_1",
    @"01_music_select/sel_cl_0",
};

static NSString *const kClearImageNames[] = {
    @"01_music_select/sel_cl_6",
    @"01_music_select/sel_cl_7",
    @"01_music_select/sel_cl_8",
    @"01_music_select/sel_cl_8",
};

static NSString *const kAddButtonImageName = @"01_music_select/sel_add";
static NSString *const kRemoveButtonImageName = @"01_music_select/sel_remove";

enum {
    kDifficultyCount = 4,
};

static const CGFloat kPlaylistButtonSize = 29.0;
// Both buttons take this origin; the two phone arms are identical.
// @ghidraAddress 0xbabf0, 0xbadbc
static const CGFloat kPlaylistButtonOriginXNarrow = -1.5;
static const CGFloat kPlaylistButtonOriginYNarrow = -2.0;

static const CGFloat kArtworkOriginXNarrow = 7.0;
static const CGFloat kArtworkOriginXWide = 14.0;
static const CGFloat kArtworkOriginYNarrow = 8.0;
static const CGFloat kArtworkOriginYWide = 15.0;
static const CGFloat kArtworkSizeNarrow = 78.0;
static const CGFloat kArtworkSizeWide = 156.0;

static const CGFloat kClearColumnXNarrow = 7.0;
static const CGFloat kClearColumnXWide = 14.0;
static const CGFloat kRankColumnXNarrow = 64.0;
static const CGFloat kRankColumnXWide = 143.0;

static const CGFloat kIndicatorRowsNarrow[] = {75.0, 64.0, 53.0, 42.0};
/** @ghidraAddress 0x2eeed8, 0x3010d0, 0x3010d8, 0x3010e0 */
static const CGFloat kIndicatorRowsWide[] = {152.0, 133.0, 114.0, 95.0};

static const CGFloat kTitleOriginXWide = 18.0;
static const CGFloat kTitleOriginYWide = 182.0;
static const CGFloat kTitleWidthWide = 146.0;
static const CGFloat kTitleHeightWide = 18.0;

static const CGFloat kTitleOriginXNarrow = 5.0;
static const CGFloat kTitleBottomInsetClassic = 23.0;
static const CGFloat kTitleBottomInsetColette = 22.0;
static const CGFloat kTitleWidthInsetNarrow = 10.0;
static const CGFloat kTitleHeightNarrow = 15.0;

static const CGFloat kArtistOriginXWide = 18.0;
static const CGFloat kArtistOriginYWide = 197.0;
static const CGFloat kArtistWidthWide = 146.0;
static const CGFloat kArtistHeightWide = 18.0;
static const CGFloat kArtistScrimHeight = 1.0;
// Yes, this exceeds 1.0; the binary sets it verbatim (a normal scale factor is <= 1.0).
static const CGFloat kArtistMinimumScaleFactor = 5.0;

static const CGFloat kTitleFontSizeNarrow = 12.0;
static const CGFloat kTitleFontSizeWide = 14.0;
static const CGFloat kArtistFontSize = 12.0;

static const CGFloat kDarkThemeTextAlpha = 0.7;

static const CGFloat kTitleScrimAlpha = 0.5;

static const NSTimeInterval kCrossFadeDuration = 0.15;

@interface RBMusicCell ()
- (CALayer *)addIndicatorLayerWithImageName:(NSString *)imageName
                                    originX:(CGFloat)originX
                                    originY:(CGFloat)originY;
- (void)applyThemeTextColor:(RBUserSettingDataTheme)thema toLabel:(UILabel *)label;
@end

@implementation RBMusicCell {
    // The tier last applied, so a refresh only swaps a layer's contents when the tier changes.
    int m_RankType[kDifficultyCount];
    int m_ClearType[kDifficultyCount];
}

#pragma mark Lifecycle

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self SetupView];

        CGRect buttonFrame;
        if (!IsPad()) {
            buttonFrame = CGRectMake(kPlaylistButtonOriginXNarrow,
                                     kPlaylistButtonOriginYNarrow,
                                     kPlaylistButtonSize,
                                     kPlaylistButtonSize);
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

- (void)prepareForReuse {
    /** @ghidraAddress 0xbaeec */
    [super prepareForReuse];
    self.artworkImageView.image = nil;
    self.titleLabel.text = nil;
    self.artistLabel.text = nil;
    self.addButton.hidden = YES;
    self.removeButton.hidden = YES;
}

#pragma mark View setup

- (void)SetupView {
    RBUserSettingDataTheme thema = [RBUserSettingData sharedInstance].thema;

    self.backgroundColor = UIColor.clearColor;

    self.bgType = ScoreDataFrameBonusTypeNone;
    UIImage *bgImage = [UIImage imageWithName:kBgImageNames[self.bgType]];
    self.bgImageLayer = [CALayer layer];
    self.bgImageLayer.frame = CGRectMake(0.0, 0.0, bgImage.size.width, bgImage.size.height);
    self.bgImageLayer.contents = (__bridge id)bgImage.CGImage;
    [self.contentView.layer addSublayer:self.bgImageLayer];

    BOOL wide = IsPad();

    self.artworkImageView = [[UIImageView alloc] init];
    self.artworkImageView.backgroundColor = UIColor.clearColor;
    self.artworkImageView.frame = CGRectMake(wide ? kArtworkOriginXWide : kArtworkOriginXNarrow,
                                             wide ? kArtworkOriginYWide : kArtworkOriginYNarrow,
                                             wide ? kArtworkSizeWide : kArtworkSizeNarrow,
                                             wide ? kArtworkSizeWide : kArtworkSizeNarrow);
    [self.contentView addSubview:self.artworkImageView];

    NSMutableArray<CALayer *> *rankBase = [NSMutableArray arrayWithCapacity:kDifficultyCount];
    NSMutableArray<CALayer *> *rank = [NSMutableArray arrayWithCapacity:kDifficultyCount];
    NSMutableArray<CALayer *> *clearBase = [NSMutableArray arrayWithCapacity:kDifficultyCount];
    NSMutableArray<CALayer *> *clear = [NSMutableArray arrayWithCapacity:kDifficultyCount];

    CGFloat clearColumnX = wide ? kClearColumnXWide : kClearColumnXNarrow;
    CGFloat rankColumnX = wide ? kRankColumnXWide : kRankColumnXNarrow;

    for (NSInteger i = 0; i < kDifficultyCount; ++i) {
        CGFloat rowY = wide ? kIndicatorRowsWide[i] : kIndicatorRowsNarrow[i];

        CALayer *clearBaseLayer = [self addIndicatorLayerWithImageName:kClearBaseImageNames[i]
                                                               originX:clearColumnX
                                                               originY:rowY];
        [clearBase addObject:clearBaseLayer];
        m_ClearType[i] = 0;

        CALayer *clearLayer = [self addIndicatorLayerWithImageName:kClearImageNames[0]
                                                           originX:clearColumnX
                                                           originY:rowY];
        [clear addObject:clearLayer];

        CALayer *rankBaseLayer = [self addIndicatorLayerWithImageName:kRankBaseImageNames[i]
                                                              originX:rankColumnX
                                                              originY:rowY];
        [rankBase addObject:rankBaseLayer];
        m_RankType[i] = 0;

        CALayer *rankLayer = [self addIndicatorLayerWithImageName:kRankImageNames[0]
                                                          originX:rankColumnX
                                                          originY:rowY];
        [rank addObject:rankLayer];
    }
    self.rankBaseImageLayers = [NSArray arrayWithArray:rankBase];
    self.rankImageLayers = [NSArray arrayWithArray:rank];
    self.clearBaseImageLayers = [NSArray arrayWithArray:clearBase];
    self.clearImageLayers = [NSArray arrayWithArray:clear];

    if (wide) {
        self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(kTitleOriginXWide,
                                                                    kTitleOriginYWide,
                                                                    kTitleWidthWide,
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
    self.titleLabel.backgroundColor = UIColor.clearColor;
    [self applyThemeTextColor:thema toLabel:self.titleLabel];
    self.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.titleLabel.font =
        [UIFont systemFontOfSize:(wide ? kTitleFontSizeWide : kTitleFontSizeNarrow)];
    [self.contentView addSubview:self.titleLabel];

    if (!wide) {
        return;
    }

    UIView *scrim = [[UIView alloc] initWithFrame:CGRectMake(kArtistOriginXWide,
                                                             kArtistOriginYWide,
                                                             kArtistWidthWide,
                                                             kArtistScrimHeight)];
    if (thema == RBUserSettingDataThemeClassic) {
        scrim.backgroundColor = [UIColor colorWithWhite:1.0 alpha:kTitleScrimAlpha];
    } else if (thema == RBUserSettingDataThemeColette) {
        scrim.backgroundColor = UIColor.clearColor;
    } else if (thema == RBUserSettingDataThemeLimelight) {
        scrim.backgroundColor = [UIColor colorWithWhite:0.0 alpha:kTitleScrimAlpha];
    }
    [self.contentView addSubview:scrim];

    self.artistLabel = [[UILabel alloc] initWithFrame:CGRectMake(kArtistOriginXWide,
                                                                 kArtistOriginYWide,
                                                                 kArtistWidthWide,
                                                                 kArtistHeightWide)];
    self.artistLabel.text = @"";
    self.artistLabel.textAlignment = NSTextAlignmentCenter;
    self.artistLabel.minimumScaleFactor = kArtistMinimumScaleFactor;
    self.artistLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.artistLabel.font = [UIFont systemFontOfSize:kArtistFontSize];
    self.artistLabel.backgroundColor = UIColor.clearColor;
    [self applyThemeTextColor:thema toLabel:self.artistLabel];
    [self.contentView addSubview:self.artistLabel];
}

- (CALayer *)addIndicatorLayerWithImageName:(NSString *)imageName
                                    originX:(CGFloat)originX
                                    originY:(CGFloat)originY {
    UIImage *image = [UIImage imageWithName:imageName];
    CALayer *layer = [CALayer layer];
    layer.frame = CGRectMake(originX, originY, image.size.width, image.size.height);
    layer.backgroundColor = UIColor.clearColor.CGColor;
    layer.contents = (__bridge id)image.CGImage;
    layer.hidden = YES;
    [self.contentView.layer addSublayer:layer];
    return layer;
}

- (void)applyThemeTextColor:(RBUserSettingDataTheme)thema toLabel:(UILabel *)label {
    if (thema == RBUserSettingDataThemeClassic) {
        label.textColor = UIColor.whiteColor;
    } else if (thema == RBUserSettingDataThemeColette || thema == RBUserSettingDataThemeLimelight) {
        label.textColor = [UIColor.blackColor colorWithAlphaComponent:kDarkThemeTextAlpha];
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

    self.frame = CGRectMake(
        self.frame.origin.x, self.frame.origin.y, bgImage.size.width, bgImage.size.height);

    for (NSInteger i = 0; i < kDifficultyCount; ++i) {
        // The three-argument entry point passes no spData, so the fourth slot falls through to
        // the never-played branch.
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

        int clearRank = GetClearRank(achievementRate);

        if (clearRank == 0 && playCount == 0) {
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
