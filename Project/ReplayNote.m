#import "ReplayNote.h"

static NSString *const kIndexCoderKey = @"index";
static NSString *const kTypeCoderKey = @"type";
static NSString *const kJudgeCoderKey = @"judge";
static NSString *const kJrCoderKey = @"jr";
static NSString *const kLongrateCoderKey = @"longrate";
static NSString *const kSlideCoderKey = @"slide";

@implementation ReplayNote

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    /** @ghidraAddress 0x1069f8 */
    self = [super init];
    if (self) {
        self.index = [aDecoder decodeObjectForKey:kIndexCoderKey];
        self.type = [aDecoder decodeObjectForKey:kTypeCoderKey];
        self.judge = [aDecoder decodeObjectForKey:kJudgeCoderKey];
        self.jr = [aDecoder decodeObjectForKey:kJrCoderKey];
        self.longrate = [aDecoder decodeObjectForKey:kLongrateCoderKey];
        self.slide = [aDecoder decodeObjectForKey:kSlideCoderKey];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    /** @ghidraAddress 0x106c44 */
    [aCoder encodeObject:self.index forKey:kIndexCoderKey];
    [aCoder encodeObject:self.type forKey:kTypeCoderKey];
    [aCoder encodeObject:self.judge forKey:kJudgeCoderKey];
    [aCoder encodeObject:self.jr forKey:kJrCoderKey];
    [aCoder encodeObject:self.longrate forKey:kLongrateCoderKey];
    if (self.slide) {
        [aCoder encodeObject:self.slide forKey:kSlideCoderKey];
    }
}

@end
