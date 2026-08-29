#import "RBUrlSchemeManager.h"

#import "RBUrlSchemeControllerProtocol.h"

// These per-host handler classes are resolved by name at run time and used only through the
// protocol.
#import "RBUrlSchemeInfoController.h"
#import "RBUrlSchemeStoreController.h"

// @ghidraAddress 0x33e7fb
static NSString *const kHandlerClassNameFormat = @"RBUrlScheme%@Controller";

static const NSUInteger kHandlerHostPrefixLength = 1;

// @ghidraAddress 0x32f9fb
// @ghidraAddress 0x338511
static NSString *const kQueryPairSeparator = @"&";
static NSString *const kQueryKeyValueSeparator = @"=";

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
    NSString *host = url.host;
    NSString *capitalisedPrefix =
        [host substringToIndex:kHandlerHostPrefixLength].capitalizedString;
    NSString *capitalisedHost =
        [host stringByReplacingCharactersInRange:NSMakeRange(0, kHandlerHostPrefixLength)
                                      withString:capitalisedPrefix];
    NSString *handlerClassName =
        [NSString stringWithFormat:kHandlerClassNameFormat, capitalisedHost];
    Class handlerClass = NSClassFromString(handlerClassName);

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
