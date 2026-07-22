/** @file
 * The device hardware-identity singleton. It resolves the running device's machine model (via
 * @c sysctlbyname("hw.machine")) to an enumerated hardware type and exposes both the raw model
 * string and that type. The lookup runs lazily on first access and is cached for the lifetime of
 * the process.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class SystemHardware, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <Foundation/Foundation.h>

/**
 * @brief The enumerated device hardware types, indexed against the @c hw.machine model table.
 *
 * Each case corresponds to one @c hw.machine string; @c SystemHardwareTypeUnknown is stored when no
 * known model matches.
 */
typedef NS_ENUM(int, SystemHardwareType) {
    /// iPhone1,1 (original iPhone).
    SystemHardwareTypeIPhone1_1 = 0,
    /// iPhone1,2 (iPhone 3G).
    SystemHardwareTypeIPhone1_2 = 1,
    /// iPhone2,1 (iPhone 3GS).
    SystemHardwareTypeIPhone2_1 = 2,
    /// iPhone3,1 (iPhone 4, GSM).
    SystemHardwareTypeIPhone3_1 = 3,
    /// iPhone3,2 (iPhone 4, GSM revised).
    SystemHardwareTypeIPhone3_2 = 4,
    /// iPod1,1 (first-generation iPod touch).
    SystemHardwareTypeIPod1_1 = 5,
    /// iPod2,1 (second-generation iPod touch).
    SystemHardwareTypeIPod2_1 = 6,
    /// iPod3,1 (third-generation iPod touch).
    SystemHardwareTypeIPod3_1 = 7,
    /// iPod4,1 (fourth-generation iPod touch).
    SystemHardwareTypeIPod4_1 = 8,
    /// iPad1,1 (original iPad).
    SystemHardwareTypeIPad1_1 = 9,
    /// iPad2,1 (iPad 2, Wi-Fi).
    SystemHardwareTypeIPad2_1 = 10,
    /// iPad2,2 (iPad 2, GSM).
    SystemHardwareTypeIPad2_2 = 11,
    /// iPad2,3 (iPad 2, CDMA).
    SystemHardwareTypeIPad2_3 = 12,
    /// i386 (the iOS Simulator).
    SystemHardwareTypeI386 = 13,
    /// A device whose @c hw.machine string matched no known model.
    SystemHardwareTypeUnknown = 14,
};

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A singleton that reports the running device's hardware model and type.
 */
@interface SystemHardware : NSObject

/**
 * @brief The raw @c hw.machine model string of the running device (for example @c iPhone3,1).
 *
 * This is populated the first time the hardware is resolved; it is @c nil until then.
 * @ghidraAddress 0x18d40 (getter)
 * @ghidraAddress 0x18d50 (setter)
 */
@property(nonatomic, strong, nullable) NSString *hardwareName;

/**
 * @brief Returns the shared hardware singleton, creating it on first use.
 * @return The shared @c SystemHardware instance.
 * @ghidraAddress 0x18b14
 */
+ (instancetype)getInstance;

/**
 * @brief Resolves the device model by querying @c sysctlbyname("hw.machine") and matching it
 * against the known model table, caching both the model string and the derived hardware type.
 *
 * This runs only when the hardware type is still unresolved.
 * @ghidraAddress 0x18b6c
 */
- (void)initHardware;

/**
 * @brief Returns the device's hardware type, resolving it lazily on first access.
 * @return The matched @c SystemHardwareType, or @c SystemHardwareTypeUnknown when no known model
 * matches.
 * @ghidraAddress 0x18cb0
 */
- (SystemHardwareType)getHardwareType;

/**
 * @brief Returns the device's raw @c hw.machine model string, resolving it lazily on first access.
 * @return The model string.
 * @ghidraAddress 0x18cf4
 */
- (nullable NSString *)getHardwareName;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
