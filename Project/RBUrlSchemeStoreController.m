//
//  RBUrlSchemeStoreController.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RBUrlSchemeStoreController).
//  Verified against the arm64 disassembly: -action:query: resolves a <action>RbAction: selector at
//  run time and calls its IMP directly, and the -packRbAction:/-campaignRbAction:/-seqRbAction:
//  handlers read the query's id parameter and store it on the app delegate.
//

#import "RBUrlSchemeStoreController.h"

#import "AppDelegate.h"

// The format used to derive a handler selector name from a routed action, for example
// @c packRbAction: for the @c pack action.
// @ghidraAddress 0x361940 (the format-string literal)
static NSString *const kActionSelectorFormat = @"%@RbAction:";

// The query-dictionary key naming the store identifier passed to each handler.
// @ghidraAddress 0x361960 (the key literal)
static NSString *const kStoreActionQueryKeyID = @"id";

// The smallest store identifier a handler treats as valid.
static const int kMinimumStoreID = 1;

// A dynamically resolved handler takes the query dictionary and returns a BOOL, matching the
// -packRbAction: shape.
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
