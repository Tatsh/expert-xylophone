//
//  RBUrlSchemeInfoController.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RBUrlSchemeInfoController).
//  Verified against the arm64 disassembly: -action:query: resolves a <action>RbAction: selector at
//  run time and calls its IMP directly, and -webRbAction: builds the web-info URL from the query's
//  id parameter.
//

#import "RBUrlSchemeInfoController.h"

#import "AppDelegate.h"

// GetRegionCode() -> NSString* two-letter region code appended as the target parameter.
#import "neEngineBridge.h"

// The format used to derive a handler selector name from a routed action, for example
// @c webRbAction: for the @c web action.
// @ghidraAddress 0x361940 (the format-string literal)
static NSString *const kActionSelectorFormat = @"%@RbAction:";

// The query-dictionary key naming the web identifier passed to -webRbAction:.
// @ghidraAddress 0x361960 (the key literal)
static NSString *const kWebActionQueryKeyID = @"id";

// The smallest web identifier -webRbAction: treats as valid.
static const int kMinimumWebID = 1;

// The query-string separator and the parameter fragments -webRbAction: appends to the base URL.
// @ghidraAddress 0x36d9a0 (the query-string separator literal)
// @ghidraAddress 0x36d9c0 (the web-id parameter literal)
// @ghidraAddress 0x36d9e0 (the target parameter literal)
static NSString *const kQueryStringSeparator = @"?";
static NSString *const kWebIDParameter = @"?webId=";
static NSString *const kTargetParameter = @"&target=";

// A dynamically resolved handler takes the query dictionary and returns a BOOL, matching the
// -webRbAction: shape.
typedef BOOL (*RBUrlSchemeActionIMP)(id, SEL, id);

@implementation RBUrlSchemeInfoController

#pragma mark - RBUrlSchemeControllerProtocol

- (BOOL)action:(NSString *)action query:(NSDictionary *)query {
    /** @ghidraAddress 0x176604 */
    SEL handler = NSSelectorFromString([NSString stringWithFormat:kActionSelectorFormat, action]);
    if (![self respondsToSelector:handler]) {
        return NO;
    }
    RBUrlSchemeActionIMP handlerImp = (RBUrlSchemeActionIMP)[self methodForSelector:handler];
    return handlerImp(self, handler, query);
}

#pragma mark - Actions

- (BOOL)webRbAction:(NSDictionary *)query {
    /** @ghidraAddress 0x17671c */
    NSString *webID = query[kWebActionQueryKeyID];
    if (!webID || webID.intValue < kMinimumWebID) {
        return NO;
    }

    NSMutableString *webInfoURL =
        [[AppDelegate appDelegate] getBaseWebInfoURL].absoluteString.mutableCopy;
    if ([webInfoURL rangeOfString:kQueryStringSeparator].location == NSNotFound) {
        [webInfoURL appendString:kWebIDParameter];
        [webInfoURL appendString:webID];
        [webInfoURL appendString:kTargetParameter];
        [webInfoURL appendString:GetRegionCode()];
        [[AppDelegate appDelegate] setWebInfoURL:webInfoURL];
    }
    return YES;
}

@end
