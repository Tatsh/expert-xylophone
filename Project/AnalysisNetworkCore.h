/** @file
 * Minimal reconstructed interface for the Applilink recommend SDK's @c AnalysisNetworkCore.
 *
 * @c AnalysisNetworkCore is the recommend network's advert-analytics facade: it posts impression
 * (list) and click registrations to the analytics server. The Applilink SDK ships as a closed
 * third-party library, so only the class methods that @c RecommendCore messages are declared here.
 * Reconstructed from Ghidra project rb458, program rb458.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The recommend network's advert-analytics facade.
 */
@interface AnalysisNetworkCore : NSObject

/**
 * @brief Register an impression list for the displayed adverts.
 * @param adType The advert-type string.
 * @param adModel The advert-model string.
 * @param adLocation The ad-location identifier.
 * @param impressionId The impression identifier.
 * @param appliIdList The advert application identifiers.
 * @param creativeIdList The advert creative identifiers.
 * @param incentiveTypeList The incentive-type strings.
 * @param installFlgList The install-flag strings.
 * @param callback The completion callback invoked with an error.
 */
+ (void)postAnalysisListRegistWithAdType:(nullable NSString *)adType
                                 adModel:(nullable NSString *)adModel
                              adLocation:(nullable NSString *)adLocation
                            impressionId:(nullable NSString *)impressionId
                             appliIdList:(nullable NSArray *)appliIdList
                          creativeIdList:(nullable NSArray *)creativeIdList
                       incentiveTypeList:(nullable NSArray *)incentiveTypeList
                          installFlgList:(nullable NSArray *)installFlgList
                                callback:(nullable void (^)(NSError *_Nullable error))callback;

/**
 * @brief Register a click for a displayed advert.
 * @param adType The advert-type string.
 * @param adModel The advert-model string.
 * @param adLocation The ad-location identifier.
 * @param impressionId The impression identifier.
 * @param appliIdTo The destination advert application identifier.
 * @param creativeId The advert creative identifier.
 * @param displayNumber The advert display-number string.
 * @param incentiveType The incentive-type string.
 * @param installFlg The install-flag string.
 * @param callback The completion callback invoked with an error.
 */
+ (void)postAnalysisClickRegistWithAdType:(nullable NSString *)adType
                                  adModel:(nullable NSString *)adModel
                               adLocation:(nullable NSString *)adLocation
                             impressionId:(nullable NSString *)impressionId
                                appliIdTo:(nullable NSString *)appliIdTo
                               creativeId:(nullable NSString *)creativeId
                            displayNumber:(nullable NSString *)displayNumber
                            incentiveType:(nullable NSString *)incentiveType
                               installFlg:(nullable NSString *)installFlg
                                 callback:(nullable void (^)(NSError *_Nullable error))callback;

/**
 * @brief Post the queued advert-analysis data to the analytics server.
 * @param callback The completion callback invoked with an error, or @c nil on success.
 * @ghidraAddress 0x20f7d8
 */
+ (void)postAnalysisDataWithCallback:(nullable void (^)(NSError *_Nullable error))callback;

/**
 * @brief Clear the persisted analytics-initialisation marker.
 *
 * Removes the @c ApplilinkAnalysis.initialize key from @c NSUserDefaults and synchronises. The
 * method name preserves the binary's misspelling.
 * @ghidraAddress 0x20f9f0
 */
+ (void)clearInitalize;

/**
 * @brief Clear the persisted daily-active-user measurement date.
 *
 * Removes the @c ApplilinkAnalysis.dauMeasurementDate key from @c NSUserDefaults and synchronises.
 * @ghidraAddress 0x20fa84
 */
+ (void)clearDAU;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
