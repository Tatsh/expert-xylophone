/** @file
 * One archived note event within a replay: its lane index, kind, judgement, and the long/slide
 * sub-results. Encoded and decoded as part of a ReplayData ghost.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class ReplayNote, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <Foundation/Foundation.h>

/**
 * @brief A single archivable replay note event.
 */
@interface ReplayNote : NSObject <NSCoding>

/**
 * @brief The note's index within the chart.
 * @ghidraAddress 0x106e4c (getter)
 * @ghidraAddress 0x106e5c (setter)
 */
@property(nonatomic, strong) NSNumber *index;
/**
 * @brief The note kind.
 * @ghidraAddress 0x106e94 (getter)
 * @ghidraAddress 0x106ea4 (setter)
 */
@property(nonatomic, strong) NSNumber *type;
/**
 * @brief The judgement result recorded for the note.
 * @ghidraAddress 0x106edc (getter)
 * @ghidraAddress 0x106eec (setter)
 */
@property(nonatomic, strong) NSNumber *judge;
/**
 * @brief The Just Reflec sub-result.
 * @ghidraAddress 0x106f24 (getter)
 * @ghidraAddress 0x106f34 (setter)
 */
@property(nonatomic, strong) NSNumber *jr;
/**
 * @brief The long-note completion rate.
 * @ghidraAddress 0x106f6c (getter)
 * @ghidraAddress 0x106f7c (setter)
 */
@property(nonatomic, strong) NSNumber *longrate;
/**
 * @brief The slide-note sub-result (optional; omitted from the archive when nil).
 * @ghidraAddress 0x106fb4 (getter)
 * @ghidraAddress 0x106fc4 (setter)
 */
@property(nonatomic, strong) NSNumber *slide;

@end

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
