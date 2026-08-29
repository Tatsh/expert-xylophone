#import <CoreFoundation/CoreFoundation.h>
#import <UIKit/UIKit.h>

#import "NSArray+RB.h"

// The iOS version at and above which CFPropertyListCreateWithData is available.
static NSString *const kPropertyListModernAPIVersion = @"4.0";

static const NSStringCompareOptions kVersionCompareOptions = NSNumericSearch;

static BOOL RBHasModernPropertyListAPI(void) {
    NSComparisonResult order =
        [[UIDevice currentDevice].systemVersion compare:kPropertyListModernAPIVersion
                                                options:kVersionCompareOptions];
    return order != NSOrderedAscending;
}

static CFPropertyListRef RBCreatePropertyList(NSData *data) {
    if (RBHasModernPropertyListAPI()) {
        return CFPropertyListCreateWithData(
            kCFAllocatorDefault, (__bridge CFDataRef)data, kCFPropertyListImmutable, NULL, NULL);
    }
    return CFPropertyListCreateFromXMLData(
        kCFAllocatorDefault, (__bridge CFDataRef)data, kCFPropertyListImmutable, NULL);
}

@implementation NSArray (RB)

+ (NSArray *)arrayFromPropertyListData:(NSData *)data {
    /** @ghidraAddress 0x12f410 */
    id plist = CFBridgingRelease(RBCreatePropertyList(data));
    if (![plist isKindOfClass:[NSArray class]]) {
        return nil;
    }
    return [[NSArray alloc] initWithArray:plist];
}

@end
