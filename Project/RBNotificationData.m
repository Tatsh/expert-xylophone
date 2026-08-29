#import "RBNotificationData.h"

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
