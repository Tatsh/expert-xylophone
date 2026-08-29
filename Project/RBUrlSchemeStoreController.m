#import "RBUrlSchemeStoreController.h"

#import "AppDelegate.h"

// @ghidraAddress 0x361940 (the format-string literal)
static NSString *const kActionSelectorFormat = @"%@RbAction:";

// @ghidraAddress 0x361960 (the key literal)
static NSString *const kStoreActionQueryKeyID = @"id";

static const int kMinimumStoreID = 1;

typedef BOOL (*RBUrlSchemeActionIMP)(id, SEL, id);

@implementation RBUrlSchemeStoreController

#pragma mark - RBUrlSchemeControllerProtocol

- (BOOL)action:(NSString *)action query:(NSDictionary *)query {
    /** @ghidraAddress 0x5550 */
    SEL handler = NSSelectorFromString([NSString stringWithFormat:kActionSelectorFormat, action]);
    if (![self respondsToSelector:handler]) {
        return NO;
    }
    RBUrlSchemeActionIMP handlerImp = (RBUrlSchemeActionIMP)[self methodForSelector:handler];
    return handlerImp(self, handler, query);
}

#pragma mark - Actions

- (BOOL)packRbAction:(NSDictionary *)query {
    /** @ghidraAddress 0x5668 */
    NSString *storeID = query[kStoreActionQueryKeyID];
    if (!storeID || storeID.intValue < kMinimumStoreID) {
        return NO;
    }
    [AppDelegate appDelegate].packIDForOpenStore = storeID;
    return YES;
}

- (BOOL)campaignRbAction:(NSDictionary *)query {
    /** @ghidraAddress 0x5744 */
    NSString *storeID = query[kStoreActionQueryKeyID];
    if (!storeID || storeID.intValue < kMinimumStoreID) {
        return NO;
    }
    [AppDelegate appDelegate].campaignIDForOpenStore = storeID;
    return YES;
}

- (BOOL)seqRbAction:(NSDictionary *)query {
    /** @ghidraAddress 0x5820 */
    NSString *storeID = query[kStoreActionQueryKeyID];
    if (!storeID || storeID.intValue < kMinimumStoreID) {
        return NO;
    }
    [AppDelegate appDelegate].extendNotePIDForOpenStore = storeID;
    return YES;
}

@end
