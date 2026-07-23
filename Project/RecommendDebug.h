/** @file
 * Minimal reconstructed interface for the Applilink recommend SDK's @c RecommendDebug.
 *
 * @c RecommendDebug is the recommend network's debug-override store: when debug mode is active it
 * supplies canned banner-display-status and advert-model setting lists in place of the archived
 * production data. The Applilink SDK ships as a closed third-party library, so only the class
 * methods that the reconstructed callers message are declared here. Reconstructed from Ghidra
 * project rb458, program rb458.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The recommend network's debug-override store.
 */
@interface RecommendDebug : NSObject

/**
 * @brief Whether debug mode is active.
 * @return @c YES when the recommend network should use the canned debug data.
 * @ghidraAddress 0x2210c8
 */
+ (BOOL)getDebugMode;

/**
 * @brief The canned banner-display-status list.
 * @return The debug banner-display-status records.
 * @ghidraAddress 0x1193f0
 */
+ (nullable NSArray *)bannerDisplayStatusList;

/**
 * @brief The canned advert-model setting list.
 * @return The debug advert-model setting records.
 * @ghidraAddress 0x119180
 */
+ (nullable NSArray *)adModelSettingList;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
