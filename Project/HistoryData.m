//
//  HistoryData.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class HistoryData). Verified against the
//  arm64 disassembly (the achievement-rate helper returns its result through the soft-float path
//  and the convert-date time interval is passed through the same path, both of which the decompiler
//  drops).
//

#import "HistoryData.h"

// Collaborator class reached from the initialiser. Its header is not yet reconstructed in this
// tree; the import resolves once that class lands, matching the speculative-import style already
// used by ScoreData.m and ReplayData.m.
#import "History.h"

@implementation HistoryData

#pragma mark - Lifecycle

- (instancetype)initWithData:(id)source {
    /** @ghidraAddress 0x17fcc */
    self = [super init];
    if (source && self) {
        self.chksco = [[source chksco] copy];
        self.score = [[source score] copy];
        self.cntCom = [[source cntCom] copy];
        self.cntGood = [[source cntGood] copy];
        self.cntGreat = [[source cntGreat] copy];
        self.cntJR = [[source cntJR] copy];
        self.cntJust = [[source cntJust] copy];
        self.cntMiss = [[source cntMiss] copy];
        self.ar = [History getAR:source];
        self.diff = [[source diff] copy];
        self.playDate = [HistoryData convertLocalDate:[source playDate]];
        self.pc = [[source pc] copy];
        self.tuneID = [[source tuneID] copy];
    }
    return self;
}

#pragma mark - Date helpers

+ (NSDate *)convertLocalDate:(NSDate *)date {
    /** @ghidraAddress 0x18530 */
    if (!date) {
        return nil;
    }
    NSInteger secondsFromGMT = [[NSTimeZone systemTimeZone] secondsFromGMTForDate:date];
    return [date dateByAddingTimeInterval:(NSTimeInterval)secondsFromGMT];
}

@end
