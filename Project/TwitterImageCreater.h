/** @file
 * Builds the play-result share image posted to Twitter. It owns an off-screen RGBA bitmap context,
 * composites the background, the title and artist images, the difficulty, level, mode, and line
 * badges, and one or two score columns (the local player and, in a rival battle, the opponent),
 * then returns the finished @c UIImage. The two score columns are held as a pair of
 * @c TwitterImageCreaterScoreElement value objects.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class TwitterImageCreater, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <CoreGraphics/CoreGraphics.h>
#import <UIKit/UIKit.h>

@class TwitterImageCreaterScoreElement;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Builds the play-result share image for Twitter.
 */
@interface TwitterImageCreater : NSObject {
    /** @brief The bitmap context width, in pixels. */
    int m_Width; // +0x08
    /** @brief The bitmap context height, in pixels. */
    int m_Height; // +0x0c
    /** @brief The device scale of the background image, applied to every drawn element. */
    float m_Scale; // +0x10
    /** @brief The backing byte buffer for @c m_Context. */
    unsigned char *m_Data; // +0x18
    /** @brief The off-screen RGBA bitmap context the image is composited into. */
    CGContextRef m_Context; // +0x20
    /** @brief The device RGB colour space backing @c m_Context. */
    CGColorSpaceRef m_ColorSpace; // +0x28
    /** @brief The two score columns: index 0 is the local player, index 1 is the rival. */
    TwitterImageCreaterScoreElement *m_Score[2]; // +0x30
}

/**
 * @brief The tune title image drawn at the top of the result.
 */
@property(nonatomic, strong, nullable) UIImage *titleImage;

/**
 * @brief The artist image drawn below the title.
 */
@property(nonatomic, strong, nullable) UIImage *artistImage;

/**
 * @brief The difficulty grade: 0 basic, 1 medium, 2 hard, 3 special.
 */
@property(nonatomic, assign) int grade;

/**
 * @brief The tune level within its grade, zero-based.
 */
@property(nonatomic, assign) int level;

/**
 * @brief The game mode: 1 selects the rival-battle two-column layout, otherwise a single column.
 */
@property(nonatomic, assign) int gameType;

/**
 * @brief The tune's total note count, compared against a column's maximum combo to mark a full
 * combo.
 */
@property(nonatomic, assign) int noteNum;

/**
 * @brief The player side that owns the primary column: 0 draws the "you" badge, 1 the "rival"
 * badge.
 */
@property(nonatomic, assign) int color;

/**
 * @brief Sets the score of one column.
 * @param score The score value.
 * @param side The column index; ignored when greater than 1.
 * @ghidraAddress 0x87930
 */
- (void)setScore:(int)score Side:(int)side;

/**
 * @brief Sets the achievement rate of one column.
 * @param aR The achievement rate.
 * @param side The column index; ignored when greater than 1.
 * @ghidraAddress 0x87958
 */
- (void)setAR:(float)aR Side:(int)side;

/**
 * @brief Sets the JUST count of one column.
 * @param justNum The JUST judgement count.
 * @param side The column index; ignored when greater than 1.
 * @ghidraAddress 0x87980
 */
- (void)setJustNum:(int)justNum Side:(int)side;

/**
 * @brief Sets the GREAT count of one column.
 * @param greatNum The GREAT judgement count.
 * @param side The column index; ignored when greater than 1.
 * @ghidraAddress 0x879a8
 */
- (void)setGreatNum:(int)greatNum Side:(int)side;

/**
 * @brief Sets the GOOD count of one column.
 * @param goodNum The GOOD judgement count.
 * @param side The column index; ignored when greater than 1.
 * @ghidraAddress 0x879d0
 */
- (void)setGoodNum:(int)goodNum Side:(int)side;

/**
 * @brief Sets the MISS count of one column.
 * @param missNum The MISS judgement count.
 * @param side The column index; ignored when greater than 1.
 * @ghidraAddress 0x879f8
 */
- (void)setMissNum:(int)missNum Side:(int)side;

/**
 * @brief Sets the JUST REFLEC count of one column.
 * @param justReflecNum The JUST REFLEC judgement count.
 * @param side The column index; ignored when greater than 1.
 * @ghidraAddress 0x87a20
 */
- (void)setJustReflecNum:(int)justReflecNum Side:(int)side;

/**
 * @brief Sets the maximum combo of one column.
 * @param maxComboNum The maximum combo reached.
 * @param side The column index; ignored when greater than 1.
 * @ghidraAddress 0x87a48
 */
- (void)setMaxComboNum:(int)maxComboNum Side:(int)side;

/**
 * @brief Sets the tune name of one column.
 * @param name The tune name.
 * @param side The column index; ignored when greater than 1.
 * @ghidraAddress 0x87a70
 */
- (void)setName:(nullable NSString *)name Side:(int)side;

/**
 * @brief Composites the whole result and returns the finished share image.
 * @return The rendered share image.
 * @ghidraAddress 0x888b0
 */
- (nullable UIImage *)createImage;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
