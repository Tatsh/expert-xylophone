#import "RBUnlockPackageItemData.h"

static NSString *const kIdentityDictionaryKey = @"ID";
static NSString *const kNameDictionaryKey = @"Name";
static NSString *const kPathDictionaryKey = @"Path";
static NSString *const kPointDictionaryKey = @"Point";
static NSString *const kTypeDictionaryKey = @"Type";

static NSString *const kDescriptionFormat =
    @"<%@: %p type:%zd identity:%zd name:%@ path:%@ point:%zd>";

@implementation RBUnlockPackageItemData

#ifdef ENABLE_PATCHES
// Price every item at nothing so the affordability test in -[RBUnlockView yesButtonTap:] passes.
- (int)point {
    return 0;
}
#endif

- (void)parseDictionary:(NSDictionary *)dictionary {
    /** @ghidraAddress 0x19a168 */
    self.identity = [dictionary[kIdentityDictionaryKey] intValue];
    self.name = dictionary[kNameDictionaryKey];
    self.path = dictionary[kPathDictionaryKey];
    self.point = [dictionary[kPointDictionaryKey] intValue];
    self.type = [dictionary[kTypeDictionaryKey] intValue];
}

- (NSString *)description {
    /** @ghidraAddress 0x19a014 */
    return [NSString stringWithFormat:kDescriptionFormat,
                                      NSStringFromClass([self class]),
                                      self,
                                      (ssize_t)self.type,
                                      (ssize_t)self.identity,
                                      self.name,
                                      self.path,
                                      (ssize_t)self.point];
}

@end
