//
//  RBUrlSchemeManager.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RBUrlSchemeManager). Verified
//  against the arm64 disassembly (the -stringWithFormat: handler-class name build and the
//  fast-enumeration query-parsing loop are partly obscured by the decompiler).
//

#import "RBUrlSchemeManager.h"

#import "RBUrlSchemeControllerProtocol.h"

// Per-host handler classes resolved by name at run time via NSClassFromString. They adopt
// RBUrlSchemeControllerProtocol and are not necessarily reconstructed in this tree yet, so they are
// referenced only through the protocol; these speculative imports resolve once those classes land.
#import "RBUrlSchemeInfoController.h"
#import "RBUrlSchemeStoreController.h"

// The format used to build a per-host handler class name from the URL host (its first letter
// capitalised), for example @c RBUrlSchemeInfoController.
// @ghidraAddress 0x33e7fb (the format-string literal)
static NSString *const kHandlerClassNameFormat = @"RBUrlScheme%@Controller";

// The number of leading host characters capitalised to form the handler class name.
static const NSUInteger kHandlerHostPrefixLength = 1;

// The separators used to split a query string: @c & between key-value pairs and @c = within a
// pair.
// @ghidraAddress 0x32f9fb (the pair separator literal)
// @ghidraAddress 0x338511 (the key-value separator literal)
static NSString *const kQueryPairSeparator = @"&";
static NSString *const kQueryKeyValueSeparator = @"=";

// The indices of the key and value within a split query pair.
enum {
    kRBUrlSchemeQueryPairIndexKey = 0,
    kRBUrlSchemeQueryPairIndexValue = 1,
};

@implementation RBUrlSchemeManager

#pragma mark - Singleton

+ (instancetype)sharedManager {
    /** @ghidraAddress 0x168174 */
    static RBUrlSchemeManager *sharedManager = nil;
    if (!sharedManager) {
        sharedManager = [[RBUrlSchemeManager alloc] init];
    }
    return sharedManager;
}

#pragma mark - Routing

- (BOOL)parseURL:(NSURL *)url {
    // Build the handler class name from the URL host, capitalising its first letter.
    NSString *host = url.host;
    NSString *capitalisedPrefix =
        [host substringToIndex:kHandlerHostPrefixLength].capitalizedString;
    NSString *capitalisedHost =
        [host stringByReplacingCharactersInRange:NSMakeRange(0, kHandlerHostPrefixLength)
                                      withString:capitalisedPrefix];
    NSString *handlerClassName =
        [NSString stringWithFormat:kHandlerClassNameFormat, capitalisedHost];
    Class handlerClass = NSClassFromString(handlerClassName);

    // Only a handler conforming to the scheme-controller protocol is dispatched to.
    if (![handlerClass conformsToProtocol:@protocol(RBUrlSchemeControllerProtocol)]) {
        return NO;
    }

    id<RBUrlSchemeControllerProtocol> handler = [[handlerClass alloc] init];
    if (!handler) {
        return NO;
    }

    NSString *action = url.lastPathComponent;
    NSDictionary *query = [self dictionaryFromQueryString:url.query];
    return [handler action:action query:query];
}

- (NSDictionary *)dictionaryFromQueryString:(NSString *)queryString {
    if (!queryString) {
        return nil;
    }

    NSMutableDictionary *result = [[NSMutableDictionary alloc] initWithCapacity:0];
    NSArray *pairs = [queryString componentsSeparatedByString:kQueryPairSeparator];
    if (!pairs || pairs.count == 0) {
        return nil;
    }

    for (NSString *pair in pairs) {
        NSArray *keyValue = [pair componentsSeparatedByString:kQueryKeyValueSeparator];
        NSString *value = keyValue[kRBUrlSchemeQueryPairIndexValue];
        NSString *key = keyValue[kRBUrlSchemeQueryPairIndexKey];
        [result setObject:value forKey:key];
    }
    return result;
}

@end
