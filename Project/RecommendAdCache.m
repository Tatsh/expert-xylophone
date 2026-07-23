#import "RecommendAdCache.h"

#import "ApplilinkConsts.h"
#import "ApplilinkNetworkError.h"
#import "ApplilinkUtilities.h"
#import "RecommendAdData.h"
#import "RecommendCore.h"
#import "RecommendWebAPI.h"

// Advert-type identifiers returned by RecommendAdData and used to pick the banner list, the URL
// key, and the HTML template.
typedef enum {
    RecommendAdCacheAdTypeBanner = 2,
    RecommendAdCacheAdTypeIcon = 3,
    RecommendAdCacheAdTypeInterstitial = 5,
} RecommendAdCacheAdType;

// The result of caching a single banner image.
typedef enum {
    RecommendAdCacheBannerResultFailed = 0,
    RecommendAdCacheBannerResultDownloaded = 1,
    RecommendAdCacheBannerResultAlreadyCached = 2,
} RecommendAdCacheBannerResult;

// The Applilink error code reported when the advert cache cannot be created.
static const NSInteger kRecommendAdCacheErrorCodeCacheCreate = 0x40b;

// The amount by which a display counter is incremented per impression.
static const int kRecommendAdCacheDisplayCountIncrement = 1;

// The initial capacity of the per-record target-URL parameter dictionary.
static const NSUInteger kRecommendAdCacheTargetParamCapacity = 13;

// A banner image older than one day is treated as expired and removed from the cache.
static const NSTimeInterval kRecommendAdCacheBannerImageTtlSeconds = 86400.0;

#pragma mark - NSUserDefaults keys

static NSString *const kRecommendAdCacheAllAdDataKey = @"ApplilinkRecommend.allAdData";
static NSString *const kRecommendAdCacheAllAdDataExpireKey = @"ApplilinkRecommend.allAdData.Expire";
static NSString *const kRecommendAdCacheAdDataListKey = @"adDataList";
static NSString *const kRecommendAdCacheAdDisplayCountDailyKey = @"adDisplayCountDaily";
static NSString *const kRecommendAdCacheAdDisplayCountTotalKey = @"adDisplayCountTotal";

#pragma mark - Archived-dictionary keys

static NSString *const kRecommendAdCacheKeyAdDisplayDate = @"adDisplayDate";
static NSString *const kRecommendAdCacheKeyFileName = @"file_name";
static NSString *const kRecommendAdCacheKeyPath = @"path";
static NSString *const kRecommendAdCacheKeyUrl = @"url";
static NSString *const kRecommendAdCacheKeyAdId = @"ad_id";

#pragma mark - Target-URL parameter keys

static NSString *const kRecommendAdCacheParamAdType = @"ad_type";
static NSString *const kRecommendAdCacheParamAdModel = @"ad_model";
static NSString *const kRecommendAdCacheParamAdLocation = @"ad_location";
static NSString *const kRecommendAdCacheParamAdIdTo = @"ad_id_to";
static NSString *const kRecommendAdCacheParamAdIdFrom = @"ad_id_from";
static NSString *const kRecommendAdCacheParamAppliIdTo = @"appli_id_to";
static NSString *const kRecommendAdCacheParamAppliId = @"appli_id";
static NSString *const kRecommendAdCacheParamCreativeId = @"creative_id";
static NSString *const kRecommendAdCacheParamIncentiveType = @"incentive_type";
static NSString *const kRecommendAdCacheParamInstallFlg = @"install_flg";
static NSString *const kRecommendAdCacheParamDefaultScheme = @"default_scheme";
static NSString *const kRecommendAdCacheParamDisplayNumber = @"display_number";
static NSString *const kRecommendAdCacheParamCountryCode = @"country_code";
static NSString *const kRecommendAdCacheParamCategoryId = @"category_id";
static NSString *const kRecommendAdCacheParamTargetUrl = @"target_url";
static NSString *const kRecommendAdCacheParamBannerUrl = @"banner_url";
static NSString *const kRecommendAdCacheParamBannerIconUrl = @"banner_icon_url";
static NSString *const kRecommendAdCacheParamInterstitialBannerUrl = @"interstitial_banner_url";

#pragma mark - Folder names

static NSString *const kRecommendAdCacheTargetBaseUrl = @"applilink://ext-app:80/send";
static NSString *const kRecommendAdCacheFolderApplilink = @"applilink";
static NSString *const kRecommendAdCacheFolderContents = @"contents";
static NSString *const kRecommendAdCacheFolderCacheImg = @"cache_img";

#pragma mark - Template placeholders

static NSString *const kRecommendAdCachePlaceholderSdkPath = @"[[SDK_PATH]]";
static NSString *const kRecommendAdCachePlaceholderBaseUrl = @"[[BASE_URL]]";
static NSString *const kRecommendAdCachePlaceholderSdkApps = @"[[SDK_APPS]]";
static NSString *const kRecommendAdCachePlaceholderVerticalAlign = @"[[VARTICAL_ALIGN]]";
static NSString *const kRecommendAdCachePlaceholderApplilinkEnv = @"[[APPLILINK_ENV]]";
static NSString *const kRecommendAdCachePlaceholderCountryCode = @"[[COUNTRY_CODE]]";

#pragma mark - Format strings

static NSString *const kRecommendAdCacheFormatInteger = @"%d";
static NSString *const kRecommendAdCacheFormatPathSeparator = @"/";
static NSString *const kRecommendAdCacheFormatDayOnly = @"yyyy/MM/dd";
static NSString *const kRecommendAdCacheFormatDayTime = @"yyyy-MM-dd HH:mm:ss";
static NSString *const kRecommendAdCacheFormatCountKey = @"count_%@";
static NSString *const kRecommendAdCacheFormatAdDataKey = @"%d_%@_adData";
static NSString *const kRecommendAdCacheFormatHtmlName = @"%d_%@.html";
static NSString *const kRecommendAdCacheFormatTemplateName = @"ad_type%d.html";
static NSString *const kRecommendAdCacheFormatUnknownAdType =
    @"no data. ad_model_setting_list AdModel:%d, adLocation:%@";
static NSString *const kRecommendAdCacheFormatZeroMatch =
    @"allAdDataForDisplay list. match data is zero. adType:%d";
static NSString *const kRecommendAdCacheUnknownAdTypeMessage =
    @"advertising type is unknown problem";

@implementation RecommendAdCache

#pragma mark - Advert-status refresh

+ (void)getAllAdStatus {
    NSDate *expire = [RecommendAdCache getAllAdDataInfoExpire];
    if (expire != nil && [expire compare:[NSDate date]] != NSOrderedAscending) {
        return;
    }
    [RecommendAdCache createFolder];
    [RecommendWebAPI layoutIndexWithCallback:^(NSError *_Nullable error) {
      /** @ghidraAddress 0x2418dc */
      if (error == nil) {
          [RecommendAdCache getTemplateFiles];
      }
      [RecommendAdCache clearCacheBannerImage];
      [RecommendAdCache getAllAdDataWithCallBack:^(NSError *_Nullable innerError) {
        /** @ghidraAddress 0x241970 */
        if (innerError == nil) {
            dispatch_async(dispatch_get_global_queue(0, 0), ^{
              /** @ghidraAddress 0x2419e0 */
              [RecommendAdData class]; // ProcessRecommendAdLists processes the fetched records.
            });
        }
      }];
    }];
}

+ (void)getAllAdDataWithCallBack:(void (^)(NSError *_Nullable error))callback {
    [[RecommendCore sharedInstance] startSessionWithCallback:^(NSError *_Nullable error) {
      /** @ghidraAddress 0x241cec */
      if (error != nil) {
          if (callback) {
              callback(error);
          }
          return;
      }
      [RecommendWebAPI allAdDataWithCallBack:^(id _Nullable data, NSError *_Nullable fetchError) {
        /** @ghidraAddress 0x241d8c */
        if (fetchError != nil) {
            if (callback) {
                callback(fetchError);
            }
            return;
        }
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
          /** @ghidraAddress 0x241e78 */
          // PersistAllAdData saves the response data and reports completion to the callback.
          (void)data;
          if (callback) {
              callback(nil);
          }
        });
      }];
    }];
}

+ (void)clearAllAdData {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kRecommendAdCacheAllAdDataKey];
}

+ (nullable NSDate *)getAllAdDataInfoExpire {
    NSData *data =
        [[NSUserDefaults standardUserDefaults] dataForKey:kRecommendAdCacheAllAdDataExpireKey];
    if (data == nil) {
        return nil;
    }
    id expire = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    if (![expire isKindOfClass:[NSDate class]]) {
        return nil;
    }
    return expire;
}

+ (void)clearAllAdDataInfoExpire {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kRecommendAdCacheAllAdDataExpireKey];
}

#pragma mark - Folder management

+ (void)createFolder {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *root =
        [NSTemporaryDirectory() stringByAppendingPathComponent:kRecommendAdCacheFolderApplilink];
    NSError *error = nil;
    BOOL isDirectory = NO;
    if (![fileManager fileExistsAtPath:root isDirectory:&isDirectory]) {
        [fileManager createDirectoryAtPath:root
               withIntermediateDirectories:YES
                                attributes:nil
                                     error:&error];
    }
    NSString *contents = [root stringByAppendingPathComponent:kRecommendAdCacheFolderContents];
    isDirectory = NO;
    if (![fileManager fileExistsAtPath:contents isDirectory:&isDirectory]) {
        [fileManager createDirectoryAtPath:contents
               withIntermediateDirectories:YES
                                attributes:nil
                                     error:&error];
    }
    NSString *cacheImg = [contents stringByAppendingPathComponent:kRecommendAdCacheFolderCacheImg];
    isDirectory = NO;
    if (![fileManager fileExistsAtPath:cacheImg isDirectory:&isDirectory]) {
        [fileManager createDirectoryAtPath:cacheImg
               withIntermediateDirectories:YES
                                attributes:nil
                                     error:&error];
    }
}

+ (void)delateFolder {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *contents = [RecommendAdCache getContentsPath];
    BOOL isDirectory = NO;
    if ([fileManager fileExistsAtPath:contents isDirectory:&isDirectory]) {
        NSError *error = nil;
        [fileManager removeItemAtPath:contents error:&error];
    }
}

#pragma mark - Banner image cache

+ (void)clearCacheBannerImage {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *cachePath = [RecommendAdCache getBannerCachePath];
    NSError *error = nil;
    BOOL isDirectory = NO;
    if (![fileManager fileExistsAtPath:cachePath isDirectory:&isDirectory]) {
        [fileManager createDirectoryAtPath:cachePath
               withIntermediateDirectories:YES
                                attributes:nil
                                     error:&error];
    }
    NSArray *entries = [fileManager contentsOfDirectoryAtPath:cachePath error:&error];
    for (NSString *entry in entries) {
        NSString *filePath = [cachePath stringByAppendingPathComponent:entry];
        if (![fileManager fileExistsAtPath:filePath]) {
            continue;
        }
        NSError *attributesError = nil;
        NSDictionary *attributes = [fileManager attributesOfItemAtPath:filePath
                                                                 error:&attributesError];
        if (attributesError != nil) {
            continue;
        }
        NSTimeInterval age =
            [[NSDate date] timeIntervalSinceDate:[attributes fileModificationDate]];
        if (age > kRecommendAdCacheBannerImageTtlSeconds) {
            [fileManager removeItemAtPath:filePath error:nil];
        }
    }
}

+ (void)allClearCacheBannerImage {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *cachePath = [RecommendAdCache getBannerCachePath];
    BOOL isDirectory = NO;
    if ([fileManager fileExistsAtPath:cachePath isDirectory:&isDirectory]) {
        NSError *error = nil;
        [fileManager removeItemAtPath:cachePath error:&error];
    }
    [RecommendAdCache createFolder];
}

+ (void)getBannerDataWithList:(NSArray *)list max:(int)max {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
      /** @ghidraAddress 0x242d3c */
      int cached = 0;
      for (NSString *entry in list) {
          if ([RecommendAdCache getBannerWithUrl:entry] == RecommendAdCacheBannerResultDownloaded) {
              ++cached;
              if (cached >= max) {
                  break;
              }
          }
      }
    });
}

+ (int)getBannerWithUrl:(NSString *)url {
    NSString *fileName = [ApplilinkUtilities geFileNameFromPath:url];
    if ([RecommendAdCache existFile:fileName]) {
        return RecommendAdCacheBannerResultAlreadyCached;
    }
    NSData *data = [RecommendAdCache getDataWithUrl:url];
    if (data != nil) {
        [RecommendAdCache saveData:data file:fileName];
    }
    return data != nil ? RecommendAdCacheBannerResultDownloaded :
                         RecommendAdCacheBannerResultFailed;
}

+ (nullable NSData *)getDataWithUrl:(NSString *)url {
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:url]];
    NSURLResponse *response = nil;
    NSError *error = nil;
    NSData *data = [NSURLConnection sendSynchronousRequest:request
                                         returningResponse:&response
                                                     error:&error];
    if (error != nil) {
        return nil;
    }
    return data;
}

+ (void)saveData:(NSData *)data file:(NSString *)file {
    NSString *filePath =
        [[RecommendAdCache getBannerCachePath] stringByAppendingPathComponent:file];
    [data writeToFile:filePath atomically:YES];
}

+ (BOOL)existFile:(NSString *)file {
    NSString *filePath =
        [[RecommendAdCache getBannerCachePath] stringByAppendingPathComponent:file];
    return [[NSFileManager defaultManager] fileExistsAtPath:filePath];
}

#pragma mark - Cache paths

+ (nullable NSString *)getContentsPath {
    return [[NSTemporaryDirectory() stringByAppendingPathComponent:kRecommendAdCacheFolderApplilink]
        stringByAppendingPathComponent:kRecommendAdCacheFolderContents];
}

+ (nullable NSString *)getBannerCachePath {
    return [[RecommendAdCache getContentsPath]
        stringByAppendingPathComponent:kRecommendAdCacheFolderCacheImg];
}

#pragma mark - Template files

+ (void)getTemplateFiles {
    NSArray *templateList = [ApplilinkConsts templateList];
    for (NSDictionary *entry in templateList) {
        NSString *file = entry[kRecommendAdCacheKeyFileName];
        NSString *path = entry[kRecommendAdCacheKeyPath];
        NSString *url = entry[kRecommendAdCacheKeyUrl];
        NSData *data = [RecommendAdCache getTemplateFile:url];
        if (data != nil) {
            [RecommendAdCache saveTemplateData:data path:path file:file];
        }
    }
}

+ (nullable NSData *)getTemplateFile:(NSString *)url {
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:url]];
    NSURLResponse *response = nil;
    NSError *error = nil;
    NSData *data = [NSURLConnection sendSynchronousRequest:request
                                         returningResponse:&response
                                                     error:&error];
    if (error != nil) {
        return nil;
    }
    return data;
}

+ (void)saveTemplateData:(NSData *)data path:(NSString *)path file:(NSString *)file {
    NSString *directory = [RecommendAdCache getContentsPath];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *components = [path componentsSeparatedByString:kRecommendAdCacheFormatPathSeparator];
    NSError *error = nil;
    for (NSString *component in components) {
        // The final path component is the file name itself; only the directory parts are created.
        if ([component isEqualToString:file]) {
            continue;
        }
        directory = [directory stringByAppendingPathComponent:component];
        BOOL isDirectory = NO;
        // The binary tests the whole relative path here, not the accumulated directory.
        if (![fileManager fileExistsAtPath:path isDirectory:&isDirectory]) {
            [fileManager createDirectoryAtPath:directory
                   withIntermediateDirectories:YES
                                    attributes:nil
                                         error:&error];
        }
    }
    NSString *filePath = [directory stringByAppendingPathComponent:file];
    [data writeToFile:filePath atomically:YES];
}

#pragma mark - HTML rendering

+ (nullable NSError *)createHtmlWithAdModel:(int)adModel
                                 adLocation:(NSString *)adLocation
                              verticalAlign:(int)verticalAlign {
    int adType = [RecommendAdData getAdTypeWithAdModel:adModel adLocation:adLocation];
    NSArray *bannerList;
    switch (adType) {
    case RecommendAdCacheAdTypeInterstitial: {
        NSArray *lottery = [RecommendAdData lotteryInterstitialWithAdLocation:adLocation];
        if (lottery != nil) {
            return (NSError *)lottery; // Faithful: the lottery result short-circuits the return.
        }
        bannerList = [RecommendAdData getAppInterstitialList];
        break;
    }
    case RecommendAdCacheAdTypeIcon:
        bannerList = [RecommendAdData getAppIconList];
        break;
    case RecommendAdCacheAdTypeBanner:
        bannerList = [RecommendAdData getAppBannerList];
        break;
    default: {
        NSString *message =
            [NSString stringWithFormat:kRecommendAdCacheFormatUnknownAdType, adModel, adLocation];
        NSDictionary *userInfo = [NSDictionary
            dictionaryWithObjectsAndKeys:kRecommendAdCacheUnknownAdTypeMessage, message, nil];
        return [ApplilinkNetworkError
            localizedApplilinkErrorWithCode:kRecommendAdCacheErrorCodeCacheCreate
                                   userInfo:userInfo];
    }
    }
    if ([bannerList count] == 0) {
        NSString *message = [NSString stringWithFormat:kRecommendAdCacheFormatZeroMatch, adType];
        NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:message, nil];
        return [ApplilinkNetworkError
            localizedApplilinkErrorWithCode:kRecommendAdCacheErrorCodeCacheCreate
                                   userInfo:userInfo];
    }
    [RecommendAdCache setTargetUrl:bannerList adType:adType adModel:adModel adLocation:adLocation];
    NSString *html = [RecommendAdCache convertHtmlWithAdType:adType
                                               verticalAlign:verticalAlign
                                                  bannerList:bannerList];
    [RecommendAdCache setHtmlAdDataWithAdModel:adModel adLocation:adLocation bannerList:bannerList];
    NSString *htmlName =
        [NSString stringWithFormat:kRecommendAdCacheFormatHtmlName, adModel, adLocation];
    NSString *htmlPath =
        [[RecommendAdCache getContentsPath] stringByAppendingPathComponent:htmlName];
    NSError *writeError = nil;
    [html writeToFile:htmlPath atomically:YES encoding:NSUTF8StringEncoding error:&writeError];
    if (adType == RecommendAdCacheAdTypeInterstitial) {
        NSString *adId = bannerList[0][kRecommendAdCacheKeyAdId];
        [RecommendAdCache setAdDisplayCountWithAdId:adId];
    }
    return nil;
}

+ (nullable NSString *)convertHtmlWithAdType:(int)adType
                               verticalAlign:(int)verticalAlign
                                  bannerList:(id)bannerList {
    NSString *templateName =
        [NSString stringWithFormat:kRecommendAdCacheFormatTemplateName, adType];
    NSString *templatePath =
        [[RecommendAdCache getContentsPath] stringByAppendingPathComponent:templateName];
    NSError *error = nil;
    NSString *html = [NSString stringWithContentsOfFile:templatePath
                                               encoding:NSUTF8StringEncoding
                                                  error:&error];
    html = [html stringByReplacingOccurrencesOfString:kRecommendAdCachePlaceholderSdkPath
                                           withString:[RecommendAdCache getContentsPath]];
    html = [html stringByReplacingOccurrencesOfString:kRecommendAdCachePlaceholderBaseUrl
                                           withString:[ApplilinkConsts baseUrlSsl]];
    if ([NSJSONSerialization isValidJSONObject:bannerList]) {
        NSData *json = [NSJSONSerialization dataWithJSONObject:bannerList
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:&error];
        NSString *jsonString = [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding];
        html = [html stringByReplacingOccurrencesOfString:kRecommendAdCachePlaceholderSdkApps
                                               withString:jsonString];
    } else {
        html = [html stringByReplacingOccurrencesOfString:kRecommendAdCachePlaceholderSdkApps
                                               withString:[bannerList description]];
    }
    NSString *verticalAlignString =
        [NSString stringWithFormat:kRecommendAdCacheFormatInteger, verticalAlign];
    html = [html stringByReplacingOccurrencesOfString:kRecommendAdCachePlaceholderVerticalAlign
                                           withString:verticalAlignString];
    html = [html stringByReplacingOccurrencesOfString:kRecommendAdCachePlaceholderApplilinkEnv
                                           withString:[ApplilinkConsts baseUrlSsl]];
    if ([ApplilinkConsts countryCode] != nil) {
        html = [html stringByReplacingOccurrencesOfString:kRecommendAdCachePlaceholderCountryCode
                                               withString:[ApplilinkConsts countryCode]];
    }
    return html;
}

+ (void)setTargetUrl:(NSArray *)targetUrl
              adType:(int)adType
             adModel:(int)adModel
          adLocation:(NSString *)adLocation {
    for (NSMutableDictionary *banner in targetUrl) {
        NSMutableDictionary *parameters =
            [NSMutableDictionary dictionaryWithCapacity:kRecommendAdCacheTargetParamCapacity];
        [parameters setValue:[NSString stringWithFormat:kRecommendAdCacheFormatInteger, adType]
                      forKey:kRecommendAdCacheParamAdType];
        [parameters setValue:[NSString stringWithFormat:kRecommendAdCacheFormatInteger, adModel]
                      forKey:kRecommendAdCacheParamAdModel];
        [parameters setValue:adLocation forKey:kRecommendAdCacheParamAdLocation];
        [parameters setValue:banner[kRecommendAdCacheKeyAdId] forKey:kRecommendAdCacheParamAdIdTo];
        NSString *creativeUrl = nil;
        switch (adType) {
        case RecommendAdCacheAdTypeInterstitial:
            creativeUrl = banner[kRecommendAdCacheParamInterstitialBannerUrl];
            break;
        case RecommendAdCacheAdTypeIcon:
            creativeUrl = banner[kRecommendAdCacheParamBannerIconUrl];
            break;
        case RecommendAdCacheAdTypeBanner:
            creativeUrl = banner[kRecommendAdCacheParamBannerUrl];
            break;
        default:
            break;
        }
        if (creativeUrl != nil) {
            NSString *creativeId = [ApplilinkUtilities geFileNameFromPath:creativeUrl];
            if (creativeId != nil) {
                [parameters setValue:creativeId forKey:kRecommendAdCacheParamCreativeId];
            }
        }
        [parameters setValue:banner[kRecommendAdCacheParamIncentiveType]
                      forKey:kRecommendAdCacheParamIncentiveType];
        [parameters setValue:banner[kRecommendAdCacheParamInstallFlg]
                      forKey:kRecommendAdCacheParamInstallFlg];
        [parameters setValue:banner[kRecommendAdCacheParamDefaultScheme]
                      forKey:kRecommendAdCacheParamDefaultScheme];
        [parameters setValue:[NSString stringWithFormat:kRecommendAdCacheFormatInteger, adModel]
                      forKey:kRecommendAdCacheParamDisplayNumber];
        [parameters setValue:banner[kRecommendAdCacheParamCountryCode]
                      forKey:kRecommendAdCacheParamCountryCode];
        [parameters setValue:banner[kRecommendAdCacheParamCategoryId]
                      forKey:kRecommendAdCacheParamCategoryId];
        [parameters setValue:banner[kRecommendAdCacheParamCreativeId]
                      forKey:kRecommendAdCacheParamCreativeId];
        [parameters setValue:[ApplilinkConsts adId] forKey:kRecommendAdCacheParamAdIdFrom];
        [parameters setValue:banner[kRecommendAdCacheParamAppliId]
                      forKey:kRecommendAdCacheParamAppliIdTo];
        NSString *url = [ApplilinkUtilities appendParametersToURL:kRecommendAdCacheTargetBaseUrl
                                                       parameters:parameters];
        [banner setObject:url forKey:kRecommendAdCacheParamTargetUrl];
    }
}

#pragma mark - Display counters

+ (void)setAdDisplayCountWithAdId:(NSString *)adId {
    [RecommendAdCache setAdDisplayCountDailyWithAdId:adId];
    [RecommendAdCache setAdDisplayCountTotalWithAdId:adId];
}

+ (void)setAdDisplayCountDailyWithAdId:(NSString *)adId {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSData *data = [defaults dataForKey:kRecommendAdCacheAdDisplayCountDailyKey];
    NSMutableDictionary *counts;
    if (data == nil) {
        counts = [NSMutableDictionary dictionary];
    } else {
        NSInteger secondsFromGMT = [[NSTimeZone systemTimeZone] secondsFromGMT];
        NSDate *localNow = [NSDate dateWithTimeIntervalSinceNow:(double)secondsFromGMT];
        counts = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        NSDate *storedDate = counts[kRecommendAdCacheKeyAdDisplayDate];
        NSDateFormatter *dayFormatter = [[NSDateFormatter alloc] init];
        [dayFormatter setDateFormat:kRecommendAdCacheFormatDayOnly];
        NSString *storedDay = [dayFormatter stringFromDate:storedDate];
        NSString *localDay = [dayFormatter stringFromDate:localNow];
        if (![storedDay isEqualToString:localDay]) {
            counts = [NSMutableDictionary dictionary];
        }
    }
    NSString *countKey = [NSString stringWithFormat:kRecommendAdCacheFormatCountKey, adId];
    NSNumber *count = counts[countKey];
    if (count == nil) {
        count = @(0);
    }
    counts[countKey] = @([count intValue] + kRecommendAdCacheDisplayCountIncrement);
    NSInteger secondsFromGMT = [[NSTimeZone systemTimeZone] secondsFromGMT];
    NSDate *localNow = [NSDate dateWithTimeIntervalSinceNow:(double)secondsFromGMT];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:kRecommendAdCacheFormatDayTime];
    [dateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    counts[kRecommendAdCacheKeyAdDisplayDate] = [dateFormatter stringFromDate:localNow];
    [defaults setObject:[NSKeyedArchiver archivedDataWithRootObject:counts]
                 forKey:kRecommendAdCacheAdDisplayCountDailyKey];
    [defaults synchronize];
}

+ (void)setAdDisplayCountTotalWithAdId:(NSString *)adId {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSData *data = [defaults dataForKey:kRecommendAdCacheAdDisplayCountTotalKey];
    NSMutableDictionary *counts;
    if (data == nil) {
        counts = [NSMutableDictionary dictionary];
    } else {
        counts = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    }
    NSString *countKey = [NSString stringWithFormat:kRecommendAdCacheFormatCountKey, adId];
    NSNumber *count = counts[countKey];
    if (count == nil) {
        count = @(0);
    }
    counts[countKey] = @([count intValue] + kRecommendAdCacheDisplayCountIncrement);
    [defaults setObject:[NSKeyedArchiver archivedDataWithRootObject:counts]
                 forKey:kRecommendAdCacheAdDisplayCountTotalKey];
    [defaults synchronize];
}

+ (void)clearAdDisplayCount {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:kRecommendAdCacheAdDisplayCountTotalKey];
    [defaults removeObjectForKey:kRecommendAdCacheAdDisplayCountDailyKey];
}

#pragma mark - HTML advert-data store

+ (void)setHtmlAdDataWithAdModel:(int)adModel
                      adLocation:(NSString *)adLocation
                      bannerList:(id)bannerList {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSData *data = [defaults dataForKey:kRecommendAdCacheAdDataListKey];
    NSMutableDictionary *adDataList;
    if (data == nil) {
        adDataList = [NSMutableDictionary dictionary];
    } else {
        adDataList = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    }
    NSString *key =
        [NSString stringWithFormat:kRecommendAdCacheFormatAdDataKey, adModel, adLocation];
    adDataList[key] = bannerList;
    [defaults setObject:[NSKeyedArchiver archivedDataWithRootObject:adDataList]
                 forKey:kRecommendAdCacheAdDataListKey];
    [defaults synchronize];
}

+ (nullable NSArray *)getHtmlAdDataWithAdModel:(int)adModel adLocation:(NSString *)adLocation {
    NSData *data =
        [[NSUserDefaults standardUserDefaults] dataForKey:kRecommendAdCacheAdDataListKey];
    if (data == nil) {
        return nil;
    }
    NSDictionary *adDataList = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    NSString *key =
        [NSString stringWithFormat:kRecommendAdCacheFormatAdDataKey, adModel, adLocation];
    return adDataList[key];
}

@end
