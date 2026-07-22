//
//  ReplayNote.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class ReplayNote). Verified against the
//  arm64 disassembly (the coder msgSends are variadic and dropped by the decompiler).
//

#import "ReplayNote.h"

/// Archive keys for each field; each matches its property name.
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
    // The slide sub-result is only archived when present.
    if (self.slide) {
        [aCoder encodeObject:self.slide forKey:kSlideCoderKey];
    }
}

@end

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
