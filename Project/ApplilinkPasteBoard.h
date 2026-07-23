/** @file
 * Minimal reconstructed interface for the KONAMI Applilink SDK's @c ApplilinkPasteBoard.
 *
 * @c ApplilinkPasteBoard mirrors the keychain-stored UDID records into the system pasteboard so
 * they survive an app reinstall. It is not itself reconstructed here; only the members that
 * @c ApplilinkUdid messages are declared. Reconstructed from Ghidra project rb458, program rb458.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Pasteboard-backed UDID store for the Applilink SDK.
 */
@interface ApplilinkPasteBoard : NSObject

/**
 * @brief Whether the SDK is currently forced to skip the pasteboard UDID.
 * @ghidraAddress 0x23674c
 */
@property(nonatomic) BOOL nonPasteBoardUdidFlag;

/**
 * @brief The stored current-UDID pasteboard record.
 * @return The stored record, or @c nil.
 * @ghidraAddress 0x234e74
 */
- (nullable NSDictionary *)storageData;

/**
 * @brief The stored old-UDID pasteboard record.
 * @return The stored record, or @c nil.
 * @ghidraAddress 0x235078
 */
- (nullable NSDictionary *)storageDataOld;

/**
 * @brief The pasteboard record for a service name and storage index.
 * @param serviceName The pasteboard service name.
 * @param storageIndex The storage slot index.
 * @param error Set to a localised error when the slot is empty.
 * @return The stored record, or @c nil.
 * @ghidraAddress 0x235218
 */
- (nullable NSDictionary *)storageDataWithServiceName:(nullable NSString *)serviceName
                                         storageIndex:(int)storageIndex
                                                error:(NSError *_Nullable *_Nullable)error;

/**
 * @brief Write a UDID into the first empty pasteboard slot.
 * @param udid The UDID to store.
 * @param error Set to a localised error on failure.
 * @return The stored UDID, or @c nil on failure.
 * @ghidraAddress 0x23565c
 */
- (nullable NSString *)writeStorageData:(nullable NSString *)udid
                                  error:(NSError *_Nullable *_Nullable)error;

/**
 * @brief Write a UDID into a pasteboard slot at a storage index.
 * @param udid The UDID to store.
 * @param storageIndex The storage slot index.
 * @param error Set to a localised error on failure.
 * @return The stored UDID, or @c nil on failure.
 * @ghidraAddress 0x2358b4
 */
- (nullable NSString *)writeStorageData:(nullable NSString *)udid
                           storageIndex:(int)storageIndex
                                  error:(NSError *_Nullable *_Nullable)error;

/**
 * @brief Delete the pasteboard slot at a storage index.
 * @param storageIndex The storage slot index.
 * @param error Set to a localised error on failure.
 * @return @c YES on success.
 * @ghidraAddress 0x235c80
 */
- (BOOL)deleteWithStorageIndex:(int)storageIndex error:(NSError *_Nullable *_Nullable)error;

/**
 * @brief The pasteboard service name for advertising UDIDs.
 * @return The advertising service name.
 * @ghidraAddress 0x2363b8
 */
- (NSString *)getServiceName;

/**
 * @brief The pasteboard service name for old UDIDs.
 * @return The old service name.
 * @ghidraAddress 0x236478
 */
- (NSString *)getServiceNameOld;

/**
 * @brief Log the pasteboard UDID state.
 * @ghidraAddress 0x236538
 */
- (void)debugLog;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
