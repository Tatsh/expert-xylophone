/** @file
 * Reconstructed interface for the KONAMI Applilink SDK's @c ApplilinkUdid device-identifier helper.
 *
 * @c ApplilinkUdid is the Applilink reward-network SDK's device-identifier manager. It resolves the
 * device advertising identifier (through @c ASIdentifierManager, reached by name so the framework
 * is not visible to static analysis), reports the advertising-tracking permission, generates and
 * hashes UDIDs, and persists them both in the iOS keychain (through the @c Security framework's
 * @c SecItem C API) and in a shared @c ApplilinkPasteBoard. It is a lazily-created singleton whose
 * @c +sharedInstance owns a serial dispatch queue and one @c ApplilinkPasteBoard. Reconstructed
 * from Ghidra project rb458, program rb458.
 */

#import <Foundation/Foundation.h>

#import "ApplilinkPasteBoard.h"

NS_ASSUME_NONNULL_BEGIN

@class ApplilinkParameters;

/**
 * @brief Advertising-identifier, UDID-generation, and keychain-persistence helper for the Applilink
 * SDK.
 */
@interface ApplilinkUdid : NSObject

/**
 * @brief The shared @c ApplilinkPasteBoard that mirrors the keychain-stored UDIDs.
 */
@property(strong, nonatomic) ApplilinkPasteBoard *pasteBoard;

/**
 * @brief The lazily-created shared singleton.
 * @return The shared @c ApplilinkUdid instance.
 * @ghidraAddress 0x22b8c4
 */
+ (instancetype)sharedInstance;

#pragma mark UDID pasteboard storage

/**
 * @brief Write a freshly generated UDID into the first empty pasteboard slot.
 * @param error Set to a localised error when the write fails.
 * @return The stored record, or @c nil on failure.
 * @ghidraAddress 0x22b9ac
 */
+ (nullable NSDictionary *)writeUDIDForFirstEmptyLocationWithError:
    (NSError *_Nullable *_Nullable)error;

/**
 * @brief Write the given UDID into the first empty pasteboard slot.
 * @param udid The UDID to store.
 * @return The stored record, or @c nil on failure.
 * @ghidraAddress 0x22bb94
 */
+ (nullable NSDictionary *)writeUDIDForFirstEmptyLocationWithUdid:(nullable NSString *)udid;

/**
 * @brief Replace the pasteboard's slot 0 UDID with the given value.
 * @param udid The UDID to store.
 * @return The stored record, or @c nil on failure.
 * @ghidraAddress 0x22bcc0
 */
+ (nullable NSDictionary *)writeUDIDWithUdid:(nullable NSString *)udid;

/**
 * @brief Read the pasteboard UDID for a service name and storage index.
 * @param serviceName The pasteboard service name.
 * @param storageIndex The storage slot index.
 * @param error Set to a localised error when the slot is empty.
 * @return The stored UDID dictionary, or @c nil.
 * @ghidraAddress 0x22bee8
 */
+ (nullable NSDictionary *)udidWithServiceName:(nullable NSString *)serviceName
                                  storageIndex:(int)storageIndex
                                         error:(NSError *_Nullable *_Nullable)error;

/**
 * @brief The first stored (potentially invalid) pasteboard UDID.
 * @param error Set to a localised error when no data is present.
 * @return The stored UDID data, or @c nil.
 * @ghidraAddress 0x22c00c
 */
+ (nullable NSDictionary *)udidForFirstInvalidDataWithError:(NSError *_Nullable *_Nullable)error;

/**
 * @brief The first stored (potentially invalid) old pasteboard UDID.
 * @param error Set to a localised error when no data is present.
 * @return The stored old UDID data, or @c nil.
 * @ghidraAddress 0x22c0d8
 */
+ (nullable NSDictionary *)udidOldForFirstInvalidDataWithError:(NSError *_Nullable *_Nullable)error;

/**
 * @brief Delete the pasteboard UDID for a service name and storage index.
 * @param serviceName The pasteboard service name.
 * @param storageIndex The storage slot index.
 * @param error Set to a localised error on failure.
 * @return @c YES when the slot was deleted or absent.
 * @ghidraAddress 0x22c1a4
 */
+ (BOOL)deleteUDIDWithServiceName:(nullable NSString *)serviceName
                     storageIndex:(int)storageIndex
                            error:(NSError *_Nullable *_Nullable)error;

/**
 * @brief Delete every stored pasteboard UDID, current and old.
 * @ghidraAddress 0x22c2f4
 */
+ (void)deleteAllUDID;

#pragma mark Advertising reward UDID

/**
 * @brief The stored advertising reward UDID, refreshing it from the keychain.
 * @param error Set to the keychain error when the read fails.
 * @return The advertising reward UDID, or @c nil.
 * @ghidraAddress 0x22c508
 */
+ (nullable NSString *)getAdvertisingRewardUdidWithError:(NSError *_Nullable *_Nullable)error;

/**
 * @brief Generate, hash, and persist a fresh advertising reward UDID.
 * @param error Set to a localised error on failure.
 * @return The new advertising reward UDID, or @c nil.
 * @ghidraAddress 0x22c63c
 */
+ (nullable NSString *)createAdvertisingRewardUdidWithError:(NSError *_Nullable *_Nullable)error;

/**
 * @brief Delete the advertising reward UDID at a keychain index.
 * @param index The reward UDID index, which must be below @c kApplilinkUdidStorageIndexCount.
 * @param error Set to a localised error on failure.
 * @return @c YES when the entry was deleted or absent.
 * @ghidraAddress 0x22c8b8
 */
+ (BOOL)deleteAdvertisingRewardUdidIndex:(int)index error:(NSError *_Nullable *_Nullable)error;

/**
 * @brief Delete every advertising reward UDID keychain entry.
 * @ghidraAddress 0x22c9f0
 */
+ (void)deleteAllAdvertisingUDID;

#pragma mark Old and new UDID

/**
 * @brief Store the old UDID in the keychain under the old service name.
 * @param oldUdid The old UDID to store.
 * @param error Set to a localised error on failure.
 * @return @c YES on success.
 * @ghidraAddress 0x22ca54
 */
+ (BOOL)setOldUdid:(nullable NSString *)oldUdid error:(NSError *_Nullable *_Nullable)error;

/**
 * @brief Read the old UDID from the keychain.
 * @param error Set to a localised error on failure.
 * @return The old UDID, or @c nil.
 * @ghidraAddress 0x22cb28
 */
+ (nullable NSString *)getOldUdidWithError:(NSError *_Nullable *_Nullable)error;

/**
 * @brief Delete the old UDID keychain entry.
 * @param error Set to a localised error on failure.
 * @return @c YES when the entry was deleted or absent.
 * @ghidraAddress 0x22cba4
 */
+ (BOOL)deleteOldUdidWithError:(NSError *_Nullable *_Nullable)error;

/**
 * @brief Store the new UDID in the keychain and the SDK core, keyed by the stored ad storage index.
 * @param newUdid The new UDID to store.
 * @param error Set to a localised error on failure.
 * @return @c YES on success.
 * @ghidraAddress 0x22cc98
 */
+ (BOOL)setNewUdid:(nullable NSString *)newUdid error:(NSError *_Nullable *_Nullable)error;

#pragma mark Keychain access

/**
 * @brief Add or update a keychain generic-password item that stores a UDID under a service key.
 * @param service The keychain service key.
 * @param udid The UDID value to store.
 * @return @c YES when @c udid is non-nil.
 * @ghidraAddress 0x22ce18
 */
+ (BOOL)setUdidWithService:(nullable NSString *)service withUDID:(nullable NSString *)udid;

/**
 * @brief Read and validate a keychain UDID, updating its modification date on read.
 * @param service The keychain service prefix.
 * @param storageIndex The storage index appended to the service key.
 * @param rewardNetworkUDIDType The reward-network UDID type selector.
 * @param error Set to a localised error when validation fails.
 * @return The validated keychain attributes, or @c nil.
 * @ghidraAddress 0x22d040
 */
+ (nullable NSDictionary *)getUdidWithService:(nullable NSString *)service
                                 storageIndex:(nullable NSString *)storageIndex
                        rewardNetworkUDIDType:(int)rewardNetworkUDIDType
                                        error:(NSError *_Nullable *_Nullable)error;

/**
 * @brief Look up a single keychain generic-password item by service key.
 * @param service The keychain service key.
 * @return The item's attribute dictionary, or @c nil when absent.
 * @ghidraAddress 0x22d3ec
 */
+ (nullable NSDictionary *)searchWithService:(nullable NSString *)service;

/**
 * @brief Delete a keychain generic-password item by service key.
 * @param service The keychain service key.
 * @param error Set to a localised error on failure.
 * @return @c YES on success or when the item is absent.
 * @ghidraAddress 0x22d52c
 */
+ (BOOL)deleteKeyChainService:(nullable NSString *)service
                        error:(NSError *_Nullable *_Nullable)error;

/**
 * @brief Validate that a keychain attribute dictionary holds a well-formed, live UDID record.
 * @param attributes The keychain attribute dictionary.
 * @param error Set to a localised error describing the first missing or invalid field.
 * @return @c YES when the record is valid.
 * @ghidraAddress 0x22d69c
 */
+ (BOOL)validate:(nullable NSDictionary *)attributes error:(NSError *_Nullable *_Nullable)error;

/**
 * @brief The keychain account (storage index) recorded for a service key.
 * @param service The keychain service key.
 * @return The stored account string, or @c \@"0" when absent.
 * @ghidraAddress 0x22d980
 */
+ (NSString *)getServiceIndex:(nullable NSString *)service;

/**
 * @brief Record the account (storage index) for a service key in the keychain.
 * @param service The keychain service key.
 * @param storageIndex The account string to store.
 * @ghidraAddress 0x22db4c
 */
+ (void)setService:(nullable NSString *)service withStorageIndex:(nullable NSString *)storageIndex;

#pragma mark Advertising identifier

/**
 * @brief A freshly minted UUID string.
 * @return A new lowercase-hyphenated UUID string.
 * @ghidraAddress 0x22dcac
 */
+ (NSString *)getCFUUID;

/**
 * @brief The device advertising identifier hashed with MD5, when tracking is available and enabled.
 * @return The hashed advertising identifier, or @c nil.
 * @ghidraAddress 0x22dcf8
 */
+ (nullable NSString *)getAdvertisingUdid;

/**
 * @brief Whether the user permits advertising tracking on this device.
 * @return @c YES when advertising tracking is enabled.
 * @ghidraAddress 0x22ddac
 */
+ (BOOL)isAdvertisingTrackingEnabled;

/**
 * @brief Whether the operating-system version exposes the advertising identifier framework.
 * @return @c YES on iOS 6.1 or later.
 * @ghidraAddress 0x22de2c
 */
+ (BOOL)isAdvertisingTrackingOSVersion;

/**
 * @brief The lowercase hex MD5 digest of a string's UTF-8 bytes.
 * @param string The string to hash.
 * @return The 32-character hex digest, or @c nil when @c string is @c nil.
 * @ghidraAddress 0x22dec0
 */
+ (nullable NSString *)md5WithString:(nullable NSString *)string;

#pragma mark UDID parameters and state

/**
 * @brief Attach the resolved UDIDs to a request parameter dictionary, honouring the priority type.
 * @param udidParameters The mutable parameter dictionary to populate.
 * @param isUDIDPriorityType The priority selecting which UDID becomes the primary value.
 * @return @c YES when at least one UDID was attached.
 * @ghidraAddress 0x22dfd8
 */
+ (BOOL)setUdidParameters:(nullable id)udidParameters isUDIDPriorityType:(int)isUDIDPriorityType;

/**
 * @brief Attach the primary UDID to a request parameter dictionary.
 * @param udidParameters The mutable parameter dictionary to populate.
 * @return @c YES when a UDID was attached.
 * @ghidraAddress 0x22e2cc
 */
+ (BOOL)setUdidParameters:(nullable id)udidParameters;

/**
 * @brief Whether the ad, current, and old UDIDs are three distinct values.
 * @return @c YES when all three UDIDs differ.
 * @ghidraAddress 0x22e42c
 */
+ (BOOL)isUdidThreeKinds;

/**
 * @brief Whether the current UDID differs from the SDK pasteboard UDID.
 * @return @c YES when the two UDIDs differ.
 * @ghidraAddress 0x22e52c
 */
+ (BOOL)isUdidSDKPasteBoard;

/**
 * @brief The keychain service name for advertising UDIDs, prefixed with the server environment.
 * @return The advertising service name.
 * @ghidraAddress 0x22e5d4
 */
+ (NSString *)getServiceName;

/**
 * @brief The keychain service name for old UDIDs, prefixed with the server environment.
 * @return The old service name.
 * @ghidraAddress 0x22e6bc
 */
+ (NSString *)getServiceNameOld;

/**
 * @brief Copy the pasteboard-stored UDID for the recorded storage index into the keychain.
 * @ghidraAddress 0x22e7a4
 */
+ (void)setUdidKeychainFromPasteBoard;

/**
 * @brief Whether the shared pasteboard reports the non-pasteboard UDID flag.
 * @return The pasteboard's non-pasteboard UDID flag.
 * @ghidraAddress 0x22e9c4
 */
+ (BOOL)isPasteBoardStatus;

/**
 * @brief The device advertising identifier UUID string, resolved by name at runtime.
 * @return The advertising identifier UUID string, or @c nil.
 * @ghidraAddress 0x22ea4c
 */
+ (nullable NSString *)getAdUdid;

/**
 * @brief The keychain bundle-seed identifier, read from a keychain access group.
 * @return The bundle-seed identifier, or @c nil.
 * @ghidraAddress 0x22ec0c
 */
- (nullable NSString *)bundleSeedID;

/**
 * @brief Log the pasteboard and SDK-core UDID state when the debug environment default is set.
 * @ghidraAddress 0x22edb4
 */
+ (void)debugLog;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
