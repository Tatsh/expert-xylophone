#import "ApplilinkPasteBoard.h"

#import <UIKit/UIKit.h>

#import "ApplilinkConsts.h"
#import "ApplilinkNetworkError.h"
#import "Crypto.h"

static NSString *const kApplilinkUdidPasteboardType = @"applilink.udid";

static NSString *const kApplilinkUdidServiceName = @"ApplilinkUdid";
static NSString *const kApplilinkUdidServiceNameFormat = @"%@_%@";

static NSString *const kApplilinkUdidPasteboardNameFormat = @"%@-%d";

static NSString *const kApplilinkUdidEnvDisabled = @"0";

static NSString *const kApplilinkUdidValueKey = @"Value";
static NSString *const kApplilinkUdidEntryDateKey = @"EntryDate";
static NSString *const kApplilinkUdidLastAccessKey = @"LastAccess";
static NSString *const kApplilinkUdidVersionKey = @"Version";
static NSString *const kApplilinkUdidStorageIndexKey = @"StorageIndex";

static const int kApplilinkUdidStorageSlotCount = 0x100;

static const NSInteger kApplilinkUdidRecordVersion = 1;

enum {
    kApplilinkUdidCipherEncrypt = 0,
    kApplilinkUdidCipherDecrypt = 1,
};

// These mirror the file-private codes in ApplilinkNetworkError.m.
enum {
    kApplilinkPasteBoardErrorInvalidField = 1013,      // A pasteboard slot could not be opened.
    kApplilinkPasteBoardErrorWriteFailed = 1015,       // Every slot write failed.
    kApplilinkPasteBoardErrorValidateError = 1016,     // A decoded record failed validation.
    kApplilinkPasteBoardErrorInvalidKey = 1017,        // The storage index exceeded the slot count.
    kApplilinkPasteBoardErrorInvalidDataType = 1018,   // A slot held no value for the record type.
    kApplilinkPasteBoardErrorInvalidFormat = 1019,     // The record was not a dictionary.
    kApplilinkPasteBoardErrorInvalidValue = 1020,      // The record was missing its value.
    kApplilinkPasteBoardErrorInvalidEntryDate = 1021,  // The record was missing its entry date.
    kApplilinkPasteBoardErrorInvalidLastAccess = 1022, // The record was missing its last access.
    kApplilinkPasteBoardErrorInvalidVersion = 1023,    // The record was missing its version.
    kApplilinkPasteBoardErrorOldVersion = 1024,        // The record's version was not positive.
};

@implementation ApplilinkPasteBoard

#pragma mark Lifecycle

/** @ghidraAddress 0x234e38 */
- (instancetype)init {
    return [super init];
}

#pragma mark Validation

/** @ghidraAddress 0x235e88 */
+ (BOOL)validate:(NSDictionary *)dict error:(NSError **)error {
    if (![dict isKindOfClass:[NSDictionary class]]) {
        if (error != NULL) {
            *error = [ApplilinkNetworkError
                localizedApplilinkErrorWithCode:kApplilinkPasteBoardErrorInvalidFormat];
        }
        return NO;
    }
    if (dict[kApplilinkUdidValueKey] == nil) {
        if (error != NULL) {
            *error = [ApplilinkNetworkError
                localizedApplilinkErrorWithCode:kApplilinkPasteBoardErrorInvalidValue];
        }
        return NO;
    }
    if (dict[kApplilinkUdidEntryDateKey] == nil) {
        if (error != NULL) {
            *error = [ApplilinkNetworkError
                localizedApplilinkErrorWithCode:kApplilinkPasteBoardErrorInvalidEntryDate];
        }
        return NO;
    }
    if (dict[kApplilinkUdidLastAccessKey] == nil) {
        if (error != NULL) {
            *error = [ApplilinkNetworkError
                localizedApplilinkErrorWithCode:kApplilinkPasteBoardErrorInvalidLastAccess];
        }
        return NO;
    }
    if (dict[kApplilinkUdidVersionKey] == nil) {
        if (error != NULL) {
            *error = [ApplilinkNetworkError
                localizedApplilinkErrorWithCode:kApplilinkPasteBoardErrorInvalidVersion];
        }
        return NO;
    }
    if ([dict[kApplilinkUdidVersionKey] intValue] <= 0) {
        if (error != NULL) {
            *error = [ApplilinkNetworkError
                localizedApplilinkErrorWithCode:kApplilinkPasteBoardErrorOldVersion];
        }
        return NO;
    }
    return YES;
}

#pragma mark Reading

/** @ghidraAddress 0x234e74 */
- (NSDictionary *)storageData {
    NSString *serviceName = [self getServiceName];
    for (int storageIndex = 0; storageIndex < kApplilinkUdidStorageSlotCount; ++storageIndex) {
        NSString *name = [NSString
            stringWithFormat:kApplilinkUdidPasteboardNameFormat, serviceName, storageIndex];
        if ([UIPasteboard pasteboardWithName:name create:NO] != nil) {
            NSError *readError = nil;
            NSDictionary *record = [self storageDataWithServiceName:serviceName
                                                       storageIndex:storageIndex
                                                              error:&readError];
            if (readError == nil && record != nil) {
                self.nonPasteBoardUdidFlag = NO;
                return record;
            }
        }
    }
    self.nonPasteBoardUdidFlag = YES;
    return [self storageDataOld];
}

/** @ghidraAddress 0x235078 */
- (NSDictionary *)storageDataOld {
    NSString *serviceName = [self getServiceNameOld];
    for (int storageIndex = 0; storageIndex < kApplilinkUdidStorageSlotCount; ++storageIndex) {
        NSString *name = [NSString
            stringWithFormat:kApplilinkUdidPasteboardNameFormat, serviceName, storageIndex];
        if ([UIPasteboard pasteboardWithName:name create:NO] != nil) {
            NSError *readError = nil;
            NSDictionary *record = [self storageDataWithServiceName:serviceName
                                                       storageIndex:storageIndex
                                                              error:&readError];
            if (readError == nil && record != nil) {
                return record;
            }
        }
    }
    return nil;
}

/** @ghidraAddress 0x235218 */
- (NSDictionary *)storageDataWithServiceName:(NSString *)serviceName
                                storageIndex:(int)storageIndex
                                       error:(NSError **)error {
    if (storageIndex >= kApplilinkUdidStorageSlotCount) {
        if (error != NULL) {
            *error = [ApplilinkNetworkError
                localizedApplilinkErrorWithCode:kApplilinkPasteBoardErrorInvalidKey];
        }
        return nil;
    }
    NSString *name =
        [NSString stringWithFormat:kApplilinkUdidPasteboardNameFormat, serviceName, storageIndex];
    UIPasteboard *pasteboard = [UIPasteboard pasteboardWithName:name create:NO];
    if (pasteboard == nil) {
        if (error != NULL) {
            *error = [ApplilinkNetworkError
                localizedApplilinkErrorWithCode:kApplilinkPasteBoardErrorInvalidField];
        }
        return nil;
    }
    NSData *archive = [pasteboard valueForPasteboardType:kApplilinkUdidPasteboardType];
    if (archive == nil) {
        if (error != NULL) {
            *error = [ApplilinkNetworkError
                localizedApplilinkErrorWithCode:kApplilinkPasteBoardErrorInvalidDataType];
        }
        return nil;
    }
    NSDictionary *record = [NSKeyedUnarchiver unarchiveObjectWithData:archive];
    NSError *validateError = nil;
    if (![ApplilinkPasteBoard validate:record error:&validateError]) {
        [pasteboard setData:nil forPasteboardType:kApplilinkUdidPasteboardType];
        if (error != NULL) {
            *error = [ApplilinkNetworkError
                localizedApplilinkErrorWithCode:kApplilinkPasteBoardErrorValidateError];
        }
        return nil;
    }
    NSMutableDictionary *refreshed = [NSMutableDictionary dictionaryWithDictionary:record];
    NSDate *now = [NSDate date];
    if (now != nil) {
        refreshed[kApplilinkUdidLastAccessKey] = now;
    }
    NSData *rewritten = [NSKeyedArchiver archivedDataWithRootObject:refreshed];
    [pasteboard setData:rewritten forPasteboardType:kApplilinkUdidPasteboardType];
    return [self convertToData:record serviceName:serviceName storageIndex:storageIndex];
}

#pragma mark Writing

/** @ghidraAddress 0x23565c */
- (NSDictionary *)writeStorageData:(NSString *)udid error:(NSError **)error {
    NSString *serviceName = [self getServiceName];
    NSError *writeError = nil;
    NSError *deleteError = nil;
    for (int storageIndex = 0; storageIndex < kApplilinkUdidStorageSlotCount; ++storageIndex) {
        NSString *name = [NSString
            stringWithFormat:kApplilinkUdidPasteboardNameFormat, serviceName, storageIndex];
        if ([UIPasteboard pasteboardWithName:name create:NO] == nil) {
            NSDictionary *record = [self writeStorageData:udid
                                             storageIndex:storageIndex
                                                    error:&writeError];
            if (record != nil) {
                return record;
            }
            [self deleteWithStorageIndex:storageIndex error:&deleteError];
        }
    }
    if (writeError != nil || deleteError != nil) {
        // The binary writes through the error pointer here without a NULL check.
        *error = [ApplilinkNetworkError
            localizedApplilinkErrorWithCode:kApplilinkPasteBoardErrorWriteFailed];
    }
    return nil;
}

/** @ghidraAddress 0x2358b4 */
- (NSDictionary *)writeStorageData:(NSString *)udid
                      storageIndex:(int)storageIndex
                             error:(NSError **)error {
    if (storageIndex >= kApplilinkUdidStorageSlotCount) {
        if (error != NULL) {
            *error = [ApplilinkNetworkError
                localizedApplilinkErrorWithCode:kApplilinkPasteBoardErrorInvalidKey];
        }
        return nil;
    }
    NSString *serviceName = [self getServiceName];
    NSString *name =
        [NSString stringWithFormat:kApplilinkUdidPasteboardNameFormat, serviceName, storageIndex];
    NSData *keySeed = [name dataUsingEncoding:NSUTF8StringEncoding];
    NSData *key = [Crypto createHash:keySeed];
    NSData *plaintext = [udid dataUsingEncoding:NSUTF8StringEncoding];
    NSData *encryptedValue = [Crypto cryptorToData:kApplilinkUdidCipherEncrypt
                                             value:plaintext
                                               key:key];
    NSDate *now = [NSDate date];
    NSDictionary *record =
        [NSDictionary dictionaryWithObjectsAndKeys:encryptedValue,
                                                   kApplilinkUdidValueKey,
                                                   now,
                                                   kApplilinkUdidEntryDateKey,
                                                   now,
                                                   kApplilinkUdidLastAccessKey,
                                                   @(kApplilinkUdidRecordVersion),
                                                   kApplilinkUdidVersionKey,
                                                   nil];
    UIPasteboard *pasteboard = [UIPasteboard pasteboardWithName:name create:YES];
    if (pasteboard == nil) {
        if (error != NULL) {
            *error = [ApplilinkNetworkError
                localizedApplilinkErrorWithCode:kApplilinkPasteBoardErrorInvalidField];
        }
        return nil;
    }
    pasteboard.persistent = YES;
    NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:record];
    [pasteboard setData:archive forPasteboardType:kApplilinkUdidPasteboardType];
    return [self convertToData:record serviceName:serviceName storageIndex:storageIndex];
}

/** @ghidraAddress 0x235c80 */
- (BOOL)deleteWithStorageIndex:(int)storageIndex error:(NSError **)error {
    if (storageIndex >= kApplilinkUdidStorageSlotCount) {
        if (error != NULL) {
            *error = [ApplilinkNetworkError
                localizedApplilinkErrorWithCode:kApplilinkPasteBoardErrorInvalidKey];
        }
        return NO;
    }
    NSString *serviceName = [self getServiceName];
    NSString *name =
        [NSString stringWithFormat:kApplilinkUdidPasteboardNameFormat, serviceName, storageIndex];
    UIPasteboard *pasteboard = [UIPasteboard pasteboardWithName:name create:NO];
    if (pasteboard == nil) {
        if (error != NULL) {
            *error = [ApplilinkNetworkError
                localizedApplilinkErrorWithCode:kApplilinkPasteBoardErrorInvalidField];
        }
        return NO;
    }
    if ([pasteboard valueForPasteboardType:kApplilinkUdidPasteboardType] == nil) {
        if (error != NULL) {
            *error = [ApplilinkNetworkError
                localizedApplilinkErrorWithCode:kApplilinkPasteBoardErrorInvalidDataType];
        }
        return NO;
    }
    [pasteboard setData:nil forPasteboardType:kApplilinkUdidPasteboardType];
    [UIPasteboard removePasteboardWithName:name];
    return YES;
}

#pragma mark Record conversion

/** @ghidraAddress 0x236174 */
- (NSDictionary *)convertToData:(NSDictionary *)record
                    serviceName:(NSString *)serviceName
                   storageIndex:(int)storageIndex {
    NSMutableDictionary *result = [NSMutableDictionary dictionaryWithDictionary:record];
    NSNumber *index = @((NSInteger)storageIndex);
    if (index != nil) {
        result[kApplilinkUdidStorageIndexKey] = index;
    }
    NSString *name =
        [NSString stringWithFormat:kApplilinkUdidPasteboardNameFormat, serviceName, storageIndex];
    NSData *key = [Crypto createHash:[name dataUsingEncoding:NSUTF8StringEncoding]];
    NSData *encryptedValue = result[kApplilinkUdidValueKey];
    NSData *decrypted = [Crypto cryptorToData:kApplilinkUdidCipherDecrypt
                                        value:encryptedValue
                                          key:key];
    NSString *value = [[NSString alloc] initWithData:decrypted encoding:NSUTF8StringEncoding];
    if (value != nil) {
        result[kApplilinkUdidValueKey] = value;
    }
    return result;
}

#pragma mark Service names

/** @ghidraAddress 0x2363b8 */
- (NSString *)getServiceName {
    NSString *env = [ApplilinkConsts baseUrlSsl];
    if (env == nil || [env isEqualToString:kApplilinkUdidEnvDisabled]) {
        return kApplilinkUdidServiceName;
    }
    return
        [NSString stringWithFormat:kApplilinkUdidServiceNameFormat, env, kApplilinkUdidServiceName];
}

/** @ghidraAddress 0x236478 */
- (NSString *)getServiceNameOld {
    NSString *env = [ApplilinkConsts envServer];
    if (env == nil || [env isEqualToString:kApplilinkUdidEnvDisabled]) {
        return kApplilinkUdidServiceName;
    }
    return
        [NSString stringWithFormat:kApplilinkUdidServiceNameFormat, env, kApplilinkUdidServiceName];
}

#pragma mark Debugging

/** @ghidraAddress 0x236538 */
- (void)debugLog {
    NSString *serviceName = [self getServiceName];
    for (int storageIndex = 0; storageIndex < kApplilinkUdidStorageSlotCount; ++storageIndex) {
        NSString *name = [NSString
            stringWithFormat:kApplilinkUdidPasteboardNameFormat, serviceName, storageIndex];
        if ([UIPasteboard pasteboardWithName:name create:NO] != nil) {
            NSError *readError = nil;
            NSDictionary *record = [self storageDataWithServiceName:serviceName
                                                       storageIndex:storageIndex
                                                              error:&readError];
            if (readError == nil && record != nil) {
                (void)record[kApplilinkUdidValueKey]; // Yes, the binary discards this lookup.
            }
        }
    }
}

@end
