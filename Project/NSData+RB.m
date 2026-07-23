//
//  NSData+RB.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (category NSData(RB)). Verified against
//  the arm64 disassembly (the Core Foundation property-list creators are variadic-shaped and their
//  option and format arguments are dropped by the decompiler, so the immutability option was
//  recovered from the register setup, where x2 through x4 are all zero).
//

#import <CoreFoundation/CoreFoundation.h>
#import <UIKit/UIKit.h>

#import "NSData+RB.h"

// The iOS version at and above which @c CFPropertyListCreateWithData is available; earlier systems
// fall back to @c CFPropertyListCreateFromXMLData.
static NSString *const kPropertyListModernAPIVersion = @"4.0";

// Comparison options used to order two dotted version strings numerically.
static const NSStringCompareOptions kVersionCompareOptions = NSNumericSearch;

// Whether the running system provides @c CFPropertyListCreateWithData (iOS 4.0 or newer).
static BOOL RBHasModernPropertyListAPI(void) {
    NSComparisonResult order =
        [[UIDevice currentDevice].systemVersion compare:kPropertyListModernAPIVersion
                                                options:kVersionCompareOptions];
    return order != NSOrderedAscending;
}

// Deserialises XML property-list bytes into an immutable property-list object, selecting the Core
// Foundation parser that matches the running iOS version.
static CFPropertyListRef RBCreatePropertyList(NSData *data) {
    // Both parsers request an immutable tree; the mutable collection returned to the caller is
    // produced afterwards by copying into a fresh mutable container.
    if (RBHasModernPropertyListAPI()) {
        return CFPropertyListCreateWithData(
            kCFAllocatorDefault, (__bridge CFDataRef)data, kCFPropertyListImmutable, NULL, NULL);
    }
    return CFPropertyListCreateFromXMLData(
        kCFAllocatorDefault, (__bridge CFDataRef)data, kCFPropertyListImmutable, NULL);
}

@implementation NSData (RB)

- (NSDictionary *)dictionary {
    /** @ghidraAddress 0x1a4470 */
    id plist = CFBridgingRelease(RBCreatePropertyList(self));
    if (![plist isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    return [NSDictionary dictionaryWithDictionary:plist];
}

- (NSMutableArray *)mutableArray {
    /** @ghidraAddress 0x1a45f8 */
    id plist = CFBridgingRelease(RBCreatePropertyList(self));
    if (![plist isKindOfClass:[NSArray class]]) {
        return nil;
    }
    return [[NSMutableArray alloc] initWithArray:plist];
}

@end
