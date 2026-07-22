/** @file
 * A single play-history entry: the tune, difficulty, score, judgement tallies, achievement rate,
 * play date, and play count for one recorded play. The class copies its fields from a score-like
 * source, derives its achievement rate through @c History, and shifts the play date into the
 * device's local time zone.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class HistoryData, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <Foundation/Foundation.h>

/**
 * @brief One entry in a player's play history, initialised from a score-like source record.
 */
@interface HistoryData : NSObject

/**
 * @brief The tamper-detection hash copied from the source record.
 * @ghidraAddress 0x18610 (getter)
 * @ghidraAddress 0x18620 (setter)
 */
@property(nonatomic, strong) NSData *chksco;
/**
 * @brief The score achieved.
 * @ghidraAddress 0x18658 (getter)
 * @ghidraAddress 0x18668 (setter)
 */
@property(nonatomic, strong) NSNumber *score;
/**
 * @brief The combo count.
 * @ghidraAddress 0x186a0 (getter)
 * @ghidraAddress 0x186b0 (setter)
 */
@property(nonatomic, strong) NSNumber *cntCom;
/**
 * @brief The Good count.
 * @ghidraAddress 0x186e8 (getter)
 * @ghidraAddress 0x186f8 (setter)
 */
@property(nonatomic, strong) NSNumber *cntGood;
/**
 * @brief The Great count.
 * @ghidraAddress 0x18730 (getter)
 * @ghidraAddress 0x18740 (setter)
 */
@property(nonatomic, strong) NSNumber *cntGreat;
/**
 * @brief The Just Reflec count.
 * @ghidraAddress 0x18778 (getter)
 * @ghidraAddress 0x18788 (setter)
 */
@property(nonatomic, strong) NSNumber *cntJR;
/**
 * @brief The Just count.
 * @ghidraAddress 0x187c0 (getter)
 * @ghidraAddress 0x187d0 (setter)
 */
@property(nonatomic, strong) NSNumber *cntJust;
/**
 * @brief The Miss count.
 * @ghidraAddress 0x18808 (getter)
 * @ghidraAddress 0x18818 (setter)
 */
@property(nonatomic, strong) NSNumber *cntMiss;
/**
 * @brief The achievement rate, derived from the source record's judgement tallies by @c History.
 * @ghidraAddress 0x18850 (getter)
 * @ghidraAddress 0x18860 (setter)
 */
@property(nonatomic, assign) float ar;
/**
 * @brief The difficulty the tune was played on.
 * @ghidraAddress 0x18870 (getter)
 * @ghidraAddress 0x18880 (setter)
 */
@property(nonatomic, strong) NSNumber *diff;
/**
 * @brief The date the tune was played, shifted into the device's local time zone.
 * @ghidraAddress 0x188b8 (getter)
 * @ghidraAddress 0x188c8 (setter)
 */
@property(nonatomic, strong) NSDate *playDate;
/**
 * @brief The play count.
 * @ghidraAddress 0x18900 (getter)
 * @ghidraAddress 0x18910 (setter)
 */
@property(nonatomic, strong) NSNumber *pc;
/**
 * @brief The tune identifier this history entry belongs to.
 * @ghidraAddress 0x18948 (getter)
 * @ghidraAddress 0x18958 (setter)
 */
@property(nonatomic, strong) NSNumber *tuneID;

/**
 * @brief Initialises a history entry by copying its fields from a score-like source record.
 * @param source The source record whose fields are copied; its judgement tallies drive the
 * achievement rate and its play date is shifted into the local time zone.
 * @return The initialised entry, or an entry with unset fields when @p source is @c nil.
 * @ghidraAddress 0x17fcc
 */
- (instancetype)initWithData:(id)source;

/**
 * @brief Shifts a date from UTC into the device's local time zone.
 * @param date The date to convert.
 * @return A date offset by the local time zone's seconds from GMT, or @c nil when @p date is
 * @c nil.
 * @ghidraAddress 0x18530
 */
+ (NSDate *)convertLocalDate:(NSDate *)date;

@end

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
