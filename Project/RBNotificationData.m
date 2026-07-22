//
//  RBNotificationData.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RBNotificationData). Verified
//  against the arm64 disassembly (the coder msgSends are variadic and dropped by the decompiler).
//

#import "RBNotificationData.h"

/// The archive key under which the payload dictionary is encoded and decoded.
static NSString *const kNotificationListCoderKey = @"notificationList";

@implementation RBNotificationData

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    /** @ghidraAddress 0x39c38 */
    self = [super init];
    if (self) {
        self.notificationDict = [aDecoder decodeObjectForKey:kNotificationListCoderKey];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    /** @ghidraAddress 0x39d1c */
    [aCoder encodeObject:self.notificationDict forKey:kNotificationListCoderKey];
}

@end

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
