/** @file
 * Reconstructed interface for the Applilink recommend SDK's @c RecommendAdCache.
 *
 * @c RecommendAdCache is the recommend network's advert-cache store: a pure class-method utility
 * (no instances, no ivars) that keeps the cached advert-status table, the aggregated advert-data
 * records, the per-advert display counters, and the on-disk advert folder (temporary HTML bodies
 * and downloaded banner images). Records are archived through @c NSKeyedArchiver into
 * @c NSUserDefaults or written to the temporary contents folder, and are dropped once their expiry
 * date has passed. The Applilink SDK ships as a closed third-party library; this interface is
 * recovered in full from the class metadata. Reconstructed from Ghidra project rb458, program
 * rb458.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The recommend network's advert-cache store.
 */
@interface RecommendAdCache : NSObject

/**
 * @brief Refresh the aggregated advert-status table.
 *
 * If the cached advert-data expiry date is still in the future the call returns early; otherwise it
 * recreates the cache folder and requests a fresh layout index from the web API.
 * @ghidraAddress 0x2417dc
 */
+ (void)getAllAdStatus;

/**
 * @brief Fetch every advert-data record through the recommend session, then report completion.
 * @param callback The completion callback invoked with an error.
 * @ghidraAddress 0x241c28
 */
+ (void)getAllAdDataWithCallBack:(nullable void (^)(NSError *_Nullable error))callback;

/**
 * @brief Clear every cached advert-data record.
 * @ghidraAddress 0x242380
 */
+ (void)clearAllAdData;

/**
 * @brief The cached advert-data expiry date.
 * @return The expiry date, or @c nil when no valid date is cached.
 * @ghidraAddress 0x2423d8
 */
+ (nullable NSDate *)getAllAdDataInfoExpire;

/**
 * @brief Clear the expiry record for the cached advert data.
 * @ghidraAddress 0x2424e0
 */
+ (void)clearAllAdDataInfoExpire;

/**
 * @brief Create the on-disk advert-cache folder tree (root, contents, and image cache).
 * @ghidraAddress 0x242538
 */
+ (void)createFolder;

/**
 * @brief Delete the on-disk advert-cache folder. The binary spells this selector @c delateFolder
 * without correcting the @c delete typo.
 * @ghidraAddress 0x242750
 */
+ (void)delateFolder;

/**
 * @brief Delete every expired banner image from the image-cache folder.
 * @ghidraAddress 0x24280c
 */
+ (void)clearCacheBannerImage;

/**
 * @brief Delete the entire image-cache folder, then recreate the cache folder tree.
 * @ghidraAddress 0x242bbc
 */
+ (void)allClearCacheBannerImage;

/**
 * @brief Pre-load the banner images for a list of advert records, up to a maximum count.
 * @param list The advert records whose banner images should be cached.
 * @param max The maximum number of images to fetch.
 * @ghidraAddress 0x242c94
 */
+ (void)getBannerDataWithList:(nullable NSArray *)list max:(int)max;

/**
 * @brief Fetch and cache the banner image at a URL when it is not already cached.
 * @param url The banner-image URL.
 * @return @c 2 when the image was already cached, @c 1 when it was downloaded and saved, otherwise
 * @c 0.
 * @ghidraAddress 0x242e9c
 */
+ (int)getBannerWithUrl:(nullable NSString *)url;

/**
 * @brief Download the raw data at a URL synchronously.
 * @param url The URL to download.
 * @return The downloaded data, or @c nil on error.
 * @ghidraAddress 0x242f84
 */
+ (nullable NSData *)getDataWithUrl:(nullable NSString *)url;

/**
 * @brief Write banner-image data into the image-cache folder.
 * @param data The image data to write.
 * @param file The cache file name.
 * @ghidraAddress 0x243080
 */
+ (void)saveData:(nullable NSData *)data file:(nullable NSString *)file;

/**
 * @brief Whether a banner-image file already exists in the image-cache folder.
 * @param file The cache file name.
 * @return @c YES when the file exists.
 * @ghidraAddress 0x24314c
 */
+ (BOOL)existFile:(nullable NSString *)file;

/**
 * @brief The filesystem path of the cached advert contents.
 * @return The contents path.
 * @ghidraAddress 0x243224
 */
+ (nullable NSString *)getContentsPath;

/**
 * @brief The filesystem path of the banner image-cache folder.
 * @return The image-cache path.
 * @ghidraAddress 0x2432b0
 */
+ (nullable NSString *)getBannerCachePath;

/**
 * @brief Download and cache every advert template file listed in the SDK template list.
 * @ghidraAddress 0x243314
 */
+ (void)getTemplateFiles;

/**
 * @brief Download a single template file from a URL synchronously.
 * @param url The template-file URL.
 * @return The downloaded data, or @c nil on error.
 * @ghidraAddress 0x24352c
 */
+ (nullable NSData *)getTemplateFile:(nullable NSString *)url;

/**
 * @brief Write template data into the contents folder, creating the intermediate directories named
 * by @p path.
 * @param data The template data to write.
 * @param path The slash-separated relative directory path.
 * @param file The template file name.
 * @ghidraAddress 0x243628
 */
+ (void)saveTemplateData:(nullable NSData *)data
                    path:(nullable NSString *)path
                    file:(nullable NSString *)file;

/**
 * @brief Create the cached HTML advert body for an advert model.
 * @param adModel The advert-model identifier.
 * @param adLocation The ad-location identifier.
 * @param verticalAlign The vertical-alignment identifier.
 * @return A localised error when the body could not be created, otherwise @c nil.
 * @ghidraAddress 0x243938
 */
+ (nullable NSError *)createHtmlWithAdModel:(int)adModel
                                 adLocation:(nullable NSString *)adLocation
                              verticalAlign:(int)verticalAlign;

/**
 * @brief Fill the advert-type HTML template with the banner list and environment placeholders.
 * @param adType The advert-type identifier.
 * @param verticalAlign The vertical-alignment identifier.
 * @param bannerList The banner records to embed.
 * @return The rendered HTML string.
 * @ghidraAddress 0x243d94
 */
+ (nullable NSString *)convertHtmlWithAdType:(int)adType
                               verticalAlign:(int)verticalAlign
                                  bannerList:(nullable id)bannerList;

/**
 * @brief Build and store the click-through target URL on every banner record.
 * @param targetUrl The mutable banner records to annotate with their target URLs.
 * @param adType The advert-type identifier.
 * @param adModel The advert-model identifier.
 * @param adLocation The ad-location identifier.
 * @ghidraAddress 0x2441fc
 */
+ (void)setTargetUrl:(nullable NSArray *)targetUrl
              adType:(int)adType
             adModel:(int)adModel
          adLocation:(nullable NSString *)adLocation;

/**
 * @brief Increment both the daily and the total display counters for an advert identifier.
 * @param adId The advert identifier.
 * @ghidraAddress 0x244860
 */
+ (void)setAdDisplayCountWithAdId:(nullable NSString *)adId;

/**
 * @brief Increment the daily display counter for an advert identifier, resetting it at the start of
 * a new local day.
 * @param adId The advert identifier.
 * @ghidraAddress 0x2448c8
 */
+ (void)setAdDisplayCountDailyWithAdId:(nullable NSString *)adId;

/**
 * @brief Increment the lifetime total display counter for an advert identifier.
 * @param adId The advert identifier.
 * @ghidraAddress 0x244df8
 */
+ (void)setAdDisplayCountTotalWithAdId:(nullable NSString *)adId;

/**
 * @brief Clear both the daily and the total display counters.
 * @ghidraAddress 0x24504c
 */
+ (void)clearAdDisplayCount;

/**
 * @brief Store the cached HTML advert records for an advert model at an ad location.
 * @param adModel The advert-model identifier.
 * @param adLocation The ad-location identifier.
 * @param bannerList The advert records to cache.
 * @ghidraAddress 0x2450bc
 */
+ (void)setHtmlAdDataWithAdModel:(int)adModel
                      adLocation:(nullable NSString *)adLocation
                      bannerList:(nullable id)bannerList;

/**
 * @brief The cached HTML advert records for an advert model at an ad location.
 * @param adModel The advert-model identifier.
 * @param adLocation The ad-location identifier.
 * @return The advert records.
 * @ghidraAddress 0x24528c
 */
+ (nullable NSArray *)getHtmlAdDataWithAdModel:(int)adModel
                                    adLocation:(nullable NSString *)adLocation;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
