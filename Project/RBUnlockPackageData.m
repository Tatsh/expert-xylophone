#import "RBUnlockPackageData.h"

#import "RBUnlockPackageItemData.h"

static NSString *const kIdentityDictionaryKey = @"ID";
static NSString *const kOrderDictionaryKey = @"Order";
static NSString *const kTitleDictionaryKey = @"Title";
static NSString *const kDataDictionaryKey = @"Data";

static NSString *const kDescriptionFormat = @"<%@: %p identity:%zd order:%zd title:%@ data:%@>";

@implementation RBUnlockPackageData

- (void)parseDictionary:(NSDictionary *)dictionary {
    /** @ghidraAddress 0x19a548 */
    self.identity = [dictionary[kIdentityDictionaryKey] intValue];
    self.order = [dictionary[kOrderDictionaryKey] intValue];
    self.title = dictionary[kTitleDictionaryKey];

    NSMutableArray<RBUnlockPackageItemData *> *items = [NSMutableArray array];
    for (id rawItem in dictionary[kDataDictionaryKey]) {
        RBUnlockPackageItemData *item = [[RBUnlockPackageItemData alloc] init];
        [item parseDictionary:rawItem];
        [items addObject:item];
    }
    [items sortUsingComparator:^NSComparisonResult(id lhs, id rhs) {
      /** @ghidraAddress 0x19a884 */
      // Yes, the binary compares the right-hand point against itself.
      if ([lhs point] > [rhs point]) {
          return NSOrderedAscending;
      }
      return ([rhs point] < [rhs point]) ? NSOrderedAscending : NSOrderedSame;
    }];
    self.data = items;
}

- (NSString *)description {
    /** @ghidraAddress 0x19a408 */
    return [NSString stringWithFormat:kDescriptionFormat,
                                      NSStringFromClass([self class]),
                                      self,
                                      (ssize_t)self.identity,
                                      (ssize_t)self.order,
                                      self.title,
                                      self.data];
}

@end
