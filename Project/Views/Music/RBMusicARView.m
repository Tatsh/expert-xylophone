//
//  RBMusicARView.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RBMusicARView). The soft-float
//  glyph measurement, centring, and per-glyph frame positioning in -UpdateScore: were recovered
//  from the arm64 disassembly at 0xc1690, where the decompiler folds the floating-point register
//  moves into pseudo-variables.
//

#import "RBMusicARView.h"

#import "RBUserSettingData.h"
#import "UIImage+RB.h"
#import "neEngineBridge.h"

// The achievement rate is scaled by this factor and truncated to an integer before being split into
// decimal glyphs; the decimal point is placed after the first (tenths) digit.
// @ghidraAddress 0x2f8540 (g_flAchievementRateHashScale)
static const float kAchievementRateHashScale = 1000.0f;

// The number of reusable glyph image views pooled by the readout, and the number of decimal digits
// extracted from the scaled rate.
enum {
    kGlyphViewCount = 6,
    kRateDigitCount = 6,
};

// The readout always shows at least this many integer glyphs, even when the significant-digit count
// is smaller.
enum {
    kMinimumGlyphCount = 2,
};

// The index, counted from the least significant digit, after which the decimal point is inserted.
enum {
    kDecimalPointDigitIndex = 1,
};

// The fixed readout size; the caller's frame width and height are overridden with these.
// @ghidraAddress 0x2eea20 (g_dCustomizeArtworkNarrowSize)
static const CGFloat kReadoutWidth = 62.0;
static const CGFloat kReadoutHeight = 8.0;

// The half-width scale and the base widths used to centre the assembled glyph row: the row is
// centred within a nominal field whose width is chosen by the iPad idiom.
// @ghidraAddress 0x2f8578 (default field width)
// @ghidraAddress 0x30110c (alternate field width)
static const float kCentringHalf = 0.5f;
static const float kFieldWidthDefault = 60.0f;
static const float kFieldWidthAlternate = 43.0f;
static const float kCentringOffsetAlternate = 9.0f;

// The bundled achievement-rate glyph images. The Colette theme draws the det_ar1 (large integer)
// and det_ar2 (small fractional) digit sets with a det_ar2 percent and decimal point; the other
// themes draw the det_bpm digits with a det_ran percent and decimal point.
static NSString *const kColetteDigitLargeImageNames[] = {@"02_music_detail/det_ar1_0",
                                                         @"02_music_detail/det_ar1_1",
                                                         @"02_music_detail/det_ar1_2",
                                                         @"02_music_detail/det_ar1_3",
                                                         @"02_music_detail/det_ar1_4",
                                                         @"02_music_detail/det_ar1_5",
                                                         @"02_music_detail/det_ar1_6",
                                                         @"02_music_detail/det_ar1_7",
                                                         @"02_music_detail/det_ar1_8",
                                                         @"02_music_detail/det_ar1_9"};
static NSString *const kColetteDigitSmallImageNames[] = {@"02_music_detail/det_ar2_0",
                                                         @"02_music_detail/det_ar2_1",
                                                         @"02_music_detail/det_ar2_2",
                                                         @"02_music_detail/det_ar2_3",
                                                         @"02_music_detail/det_ar2_4",
                                                         @"02_music_detail/det_ar2_5",
                                                         @"02_music_detail/det_ar2_6",
                                                         @"02_music_detail/det_ar2_7",
                                                         @"02_music_detail/det_ar2_8",
                                                         @"02_music_detail/det_ar2_9"};
static NSString *const kOtherDigitImageNames[] = {@"02_music_detail/det_bpm_0",
                                                  @"02_music_detail/det_bpm_1",
                                                  @"02_music_detail/det_bpm_2",
                                                  @"02_music_detail/det_bpm_3",
                                                  @"02_music_detail/det_bpm_4",
                                                  @"02_music_detail/det_bpm_5",
                                                  @"02_music_detail/det_bpm_6",
                                                  @"02_music_detail/det_bpm_7",
                                                  @"02_music_detail/det_bpm_8",
                                                  @"02_music_detail/det_bpm_9"};
static NSString *const kColettePercentImageName = @"02_music_detail/det_ar2_per";
static NSString *const kColetteDecimalImageName = @"02_music_detail/det_ar2_ten";
static NSString *const kOtherPercentImageName = @"02_music_detail/det_ran_per";
static NSString *const kOtherDecimalImageName = @"02_music_detail/det_ran_ten";

@implementation RBMusicARView

#pragma mark Lifecycle

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = UIColor.clearColor;
        [self setFrame:CGRectMake(frame.origin.x, frame.origin.y, kReadoutWidth, kReadoutHeight)];
        self.numHeightL = 0.0f;
        self.numHeightS = 0.0f;
        self.scoreImageArray = [[NSMutableArray alloc] initWithCapacity:kGlyphViewCount];
        for (int i = 0; i < kGlyphViewCount; ++i) {
            UIImageView *glyphView = [[UIImageView alloc] init];
            [self addSubview:glyphView];
            [self.scoreImageArray addObject:glyphView];
        }
        // The binary's init sends UpdateScore: with an unset argument register (a blank readout).
        [self UpdateScore:0.0f];
    }
    return self;
}

#pragma mark Achievement-rate readout

- (void)UpdateScore:(float)achievementRate {
    int digits[kRateDigitCount] = {0};
    int significantDigits = 0;
    int scaled = (int)(achievementRate * kAchievementRateHashScale);
    for (int i = 0; i < kRateDigitCount; ++i) {
        digits[i] = scaled % 10;
        if (digits[i] != 0) {
            significantDigits = i + 1;
        }
        scaled /= 10;
    }
    int glyphCount =
        significantDigits < kMinimumGlyphCount ? kMinimumGlyphCount : significantDigits;

    NSMutableArray<UIImage *> *imageList = [NSMutableArray arrayWithCapacity:kGlyphViewCount];
    BOOL isColette = NO;
    BOOL hasStarted = NO;
    BOOL decimalEmitted = NO;
    BOOL haveAppended = NO;
    int digitIndex = 0;
    float rowWidth = 0.0f;

    // Build the glyph row from the least significant glyph: the percent sign, one fractional digit,
    // the decimal point, then the integer digits.
    for (int step = 0; step < kGlyphViewCount; ++step) {
        isColette = [RBUserSettingData sharedInstance].thema == RBUserSettingDataThemeColette;
        UIImage *glyph = nil;
        if (isColette) {
            if (!hasStarted) {
                glyph = [UIImage imageWithName:kColettePercentImageName];
            } else if (!decimalEmitted && digitIndex == kDecimalPointDigitIndex) {
                glyph = [UIImage imageWithName:kColetteDecimalImageName];
                decimalEmitted = YES;
                digitIndex = kDecimalPointDigitIndex;
            } else if (digitIndex < glyphCount) {
                if (decimalEmitted) {
                    glyph =
                        [UIImage imageWithName:kColetteDigitLargeImageNames[digits[digitIndex]]];
                    self.numHeightL = glyph.size.height;
                } else {
                    glyph =
                        [UIImage imageWithName:kColetteDigitSmallImageNames[digits[digitIndex]]];
                    self.numHeightS = glyph.size.height;
                }
                ++digitIndex;
            }
        } else {
            if (!hasStarted) {
                glyph = [UIImage imageWithName:kOtherPercentImageName];
            } else if (!decimalEmitted && digitIndex == kDecimalPointDigitIndex) {
                glyph = [UIImage imageWithName:kOtherDecimalImageName];
                decimalEmitted = YES;
                digitIndex = kDecimalPointDigitIndex;
            } else if (digitIndex < glyphCount) {
                glyph = [UIImage imageWithName:kOtherDigitImageNames[digits[digitIndex]]];
                CGFloat glyphHeight = glyph.size.height;
                self.numHeightS = glyphHeight;
                self.numHeightL = glyphHeight;
                ++digitIndex;
            }
        }

        if (glyph != nil) {
            rowWidth += glyph.size.width;
            if (haveAppended) {
                // Each glyph after the first is separated by the iPad idiom advance.
                rowWidth += (float)IsPad();
            }
            [imageList addObject:glyph];
            haveAppended = YES;
        }
        hasStarted = YES;
    }

    // Centre the assembled row within the nominal field for the active iPad idiom.
    float centringOffset;
    if (!IsPad()) {
        centringOffset = (kFieldWidthDefault - rowWidth) * kCentringHalf;
    } else {
        centringOffset =
            (kFieldWidthAlternate - rowWidth) * kCentringHalf + kCentringOffsetAlternate;
    }

    if ([RBUserSettingData sharedInstance].thema == RBUserSettingDataThemeColette) {
        // Colette draws the row into the pool from the last built glyph, advancing rightward from
        // the origin. The centring offset computed above is not applied on this path.
        NSInteger listIndex = (NSInteger)imageList.count - 1;
        int cursorX = 0;
        for (UIImageView *glyphView in self.scoreImageArray) {
            UIImage *glyph = listIndex < 0 ? nil : imageList[listIndex];
            --listIndex;
            if (glyph == nil) {
                glyphView.hidden = YES;
                continue;
            }
            glyphView.image = glyph;
            // A small glyph is nudged down to baseline-align with the large integer glyphs.
            int yOffset =
                glyph.size.height == self.numHeightS ? (int)(self.numHeightL - self.numHeightS) : 0;
            glyphView.frame = CGRectMake(cursorX, yOffset, glyph.size.width, glyph.size.height);
            int advance = IsPad();
            glyphView.hidden = NO;
            cursorX = advance + (int)(cursorX + glyph.size.width);
        }
    } else {
        // The other themes draw the row into the pool from the first built glyph, advancing
        // leftward from the centred right edge.
        int cursorX = (int)(rowWidth + (float)(int)centringOffset);
        NSUInteger listIndex = 0;
        for (UIImageView *glyphView in self.scoreImageArray) {
            UIImage *glyph = nil;
            if (listIndex < imageList.count) {
                glyph = imageList[listIndex];
                ++listIndex;
            }
            if (glyph == nil) {
                glyphView.hidden = YES;
                continue;
            }
            glyphView.image = glyph;
            int yOffset =
                glyph.size.height == self.numHeightS ? (int)(self.numHeightL - self.numHeightS) : 0;
            int glyphX = (int)(cursorX - (int)glyph.size.width);
            glyphView.frame = CGRectMake(glyphX, yOffset, glyph.size.width, glyph.size.height);
            int advance = IsPad();
            glyphView.hidden = NO;
            cursorX = glyphX - advance;
        }
    }
}

@end
