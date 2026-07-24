/** @file
 * A small value object holding one score row's fields for the Twitter share image: the score,
 * achievement rate, per-judgement note counts, maximum combo, and the tune name. One instance
 * represents a single side (the local player or a rival) of the two-column result layout drawn by
 * @c TwitterImageCreater.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class TwitterImageCreaterScoreElement,
 * image base 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief One score row's values for the Twitter share image.
 */
@interface TwitterImageCreaterScoreElement : NSObject

/**
 * @brief The final score.
 */
@property(nonatomic, assign) int score;

/**
 * @brief The achievement rate.
 */
@property(nonatomic, assign) float ar;

/**
 * @brief The number of JUST judgements.
 */
@property(nonatomic, assign) int justNum;

/**
 * @brief The number of GREAT judgements.
 */
@property(nonatomic, assign) int greatNum;

/**
 * @brief The number of GOOD judgements.
 */
@property(nonatomic, assign) int goodNum;

/**
 * @brief The number of MISS judgements.
 */
@property(nonatomic, assign) int missNum;

/**
 * @brief The number of JUST REFLEC judgements.
 */
@property(nonatomic, assign) int justReflecNum;

/**
 * @brief The maximum combo reached.
 */
@property(nonatomic, assign) int maxComboNum;

/**
 * @brief The tune name.
 */
@property(nonatomic, strong, nullable) NSString *name;

/**
 * @brief Clears the tune name back to @c nil.
 * @ghidraAddress 0x87770
 */
- (void)reset;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
