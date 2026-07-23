/** @file
 * Minimal reconstructed interface for the Applilink recommend SDK's @c RecommendAdCache.
 *
 * @c RecommendAdCache is the recommend network's advert-cache store: it manages the on-disk advert
 * folder, the cached HTML advert bodies, and the aggregated advert-status table. The Applilink SDK
 * ships as a closed third-party library, so only the class methods that @c RecommendCore messages
 * are declared here. Reconstructed from Ghidra project rb458, program rb458.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The recommend network's advert-cache store.
 */
@interface RecommendAdCache : NSObject

/**
 * @brief Clear every cached advert-data record.
 */
+ (void)clearAllAdData;

/**
 * @brief Delete the on-disk advert-cache folder. The binary spells this selector @c delateFolder
 * without correcting the @c delete typo.
 */
+ (void)delateFolder;

/**
 * @brief Clear the expiry records for every cached advert-data entry.
 */
+ (void)clearAllAdDataInfoExpire;

/**
 * @brief Refresh the aggregated advert-status table.
 */
+ (void)getAllAdStatus;

/**
 * @brief The filesystem path of the cached advert contents.
 * @return The contents path.
 */
+ (nullable NSString *)getContentsPath;

/**
 * @brief Create the cached HTML advert body for an advert model.
 * @param adModel The advert-model identifier.
 * @param adLocation The ad-location identifier.
 * @param verticalAlign The vertical-alignment identifier.
 * @return A localised error when the body could not be created, otherwise @c nil.
 */
+ (nullable NSError *)createHtmlWithAdModel:(int)adModel
                                 adLocation:(nullable NSString *)adLocation
                              verticalAlign:(int)verticalAlign;

/**
 * @brief The cached HTML advert records for an advert model at an ad location.
 * @param adModel The advert-model identifier.
 * @param adLocation The ad-location identifier.
 * @return The advert records.
 */
+ (nullable NSArray *)getHtmlAdDataWithAdModel:(int)adModel
                                    adLocation:(nullable NSString *)adLocation;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
