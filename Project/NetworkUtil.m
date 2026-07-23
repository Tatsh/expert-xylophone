//
//  NetworkUtil.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class NetworkUtil). Verified against the
//  arm64 disassembly (the stringWithFormat: argument lists are variadic and dropped by the
//  decompiler).
//

#import "NetworkUtil.h"

#import "neEngineBridge.h"

// The secure API endpoint scheme, host, and the common CGI base path every endpoint is built under.
static NSString *const kSecureAPIScheme = @"https";
static NSString *const kSecureAPIHost = @"akx.s.konaminet.jp";
static NSString *const kSecureAPIBasePath = @"/akx/main/cgi/";

// The APNs device-token registration endpoint, relative to the CGI base path.
static NSString *const kTokenSetAPIPath = @"push/token/";

// The searchable-spot campaign-master and list endpoints, relative to the CGI base path.
static NSString *const kSearchMasterAPIPath = @"search_master/";
static NSString *const kSearchListAPIPath = @"gamecenter/";

// The device user-info query and the searchable-spot master query format strings.
static NSString *const kUserInfoFormat = @"uuid=%@&version=%@&device=%@&os=%@&locale=%@";
static NSString *const kSearchMasterParamFormat = @"target=%@&%@";

@interface NetworkUtil ()
// The common device fingerprint query appended to authenticated requests.
+ (NSString *)userInfo;
@end

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

+ (NSString *)userInfo {
    return [NSString stringWithFormat:kUserInfoFormat,
                                      [NetworkUtil identifierParams],
                                      GetBundleVersionString(),
                                      [NetworkUtil deviceName],
                                      GetSystemVersionString(),
                                      GetFormattedVersionString()];
}

+ (NSURL *)searchMasterURL {
    NSString *param = [NSString
        stringWithFormat:kSearchMasterParamFormat, GetRegionCode(), [NetworkUtil userInfo]];
    return [NetworkUtil createSecureAPI:kSearchMasterAPIPath withParam:param];
}

+ (NSURL *)searchURL {
    return [NetworkUtil createSecureAPI:kSearchListAPIPath withParam:nil];
}

@end
