/** @file
 * Reconstructed interface for the Applilink recommend SDK's @c RecommendDebug.
 *
 * @c RecommendDebug is the recommend network's debug-override store. It is a stateless utility
 * class: every member is a class method and the class holds no instance state. When debug mode is
 * active it supplies canned banner-display-status, advert-model setting, banner, and icon lists in
 * place of the archived production data, persists the debug-mode flag in @c NSUserDefaults, and
 * exposes the recorded interstitial frequency and display-specification state for inspection. The
 * canned records are the Applilink sandbox test fixtures. The Applilink SDK ships as a closed
 * third-party library; the full class surface is recovered here from the Objective-C metadata.
 * Reconstructed from Ghidra project rb458, program rb458.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The recommend network's debug-override store.
 */
@interface RecommendDebug : NSObject

/**
 * @brief The canned advert-model setting list.
 * @return The debug advert-model setting records.
 * @ghidraAddress 0x219180
 */
+ (NSArray<NSDictionary *> *)adModelSettingList;

/**
 * @brief The canned banner-display-status list.
 * @return The debug banner-display-status records.
 * @ghidraAddress 0x2193f0
 */
+ (NSArray<NSDictionary *> *)bannerDisplayStatusList;

/**
 * @brief The canned banner advert list.
 * @return The debug banner advert records.
 * @ghidraAddress 0x219600
 */
+ (NSArray<NSDictionary *> *)bannerList;

/**
 * @brief The canned icon advert list.
 * @return The debug icon advert records.
 * @ghidraAddress 0x21acd0
 */
+ (NSArray<NSDictionary *> *)iconList;

/**
 * @brief Persist the debug-mode override flag.
 *
 * Stores @p debugMode in @c NSUserDefaults under the @c applilink.debug.mode key, or removes the
 * key when @p debugMode is @c nil.
 * @param debugMode The debug-mode flag object, or @c nil to clear it.
 * @ghidraAddress 0x21c43c
 */
+ (void)debugMode:(nullable id)debugMode;

/**
 * @brief The persisted debug-mode override flag.
 * @return The stored @c applilink.debug.mode object, or @c nil when debug mode is not active.
 * @ghidraAddress 0x21c514
 */
+ (nullable id)getDebugMode;

/**
 * @brief The recorded interstitial-frequency state.
 *
 * Merges the unarchived @c ApplilinkRecommend.frequency counters with the current interstitial
 * location display specification for inspection.
 * @return A dictionary describing the interstitial-frequency state.
 * @ghidraAddress 0x21c580
 */
+ (NSMutableDictionary *)getFrequencyStatus;

/**
 * @brief The recorded interstitial display-specification state.
 *
 * Merges the unarchived daily and total advert-display counts with the current interstitial
 * display specification for inspection.
 * @return A dictionary describing the interstitial display-specification state.
 * @ghidraAddress 0x21c704
 */
+ (NSMutableDictionary *)getDisplaySpec;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
