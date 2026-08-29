#import "HistoryData.h"

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
