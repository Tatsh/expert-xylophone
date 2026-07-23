#import "ApplilinkUtilities.h"

#import <sys/sysctl.h>

#import "ApplilinkConsts.h"
#import "NSStringURLEncoding.h"

// User-agent parameter dictionary keys.
static NSString *const kUserAgentAppliIdKey = @"ua_appli_id";
static NSString *const kUserAgentDeviceKey = @"ua_device";
static NSString *const kUserAgentOSKey = @"ua_os";
static NSString *const kUserAgentSdkKey = @"ua_sdk";
static NSString *const kUserAgentAppliVersionKey = @"ua_appli_ver";
static NSString *const kUserAgentLanguageKey = @"ua_lang";
static NSString *const kUserAgentRegionKey = @"ua_region";

// The user-agent parameter dictionary always carries these seven entries.
static const NSUInteger kUserAgentParameterCount = 7;

// SDK identity reported in the user-agent SDK field.
static NSString *const kApplilinkSdkName = @"ApplilinkNetwork";
static NSString *const kApplilinkSdkVersion = @"2.2.2";

// Fallbacks used when the device provides no locale information.
static NSString *const kDefaultLanguage = @"ja";
static NSString *const kDefaultCountryCode = @"JP";

// Query-string assembly.
static NSString *const kQueryPairSeparator = @"&";
static NSString *const kQueryStart = @"?";
static NSString *const kArrayParameterFormat = @"%@[]=%@";
static NSString *const kScalarParameterFormat = @"%@=%@";

// The sysctl key that reports the hardware model, and the exception domain and messages raised when
// reading it fails.
static const char *const kHardwareModelSysctlName = "hw.machine";
static NSString *const kDeviceNameExceptionName = @"Warn";
static NSString *const kSysctlFailureFormat = @"Failed in sysctlbyname. errno=%d";
static NSString *const kMallocFailureMessage = @"Failed in malloc in deviceName.";

// The alphabet and length of a generated impression identifier.
static NSString *const kImpressionIdAlphabet =
    @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
static const int kImpressionIdLength = 64;

// The predicate used to narrow a list by a key path, and the path separator used to trim a file
// name.
static NSString *const kNarrowListPredicateFormat = @"%K MATCHES %@";
static NSString *const kPathSeparator = @"/";

// Cached device model name; read once from the hardware sysctl.
static NSString *gApplilinkDeviceName = nil; // @ghidraAddress 0x3df610

@implementation ApplilinkUtilities

#pragma mark - Dictionaries

+ (NSDictionary *)joinDictionary:(NSDictionary *)joinDictionary
                  withDictionary:(NSDictionary *)withDictionary {
    NSMutableDictionary *merged =
        [NSMutableDictionary dictionaryWithCapacity:joinDictionary.count + withDictionary.count];
    [merged addEntriesFromDictionary:joinDictionary];
    [merged addEntriesFromDictionary:withDictionary];
    return merged;
}

+ (NSDictionary *)userAgentParametersJoinDictionary:
    (NSDictionary *)userAgentParametersJoinDictionary {
    return [self joinDictionary:userAgentParametersJoinDictionary
                 withDictionary:[self userAgentParameters]];
}

+ (NSDictionary *)userAgentParameters {
    NSString *sdk = [NSString stringWithFormat:@"%@%@", kApplilinkSdkName, kApplilinkSdkVersion];
    UIDevice *device = [UIDevice currentDevice];
    NSString *appVersion = [NSStringURLEncoding
        URLEncodedString:[[NSBundle mainBundle]
                             objectForInfoDictionaryKey:(NSString *)kCFBundleVersionKey]];
    NSString *appliId = [ApplilinkConsts appliId];
    NSString *deviceName = [NSStringURLEncoding URLEncodedString:[self deviceName]];
    NSString *osName =
        [NSString stringWithFormat:@"%@ %@", device.systemName, device.systemVersion];
    NSString *os = [NSStringURLEncoding URLEncodedString:osName];
    NSString *sdkEncoded = [NSStringURLEncoding URLEncodedString:sdk];
    NSString *language = [self localeString];
    NSString *region = [self countryCodeString];

    NSMutableDictionary *parameters =
        [NSMutableDictionary dictionaryWithCapacity:kUserAgentParameterCount];
    if (appliId) {
        parameters[kUserAgentAppliIdKey] = appliId;
    }
    if (deviceName) {
        parameters[kUserAgentDeviceKey] = deviceName;
    }
    if (os) {
        parameters[kUserAgentOSKey] = os;
    }
    if (sdkEncoded) {
        parameters[kUserAgentSdkKey] = sdkEncoded;
    }
    if (appVersion) {
        parameters[kUserAgentAppliVersionKey] = appVersion;
    }
    if (language) {
        parameters[kUserAgentLanguageKey] = language;
    }
    if (region) {
        parameters[kUserAgentRegionKey] = region;
    }
    return parameters;
}

#pragma mark - Device and locale

+ (NSString *)deviceName {
    if (gApplilinkDeviceName == nil) {
        size_t length = 0;
        if (sysctlbyname(kHardwareModelSysctlName, NULL, &length, NULL, 0) != 0) {
            [NSException raise:kDeviceNameExceptionName format:kSysctlFailureFormat, *__error()];
        }
        void *model = malloc(length);
        if (model == NULL) {
            [NSException raise:kDeviceNameExceptionName format:kMallocFailureMessage];
        }
        if (sysctlbyname(kHardwareModelSysctlName, model, &length, NULL, 0) != 0) {
            free(model);
            [NSException raise:kDeviceNameExceptionName format:kSysctlFailureFormat, *__error()];
        }
        gApplilinkDeviceName = [NSString stringWithCString:model encoding:NSUTF8StringEncoding];
        free(model);
    }
    return gApplilinkDeviceName;
}

+ (NSString *)localeString {
    NSString *language = [NSLocale preferredLanguages][0];
    if (language == nil) {
        language = kDefaultLanguage;
    }
    return language;
}

+ (NSString *)countryCodeString {
    NSString *countryCode = [[NSLocale currentLocale] objectForKey:NSLocaleCountryCode];
    if (countryCode == nil) {
        countryCode = kDefaultCountryCode;
    }
    return countryCode;
}

#pragma mark - URL parameters

+ (NSString *)appendParametersToURL:(NSString *)appendParametersToURL
                         parameters:(NSDictionary *)parameters {
    for (id key in parameters) {
        id value = [parameters valueForKey:key];
        NSMutableArray *pairs = [NSMutableArray array];
        if ([value isKindOfClass:[NSArray class]]) {
            for (NSUInteger i = 0; i < [value count]; ++i) {
                [pairs addObject:[NSString stringWithFormat:kArrayParameterFormat,
                                                            key,
                                                            [value objectAtIndex:i]]];
            }
        } else {
            [pairs addObject:[NSString stringWithFormat:kScalarParameterFormat,
                                                        key,
                                                        [parameters objectForKey:key]]];
        }
        NSString *joined = [pairs componentsJoinedByString:kQueryPairSeparator];
        NSString *lead = [appendParametersToURL rangeOfString:kQueryStart].location == NSNotFound ?
                             kQueryStart :
                             kQueryPairSeparator;
        appendParametersToURL =
            [appendParametersToURL stringByAppendingFormat:@"%@%@", lead, joined];
    }
    return appendParametersToURL;
}

#pragma mark - View hierarchy

+ (BOOL)hasParentViewController:(UIResponder *)hasParentViewController {
    // A window or application returns NO here; only a view walks the responder chain, and only a
    // view controller is treated as an attached parent. This matches the binary.
    if ([hasParentViewController isKindOfClass:[UIWindow class]]) {
        return NO;
    }
    if ([hasParentViewController isKindOfClass:[UIApplication class]]) {
        return NO;
    }
    if ([hasParentViewController isKindOfClass:[UIView class]]) {
        return [self hasParentViewController:[hasParentViewController nextResponder]];
    }
    return [hasParentViewController isKindOfClass:[UIViewController class]];
}

#pragma mark - Identifiers

+ (NSString *)getImpressionId {
    NSMutableString *impressionId = [NSMutableString stringWithCapacity:kImpressionIdLength];
    for (int i = 0; i < kImpressionIdLength; ++i) {
        u_int32_t random = arc4random();
        unichar character =
            [kImpressionIdAlphabet characterAtIndex:random % kImpressionIdAlphabet.length];
        [impressionId appendFormat:@"%C", character];
    }
    return impressionId;
}

#pragma mark - Lists and paths

+ (NSArray *)narrowedListWithList:(NSArray *)narrowedListWithList
                           object:(NSString *)object
                           forKey:(NSString *)forKey {
    NSDictionary *substitution = [NSDictionary dictionaryWithObject:object forKey:forKey];
    // The binary builds a concrete predicate from the format and then re-binds the same variables
    // through the substitution dictionary; both steps are kept.
    NSPredicate *predicate =
        [NSPredicate predicateWithFormat:kNarrowListPredicateFormat, forKey, object];
    predicate = [predicate predicateWithSubstitutionVariables:substitution];
    return [narrowedListWithList filteredArrayUsingPredicate:predicate];
}

+ (NSString *)geFileNameFromPath:(NSString *)geFileNameFromPath {
    NSRange separator = [geFileNameFromPath rangeOfString:kPathSeparator options:NSBackwardsSearch];
    if (separator.location != NSNotFound) {
        // The substring keeps the separator, matching the binary's use of the range location.
        geFileNameFromPath = [geFileNameFromPath substringFromIndex:separator.location];
    }
    return geFileNameFromPath;
}

+ (void)debugLog {
}

@end
