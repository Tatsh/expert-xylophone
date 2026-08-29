#import "RBMusicScoreView.h"

#import "RBUserSettingData.h"
#import "UIImage+RB.h"

enum { kScoreDigitCount = 4 };

enum {
    kGradeA = 0,
    kGradeB = 1,
    kGradeC = 2,
    kGradeD = 3,
};

static const CGFloat kDigitSpacing = 2.0;

static const CGFloat kDigitAlphaFull = 1.0;
static const CGFloat kDigitAlphaDimmed = 0.5;

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
    // Written but never read: the readout is driven entirely from the argument.
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

        if (i == 0 || i <= highestNonZero) {
            digitView.alpha = kDigitAlphaFull;
        } else {
            digitView.alpha = kDigitAlphaDimmed;
        }

        x = (int)((double)x + glyphSize.width + kDigitSpacing);
    }
}

@end
