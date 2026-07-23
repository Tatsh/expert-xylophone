/** @file
 * Minimal reconstructed interface for the Applilink recommend SDK's @c RecommendAdData.
 *
 * @c RecommendAdData is the recommend network's advert-data model store: it answers advert-status
 * and advert-type queries by advert model, looks up advert records by application identifier, and
 * derives the install-flag string for a record. The Applilink SDK ships as a closed third-party
 * library, so only the class methods that @c RecommendCore messages are declared here.
 * Reconstructed from Ghidra project rb458, program rb458.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The recommend network's advert-data model store.
 */
@interface RecommendAdData : NSObject

/**
 * @brief The cached advert status for an advert model.
 * @param adModel The advert-model identifier.
 * @return One when the advert is available, otherwise a non-available status.
 */
+ (int)getAdStatusByAdModel:(int)adModel;

/**
 * @brief The advert type for an advert model at an ad location.
 * @param adModel The advert-model identifier.
 * @param adLocation The ad-location identifier.
 * @return The advert-type identifier.
 */
+ (int)getAdTypeWithAdModel:(int)adModel adLocation:(nullable NSString *)adLocation;

/**
 * @brief The advert-data record for an application identifier.
 * @param appliId The advert application identifier.
 * @return The advert-data record, or @c nil.
 */
+ (nullable NSDictionary *)getAdDataWithAppliId:(nullable NSString *)appliId;

/**
 * @brief The install-flag string for an advert-data record.
 * @param adData The advert-data record.
 * @return The install-flag string, or @c nil.
 */
+ (nullable NSString *)getInstallFlgWithAdData:(nullable NSDictionary *)adData;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
