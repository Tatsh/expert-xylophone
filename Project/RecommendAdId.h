/** @file
 * Minimal reconstructed interface for the Applilink recommend SDK's @c RecommendAdId.
 *
 * @c RecommendAdId is the recommend network's advertising-identifier record: it persists the
 * advertising identifier keyed by country code and category id, and resolves the identifier used
 * for an inbound advert redirect. The Applilink SDK ships as a closed third-party library, so only
 * the methods that @c RecommendCore messages are declared here. Reconstructed from Ghidra project
 * rb458, program rb458.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The recommend network's advertising-identifier record.
 */
@interface RecommendAdId : NSObject

/**
 * @brief Initialise the record for a country code and category id.
 * @param countryCode The country code.
 * @param categoryId The advert category identifier.
 * @return The initialised record.
 */
- (nullable instancetype)initWithCountryCode:(nullable NSString *)countryCode
                                  categoryId:(nullable NSString *)categoryId;

/**
 * @brief Load the stored advertising identifier for a country code and category id.
 * @param countryCode The country code.
 * @param categoryId The advert category identifier.
 * @param error On failure, the localised error; may be @c NULL.
 * @return The stored record, or @c nil.
 */
- (nullable NSDictionary *)getWithCountryCode:(nullable NSString *)countryCode
                                   categoryId:(nullable NSString *)categoryId
                                        error:(NSError *_Nullable *_Nullable)error;

/**
 * @brief Store the advertising identifier for an inbound advert redirect.
 * @param adIdFrom The source advertising identifier.
 * @param countryCode The country code.
 * @param categoryId The advert category identifier.
 * @param adType The advert-type string.
 * @param error On failure, the localised error; may be @c NULL.
 */
- (void)setWithAdIdFrom:(nullable NSString *)adIdFrom
            countryCode:(nullable NSString *)countryCode
             categoryId:(nullable NSString *)categoryId
                 adType:(nullable NSString *)adType
                  error:(NSError *_Nullable *_Nullable)error;

/**
 * @brief Delete the stored advertising identifier for a country code and category id.
 * @param countryCode The country code.
 * @param categoryId The advert category identifier.
 * @param error On failure, the localised error; may be @c NULL.
 */
- (void)deleteWithCountryCode:(nullable NSString *)countryCode
                   categoryId:(nullable NSString *)categoryId
                        error:(NSError *_Nullable *_Nullable)error;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
