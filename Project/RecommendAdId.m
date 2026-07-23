#import "RecommendAdId.h"

#import <UIKit/UIKit.h>

#import "ApplilinkConsts.h"
#import "ApplilinkNetworkError.h"
#import "ApplilinkUdid.h"
#import "ApplilinkWebAPI.h"
#import "Crypto.h"

// The lowest iOS version whose ad-identifier record is stored server-side (through the Applilink
// pasteboard web API) rather than in a local device pasteboard.
static const float kRecommendAdIdServerStorageMinimumSystemVersion = 7.0f;

// Format that builds the local pasteboard name from a fixed prefix, the country code, and the
// category id: "ApplilinkRecommend.AdId_<countryCode>_<categoryId>".
static NSString *const kRecommendAdIdServiceNameFormat = @"%@_%@_%@";
static NSString *const kRecommendAdIdServiceNamePrefix = @"ApplilinkRecommend.AdId";

// The pasteboard type under which the archived record is stored on the local device pasteboard.
static NSString *const kRecommendAdIdPasteboardType = @"applilink.adid";

// Applilink pasteboard web-API endpoint paths, appended to the SSL base URL.
static NSString *const kRecommendAdIdPathGet = @"/ad/external/pasteboard/get.php";
static NSString *const kRecommendAdIdPathSet = @"/ad/external/pasteboard/set.php";
static NSString *const kRecommendAdIdPathDelete = @"/ad/external/pasteboard/delete.php";

// HTTP methods used by the pasteboard web API.
static NSString *const kRecommendAdIdHTTPMethodGet = @"GET";
static NSString *const kRecommendAdIdHTTPMethodPost = @"POST";

// Keys of the record dictionary returned to and accepted from callers.
static NSString *const kRecommendAdIdKeyCountryCode = @"CountryCode";
static NSString *const kRecommendAdIdKeyCategoryId = @"CategoryId";
static NSString *const kRecommendAdIdKeyAdIdFrom = @"AdIdFrom";
static NSString *const kRecommendAdIdKeyAdType = @"AdType";
static NSString *const kRecommendAdIdKeyEntryDate = @"EntryDate";

// Keys of the web-API request body.
static NSString *const kRecommendAdIdRequestKeyUdid = @"udid";
static NSString *const kRecommendAdIdRequestKeyCountryCode = @"country_code";
static NSString *const kRecommendAdIdRequestKeyCategoryId = @"category_id";
static NSString *const kRecommendAdIdRequestKeyAdIdFrom = @"ad_id_from";
static NSString *const kRecommendAdIdRequestKeyAdType = @"ad_type";

// Keys of the web-API response body.
static NSString *const kRecommendAdIdResponseKeyStatus = @"status";
static NSString *const kRecommendAdIdResponseKeyErrorCode = @"error_code";
static NSString *const kRecommendAdIdResponseKeyKind = @"kind";
static NSString *const kRecommendAdIdResponseKeyCountryCode = @"country_code";
static NSString *const kRecommendAdIdResponseKeyCategoryId = @"category_id";
static NSString *const kRecommendAdIdResponseKeyAdIdFrom = @"ad_id_from";
static NSString *const kRecommendAdIdResponseKeyAdType = @"ad_type";

// Response @c kind values that map an unsuccessful response to a specific Applilink error.
static NSString *const kRecommendAdIdKindAuthorization = @"authorization";
static NSString *const kRecommendAdIdKindParameterError = @"parameter_error";

// The @c NSString encoding used both for the Crypto hashing input and for its decrypted output.
static const NSStringEncoding kRecommendAdIdStringEncoding = NSUTF8StringEncoding;

// Applilink error codes passed to +localizedApplilinkErrorWithCode:[userInfo:].
enum {
    kRecommendAdIdErrorCodeGeneric = 1000,
    kRecommendAdIdErrorParameterError = 1001,        // 0x3e9
    kRecommendAdIdErrorAuthorization = 1002,         // 0x3ea
    kRecommendAdIdErrorRequestFailed = 1003,         // 0x3eb
    kRecommendAdIdErrorServerRejected = 1009,        // 0x3f1
    kRecommendAdIdErrorPasteboardUnavailable = 1013, // 0x3f5
    kRecommendAdIdErrorRecordNotFound = 1018,        // 0x3fa
    kRecommendAdIdErrorUdidUnavailable = 1028,       // 0x404
};

// Response @c error_code sentinel for a well-formed successful response, and the specific
// server-side error code the response maps to +localizedApplilinkErrorWithCode:.
enum {
    kRecommendAdIdResponseErrorCodeNone = 100000000,
    kRecommendAdIdResponseErrorCodeServerRejected = 0xc106101,
};

@interface RecommendAdId () {
    // The local device pasteboard name; also the Crypto hashing key for locally stored records.
    NSString *_serviceName;
}

/**
 * @brief Rebuild a caller-facing record dictionary by locally decrypting a stored pasteboard record.
 * @param data The archived record read from the local device pasteboard.
 * @return The decrypted record dictionary.
 * @ghidraAddress 0x203f88
 */
- (nullable NSDictionary *)convertToData:(nullable NSDictionary *)data;

/**
 * @brief Read the record for a udid, country code, and category id through the pasteboard web API.
 * @param udid The hashed advertising udid.
 * @param countryCode The country code.
 * @param categoryId The advert category identifier.
 * @param error On failure, the localised error; may be @c NULL.
 * @return The record dictionary, or @c nil on failure.
 * @ghidraAddress 0x204350
 */
- (nullable NSDictionary *)getPasteboardWithUdid:(nullable NSString *)udid
                                     countryCode:(nullable NSString *)countryCode
                                      categoryId:(nullable NSString *)categoryId
                                           error:(NSError *_Nullable *_Nullable)error;

/**
 * @brief Store the record for a udid through the pasteboard web API.
 * @param udid The hashed advertising udid.
 * @param countryCode The country code.
 * @param categoryId The advert category identifier.
 * @param adIdFrom The source advertising identifier.
 * @param adType The advert-type string.
 * @param error On failure, the localised error; may be @c NULL.
 * @ghidraAddress 0x20498c
 */
- (void)setPasteboardWithUdid:(nullable NSString *)udid
                  countryCode:(nullable NSString *)countryCode
                   categoryId:(nullable NSString *)categoryId
                     adIdFrom:(nullable NSString *)adIdFrom
                       adType:(nullable NSString *)adType
                        error:(NSError *_Nullable *_Nullable)error;

/**
 * @brief Delete the record for a udid through the pasteboard web API.
 * @param udid The hashed advertising udid.
 * @param countryCode The country code.
 * @param categoryId The advert category identifier.
 * @param error On failure, the localised error; may be @c NULL.
 * @ghidraAddress 0x204ed8
 */
- (void)deletePasteboardWithUdid:(nullable NSString *)udid
                     countryCode:(nullable NSString *)countryCode
                      categoryId:(nullable NSString *)categoryId
                           error:(NSError *_Nullable *_Nullable)error;

@end

@implementation RecommendAdId

#pragma mark - Lifecycle

/** @ghidraAddress 0x20314c */
- (instancetype)initWithCountryCode:(NSString *)countryCode categoryId:(NSString *)categoryId {
    self = [super init];
    if (self) {
        _serviceName = [NSString stringWithFormat:kRecommendAdIdServiceNameFormat,
                                                  kRecommendAdIdServiceNamePrefix,
                                                  countryCode,
                                                  categoryId];
    }
    return self;
}

#pragma mark - Public record access

/** @ghidraAddress 0x203224 */
- (NSDictionary *)getWithCountryCode:(NSString *)countryCode
                          categoryId:(NSString *)categoryId
                               error:(NSError *_Nullable *)error {
    if ([UIDevice currentDevice].systemVersion.floatValue >=
        kRecommendAdIdServerStorageMinimumSystemVersion) {
        NSString *udid = [ApplilinkUdid getAdUdid];
        if (udid == nil) {
            if (error != NULL) {
                *error = [ApplilinkNetworkError
                    localizedApplilinkErrorWithCode:kRecommendAdIdErrorUdidUnavailable];
            }
            return nil;
        }
        NSString *hashedUdid = [Crypto sha1:udid];
        NSError *requestError = nil;
        NSDictionary *record = [self getPasteboardWithUdid:hashedUdid
                                               countryCode:countryCode
                                                categoryId:categoryId
                                                     error:&requestError];
        if (requestError != nil) {
            if (error != NULL) {
                *error = requestError;
            }
            return nil;
        }
        return record;
    }
    UIPasteboard *pasteboard = [UIPasteboard pasteboardWithName:_serviceName create:NO];
    if (pasteboard == nil) {
        if (error != NULL) {
            *error = [ApplilinkNetworkError
                localizedApplilinkErrorWithCode:kRecommendAdIdErrorPasteboardUnavailable];
        }
        return nil;
    }
    id archived = [pasteboard valueForPasteboardType:kRecommendAdIdPasteboardType];
    if (archived == nil) {
        if (error != NULL) {
            *error = [ApplilinkNetworkError
                localizedApplilinkErrorWithCode:kRecommendAdIdErrorRecordNotFound];
        }
        return nil;
    }
    NSDictionary *stored = [NSKeyedUnarchiver unarchiveObjectWithData:archived];
    return [self convertToData:stored];
}

/** @ghidraAddress 0x2035f4 */
- (void)setWithAdIdFrom:(NSString *)adIdFrom
            countryCode:(NSString *)countryCode
             categoryId:(NSString *)categoryId
                 adType:(NSString *)adType
                  error:(NSError *_Nullable *)error {
    if ([UIDevice currentDevice].systemVersion.floatValue >=
        kRecommendAdIdServerStorageMinimumSystemVersion) {
        NSString *udid = [ApplilinkUdid getAdUdid];
        if (udid == nil) {
            if (error != NULL) {
                *error = [ApplilinkNetworkError
                    localizedApplilinkErrorWithCode:kRecommendAdIdErrorUdidUnavailable];
            }
            return;
        }
        NSString *hashedUdid = [Crypto sha1:udid];
        NSError *requestError = nil;
        [self setPasteboardWithUdid:hashedUdid
                        countryCode:countryCode
                         categoryId:categoryId
                           adIdFrom:adIdFrom
                             adType:adType
                              error:&requestError];
        if (requestError != nil) {
            if (error != NULL) {
                *error = requestError;
            }
            return;
        }
        NSMutableDictionary *record = [NSMutableDictionary dictionaryWithCapacity:4];
        if (countryCode != nil) {
            [record setValue:countryCode forKey:kRecommendAdIdKeyCountryCode];
        }
        if (categoryId != nil) {
            [record setValue:categoryId forKey:kRecommendAdIdKeyCategoryId];
        }
        if (adIdFrom != nil) {
            [record setValue:adIdFrom forKey:kRecommendAdIdKeyAdIdFrom];
        }
        if (adType != nil) {
            [record setValue:adType forKey:kRecommendAdIdKeyAdType];
        }
        return;
    }
    // Pre-iOS 7: build the record locally, encrypt each field with the service-name-derived key,
    // and archive it into a persistent device pasteboard.
    NSData *keyData = [_serviceName dataUsingEncoding:kRecommendAdIdStringEncoding];
    NSData *key = [Crypto createHash:keyData];
    NSData *encryptedAdIdFrom =
        [Crypto cryptorToData:0
                        value:[adIdFrom dataUsingEncoding:kRecommendAdIdStringEncoding]
                          key:key];
    NSData *encryptedCountryCode =
        [Crypto cryptorToData:0
                        value:[countryCode dataUsingEncoding:kRecommendAdIdStringEncoding]
                          key:key];
    NSData *encryptedCategoryId =
        [Crypto cryptorToData:0
                        value:[categoryId dataUsingEncoding:kRecommendAdIdStringEncoding]
                          key:key];
    NSData *encryptedAdType = nil;
    if (adType != nil) {
        encryptedAdType =
            [Crypto cryptorToData:0
                            value:[adType dataUsingEncoding:kRecommendAdIdStringEncoding]
                              key:key];
    }
    NSDate *entryDate = [NSDate date];
    NSMutableDictionary *record = [NSMutableDictionary dictionaryWithCapacity:5];
    if (encryptedAdIdFrom != nil) {
        [record setValue:encryptedAdIdFrom forKey:kRecommendAdIdKeyAdIdFrom];
    }
    if (encryptedCountryCode != nil) {
        [record setValue:encryptedCountryCode forKey:kRecommendAdIdKeyCountryCode];
    }
    if (encryptedCategoryId != nil) {
        [record setValue:encryptedCategoryId forKey:kRecommendAdIdKeyCategoryId];
    }
    if (entryDate != nil) {
        [record setValue:entryDate forKey:kRecommendAdIdKeyEntryDate];
    }
    // Yes, the binary gates on adType but stores encryptedAdType (nil above when adType is nil).
    if (adType != nil) {
        [record setValue:encryptedAdType forKey:kRecommendAdIdKeyAdType];
    }
    UIPasteboard *pasteboard = [UIPasteboard pasteboardWithName:_serviceName create:YES];
    if (pasteboard == nil) {
        if (error != NULL) {
            *error = [ApplilinkNetworkError
                localizedApplilinkErrorWithCode:kRecommendAdIdErrorPasteboardUnavailable];
        }
        return;
    }
    pasteboard.persistent = YES;
    NSData *archived = [NSKeyedArchiver archivedDataWithRootObject:record];
    [pasteboard setData:archived forPasteboardType:kRecommendAdIdPasteboardType];
    // Yes, the binary discards this decrypted round-trip; it is evaluated only for its side effects.
    [self convertToData:record];
}

/** @ghidraAddress 0x203cfc */
- (void)deleteWithCountryCode:(NSString *)countryCode
                   categoryId:(NSString *)categoryId
                        error:(NSError *_Nullable *)error {
    if ([UIDevice currentDevice].systemVersion.floatValue >=
        kRecommendAdIdServerStorageMinimumSystemVersion) {
        NSString *udid = [ApplilinkUdid getAdUdid];
        if (udid == nil) {
            if (error != NULL) {
                *error = [ApplilinkNetworkError
                    localizedApplilinkErrorWithCode:kRecommendAdIdErrorUdidUnavailable];
            }
            return;
        }
        NSString *hashedUdid = [Crypto sha1:udid];
        NSError *requestError = nil;
        [self deletePasteboardWithUdid:hashedUdid
                           countryCode:countryCode
                            categoryId:categoryId
                                 error:&requestError];
        if (requestError != nil && error != NULL) {
            *error = requestError;
        }
        return;
    }
    UIPasteboard *pasteboard = [UIPasteboard pasteboardWithName:_serviceName create:NO];
    if (pasteboard == nil) {
        if (error != NULL) {
            *error = [ApplilinkNetworkError
                localizedApplilinkErrorWithCode:kRecommendAdIdErrorPasteboardUnavailable];
        }
        return;
    }
    [pasteboard setData:nil forPasteboardType:kRecommendAdIdPasteboardType];
    [UIPasteboard removePasteboardWithName:_serviceName];
}

#pragma mark - Local record decryption

/** @ghidraAddress 0x203f88 */
- (NSDictionary *)convertToData:(NSDictionary *)data {
    NSMutableDictionary *record = [NSMutableDictionary dictionaryWithDictionary:data];
    NSData *keyData = [_serviceName dataUsingEncoding:kRecommendAdIdStringEncoding];
    NSData *key = [Crypto createHash:keyData];

    id encryptedAdIdFrom = record[kRecommendAdIdKeyAdIdFrom];
    NSString *adIdFrom = [[NSString alloc] initWithData:[Crypto cryptorToData:1
                                                                        value:encryptedAdIdFrom
                                                                          key:key]
                                               encoding:kRecommendAdIdStringEncoding];
    if (adIdFrom != nil) {
        record[kRecommendAdIdKeyAdIdFrom] = adIdFrom;
    }

    NSString *countryCode = [[NSString alloc]
        initWithData:[Crypto cryptorToData:1 value:record[kRecommendAdIdKeyCountryCode] key:key]
            encoding:kRecommendAdIdStringEncoding];
    if (countryCode != nil) {
        record[kRecommendAdIdKeyCountryCode] = countryCode;
    }

    NSString *categoryId = [[NSString alloc]
        initWithData:[Crypto cryptorToData:1 value:record[kRecommendAdIdKeyCategoryId] key:key]
            encoding:kRecommendAdIdStringEncoding];
    if (categoryId != nil) {
        record[kRecommendAdIdKeyCategoryId] = categoryId;
    }

    id encryptedAdType = record[kRecommendAdIdKeyAdType];
    // Yes, the binary gates the ad-type decryption on the AdIdFrom entry, not on the AdType entry.
    if (encryptedAdIdFrom != nil) {
        NSString *adType = [[NSString alloc] initWithData:[Crypto cryptorToData:1
                                                                          value:encryptedAdType
                                                                            key:key]
                                                 encoding:kRecommendAdIdStringEncoding];
        if (adType != nil) {
            record[kRecommendAdIdKeyAdType] = adType;
        }
    }
    return record;
}

#pragma mark - Pasteboard web API

// Map an unsuccessful pasteboard-web-API response to an Applilink error code, returning 0 when the
// response indicates success. This de-inlines the identical classification block that the binary
// repeats inline in each of the three web-API methods.
static NSInteger RecommendAdIdErrorCodeForResponse(NSDictionary *response) {
    id status = response[kRecommendAdIdResponseKeyStatus];
    if (![status isKindOfClass:[NSString class]] && ![status isKindOfClass:[NSNumber class]]) {
        status = nil;
    }
    BOOL succeeded = [status boolValue];

    id errorCodeValue = response[kRecommendAdIdResponseKeyErrorCode];
    int errorCode;
    if (([errorCodeValue isKindOfClass:[NSString class]] ||
         [errorCodeValue isKindOfClass:[NSNumber class]]) &&
        errorCodeValue != nil) {
        errorCode = [errorCodeValue intValue];
    } else {
        errorCode = kRecommendAdIdResponseErrorCodeNone;
    }

    id kind = response[kRecommendAdIdResponseKeyKind];
    if (![kind isKindOfClass:[NSString class]]) {
        kind = nil;
    }

    if (errorCode == kRecommendAdIdResponseErrorCodeNone && succeeded) {
        return 0;
    }
    if (errorCode == kRecommendAdIdResponseErrorCodeServerRejected) {
        return kRecommendAdIdErrorServerRejected;
    }
    if ([kind isEqualToString:kRecommendAdIdKindAuthorization]) {
        return kRecommendAdIdErrorAuthorization;
    }
    if ([kind isEqualToString:kRecommendAdIdKindParameterError]) {
        return kRecommendAdIdErrorParameterError;
    }
    return kRecommendAdIdErrorCodeGeneric;
}

/** @ghidraAddress 0x204350 */
- (NSDictionary *)getPasteboardWithUdid:(NSString *)udid
                            countryCode:(NSString *)countryCode
                             categoryId:(NSString *)categoryId
                                  error:(NSError *_Nullable *)error {
    NSMutableDictionary *body = [NSMutableDictionary dictionaryWithCapacity:3];
    if (udid != nil) {
        [body setValue:udid forKey:kRecommendAdIdRequestKeyUdid];
    }
    if (countryCode != nil) {
        [body setValue:countryCode forKey:kRecommendAdIdRequestKeyCountryCode];
    }
    if (categoryId != nil) {
        [body setValue:categoryId forKey:kRecommendAdIdRequestKeyCategoryId];
    }
    NSString *url = [[ApplilinkConsts baseUrlSsl] stringByAppendingString:kRecommendAdIdPathGet];
    NSError *requestError = nil;
    NSDictionary *response = [ApplilinkWebAPI requestSynchronousWithURL:url
                                                                 method:kRecommendAdIdHTTPMethodGet
                                                             parameters:body
                                                            cachePolicy:nil
                                                                  error:&requestError];
    if (requestError != nil) {
        if (error != NULL) {
            *error = requestError;
        }
        return nil;
    }
    if (response == nil) {
        if (error != NULL) {
            *error = [ApplilinkNetworkError
                localizedApplilinkErrorWithCode:kRecommendAdIdErrorRequestFailed
                                       userInfo:nil];
        }
        return nil;
    }
    NSInteger errorCode = RecommendAdIdErrorCodeForResponse(response);
    if (errorCode != 0) {
        if (error != NULL) {
            *error = [ApplilinkNetworkError localizedApplilinkErrorWithCode:errorCode
                                                                   userInfo:response];
        }
        return nil;
    }
    NSString *responseCountryCode = response[kRecommendAdIdResponseKeyCountryCode];
    NSString *responseCategoryId = response[kRecommendAdIdResponseKeyCategoryId];
    NSString *responseAdIdFrom = response[kRecommendAdIdResponseKeyAdIdFrom];
    NSString *responseAdType = response[kRecommendAdIdResponseKeyAdType];
    NSMutableDictionary *record = [NSMutableDictionary dictionaryWithCapacity:4];
    if (responseCountryCode != nil) {
        [record setValue:responseCountryCode forKey:kRecommendAdIdKeyCountryCode];
    }
    if (responseCategoryId != nil) {
        [record setValue:responseCategoryId forKey:kRecommendAdIdKeyCategoryId];
    }
    if (responseAdIdFrom != nil) {
        [record setValue:responseAdIdFrom forKey:kRecommendAdIdKeyAdIdFrom];
    }
    if (responseAdType != nil) {
        [record setValue:responseAdType forKey:kRecommendAdIdKeyAdType];
    }
    return record;
}

/** @ghidraAddress 0x20498c */
- (void)setPasteboardWithUdid:(NSString *)udid
                  countryCode:(NSString *)countryCode
                   categoryId:(NSString *)categoryId
                     adIdFrom:(NSString *)adIdFrom
                       adType:(NSString *)adType
                        error:(NSError *_Nullable *)error {
    NSMutableDictionary *body = [NSMutableDictionary dictionaryWithCapacity:5];
    if (udid != nil) {
        [body setValue:udid forKey:kRecommendAdIdRequestKeyUdid];
    }
    if (countryCode != nil) {
        [body setValue:countryCode forKey:kRecommendAdIdRequestKeyCountryCode];
    }
    if (categoryId != nil) {
        [body setValue:categoryId forKey:kRecommendAdIdRequestKeyCategoryId];
    }
    if (adIdFrom != nil) {
        [body setValue:adIdFrom forKey:kRecommendAdIdRequestKeyAdIdFrom];
    }
    if (adType != nil) {
        [body setValue:adType forKey:kRecommendAdIdRequestKeyAdType];
    }
    NSString *url = [[ApplilinkConsts baseUrlSsl] stringByAppendingString:kRecommendAdIdPathSet];
    NSError *requestError = nil;
    NSDictionary *response = [ApplilinkWebAPI requestSynchronousWithURL:url
                                                                 method:kRecommendAdIdHTTPMethodPost
                                                             parameters:body
                                                            cachePolicy:nil
                                                                  error:&requestError];
    if (requestError != nil) {
        if (error != NULL) {
            *error = requestError;
        }
        return;
    }
    if (response == nil) {
        if (error != NULL) {
            *error = [ApplilinkNetworkError
                localizedApplilinkErrorWithCode:kRecommendAdIdErrorRequestFailed
                                       userInfo:nil];
        }
        return;
    }
    NSInteger errorCode = RecommendAdIdErrorCodeForResponse(response);
    if (errorCode != 0 && error != NULL) {
        *error = [ApplilinkNetworkError localizedApplilinkErrorWithCode:errorCode
                                                               userInfo:response];
    }
}

/** @ghidraAddress 0x204ed8 */
- (void)deletePasteboardWithUdid:(NSString *)udid
                     countryCode:(NSString *)countryCode
                      categoryId:(NSString *)categoryId
                           error:(NSError *_Nullable *)error {
    NSMutableDictionary *body = [NSMutableDictionary dictionaryWithCapacity:3];
    if (udid != nil) {
        [body setValue:udid forKey:kRecommendAdIdRequestKeyUdid];
    }
    if (countryCode != nil) {
        [body setValue:countryCode forKey:kRecommendAdIdRequestKeyCountryCode];
    }
    if (categoryId != nil) {
        [body setValue:categoryId forKey:kRecommendAdIdRequestKeyCategoryId];
    }
    NSString *url = [[ApplilinkConsts baseUrlSsl] stringByAppendingString:kRecommendAdIdPathDelete];
    NSError *requestError = nil;
    NSDictionary *response = [ApplilinkWebAPI requestSynchronousWithURL:url
                                                                 method:kRecommendAdIdHTTPMethodPost
                                                             parameters:body
                                                            cachePolicy:nil
                                                                  error:&requestError];
    if (requestError != nil) {
        if (error != NULL) {
            *error = requestError;
        }
        return;
    }
    if (response == nil) {
        if (error != NULL) {
            *error = [ApplilinkNetworkError
                localizedApplilinkErrorWithCode:kRecommendAdIdErrorRequestFailed
                                       userInfo:nil];
        }
        return;
    }
    NSInteger errorCode = RecommendAdIdErrorCodeForResponse(response);
    if (errorCode != 0 && error != NULL) {
        *error = [ApplilinkNetworkError localizedApplilinkErrorWithCode:errorCode
                                                               userInfo:response];
    }
}

@end
