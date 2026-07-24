//
//  ApplilinkUdid.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class ApplilinkUdid). This is a plain
//  Objective-C file: the advertising-identifier framework is reached through NSClassFromString and
//  NSSelectorFromString, the keychain through the Security framework's SecItem C API, and the MD5
//  digest through CommonCrypto, so there is no C++.
//
//  ApplilinkUdid is the Applilink reward-network SDK's device-identifier manager. It is a lazily
//  created singleton whose +sharedInstance owns a serial dispatch queue and one ApplilinkPasteBoard;
//  every operation is a class method that routes through that shared pasteboard and the keychain.
//
//  In the KONAMI PopnRhythmin build this class is RewardNetworkUdid; rb458 renamed it to
//  ApplilinkUdid and added a few nil guards, but the algorithms match.
//

#import "ApplilinkUdid.h"

#import <CommonCrypto/CommonDigest.h>
#import <Security/Security.h>

#import "ApplilinkCore.h"
#import "ApplilinkNetworkError.h"
#import "ApplilinkPasteBoard.h"

// The Applilink error codes this class reports. They index into the localised-message table owned
// by ApplilinkNetworkError.
typedef enum {
    kApplilinkUdidErrorNoData = 0x3f4,             // No stored UDID data.
    kApplilinkUdidErrorWriteFailed = 0x3f7,        // A pasteboard or keychain write failed.
    kApplilinkUdidErrorNotDictionary = 0x3f8,      // A keychain record was not a dictionary.
    kApplilinkUdidErrorIndexOutOfRange = 0x3f9,    // A reward UDID index was out of range.
    kApplilinkUdidErrorValidateNotDict = 0x3fb,    // Validation: record is not a dictionary.
    kApplilinkUdidErrorValidateNoAccount = 0x3fc,  // Validation: missing account field.
    kApplilinkUdidErrorValidateNoCreated = 0x3fd,  // Validation: missing creation-date field.
    kApplilinkUdidErrorValidateNoModified = 0x3fe, // Validation: missing modification-date field.
    kApplilinkUdidErrorValidateNoGeneric = 0x3ff,  // Validation: missing generic (count) field.
    kApplilinkUdidErrorValidateExpired = 0x400, // Validation: the record's use count is exhausted.
    kApplilinkUdidErrorDeleteFailed = 0x402,    // A keychain delete failed.
} ApplilinkUdidErrorCode;

// The number of keychain and pasteboard storage slots swept when deleting every UDID.
static const int kApplilinkUdidStorageIndexCount = 0x100;

// The oldest operating-system version that exposes the advertising-identifier framework.
static const float kApplilinkUdidAdSupportMinOSVersion = 6.1f;

// The reward-network UDID type selectors passed to
// +getUdidWithService:storageIndex:rewardNetworkUDIDType:error:.
typedef enum {
    kApplilinkUdidRewardNetworkTypeOld = 0,
    kApplilinkUdidRewardNetworkTypeAdvertising = 1,
} ApplilinkUdidRewardNetworkType;

// The keychain account key that records the storage index for the advertising service.
static NSString *const kApplilinkUdidAdStorageIndexKey = @"adStorageIndex";
// The default storage index used when the keychain holds no account string.
static NSString *const kApplilinkUdidDefaultStorageIndex = @"0";

// The base service names, combined with the server environment by +getServiceName(Old).
static NSString *const kApplilinkUdidAdvertisingServiceName = @"ApplilinkAdUdid";
static NSString *const kApplilinkUdidOldServiceName = @"ApplilinkUdid";

// The NSUserDefaults key holding the server environment name.
static NSString *const kApplilinkUdidEnvKey = @"ApplilinkNetwork.env";
// The environment value selecting the production server (no service-name prefix).
static NSString *const kApplilinkUdidEnvProduction = @"0";
// The NSUserDefaults key holding the pasteboard reward storage index.
static NSString *const kApplilinkUdidRewardStorageIndexKey = @"ApplilinkReward.storageIndex";

// Format strings combining a service name with an environment prefix or a storage index.
static NSString *const kApplilinkUdidEnvServiceFormat = @"%@_%@";
static NSString *const kApplilinkUdidServiceIndexFormat = @"%@-%@";
static NSString *const kApplilinkUdidServiceIndexNumberFormat = @"%@-%d";
// The format used to build one hex byte of an MD5 digest.
static NSString *const kApplilinkUdidHexByteFormat = @"%02x";
// The separator splitting a keychain access group into its bundle-seed identifier prefix.
static NSString *const kApplilinkUdidAccessGroupSeparator = @".";

// Parameter dictionary keys used when attaching UDIDs to a request.
static NSString *const kApplilinkUdidParamKeyUdid = @"udid";
static NSString *const kApplilinkUdidParamKeyOldUdid = @"old_udid";
// The pasteboard record key holding the stored UDID value.
static NSString *const kApplilinkUdidPasteBoardValueKey = @"Value";

// The name of the serial dispatch queue backing the singleton and pasteboard.
static NSString *const kApplilinkUdidQueueName = @"ApplilinkUdid";

// The all-zero advertising identifier returned when tracking is disabled; the MD5 hash is skipped
// for it.
static NSString *const kApplilinkUdidNullAdvertisingIdentifier =
    @"00000000-0000-0000-0000-000000000000";

// The advertising-identifier framework is reached by name so it does not appear in the binary's
// import table. The stored names are each shifted forward by one character; decoding subtracts one
// from every byte to recover "ASIdentifierManager", "advertisingIdentifier", "sharedManager", and
// "UUIDString".
static NSString *const kApplilinkUdidEncodedIdentifierManagerClass = @"BTJefoujgjfsNbobhfs";
static NSString *const kApplilinkUdidEncodedAdvertisingIdentifierSelector =
    @"bewfsujtjohJefoujgjfs";

// Decode a Caesar-shifted name by subtracting one from each byte.
static NSString *ApplilinkUdidDecodeShiftedName(NSString *encoded) {
    const char *bytes = [encoded cStringUsingEncoding:NSASCIIStringEncoding];
    NSMutableData *decoded = [NSMutableData dataWithLength:strlen(bytes)];
    char *out = (char *)decoded.mutableBytes;
    for (size_t i = 0; bytes[i] != '\0'; ++i) {
        out[i] = (char)(bytes[i] - 1);
    }
    return [NSString stringWithCString:out encoding:NSASCIIStringEncoding];
}

@implementation ApplilinkUdid

#pragma mark Lifecycle

/** @ghidraAddress 0x22b7c4 */
+ (instancetype)allocWithZone:(struct _NSZone *)zone {
    static dispatch_once_t onceToken;
    static ApplilinkUdid *instance = nil;
    dispatch_once(&onceToken, ^{
      /** @ghidraAddress 0x22b83c */
      // The binary lazily creates the shared serial queue here and allocates the singleton
      // through the superclass, returning the just-allocated instance for +sharedInstance to
      // finish initialising.
      instance = [super allocWithZone:zone];
    });
    return instance;
}

/** @ghidraAddress 0x22b8c4 */
+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    static ApplilinkUdid *instance = nil;
    dispatch_once(&onceToken, ^{
      /** @ghidraAddress 0x22b908 */
      instance = [[ApplilinkUdid alloc] init];
      instance.pasteBoard = [[ApplilinkPasteBoard alloc] init];
    });
    return instance;
}

/** @ghidraAddress 0x22b5f0 */
- (instancetype)init {
    // The binary runs [super init] synchronously on the shared serial queue.
    __block ApplilinkUdid *initialized = nil;
    dispatch_sync(dispatch_queue_create(kApplilinkUdidQueueName.UTF8String, NULL), ^{
      /** @ghidraAddress 0x22b700 */
      initialized = [super init];
    });
    return initialized;
}

#pragma mark UDID pasteboard storage

/** @ghidraAddress 0x22b9ac */
+ (NSDictionary *)writeUDIDForFirstEmptyLocationWithError:(NSError **)error {
    ApplilinkUdid *shared = [ApplilinkUdid sharedInstance];
    NSDictionary *storageData = shared.pasteBoard.storageData;
    NSString *udid = storageData[kApplilinkUdidPasteBoardValueKey];
    if (udid == nil) {
        // No stored value: mint a fresh UUID.
        CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
        udid = (__bridge_transfer NSString *)CFUUIDCreateString(kCFAllocatorDefault, uuid);
        CFRelease(uuid);
    }
    NSError *writeError = nil;
    NSDictionary *written = [shared.pasteBoard writeStorageData:udid error:&writeError];
    if (written == nil) {
        if (error != NULL) {
            *error = [ApplilinkNetworkError
                localizedApplilinkErrorWithCode:kApplilinkUdidErrorWriteFailed];
        }
    } else {
        shared.pasteBoard.nonPasteBoardUdidFlag = NO;
    }
    return written;
}

/** @ghidraAddress 0x22bb94 */
+ (NSDictionary *)writeUDIDForFirstEmptyLocationWithUdid:(NSString *)udid {
    ApplilinkUdid *shared = [ApplilinkUdid sharedInstance];
    NSDictionary *written = [shared.pasteBoard writeStorageData:udid error:NULL];
    if (written != nil) {
        [ApplilinkUdid sharedInstance].pasteBoard.nonPasteBoardUdidFlag = NO;
    }
    return written;
}

/** @ghidraAddress 0x22bcc0 */
+ (NSDictionary *)writeUDIDWithUdid:(NSString *)udid {
    ApplilinkUdid *shared = [ApplilinkUdid sharedInstance];
    NSString *serviceName = [ApplilinkUdid getServiceName];
    NSError *readError = nil;
    NSDictionary *existing = [shared.pasteBoard storageDataWithServiceName:serviceName
                                                              storageIndex:0
                                                                     error:&readError];
    if (existing != nil) {
        [shared.pasteBoard deleteWithStorageIndex:0 error:&readError];
    }
    NSDictionary *written = [shared.pasteBoard writeStorageData:udid
                                                   storageIndex:0
                                                          error:&readError];
    if (written != nil) {
        [ApplilinkUdid sharedInstance].pasteBoard.nonPasteBoardUdidFlag = NO;
    }
    return written;
}

/** @ghidraAddress 0x22bee8 */
+ (NSDictionary *)udidWithServiceName:(NSString *)serviceName
                         storageIndex:(int)storageIndex
                                error:(NSError **)error {
    ApplilinkUdid *shared = [ApplilinkUdid sharedInstance];
    NSDictionary *data = [shared.pasteBoard storageDataWithServiceName:serviceName
                                                          storageIndex:storageIndex
                                                                 error:NULL];
    if (data == nil && error != NULL) {
        *error = [ApplilinkNetworkError localizedApplilinkErrorWithCode:kApplilinkUdidErrorNoData];
    }
    return data;
}

/** @ghidraAddress 0x22c00c */
+ (NSDictionary *)udidForFirstInvalidDataWithError:(NSError **)error {
    NSDictionary *data = [ApplilinkUdid sharedInstance].pasteBoard.storageData;
    if (data == nil && error != NULL) {
        *error = [ApplilinkNetworkError localizedApplilinkErrorWithCode:kApplilinkUdidErrorNoData];
    }
    return data;
}

/** @ghidraAddress 0x22c0d8 */
+ (NSDictionary *)udidOldForFirstInvalidDataWithError:(NSError **)error {
    NSDictionary *data = [ApplilinkUdid sharedInstance].pasteBoard.storageDataOld;
    if (data == nil && error != NULL) {
        *error = [ApplilinkNetworkError localizedApplilinkErrorWithCode:kApplilinkUdidErrorNoData];
    }
    return data;
}

/** @ghidraAddress 0x22c1a4 */
+ (BOOL)deleteUDIDWithServiceName:(NSString *)serviceName
                     storageIndex:(int)storageIndex
                            error:(NSError **)error {
    NSString *env = [[NSUserDefaults standardUserDefaults] objectForKey:kApplilinkUdidEnvKey];
    if (env != nil && ![env isEqualToString:kApplilinkUdidEnvProduction]) {
        NSError *deleteError = nil;
        [[ApplilinkUdid sharedInstance].pasteBoard deleteWithStorageIndex:storageIndex
                                                                    error:&deleteError];
        if (deleteError != nil) {
            *error = deleteError;
            return NO;
        }
    }
    return YES;
}

/** @ghidraAddress 0x22c2f4 */
+ (void)deleteAllUDID {
    ApplilinkPasteBoard *pasteBoard = [[ApplilinkPasteBoard alloc] init];
    NSString *serviceName = [pasteBoard getServiceName];
    for (int index = 0; index < kApplilinkUdidStorageIndexCount; ++index) {
        NSError *readError = nil;
        NSDictionary *data = [ApplilinkUdid udidWithServiceName:serviceName
                                                   storageIndex:index
                                                          error:&readError];
        if (data != nil && readError == nil) {
            NSError *deleteError = nil;
            [ApplilinkUdid deleteUDIDWithServiceName:serviceName
                                        storageIndex:index
                                               error:&deleteError];
        }
    }
    NSString *oldServiceName = [pasteBoard getServiceNameOld];
    for (int index = 0; index < kApplilinkUdidStorageIndexCount; ++index) {
        NSError *readError = nil;
        NSDictionary *data = [ApplilinkUdid udidWithServiceName:oldServiceName
                                                   storageIndex:index
                                                          error:&readError];
        if (data != nil && readError == nil) {
            NSError *deleteError = nil;
            [ApplilinkUdid deleteUDIDWithServiceName:oldServiceName
                                        storageIndex:index
                                               error:&deleteError];
        }
    }
}

#pragma mark Advertising reward UDID

/** @ghidraAddress 0x22c508 */
+ (NSString *)getAdvertisingRewardUdidWithError:(NSError **)error {
    if (![ApplilinkUdid isAdvertisingTrackingOSVersion]) {
        return nil;
    }
    NSString *serviceName = [ApplilinkUdid getServiceName];
    NSString *storageIndex = [ApplilinkUdid getServiceIndex:kApplilinkUdidAdStorageIndexKey];
    NSError *readError = nil;
    NSDictionary *record =
        [ApplilinkUdid getUdidWithService:serviceName
                             storageIndex:storageIndex
                    rewardNetworkUDIDType:kApplilinkUdidRewardNetworkTypeAdvertising
                                    error:&readError];
    if (readError != nil || record == nil) {
        *error = readError;
        return [ApplilinkUdid getAdvertisingUdid];
    }
    return (NSString *)record;
}

/** @ghidraAddress 0x22c63c */
+ (NSString *)createAdvertisingRewardUdidWithError:(NSError **)error {
    if (![ApplilinkUdid isAdvertisingTrackingOSVersion]) {
        return nil;
    }
    NSString *serviceName = [ApplilinkUdid getServiceName];
    NSString *storageIndex = [ApplilinkUdid getServiceIndex:kApplilinkUdidAdStorageIndexKey];
    NSError *readError = nil;
    NSString *storedUdid =
        (NSString *)[ApplilinkUdid getUdidWithService:serviceName
                                         storageIndex:storageIndex
                                rewardNetworkUDIDType:kApplilinkUdidRewardNetworkTypeAdvertising
                                                error:&readError];
    NSString *newUdid = [ApplilinkUdid getAdvertisingUdid];
    if (storedUdid == nil) {
        NSError *setError = readError;
        [ApplilinkUdid setNewUdid:newUdid error:&setError];
        if (setError != nil) {
            *error = [ApplilinkNetworkError
                localizedApplilinkErrorWithCode:kApplilinkUdidErrorWriteFailed];
        }
        [ApplilinkCore clearInitialize];
        return newUdid;
    }
    if (![storedUdid isEqualToString:newUdid]) {
        NSError *oldError = readError;
        [ApplilinkUdid setOldUdid:storedUdid error:&oldError];
        NSError *newError = oldError;
        [ApplilinkUdid setNewUdid:newUdid error:&newError];
        [ApplilinkCore clearInitialize];
        *error = nil;
        return newUdid;
    }
    return storedUdid;
}

/** @ghidraAddress 0x22c8b8 */
+ (BOOL)deleteAdvertisingRewardUdidIndex:(int)index error:(NSError **)error {
    if (index >= kApplilinkUdidStorageIndexCount) {
        if (error == NULL) {
            return NO;
        }
        *error = [ApplilinkNetworkError
            localizedApplilinkErrorWithCode:kApplilinkUdidErrorIndexOutOfRange];
        return NO;
    }
    NSString *serviceKey = [NSString stringWithFormat:kApplilinkUdidServiceIndexNumberFormat,
                                                      [ApplilinkUdid getServiceName],
                                                      index];
    NSError *deleteError = nil;
    [ApplilinkUdid deleteKeyChainService:serviceKey error:&deleteError];
    if (deleteError == nil) {
        return YES;
    }
    if (error == NULL) {
        return NO;
    }
    *error = deleteError;
    return NO;
}

/** @ghidraAddress 0x22c9f0 */
+ (void)deleteAllAdvertisingUDID {
    for (int index = 0; index < kApplilinkUdidStorageIndexCount; ++index) {
        NSError *deleteError = nil;
        [ApplilinkUdid deleteAdvertisingRewardUdidIndex:index error:&deleteError];
    }
}

#pragma mark Old and new UDID

/** @ghidraAddress 0x22ca54 */
+ (BOOL)setOldUdid:(NSString *)oldUdid error:(NSError **)error {
    NSString *serviceKey = [NSString stringWithFormat:kApplilinkUdidServiceIndexFormat,
                                                      [ApplilinkUdid getServiceNameOld],
                                                      kApplilinkUdidDefaultStorageIndex];
    return [ApplilinkUdid setUdidWithService:serviceKey withUDID:oldUdid];
}

/** @ghidraAddress 0x22cb28 */
+ (NSString *)getOldUdidWithError:(NSError **)error {
    NSString *serviceName = [ApplilinkUdid getServiceNameOld];
    return (NSString *)[ApplilinkUdid getUdidWithService:serviceName
                                            storageIndex:kApplilinkUdidDefaultStorageIndex
                                   rewardNetworkUDIDType:kApplilinkUdidRewardNetworkTypeOld
                                                   error:error];
}

/** @ghidraAddress 0x22cba4 */
+ (BOOL)deleteOldUdidWithError:(NSError **)error {
    NSString *serviceKey = [NSString stringWithFormat:kApplilinkUdidServiceIndexFormat,
                                                      [ApplilinkUdid getServiceNameOld],
                                                      kApplilinkUdidDefaultStorageIndex];
    NSError *deleteError = nil;
    [ApplilinkUdid deleteKeyChainService:serviceKey error:&deleteError];
    if (deleteError == nil) {
        return YES;
    }
    if (error == NULL) {
        return NO;
    }
    *error = deleteError;
    return NO;
}

/** @ghidraAddress 0x22cc98 */
+ (BOOL)setNewUdid:(NSString *)newUdid error:(NSError **)error {
    NSString *storageIndex = [ApplilinkUdid getServiceIndex:kApplilinkUdidAdStorageIndexKey];
    NSString *serviceName = [ApplilinkUdid getServiceName];
    if (storageIndex == nil || storageIndex.length == 0) {
        storageIndex = kApplilinkUdidDefaultStorageIndex;
    }
    NSString *serviceKey =
        [NSString stringWithFormat:kApplilinkUdidServiceIndexFormat, serviceName, storageIndex];
    [ApplilinkCore setAdUdid:newUdid];
    BOOL stored = [ApplilinkUdid setUdidWithService:serviceKey withUDID:newUdid];
    if (stored) {
        [ApplilinkUdid setService:kApplilinkUdidAdStorageIndexKey withStorageIndex:storageIndex];
    }
    return stored;
}

#pragma mark Keychain access

/** @ghidraAddress 0x22ce18 */
+ (BOOL)setUdidWithService:(NSString *)service withUDID:(NSString *)udid {
    NSDate *now = [NSDate date];
    NSNumber *initialUseCount = @1;
    if (udid == nil) {
        return NO;
    }
    if ([ApplilinkUdid searchWithService:service] != nil) {
        // Replace any stale record before adding the new one.
        NSError *deleteError = nil;
        [ApplilinkUdid deleteKeyChainService:service error:&deleteError];
    }
    NSDictionary *query = @{
        (__bridge id)kSecClass : (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrAccount : udid,
        (__bridge id)kSecAttrService : service,
        (__bridge id)kSecAttrCreationDate : now,
        (__bridge id)kSecAttrModificationDate : now,
        (__bridge id)kSecAttrGeneric : initialUseCount,
    };
    SecItemAdd((__bridge CFDictionaryRef)query, NULL);
    return YES;
}

/** @ghidraAddress 0x22d040 */
+ (NSDictionary *)getUdidWithService:(NSString *)service
                        storageIndex:(NSString *)storageIndex
               rewardNetworkUDIDType:(int)rewardNetworkUDIDType
                               error:(NSError **)error {
    (void)[NSDate date]; // Yes, the binary evaluates and discards [NSDate date] here.
    if (storageIndex != nil) {
        (void)storageIndex.length; // Yes, the binary reads and discards the length here.
    }
    NSString *serviceKey =
        [NSString stringWithFormat:kApplilinkUdidServiceIndexFormat, service, storageIndex];
    NSDictionary *record = [ApplilinkUdid searchWithService:serviceKey];
    if (record == nil) {
        return nil;
    }
    NSMutableDictionary *attributes = [NSMutableDictionary dictionaryWithDictionary:record];
    NSError *validateError = nil;
    if (![ApplilinkUdid validate:record error:&validateError]) {
        if (error != NULL) {
            *error = [ApplilinkNetworkError
                localizedApplilinkErrorWithCode:kApplilinkUdidErrorNotDictionary];
        }
        return nil;
    }
    NSString *account = attributes[(__bridge id)kSecAttrAccount];
    if (![account isKindOfClass:[NSString class]]) {
        account = nil;
    }
    NSDictionary *matchQuery = @{
        (__bridge id)kSecClass : (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService : serviceKey,
    };
    NSDictionary *update = @{
        (__bridge id)kSecAttrModificationDate : [NSDate date],
    };
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)matchQuery, NULL);
    if (status == errSecSuccess) {
        SecItemUpdate((__bridge CFDictionaryRef)matchQuery, (__bridge CFDictionaryRef)update);
    }
    return account != nil ? attributes : nil;
}

/** @ghidraAddress 0x22d3ec */
+ (NSDictionary *)searchWithService:(NSString *)service {
    if (service == nil) {
        return nil;
    }
    NSDictionary *query = @{
        (__bridge id)kSecClass : (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecMatchLimit : (__bridge id)kSecMatchLimitOne,
        (__bridge id)kSecReturnAttributes : (__bridge id)kCFBooleanTrue,
        (__bridge id)kSecAttrService : service,
    };
    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    if (status != errSecSuccess) {
        return nil;
    }
    return (__bridge_transfer NSDictionary *)result;
}

/** @ghidraAddress 0x22d52c */
+ (BOOL)deleteKeyChainService:(NSString *)service error:(NSError **)error {
    if ([ApplilinkUdid searchWithService:service] != nil) {
        NSDictionary *query = @{
            (__bridge id)kSecClass : (__bridge id)kSecClassGenericPassword,
            (__bridge id)kSecReturnAttributes : (__bridge id)kCFBooleanTrue,
            (__bridge id)kSecAttrService : service,
        };
        OSStatus status = SecItemDelete((__bridge CFDictionaryRef)query);
        if (status != errSecSuccess) {
            if (error != NULL) {
                *error = [ApplilinkNetworkError
                    localizedApplilinkErrorWithCode:kApplilinkUdidErrorDeleteFailed];
            }
            return NO;
        }
    }
    return YES;
}

/** @ghidraAddress 0x22d69c */
+ (BOOL)validate:(NSDictionary *)attributes error:(NSError **)error {
    if (![attributes isKindOfClass:[NSDictionary class]]) {
        if (error == NULL) {
            return NO;
        }
        *error = [ApplilinkNetworkError
            localizedApplilinkErrorWithCode:kApplilinkUdidErrorValidateNotDict];
        return NO;
    }
    if (attributes[(__bridge id)kSecAttrAccount] == nil) {
        if (error == NULL) {
            return NO;
        }
        *error = [ApplilinkNetworkError
            localizedApplilinkErrorWithCode:kApplilinkUdidErrorValidateNoAccount];
        return NO;
    }
    if (attributes[(__bridge id)kSecAttrCreationDate] == nil) {
        if (error == NULL) {
            return NO;
        }
        *error = [ApplilinkNetworkError
            localizedApplilinkErrorWithCode:kApplilinkUdidErrorValidateNoCreated];
        return NO;
    }
    if (attributes[(__bridge id)kSecAttrModificationDate] == nil) {
        if (error == NULL) {
            return NO;
        }
        *error = [ApplilinkNetworkError
            localizedApplilinkErrorWithCode:kApplilinkUdidErrorValidateNoModified];
        return NO;
    }
    NSNumber *useCount = attributes[(__bridge id)kSecAttrGeneric];
    if (useCount == nil) {
        if (error == NULL) {
            return NO;
        }
        *error = [ApplilinkNetworkError
            localizedApplilinkErrorWithCode:kApplilinkUdidErrorValidateNoGeneric];
        return NO;
    }
    if (useCount.intValue > 0) {
        return YES;
    }
    if (error == NULL) {
        return NO;
    }
    *error =
        [ApplilinkNetworkError localizedApplilinkErrorWithCode:kApplilinkUdidErrorValidateExpired];
    return NO;
}

/** @ghidraAddress 0x22d980 */
+ (NSString *)getServiceIndex:(NSString *)service {
    NSDictionary *query = @{
        (__bridge id)kSecClass : (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecMatchLimit : (__bridge id)kSecMatchLimitOne,
        (__bridge id)kSecReturnAttributes : (__bridge id)kCFBooleanTrue,
        (__bridge id)kSecAttrService : service,
    };
    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    if (status != errSecSuccess) {
        return kApplilinkUdidDefaultStorageIndex;
    }
    NSDictionary *attributes = (__bridge_transfer NSDictionary *)result;
    NSString *account = attributes[(__bridge id)kSecAttrAccount];
    if (![account isKindOfClass:[NSString class]]) {
        return kApplilinkUdidDefaultStorageIndex;
    }
    return account;
}

/** @ghidraAddress 0x22db4c */
+ (void)setService:(NSString *)service withStorageIndex:(NSString *)storageIndex {
    NSError *deleteError = nil;
    [ApplilinkUdid deleteKeyChainService:service error:&deleteError];
    NSDictionary *query = @{
        (__bridge id)kSecClass : (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrAccount : storageIndex,
        (__bridge id)kSecAttrService : service,
    };
    SecItemAdd((__bridge CFDictionaryRef)query, NULL);
}

#pragma mark Advertising identifier

/** @ghidraAddress 0x22dcac */
+ (NSString *)getCFUUID {
    CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
    NSString *uuidString =
        (__bridge_transfer NSString *)CFUUIDCreateString(kCFAllocatorDefault, uuid);
    CFRelease(uuid);
    return uuidString;
}

/** @ghidraAddress 0x22dcf8 */
+ (NSString *)getAdvertisingUdid {
    if (![ApplilinkUdid isAdvertisingTrackingOSVersion]) {
        return nil;
    }
    NSString *adUdid = [ApplilinkUdid getAdUdid];
    if ([adUdid isEqualToString:kApplilinkUdidNullAdvertisingIdentifier]) {
        return nil;
    }
    return [ApplilinkUdid md5WithString:adUdid];
}

/** @ghidraAddress 0x22ddac */
+ (BOOL)isAdvertisingTrackingEnabled {
    if (![ApplilinkUdid isAdvertisingTrackingOSVersion]) {
        return YES;
    }
    id identifierManager = [NSClassFromString(ApplilinkUdidDecodeShiftedName(
        kApplilinkUdidEncodedIdentifierManagerClass)) performSelector:@selector(sharedManager)];
    return (BOOL)[identifierManager performSelector:@selector(isAdvertisingTrackingEnabled)];
}

/** @ghidraAddress 0x22de2c */
+ (BOOL)isAdvertisingTrackingOSVersion {
    return [UIDevice currentDevice].systemVersion.floatValue >= kApplilinkUdidAdSupportMinOSVersion;
}

/** @ghidraAddress 0x22dec0 */
+ (NSString *)md5WithString:(NSString *)string {
    if (string == nil) {
        return nil;
    }
    const char *data = string.UTF8String;
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5(data, (CC_LONG)strlen(data), digest);
    NSMutableString *hex = [NSMutableString stringWithCapacity:0x20];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; ++i) {
        [hex appendFormat:kApplilinkUdidHexByteFormat, digest[i]];
    }
    return hex;
}

#pragma mark UDID parameters and state

/** @ghidraAddress 0x22dfd8 */
+ (BOOL)setUdidParameters:(id)udidParameters isUDIDPriorityType:(int)isUDIDPriorityType {
    NSString *adUdid = [ApplilinkCore ad_udid];
    NSString *udid = [ApplilinkCore udid];
    NSString *oldUdid = [ApplilinkCore old_udid];
    NSString *pasteBoardUdid = [ApplilinkCore pasteBoard_udid];
    if (adUdid == nil && udid == nil && oldUdid == nil) {
        [ApplilinkCore clearInitialize];
        return NO;
    }
    if ([ApplilinkUdid isAdvertisingTrackingOSVersion]) {
        // Advertising tracking is available: prefer the advertising UDID.
        if (adUdid == nil) {
            [ApplilinkCore clearInitialize];
            return NO;
        }
        [udidParameters setValue:adUdid forKey:kApplilinkUdidParamKeyUdid];
        NSString *secondaryUdid;
        if (isUDIDPriorityType == 0) {
            secondaryUdid = (udid == nil || [adUdid isEqualToString:udid]) ? oldUdid : udid;
        } else if (isUDIDPriorityType == kApplilinkUdidRewardNetworkTypeAdvertising) {
            secondaryUdid = oldUdid;
        } else if (isUDIDPriorityType == 2 && udid != nil &&
                   ![udid isEqualToString:pasteBoardUdid]) {
            secondaryUdid = pasteBoardUdid;
        } else {
            secondaryUdid = nil;
        }
        if (![adUdid isEqualToString:secondaryUdid]) {
            [udidParameters setValue:secondaryUdid forKey:kApplilinkUdidParamKeyOldUdid];
        }
        return YES;
    }
    // Advertising tracking is unavailable: fall back to the current UDID.
    if (udid == nil) {
        if (oldUdid != nil) {
            [udidParameters setValue:oldUdid forKey:kApplilinkUdidParamKeyUdid];
        } else {
            return NO;
        }
    } else {
        [udidParameters setValue:udid forKey:kApplilinkUdidParamKeyUdid];
        if (oldUdid != nil && ![oldUdid isEqualToString:udid]) {
            [udidParameters setValue:oldUdid forKey:kApplilinkUdidParamKeyOldUdid];
        }
    }
    if (isUDIDPriorityType == 2 && udid != nil && ![udid isEqualToString:pasteBoardUdid]) {
        [udidParameters setValue:pasteBoardUdid forKey:kApplilinkUdidParamKeyOldUdid];
    }
    return YES;
}

/** @ghidraAddress 0x22e2cc */
+ (BOOL)setUdidParameters:(id)udidParameters {
    NSString *adUdid = [ApplilinkCore ad_udid];
    NSString *udid = [ApplilinkCore udid];
    NSString *oldUdid = [ApplilinkCore old_udid];
    if (adUdid == nil && udid == nil && oldUdid == nil) {
        return NO;
    }
    NSString *primaryUdid;
    if ([ApplilinkUdid isAdvertisingTrackingOSVersion]) {
        primaryUdid = adUdid;
    } else {
        primaryUdid = (udid == nil) ? oldUdid : udid;
    }
    if (primaryUdid == nil) {
        return NO;
    }
    [udidParameters setValue:primaryUdid forKey:kApplilinkUdidParamKeyUdid];
    return YES;
}

/** @ghidraAddress 0x22e42c */
+ (BOOL)isUdidThreeKinds {
    NSString *adUdid = [ApplilinkCore ad_udid];
    NSString *udid = [ApplilinkCore udid];
    NSString *oldUdid = [ApplilinkCore old_udid];
    if (adUdid == nil || udid == nil || oldUdid == nil) {
        return NO;
    }
    if ([adUdid isEqualToString:udid]) {
        return NO;
    }
    if ([oldUdid isEqualToString:udid]) {
        return NO;
    }
    return ![adUdid isEqualToString:oldUdid];
}

/** @ghidraAddress 0x22e52c */
+ (BOOL)isUdidSDKPasteBoard {
    NSString *udid = [ApplilinkCore udid];
    NSString *pasteBoardUdid = [ApplilinkCore pasteBoard_udid];
    if (udid == nil || pasteBoardUdid == nil) {
        return NO;
    }
    return ![udid isEqualToString:pasteBoardUdid];
}

/** @ghidraAddress 0x22e5d4 */
+ (NSString *)getServiceName {
    NSString *env = [[NSUserDefaults standardUserDefaults] objectForKey:kApplilinkUdidEnvKey];
    if ([env isEqualToString:kApplilinkUdidEnvProduction]) {
        return kApplilinkUdidAdvertisingServiceName;
    }
    return [NSString
        stringWithFormat:kApplilinkUdidEnvServiceFormat, env, kApplilinkUdidAdvertisingServiceName];
}

/** @ghidraAddress 0x22e6bc */
+ (NSString *)getServiceNameOld {
    NSString *env = [[NSUserDefaults standardUserDefaults] objectForKey:kApplilinkUdidEnvKey];
    if ([env isEqualToString:kApplilinkUdidEnvProduction]) {
        return kApplilinkUdidOldServiceName;
    }
    return [NSString
        stringWithFormat:kApplilinkUdidEnvServiceFormat, env, kApplilinkUdidOldServiceName];
}

/** @ghidraAddress 0x22e7a4 */
+ (void)setUdidKeychainFromPasteBoard {
    NSString *storedIndex =
        [[NSUserDefaults standardUserDefaults] stringForKey:kApplilinkUdidRewardStorageIndexKey];
    NSString *serviceName = [ApplilinkUdid getServiceName];
    if (storedIndex != nil) {
        NSDictionary *record = [ApplilinkUdid udidWithServiceName:serviceName
                                                     storageIndex:storedIndex.intValue
                                                            error:NULL];
        if (record != nil) {
            [ApplilinkUdid setOldUdid:record[kApplilinkUdidPasteBoardValueKey] error:NULL];
            return;
        }
    }
    NSString *oldServiceName = [ApplilinkUdid getServiceNameOld];
    if (storedIndex != nil) {
        NSDictionary *record = [ApplilinkUdid udidWithServiceName:oldServiceName
                                                     storageIndex:storedIndex.intValue
                                                            error:NULL];
        if (record != nil) {
            [ApplilinkUdid setOldUdid:record[kApplilinkUdidPasteBoardValueKey] error:NULL];
        }
    }
}

/** @ghidraAddress 0x22e9c4 */
+ (BOOL)isPasteBoardStatus {
    return [ApplilinkUdid sharedInstance].pasteBoard.nonPasteBoardUdidFlag;
}

/** @ghidraAddress 0x22ea4c */
+ (NSString *)getAdUdid {
    NSString *className =
        ApplilinkUdidDecodeShiftedName(kApplilinkUdidEncodedIdentifierManagerClass);
    Class identifierManagerClass = NSClassFromString(className);
    NSString *selectorName =
        ApplilinkUdidDecodeShiftedName(kApplilinkUdidEncodedAdvertisingIdentifierSelector);
    SEL advertisingIdentifierSelector = NSSelectorFromString(selectorName);
    id identifierManager = [identifierManagerClass performSelector:@selector(sharedManager)];
    id advertisingIdentifier = [identifierManager performSelector:advertisingIdentifierSelector];
    if (advertisingIdentifier == nil) {
        return nil;
    }
    return [advertisingIdentifier performSelector:@selector(UUIDString)];
}

/** @ghidraAddress 0x22ec0c */
- (NSString *)bundleSeedID {
    NSDictionary *query = @{
        (__bridge id)kSecClass : (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrAccount : @"bundleSeedID",
        (__bridge id)kSecAttrService : @"",
        (__bridge id)kSecReturnAttributes : (__bridge id)kCFBooleanTrue,
    };
    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    if (status == errSecItemNotFound) {
        status = SecItemAdd((__bridge CFDictionaryRef)query, &result);
    }
    if (status != errSecSuccess) {
        return nil;
    }
    NSDictionary *attributes = (__bridge_transfer NSDictionary *)result;
    NSString *accessGroup = attributes[(__bridge id)kSecAttrAccessGroup];
    return [[accessGroup componentsSeparatedByString:kApplilinkUdidAccessGroupSeparator]
               objectEnumerator]
        .nextObject;
}

/** @ghidraAddress 0x22edb4 */
+ (void)debugLog {
    NSString *env = [[NSUserDefaults standardUserDefaults] objectForKey:kApplilinkUdidEnvKey];
    if (env == nil) {
        return;
    }
    [[ApplilinkUdid sharedInstance].pasteBoard debugLog];
    (void)[ApplilinkCore ad_udid]; // Yes, the binary evaluates and discards these accessors.
    (void)[ApplilinkCore udid];
    (void)[ApplilinkCore old_udid];
}

@end
