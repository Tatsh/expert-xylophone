#import "RBUrlSchemeInfoController.h"

#import "AppDelegate.h"
#import "deviceenvironment.h"

// @ghidraAddress 0x361940 (the format-string literal)
static NSString *const kActionSelectorFormat = @"%@RbAction:";

// @ghidraAddress 0x361960 (the key literal)
static NSString *const kWebActionQueryKeyID = @"id";

static const int kMinimumWebID = 1;

// @ghidraAddress 0x36d9a0 (the query-string separator literal)
// @ghidraAddress 0x36d9c0 (the web-id parameter literal)
// @ghidraAddress 0x36d9e0 (the target parameter literal)
static NSString *const kQueryStringSeparator = @"?";
static NSString *const kWebIDParameter = @"?webId=";
static NSString *const kTargetParameter = @"&target=";

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
