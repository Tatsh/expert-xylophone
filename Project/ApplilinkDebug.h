/** @file
 * Reconstructed interface for the Applilink recommend SDK's @c ApplilinkDebug.
 *
 * @c ApplilinkDebug is the Applilink advert-SDK debug console's facade. It is a stateless utility
 * class: every member is a class method and the class holds no instance state. Each method is a
 * thin forwarder that exposes an SDK internal to the debug UI: reading identity and configuration
 * values (country code, category identifier, the cached device/advertising/old UDIDs, the SDK
 * version, the debug-mode override), reporting the recommend interstitial frequency and
 * display-specification state, and driving the debug reset actions (clearing the stored UDIDs, the
 * reward and recommend session and advert status, the analytics initialisation marker and
 * daily-active-user date, and the cached banner images). The concrete work lives in
 * @c ApplilinkConsts, @c ApplilinkCore, @c RewardCore, @c RecommendCore, @c AnalysisNetworkCore,
 * @c RecommendAdCache, and @c RecommendDebug; this class only routes to them. The Applilink SDK
 * ships as a closed third-party library; the full class surface is recovered here from the
 * Objective-C metadata. Reconstructed from Ghidra project rb458, program rb458.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The Applilink advert-SDK debug console's facade.
 */
@interface ApplilinkDebug : NSObject

/**
 * @brief The configured country code.
 * @return The @c ApplilinkConsts country code, or @c nil when none is set.
 * @ghidraAddress 0x220e5c
 */
+ (nullable NSString *)countryCode;

/**
 * @brief The configured category identifier.
 * @return The @c ApplilinkConsts category identifier, or @c nil when none is set.
 * @ghidraAddress 0x220e74
 */
+ (nullable NSString *)categoryId;

/**
 * @brief The cached device UDID.
 * @return The @c ApplilinkCore cached UDID, or @c nil when none is cached.
 * @ghidraAddress 0x220e8c
 */
+ (nullable NSString *)udid;

/**
 * @brief The cached advertising UDID.
 * @return The @c ApplilinkCore cached advertising UDID, or @c nil when none is cached.
 * @ghidraAddress 0x220ea4
 */
+ (nullable NSString *)ad_udid;

/**
 * @brief The cached previous UDID.
 * @return The @c ApplilinkCore cached old UDID, or @c nil when none is cached.
 * @ghidraAddress 0x220ebc
 */
+ (nullable NSString *)old_udid;

/**
 * @brief Clear the stored device UDID.
 * @ghidraAddress 0x220ed4
 */
+ (void)clearUDID;

/**
 * @brief Clear the stored previous UDID held in the key chain.
 * @ghidraAddress 0x220eec
 */
+ (void)clearKeyChainOldUDID;

/**
 * @brief Clear the stored advertising UDID.
 * @ghidraAddress 0x220f04
 */
+ (void)clearAdUDID;

/**
 * @brief The Applilink SDK version string.
 * @return The fixed SDK version, @c "2.2.2.5".
 * @ghidraAddress 0x220f1c
 */
+ (NSString *)versionDev;

/**
 * @brief Clear the reward and recommend session state.
 * @ghidraAddress 0x220f68
 */
+ (void)clearSession;

/**
 * @brief Clear the reward and recommend advert status.
 * @ghidraAddress 0x220ff4
 */
+ (void)clearAdStatus;

/**
 * @brief Clear the persisted analytics-initialisation marker.
 *
 * The method name preserves the binary's misspelling.
 * @ghidraAddress 0x221080
 */
+ (void)clearInitalize;

/**
 * @brief Clear the persisted daily-active-user measurement date.
 * @ghidraAddress 0x221098
 */
+ (void)clearDAU;

/**
 * @brief Persist the debug-mode override flag.
 * @param debugMode The debug-mode flag object, or @c nil to clear it.
 * @ghidraAddress 0x2210b0
 */
+ (void)debugMode:(nullable id)debugMode;

/**
 * @brief The persisted debug-mode override flag.
 * @return The stored debug-mode object, or @c nil when debug mode is not active.
 * @ghidraAddress 0x2210c8
 */
+ (nullable id)getDebugMode;

/**
 * @brief Clear all cached recommend banner images.
 * @ghidraAddress 0x2210e0
 */
+ (void)allClearCacheBannerImage;

/**
 * @brief The recorded interstitial-frequency state.
 * @return A dictionary describing the interstitial-frequency state.
 * @ghidraAddress 0x2210f8
 */
+ (NSMutableDictionary *)getFrequencyStatus;

/**
 * @brief The recorded interstitial display-specification state.
 * @return A dictionary describing the interstitial display-specification state.
 * @ghidraAddress 0x221110
 */
+ (NSMutableDictionary *)getDisplaySpec;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
