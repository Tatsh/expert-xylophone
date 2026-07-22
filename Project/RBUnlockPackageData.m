//
//  RBUnlockPackageData.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RBUnlockPackageData). Verified
//  against the arm64 disassembly (the fast-enumeration parse and the sort comparator are garbled by
//  the decompiler; the comparator's self-compare was confirmed as a genuine binary bug, not a
//  decompiler artefact, from the instruction operands).
//

#import "RBUnlockPackageData.h"

#import "RBUnlockPackageItemData.h"

/// Catalogue-dictionary keys for a package.
static NSString *const kIdentityDictionaryKey = @"ID";
static NSString *const kOrderDictionaryKey = @"Order";
static NSString *const kTitleDictionaryKey = @"Title";
static NSString *const kDataDictionaryKey = @"Data";

/// The debug description format: class, address, identifier, order, title, and item list.
static NSString *const kDescriptionFormat =
    @"<%@: %p identity:%zd order:%zd title:%@ data:%@>";

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
        // Orders a higher point value first. As in the shipped build, the else branch compares the
        // right-hand item's point against itself, so it can only ever report the two items as equal.
        if ([lhs point] > [rhs point]) {
            return NSOrderedAscending;
        }
        return ([rhs point] < [rhs point]) ? NSOrderedAscending : NSOrderedSame;
    }];
    self.data = items;
}

- (NSString *)description {
    /** @ghidraAddress 0x19a408 */
    return [NSString stringWithFormat:kDescriptionFormat, NSStringFromClass([self class]), self,
                                      self.identity, self.order, self.title, self.data];
}

@end

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
