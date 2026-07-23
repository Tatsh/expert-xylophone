/** @file
 * Reconstructed interface for the Applilink recommend SDK's @c RecommendAdData.
 *
 * @c RecommendAdData is the recommend network's advert-data model store. It is a stateless utility
 * class: every member is a class method and the class holds no instance state. The store reads the
 * archived advert payload that the SDK caches in @c NSUserDefaults (the @c ApplilinkRecommend.allAdData
 * blob and its sub-lists), narrows and filters those records by advert identifier, advert model,
 * advert type, and application identifier, resolves the on-disk banner and interstitial cache paths,
 * runs the weighted interstitial lottery, and derives the install-flag string for a record. The
 * Applilink SDK ships as a closed third-party library; the full class surface is recovered here from
 * the Objective-C metadata. Reconstructed from Ghidra project rb458, program rb458.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The recommend network's advert-data model store.
 */
@interface RecommendAdData : NSObject

/**
 * @brief The archived banner-display-status list.
 *
 * In debug mode the list comes from @c RecommendDebug; otherwise it is unarchived from the
 * @c ApplilinkRecommend.allAdData blob under its @c banner_display_status_list key.
 * @return The banner-display-status records, or @c nil.
 * @ghidraAddress 0x126e90
 */
+ (nullable NSArray *)getBannerDisplayStatusList;

/**
 * @brief The archived advert-model setting list.
 *
 * In debug mode the list comes from @c RecommendDebug; otherwise it is unarchived from the
 * @c ApplilinkRecommend.allAdData blob under its @c ad_model_setting_list key.
 * @return The advert-model setting records, or @c nil.
 * @ghidraAddress 0x126fbc
 */
+ (nullable NSArray *)getAdModelSettingList;

/**
 * @brief The archived advert list.
 *
 * Unarchived from the @c ApplilinkRecommend.allAdData blob under its @c list key.
 * @return The advert records, or @c nil.
 * @ghidraAddress 0x1270e8
 */
+ (nullable NSArray *)getAdList;

/**
 * @brief The archived interstitial-specification dictionary.
 *
 * Unarchived from the @c ApplilinkRecommend.allAdData blob under its @c interstitial_spec_list key.
 * @return The interstitial-specification dictionary, or @c nil.
 * @ghidraAddress 0x1271c4
 */
+ (nullable NSDictionary *)getInterstitialSpecList;

/**
 * @brief The cached advert status for an advert model.
 *
 * Looks the advert model up in the banner-display-status list and returns its @c status value.
 * @param adModel The advert-model identifier.
 * @return The advert @c status value, or zero when the model is absent or malformed.
 * @ghidraAddress 0x1272a0
 */
+ (int)getAdStatusByAdModel:(int)adModel;

/**
 * @brief The advert-data record for an advert identifier.
 *
 * Narrows the advert list to the records whose @c ad_id equals @p adId and returns the first match.
 * @param adId The advert identifier.
 * @return The advert-data record, or @c nil.
 * @ghidraAddress 0x127460
 */
+ (nullable NSDictionary *)getAdDataByAdId:(int)adId;

/**
 * @brief The advert-data record for an application identifier.
 *
 * Narrows the advert list to the records whose @c appli_id equals @p appliId, preferring a record
 * whose @c primary_flg is set, and returns that record.
 * @param appliId The advert application identifier.
 * @return The advert-data record, or @c nil.
 * @ghidraAddress 0x127570
 */
+ (nullable NSDictionary *)getAdDataWithAppliId:(nullable NSString *)appliId;

/**
 * @brief The advert list narrowed to a single advert type.
 * @param adType The advert-type identifier.
 * @return The advert records whose @c ad_type equals @p adType.
 * @ghidraAddress 0x1277dc
 */
+ (nullable NSArray *)getAdListByAdType:(int)adType;

/**
 * @brief The application-banner records for the lottery banner.
 *
 * Draws a lottery banner, resolves its cached @c banner_url to the on-disk banner-cache path, and
 * records the creative identifier.
 * @return An array with the single resolved banner record, or @c nil.
 * @ghidraAddress 0x1278a0
 */
+ (nullable NSArray *)getAppBannerList;

/**
 * @brief The application-icon records for the lottery icons.
 *
 * Resolves each drawn lottery-icon @c banner_icon_url to its cached file name and records the
 * creative identifier.
 * @return The resolved icon records.
 * @ghidraAddress 0x127c50
 */
+ (nullable NSArray *)getAppIconList;

/**
 * @brief The application-interstitial records for the lottery interstitial.
 *
 * Draws a lottery interstitial, resolves its cached @c interstitial_banner_url to the on-disk
 * banner-cache path, records the creative identifier, and attaches the install-flag string.
 * @return An array with the single resolved interstitial record, or @c nil.
 * @ghidraAddress 0x127fec
 */
+ (nullable NSArray *)getAppInterstitialList;

/**
 * @brief Draw a lottery banner record.
 *
 * Filters the banner-type adverts to the ones still within their display term, then picks one
 * uniformly at random.
 * @return The drawn banner record, or @c nil.
 * @ghidraAddress 0x1283c8
 */
+ (nullable NSDictionary *)getLotteryBannerData;

/**
 * @brief Draw up to four lottery icon records.
 *
 * Filters the icon-type adverts to the ones still within their display term, shuffles them, and
 * returns the first four (or fewer).
 * @return The drawn icon records, or @c nil.
 * @ghidraAddress 0x1284c4
 */
+ (nullable NSArray *)getLotteryIconData;

/**
 * @brief Draw a lottery interstitial record.
 *
 * Reduces the interstitial display-specification list to the entries whose daily and total display
 * counts and install state still allow a display, then draws one weighted by priority.
 * @return The drawn interstitial record, or @c nil.
 * @ghidraAddress 0x128624
 */
+ (nullable NSDictionary *)getLotteryInterstitialData;

/**
 * @brief Draw one record from a priority-weighted list.
 *
 * Sums every record's @c priority, draws a value in that range, and returns the record whose
 * cumulative priority window contains the draw.
 * @param list The candidate records, each carrying a @c priority.
 * @return The drawn record, or @c nil.
 * @ghidraAddress 0x128770
 */
+ (nullable NSDictionary *)getLotteryInterstitialDataWithList:(nullable NSArray *)list;

/**
 * @brief The interstitial display-specification list sorted by descending priority.
 * @return The @c ad_display_spec entries sorted by @c priority.
 * @ghidraAddress 0x128a18
 */
+ (nullable NSArray *)getInterstitialSpecPriorityList;

/**
 * @brief Filter a display-specification list by remaining display count.
 *
 * Keeps the entries whose recorded daily and total display counts are still below their
 * @c max_display_count_daily and @c max_display_count_total limits.
 * @param list The @c ad_display_spec entries to filter.
 * @return The entries that may still be displayed.
 * @ghidraAddress 0x128b28
 */
+ (nullable NSArray *)getInterstitialSpecCountForAdDisplaySpecList:(nullable NSArray *)list;

/**
 * @brief Filter a display-specification list by install state and display term.
 *
 * Keeps the entries whose advert is installed (or whose install is not required) and whose display
 * term has not expired, carrying the @c priority through to each surviving record.
 * @param list The @c ad_display_spec entries to filter.
 * @return The entries that may still be displayed.
 * @ghidraAddress 0x129078
 */
+ (nullable NSArray *)getInterstitialSpecInstallForAdDisplaySpecList:(nullable NSArray *)list;

/**
 * @brief The interstitial advert records for a display-specification list.
 *
 * Resolves each entry's advert data by @c ad_id_to and keeps the records that carry a non-empty
 * @c interstitial_banner_url.
 * @param list The @c ad_display_spec entries.
 * @return The interstitial advert records.
 * @ghidraAddress 0x1297c4
 */
+ (nullable NSArray *)getAdInterstitialUrlListTermForAdDisplaySpecList:(nullable NSArray *)list;

/**
 * @brief The interstitial advert records of a list that carry a banner URL.
 * @param list The advert records to filter.
 * @return The records with a non-empty @c interstitial_banner_url.
 * @ghidraAddress 0x129ae8
 */
+ (nullable NSArray *)getAdInterstitialUrlListTermForList:(nullable NSArray *)list;

/**
 * @brief The archived daily advert-display-count dictionary, valid only for today.
 *
 * Unarchives the @c adDisplayCountDaily blob and returns it only when its recorded @c adDisplayDate
 * matches the current day; otherwise @c nil.
 * @return The daily display-count dictionary, or @c nil.
 * @ghidraAddress 0x129ce4
 */
+ (nullable NSDictionary *)getAdDisplayCountDailyDictionary;

/**
 * @brief The archived total advert-display-count dictionary.
 * @return The total display-count dictionary, or @c nil.
 * @ghidraAddress 0x129ee0
 */
+ (nullable NSDictionary *)getAdDisplayCountTotalDictionary;

/**
 * @brief The advert type for an advert model at an ad location.
 *
 * Searches the advert-model setting list for the entry matching @p adLocation and @p adModel and
 * returns its @c ad_type value, defaulting to the app-banner type when there is no match.
 * @param adModel The advert-model identifier.
 * @param adLocation The ad-location identifier.
 * @return The advert-type identifier.
 * @ghidraAddress 0x129f90
 */
+ (int)getAdTypeWithAdModel:(int)adModel adLocation:(nullable NSString *)adLocation;

/**
 * @brief Filter a list to the records still within their display term.
 *
 * Keeps the records whose @c external_ad_disp_mng_end_date is at or after the current time.
 * @param list The advert records to filter.
 * @return The records still within their display term.
 * @ghidraAddress 0x12a288
 */
+ (nullable NSArray *)getAdListTermForList:(nullable NSArray *)list;

/**
 * @brief The banner advert records of a list that carry a banner URL.
 * @param list The advert records to filter.
 * @return The records with a non-empty @c banner_url.
 * @ghidraAddress 0x12a610
 */
+ (nullable NSArray *)getAdBannerListForList:(nullable NSArray *)list;

/**
 * @brief A randomly shuffled copy of a list.
 * @param list The list to shuffle.
 * @return A new array with the elements of @p list in random order.
 * @ghidraAddress 0x12a884
 */
+ (nullable NSArray *)shuffled:(nullable NSArray *)list;

/**
 * @brief Run the interstitial-display frequency lottery for an ad location.
 *
 * Reads the @c frequency_n / @c frequency_m specification for @p adLocation, advances the persisted
 * per-location frequency counters, and decides whether the interstitial should be shown this time.
 * @param adLocation The ad-location identifier.
 * @return @c nil when the interstitial should be shown, otherwise a localised @c NSError describing
 * why it was suppressed.
 * @ghidraAddress 0x12aa30
 */
+ (nullable NSError *)lotteryInterstitialWithAdLocation:(nullable NSString *)adLocation;

/**
 * @brief The install-flag string for an advert-data record.
 *
 * Returns @c "1" when the record's @c install_flg is already set, or when the record's
 * @c default_scheme URL can be opened by the device; otherwise @c "0".
 * @param adData The advert-data record.
 * @return @c "1" or @c "0".
 * @ghidraAddress 0x12b200
 */
+ (nullable NSString *)getInstallFlgWithAdData:(nullable NSDictionary *)adData;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
