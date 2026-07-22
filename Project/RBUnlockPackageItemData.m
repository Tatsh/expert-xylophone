//
//  RBUnlockPackageItemData.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RBUnlockPackageItemData). Verified
//  against the arm64 disassembly (the description is a variadic stringWithFormat: whose %zd slots
//  the decompiler cannot fully recover, so the argument order was read from the store order on the
//  outgoing stack).
//

#import "RBUnlockPackageItemData.h"

/// Entry-dictionary keys for a single unlock item.
static NSString *const kIdentityDictionaryKey = @"ID";
static NSString *const kNameDictionaryKey = @"Name";
static NSString *const kPathDictionaryKey = @"Path";
static NSString *const kPointDictionaryKey = @"Point";
static NSString *const kTypeDictionaryKey = @"Type";

/// The debug description format: class, address, type, identifier, name, path, and point.
static NSString *const kDescriptionFormat =
    @"<%@: %p type:%zd identity:%zd name:%@ path:%@ point:%zd>";

@implementation RBUnlockPackageItemData

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
    return [NSString stringWithFormat:kDescriptionFormat, NSStringFromClass([self class]), self,
                                      self.type, self.identity, self.name, self.path, self.point];
}

@end

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
