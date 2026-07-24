//
//  TwitterImageCreater.mm
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class TwitterImageCreater). Verified
//  against the arm64 disassembly: the CoreGraphics compositing helpers take their coordinates and
//  scale in VFP registers, so the decompiler drops several float parameters and scrambles the
//  CGContextDrawImage rectangle; the true signatures and the rectangle layout
//  {x, m_Height - y - scale*h, scale*w, scale*h} were recovered from the register reads. The
//  per-element layout coordinates and asset names come from the binary's static position tables and
//  the twitter/tw_* image set.
//

#import "TwitterImageCreater.h"

#import <CoreGraphics/CoreGraphics.h>

#import "RBUserSettingData.h"
#import "TwitterImageCreaterScoreElement.h"
#import "UIImage+RB.h"
#import "neEngineBridge.h"

// The number of score columns: index 0 is the local player, index 1 is the rival.
static const int kScoreColumnCount = 2;

// The bits per component of the RGBA compositing context.
static const size_t kBitsPerComponent = 8;

// The number of bytes per pixel in the RGBA compositing context.
static const int kBytesPerPixel = 4;

// The theme identifier whose result layout uses the alternate level-badge coordinates.
static const int kThemaAlternateLayout = 2;

// The game mode that draws the rival-battle two-column layout.
static const int kGameTypeRivalBattle = 1;

// The player-side values that select which badge a column draws.
static const int kColorSideYou = 0;
static const int kColorSideRival = 1;

// The maximum clear-rank value; the rank badge asset number counts down from it.
static const int kMaxClearRank = 5;

// The digit count drawn for an achievement rate, and the factor that turns the rate into that many
// fixed-point digits.
// @ghidraAddress 0x2f8540 (g_flAchievementRateHashScale)
static const float kAchievementRateHashScale = 1000.0f;
static const int kAchievementRateDigits = 4;

// The vertical nudge applied to the leading dot tile drawn beside a number.
static const int kDotTileVerticalOffset = 8;

// The largest single-digit value; digit counting stops once the remaining value is no larger.
static const int kMaxSingleDigit = 9;

// The difficulty-grade letters used to build the level-badge asset names, indexed by grade.
static const char kGradeLetters[] = {'b', 'm', 'h', 's'};

// The twitter share-image asset names.
static NSString *const kAssetBackground = @"12_twitter/tw_bg";
static NSString *const kAssetScorePlus = @"12_twitter/tw_sc_p";
static NSString *const kAssetLine = @"12_twitter/tw_line";
static NSString *const kAssetJustReflecMode = @"12_twitter/tw_jr_mode";
static NSString *const kAssetFullComboMode = @"12_twitter/tw_fc_mode";
static NSString *const kAssetRankCombo = @"12_twitter/tw_ran_combo";
static NSString *const kAssetDigitZero = @"12_twitter/tw_sc_0";
static NSString *const kAssetDot = @"12_twitter/tw_sc_t";
static NSString *const kAssetYouBadge = @"12_twitter/tw_r_you";
static NSString *const kAssetYouBadgeAlt = @"12_twitter/tw_b_you";
static NSString *const kAssetRivalBadge = @"12_twitter/tw_b_rival";
static NSString *const kAssetRivalBadgeAlt = @"12_twitter/tw_r_rival";

static NSString *const kAssetDigitFormat = @"12_twitter/tw_sc_%d";
static NSString *const kAssetDifficultyFormat = @"12_twitter/tw_dif_%d";
static NSString *const kAssetLevelFormat = @"12_twitter/tw_lev_%c_%d";
static NSString *const kAssetRankFormat = @"12_twitter/tw_ran_%d";

// One score column's layout coordinates. The binary keeps these as a table of raw doubles indexed
// by the column, at a stride of 0x1b0 bytes per column.
typedef struct {
    CGPoint icon;
    CGPoint combo;
    CGPoint rank;
    CGPoint score;
    CGPoint achievementRate;
    CGPoint scorePlus;
    CGPoint just;
    CGPoint great;
    CGPoint good;
    CGPoint miss;
    CGPoint justReflec;
} TwitterImageCreaterColumnLayout;

// The two per-column layouts, recovered from the static position table at raw 0x1002fea70.
// @ghidraAddress 0x2fea70
static const TwitterImageCreaterColumnLayout kColumnLayouts[] = {
    {
        .icon = {143.0, 115.0},
        .combo = {163.0, 131.0},
        .rank = {169.0, 144.0},
        .score = {195.0, 179.0},
        .achievementRate = {209.0, 196.0},
        .scorePlus = {210.0, 198.0},
        .just = {195.0, 225.0},
        .great = {195.0, 242.0},
        .good = {195.0, 259.0},
        .miss = {195.0, 276.0},
        .justReflec = {195.0, 293.0},
    },
    {
        .icon = {260.0, 115.0},
        .combo = {280.0, 131.0},
        .rank = {286.0, 144.0},
        .score = {312.0, 179.0},
        .achievementRate = {326.0, 196.0},
        .scorePlus = {327.0, 198.0},
        .just = {312.0, 225.0},
        .great = {312.0, 242.0},
        .good = {312.0, 259.0},
        .miss = {312.0, 276.0},
        .justReflec = {312.0, 293.0},
    },
};

// The composite-element coordinates. The binary copies these fixed constants from rodata into a
// global table at start-up (InitializeParticleOffsetTable, raw 0x100088f3c); the source values are
// inlined here since they never change.
// @ghidraAddress 0x2fe9f0
static const CGPoint g_TwitterTitlePos = {80.0, 62.0};
static const CGPoint g_TwitterArtistPos = {80.0, 89.0};
static const CGPoint g_TwitterDifficultyPos = {24.0, 60.0};
static const CGPoint g_TwitterLevelPos = {33.0, 79.0};
static const CGPoint g_TwitterLinePos = {129.0, 176.0};
static const CGPoint g_TwitterLevelPosAlt = {19.0, 57.0};
static const CGPoint g_TwitterJustReflecPos = {25.0, 115.0};
static const CGPoint g_TwitterFullComboPos = {25.0, 135.0};

@interface TwitterImageCreater ()

// Allocates the off-screen RGBA bitmap context of the given pixel dimensions.
// @ghidraAddress 0x87ae4
- (void)createContext:(int)width:(int)height;
// Draws an image with the given scale, bottom-left anchored at (x, y) in flipped context space.
// @ghidraAddress 0x87ba0
- (void)drawImage:(nullable UIImage *)image X:(int)x Y:(int)y Scale:(float)scale;
// Draws an image at unit scale, bottom-left anchored at (x, y).
// @ghidraAddress 0x87c78
- (void)drawImage:(nullable UIImage *)image X:(int)x Y:(int)y;
// Loads the named asset and draws it at the current scale, anchored at (x, y).
// @ghidraAddress 0x87d40
- (void)drawImageFileName:(nullable NSString *)name X:(int)x Y:(int)y;
// Loads the named asset and draws it at the current scale, anchored at a layout point.
// @ghidraAddress 0x87dd4
- (void)drawImageFileName:(nullable NSString *)name Position:(CGPoint)position;
// Draws text at a layout point using a font and colour, in flipped context space.
// @ghidraAddress 0x87e68
- (void)drawText:(nullable NSString *)text
        Position:(CGPoint)position
            Font:(nullable UIFont *)font
           Color:(nullable UIColor *)color;
// Draws a right-aligned run of digit tiles for a number, optionally leading with a dot tile.
// @ghidraAddress 0x87fa4
- (void)drawNumber:(int)number Position:(CGPoint)position Keta:(int)keta Dot:(BOOL)dot;
// Returns the number of significant decimal digits in a value, at least one.
// @ghidraAddress 0x881fc
- (int)getDigitNum:(int)number;
// Draws one score column: its badge, combo, rank, and per-judgement counts.
// @ghidraAddress 0x88244
- (void)drawScore:(int)side Pos:(int)pos Dot:(BOOL)dot;
// Releases the bitmap context, colour space, and backing buffer.
// @ghidraAddress 0x87848
- (void)reset;

@end

@implementation TwitterImageCreater

#pragma mark - Lifecycle

- (instancetype)init {
    /** @ghidraAddress 0x87784 */
    self = [super init];
    if (self != nil) {
        for (int i = 0; i < kScoreColumnCount; ++i) {
            m_Score[i] = [[TwitterImageCreaterScoreElement alloc] init];
        }
    }
    return self;
}

- (void)dealloc {
    /** @ghidraAddress 0x878ac */
    [self reset];
}

- (void)reset {
    /** @ghidraAddress 0x87848 */
    if (m_Data != nullptr) {
        delete[] m_Data;
        m_Data = nullptr;
    }
    if (m_Context != nullptr) {
        CGContextRelease(m_Context);
        m_Context = nullptr;
    }
    if (m_ColorSpace != nullptr) {
        CGColorSpaceRelease(m_ColorSpace);
        m_ColorSpace = nullptr;
    }
}

#pragma mark - Column setters

- (void)setScore:(int)score Side:(int)side {
    /** @ghidraAddress 0x87930 */
    if (side < kScoreColumnCount) {
        [m_Score[side] setScore:score];
    }
}

- (void)setAR:(float)aR Side:(int)side {
    /** @ghidraAddress 0x87958 */
    if (side < kScoreColumnCount) {
        [m_Score[side] setAr:aR];
    }
}

- (void)setJustNum:(int)justNum Side:(int)side {
    /** @ghidraAddress 0x87980 */
    if (side < kScoreColumnCount) {
        [m_Score[side] setJustNum:justNum];
    }
}

- (void)setGreatNum:(int)greatNum Side:(int)side {
    /** @ghidraAddress 0x879a8 */
    if (side < kScoreColumnCount) {
        [m_Score[side] setGreatNum:greatNum];
    }
}

- (void)setGoodNum:(int)goodNum Side:(int)side {
    /** @ghidraAddress 0x879d0 */
    if (side < kScoreColumnCount) {
        [m_Score[side] setGoodNum:goodNum];
    }
}

- (void)setMissNum:(int)missNum Side:(int)side {
    /** @ghidraAddress 0x879f8 */
    if (side < kScoreColumnCount) {
        [m_Score[side] setMissNum:missNum];
    }
}

- (void)setJustReflecNum:(int)justReflecNum Side:(int)side {
    /** @ghidraAddress 0x87a20 */
    if (side < kScoreColumnCount) {
        [m_Score[side] setJustReflecNum:justReflecNum];
    }
}

- (void)setMaxComboNum:(int)maxComboNum Side:(int)side {
    /** @ghidraAddress 0x87a48 */
    if (side < kScoreColumnCount) {
        [m_Score[side] setMaxComboNum:maxComboNum];
    }
}

- (void)setName:(NSString *)name Side:(int)side {
    /** @ghidraAddress 0x87a70 */
    if (side < kScoreColumnCount) {
        [m_Score[side] setName:name];
    }
}

#pragma mark - Context

- (void)createContext:(int)width:(int)height {
    /** @ghidraAddress 0x87ae4 */
    [self reset];
    m_Width = width;
    m_Height = height;
    m_Data = new unsigned char[static_cast<size_t>(width * height * kBytesPerPixel)];
    m_ColorSpace = CGColorSpaceCreateDeviceRGB();
    m_Context = CGBitmapContextCreate(m_Data,
                                      width,
                                      height,
                                      kBitsPerComponent,
                                      static_cast<size_t>(width * kBytesPerPixel),
                                      m_ColorSpace,
                                      kCGImageAlphaPremultipliedLast);
}

#pragma mark - Compositing

- (void)drawImage:(UIImage *)image X:(int)x Y:(int)y Scale:(float)scale {
    /** @ghidraAddress 0x87ba0 */
    CGSize size = image.size;
    CGContextDrawImage(
        m_Context,
        CGRectMake(
            x, (m_Height - y) - scale * size.height, scale * size.width, scale * size.height),
        image.CGImage);
}

- (void)drawImage:(UIImage *)image X:(int)x Y:(int)y {
    /** @ghidraAddress 0x87c78 */
    CGSize size = image.size;
    CGContextDrawImage(m_Context,
                       CGRectMake(x, (m_Height - y) - size.height, size.width, size.height),
                       image.CGImage);
}

- (void)drawImageFileName:(NSString *)name X:(int)x Y:(int)y {
    /** @ghidraAddress 0x87d40 */
    [self drawImage:[UIImage imageWithName:name] X:x Y:y Scale:m_Scale];
}

- (void)drawImageFileName:(NSString *)name Position:(CGPoint)position {
    /** @ghidraAddress 0x87dd4 */
    [self drawImage:[UIImage imageWithName:name]
                  X:static_cast<int>(position.x)
                  Y:static_cast<int>(position.y)
              Scale:m_Scale];
}

- (void)drawText:(NSString *)text
        Position:(CGPoint)position
            Font:(UIFont *)font
           Color:(UIColor *)color {
    /** @ghidraAddress 0x87e68 */
    UIGraphicsPushContext(m_Context);
    [color set];
    // The context is flipped to draw the text upright, then restored afterwards.
    CGContextTranslateCTM(m_Context, position.x, m_Height - position.y);
    CGContextScaleCTM(m_Context, 1.0, -1.0);
    [text drawAtPoint:CGPointZero withFont:font];
    CGContextScaleCTM(m_Context, 1.0, -1.0);
    CGContextTranslateCTM(m_Context, -position.x, -(m_Height - position.y));
    UIGraphicsPopContext();
}

- (void)drawNumber:(int)number Position:(CGPoint)position Keta:(int)keta Dot:(BOOL)dot {
    /** @ghidraAddress 0x87fa4 */
    int digits[6] = {0};
    int significant = 0;
    int remaining = number;
    for (int i = 0; i < keta; ++i) {
        digits[i] = remaining % 10;
        if (remaining % 10 != 0) {
            significant = i + 1;
        }
        remaining = remaining / 10;
    }

    int drawCount = significant > 0 ? significant : 1;
    if (dot && drawCount < kScoreColumnCount) {
        // With a dot, always draw at least two tiles so the leading digit sits beside the dot.
        drawCount = 2;
    }

    int cursorX = static_cast<int>(position.x);
    for (int i = 0; i < drawCount; ++i) {
        UIImage *digitImage =
            [UIImage imageWithName:[NSString stringWithFormat:kAssetDigitFormat, digits[i]]];
        cursorX = static_cast<int>(cursorX - digitImage.size.width * m_Scale);
        [self drawImage:digitImage X:cursorX Y:static_cast<int>(position.y) Scale:m_Scale];
        if (i == 0 && dot) {
            UIImage *dotImage = [UIImage imageWithName:kAssetDot];
            cursorX = static_cast<int>(cursorX - dotImage.size.width * m_Scale);
            [self drawImage:dotImage
                          X:cursorX
                          Y:static_cast<int>(position.y) + kDotTileVerticalOffset
                      Scale:m_Scale];
        }
    }
}

- (int)getDigitNum:(int)number {
    /** @ghidraAddress 0x881fc */
    if (number == 0) {
        return 1;
    }
    int count = 0;
    int remaining = number;
    do {
        ++count;
        int previous = remaining;
        remaining = remaining / 10;
        if (previous <= kMaxSingleDigit) {
            break;
        }
    } while (true);
    return count;
}

- (void)drawScore:(int)side Pos:(int)pos Dot:(BOOL)dot {
    /** @ghidraAddress 0x88244 */
    TwitterImageCreaterScoreElement *element = m_Score[side];
    const TwitterImageCreaterColumnLayout *layout = &kColumnLayouts[pos];

    UIImage *digitTile = [UIImage imageWithName:kAssetDigitZero];
    int digitStep = static_cast<int>(digitTile.size.width * m_Scale);

    if (dot) {
        if (side == kColorSideYou) {
            if (self.color == kColorSideYou) {
                [self drawImageFileName:kAssetRivalBadge Position:layout->icon];
            } else if (self.color == kColorSideRival) {
                [self drawImageFileName:kAssetRivalBadgeAlt Position:layout->icon];
            }
        } else {
            if (self.color == kColorSideYou) {
                [self drawImageFileName:kAssetYouBadge Position:layout->icon];
            } else if (self.color == kColorSideRival) {
                [self drawImageFileName:kAssetYouBadgeAlt Position:layout->icon];
            }
        }
    }

    if (self.noteNum == element.maxComboNum) {
        [self drawImageFileName:kAssetRankCombo Position:layout->combo];
    }

    int rank = GetClearRank(element.ar);
    [self drawImageFileName:[NSString stringWithFormat:kAssetRankFormat, kMaxClearRank - rank]
                   Position:layout->rank];

    int scoreDigits = [self getDigitNum:element.score];
    [self drawNumber:element.score
            Position:CGPointMake(scoreDigits * digitStep / 2 + layout->score.x, layout->score.y)
                Keta:scoreDigits
                 Dot:NO];

    [self drawNumber:static_cast<int>(element.ar * kAchievementRateHashScale)
            Position:layout->achievementRate
                Keta:kAchievementRateDigits
                 Dot:YES];
    [self drawImageFileName:kAssetScorePlus Position:layout->scorePlus];

    int justDigits = [self getDigitNum:element.justNum];
    [self drawNumber:element.justNum
            Position:CGPointMake(justDigits * digitStep / 2 + layout->just.x, layout->just.y)
                Keta:justDigits
                 Dot:NO];

    int greatDigits = [self getDigitNum:element.greatNum];
    [self drawNumber:element.greatNum
            Position:CGPointMake(greatDigits * digitStep / 2 + layout->great.x, layout->great.y)
                Keta:greatDigits
                 Dot:NO];

    int goodDigits = [self getDigitNum:element.goodNum];
    [self drawNumber:element.goodNum
            Position:CGPointMake(goodDigits * digitStep / 2 + layout->good.x, layout->good.y)
                Keta:goodDigits
                 Dot:NO];

    int missDigits = [self getDigitNum:element.missNum];
    [self drawNumber:element.missNum
            Position:CGPointMake(missDigits * digitStep / 2 + layout->miss.x, layout->miss.y)
                Keta:missDigits
                 Dot:NO];

    int justReflecDigits = [self getDigitNum:element.justReflecNum];
    [self drawNumber:element.justReflecNum
            Position:CGPointMake(justReflecDigits * digitStep / 2 + layout->justReflec.x,
                                 layout->justReflec.y)
                Keta:justReflecDigits
                 Dot:NO];
}

#pragma mark - Image

- (UIImage *)createImage {
    /** @ghidraAddress 0x888b0 */
    UIImage *background = [UIImage imageWithName:kAssetBackground];
    CGSize size = background.size;
    m_Scale = static_cast<float>(background.scale);
    [self createContext:static_cast<int>(size.width * m_Scale):static_cast<int>(size.height *
                                                                                m_Scale)];
    [self drawImage:background X:0 Y:0 Scale:static_cast<float>(background.scale)];

    [self drawImage:self.titleImage
                  X:static_cast<int>(g_TwitterTitlePos.x)
                  Y:static_cast<int>(g_TwitterTitlePos.y)];
    [self drawImage:self.artistImage
                  X:static_cast<int>(g_TwitterArtistPos.x)
                  Y:static_cast<int>(g_TwitterArtistPos.y)];

    if ([RBUserSettingData sharedInstance].thema != kThemaAlternateLayout) {
        [self drawImageFileName:[NSString stringWithFormat:kAssetDifficultyFormat, self.grade + 1]
                              X:static_cast<int>(g_TwitterDifficultyPos.x)
                              Y:static_cast<int>(g_TwitterDifficultyPos.y)];
    }

    NSString *levelName =
        [NSString stringWithFormat:kAssetLevelFormat, kGradeLetters[self.grade], self.level + 1];
    if ([RBUserSettingData sharedInstance].thema == kThemaAlternateLayout) {
        [self drawImageFileName:levelName
                              X:static_cast<int>(g_TwitterLevelPosAlt.x)
                              Y:static_cast<int>(g_TwitterLevelPosAlt.y)];
    } else {
        [self drawImageFileName:levelName
                              X:static_cast<int>(g_TwitterLevelPos.x)
                              Y:static_cast<int>(g_TwitterLevelPos.y)];
    }

    if ([RBUserSettingData sharedInstance].fullJustReflec) {
        [self drawImageFileName:kAssetJustReflecMode
                              X:static_cast<int>(g_TwitterJustReflecPos.x)
                              Y:static_cast<int>(g_TwitterJustReflecPos.y)];
    }
    if ([RBUserSettingData sharedInstance].userFullCombo) {
        [self drawImageFileName:kAssetFullComboMode
                              X:static_cast<int>(g_TwitterFullComboPos.x)
                              Y:static_cast<int>(g_TwitterFullComboPos.y)];
    }

    if (self.gameType == kGameTypeRivalBattle) {
        [self drawScore:kColorSideRival Pos:kColorSideYou Dot:YES];
        [self drawScore:kColorSideYou Pos:kColorSideRival Dot:YES];
    } else {
        [self drawImageFileName:kAssetLine
                              X:static_cast<int>(g_TwitterLinePos.x)
                              Y:static_cast<int>(g_TwitterLinePos.y)];
        [self drawScore:kColorSideRival Pos:kColorSideRival Dot:NO];
    }

    CGImageRef rendered = CGBitmapContextCreateImage(m_Context);
    UIImage *result = [UIImage imageWithCGImage:rendered];
    CGImageRelease(rendered);
    return result;
}

@end
