#import "RBMusicScoreView.h"

#import "RBUserSettingData.h"
#import "UIImage+RB.h"

// The score is always drawn as a fixed four-digit column.
enum { kScoreDigitCount = 4 };

// The difficulty grades selecting the themed glyph set.
enum {
    kGradeA = 0,
    kGradeB = 1,
    kGradeC = 2,
    kGradeD = 3,
};

// The horizontal gap, in points, inserted after each digit glyph.
static const CGFloat kDigitSpacing = 2.0;

// The two glyph opacities: significant digits are fully opaque and leading zeros are dimmed.
static const CGFloat kDigitAlphaFull = 1.0;
static const CGFloat kDigitAlphaDimmed = 0.5;

// The digit glyph image names, indexed by digit value. The white theme uses this plain set; the
// black and brown themes pick one of the grade sets below.
static NSString *const kDigitImageNamesWhite[] = {
    @"02_music_detail/det_sc_0",
    @"02_music_detail/det_sc_1",
    @"02_music_detail/det_sc_2",
    @"02_music_detail/det_sc_3",
    @"02_music_detail/det_sc_4",
    @"02_music_detail/det_sc_5",
    @"02_music_detail/det_sc_6",
    @"02_music_detail/det_sc_7",
    @"02_music_detail/det_sc_8",
    @"02_music_detail/det_sc_9",
};

static NSString *const kDigitImageNamesGradeA[] = {
    @"02_music_detail/det_sca_0",
    @"02_music_detail/det_sca_1",
    @"02_music_detail/det_sca_2",
    @"02_music_detail/det_sca_3",
    @"02_music_detail/det_sca_4",
    @"02_music_detail/det_sca_5",
    @"02_music_detail/det_sca_6",
    @"02_music_detail/det_sca_7",
    @"02_music_detail/det_sca_8",
    @"02_music_detail/det_sca_9",
};

static NSString *const kDigitImageNamesGradeB[] = {
    @"02_music_detail/det_scb_0",
    @"02_music_detail/det_scb_1",
    @"02_music_detail/det_scb_2",
    @"02_music_detail/det_scb_3",
    @"02_music_detail/det_scb_4",
    @"02_music_detail/det_scb_5",
    @"02_music_detail/det_scb_6",
    @"02_music_detail/det_scb_7",
    @"02_music_detail/det_scb_8",
    @"02_music_detail/det_scb_9",
};

static NSString *const kDigitImageNamesGradeC[] = {
    @"02_music_detail/det_scc_0",
    @"02_music_detail/det_scc_1",
    @"02_music_detail/det_scc_2",
    @"02_music_detail/det_scc_3",
    @"02_music_detail/det_scc_4",
    @"02_music_detail/det_scc_5",
    @"02_music_detail/det_scc_6",
    @"02_music_detail/det_scc_7",
    @"02_music_detail/det_scc_8",
    @"02_music_detail/det_scc_9",
};

static NSString *const kDigitImageNamesGradeD[] = {
    @"02_music_detail/det_scd_0",
    @"02_music_detail/det_scd_1",
    @"02_music_detail/det_scd_2",
    @"02_music_detail/det_scd_3",
    @"02_music_detail/det_scd_4",
    @"02_music_detail/det_scd_5",
    @"02_music_detail/det_scd_6",
    @"02_music_detail/det_scd_7",
    @"02_music_detail/det_scd_8",
    @"02_music_detail/det_scd_9",
};

@interface RBMusicScoreView () {
    // The last score passed to UpdateScore:, named as in the binary's ivar list. The binary
    // records it here but the readout is driven entirely by the argument, so nothing reads it
    // back.
    int m_Score; // +0x8
}
@end

@implementation RBMusicScoreView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = UIColor.clearColor;
        self.scoreImageViews = [NSMutableArray arrayWithCapacity:kScoreDigitCount];
        for (int i = 0; i < kScoreDigitCount; ++i) {
            [self.scoreImageViews addObject:[[UIImageView alloc] init]];
            [self addSubview:self.scoreImageViews[i]];
        }
        [self UpdateScore:0];
    }
    return self;
}

- (void)UpdateScore:(int)UpdateScore {
    m_Score = UpdateScore;

    // Split the score into its four decimal digits, least significant first, and record the index
    // of the most significant non-zero digit so the leading zeros can be dimmed.
    int digits[kScoreDigitCount];
    int highestNonZero = 0;
    int remaining = UpdateScore;
    for (int i = 0; i < kScoreDigitCount; ++i) {
        digits[i] = remaining % 10;
        if (remaining % 10 != 0) {
            highestNonZero = i;
        }
        remaining /= 10;
    }

    RBUserSettingDataTheme theme = [RBUserSettingData sharedInstance].thema;
    int x = 0;
    // Draw from the most significant digit (index 3) down to the ones place (index 0).
    for (int i = kScoreDigitCount - 1; i >= 0; --i) {
        NSString *const *glyphNames = nil;
        if (theme == RBUserSettingDataThemeClassic) {
            glyphNames = kDigitImageNamesWhite;
        } else if (theme == RBUserSettingDataThemeLimelight ||
                   theme == RBUserSettingDataThemeColette) {
            switch (self.grade) {
            case kGradeA:
                glyphNames = kDigitImageNamesGradeA;
                break;
            case kGradeB:
                glyphNames = kDigitImageNamesGradeB;
                break;
            case kGradeC:
                glyphNames = kDigitImageNamesGradeC;
                break;
            case kGradeD:
                glyphNames = kDigitImageNamesGradeD;
                break;
            default:
                break;
            }
        }

        UIImage *glyph = glyphNames != nil ? [UIImage imageWithName:glyphNames[digits[i]]] : nil;
        CGSize glyphSize = glyph.size;

        UIImageView *digitView = self.scoreImageViews[i];
        digitView.image = glyph;
        digitView.frame = CGRectMake(x, 0.0, glyphSize.width, glyphSize.height);

        // The ones place and every digit at or below the most significant non-zero digit are fully
        // opaque; the leading insignificant zeros are dimmed.
        if (i == 0 || i <= highestNonZero) {
            digitView.alpha = kDigitAlphaFull;
        } else {
            digitView.alpha = kDigitAlphaDimmed;
        }

        x = (int)((double)x + glyphSize.width + kDigitSpacing);
    }
}

@end
