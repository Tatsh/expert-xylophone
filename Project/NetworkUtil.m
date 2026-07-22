//
//  NetworkUtil.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class NetworkUtil). Verified against the
//  arm64 disassembly (the stringWithFormat: argument lists are variadic and dropped by the
//  decompiler).
//

#import "NetworkUtil.h"

/// The secure API endpoint scheme, host, and the common CGI base path every endpoint is built under.
static NSString *const kSecureAPIScheme = @"https";
static NSString *const kSecureAPIHost = @"akx.s.konaminet.jp";
static NSString *const kSecureAPIBasePath = @"/akx/main/cgi/";

/// The APNs device-token registration endpoint, relative to the CGI base path.
static NSString *const kTokenSetAPIPath = @"push/token/";

@implementation NetworkUtil

+ (NSURL *)createSecureURL:(NSString *)path {
    return [[NSURL alloc] initWithScheme:kSecureAPIScheme host:kSecureAPIHost path:path];
}

+ (NSURL *)createSecureAPI:(NSString *)api withParam:(NSString *)param {
    NSString *path;
    if (param) {
        path = [NSString stringWithFormat:@"%@%@?%@", kSecureAPIBasePath, api, param];
    } else {
        path = [NSString stringWithFormat:@"%@%@", kSecureAPIBasePath, api];
    }
    return [NetworkUtil createSecureURL:path];
}

+ (NSURL *)tokenSetURL {
    return [NetworkUtil createSecureAPI:kTokenSetAPIPath withParam:nil];
}

@end

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
