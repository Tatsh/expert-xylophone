#import <CoreFoundation/CoreFoundation.h>
#import <UIKit/UIKit.h>

#import "NSData+RB.h"

static NSString *const kPropertyListModernAPIVersion = @"4.0";

static const NSStringCompareOptions kVersionCompareOptions = NSNumericSearch;

static BOOL RBHasModernPropertyListAPI(void) {
    NSComparisonResult order =
        [[UIDevice currentDevice].systemVersion compare:kPropertyListModernAPIVersion
                                                options:kVersionCompareOptions];
    return order != NSOrderedAscending;
}

static CFPropertyListRef RBCreatePropertyList(NSData *data) {
    // Both parsers request an immutable tree; a mutable result is copied out afterwards.
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
