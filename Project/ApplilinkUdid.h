/** @file
 * Minimal reconstructed interface for the Applilink SDK's @c ApplilinkUdid helper.
 *
 * @c ApplilinkUdid resolves the device's advertising identifier and reports the user's
 * advertising-tracking preference. Only the capability query the reconstructed sources message is
 * declared here. Reconstructed from Ghidra project rb458, program rb458.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Advertising-identifier and tracking-permission helper for the Applilink SDK.
 */
@interface ApplilinkUdid : NSObject

/**
 * @brief Whether the user permits advertising tracking on this device.
 * @return @c YES when advertising tracking is enabled.
 * @ghidraAddress 0x22ddac
 */
+ (BOOL)isAdvertisingTrackingEnabled;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
