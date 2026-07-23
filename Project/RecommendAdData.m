#import "RecommendAdData.h"

#import <UIKit/UIKit.h>

#import "ApplilinkNetworkError.h"
#import "ApplilinkUtilities.h"
#import "RecommendAdCache.h"
#import "RecommendDebug.h"

// NSUserDefaults archive keys.
static NSString *const kAllAdDataKey = @"ApplilinkRecommend.allAdData";
static NSString *const kFrequencyKey = @"ApplilinkRecommend.frequency";
static NSString *const kAdDisplayCountDailyKey = @"adDisplayCountDaily";
static NSString *const kAdDisplayCountTotalKey = @"adDisplayCountTotal";

// Sub-keys of the archived allAdData blob.
static NSString *const kBannerDisplayStatusListKey = @"banner_display_status_list";
static NSString *const kAdModelSettingListKey = @"ad_model_setting_list";
static NSString *const kAdListKey = @"list";
static NSString *const kInterstitialSpecListKey = @"interstitial_spec_list";

// Advert-record and display-specification field keys.
static NSString *const kAdIdKey = @"ad_id";
static NSString *const kAppliIdKey = @"appli_id";
static NSString *const kAdTypeKey = @"ad_type";
static NSString *const kAdModelKey = @"ad_model";
static NSString *const kAdLocationKey = @"ad_location";
static NSString *const kStatusKey = @"status";
static NSString *const kPrimaryFlgKey = @"primary_flg";
static NSString *const kInstallFlgKey = @"install_flg";
static NSString *const kDefaultSchemeKey = @"default_scheme";
static NSString *const kBannerUrlKey = @"banner_url";
static NSString *const kBannerIconUrlKey = @"banner_icon_url";
static NSString *const kInterstitialBannerUrlKey = @"interstitial_banner_url";
static NSString *const kCreativeIdKey = @"creative_id";
static NSString *const kPriorityKey = @"priority";
static NSString *const kPriorityKeyPath = @"priority.intValue";
static NSString *const kAdDisplaySpecKey = @"ad_display_spec";
static NSString *const kAdLocationDisplaySpecKey = @"ad_location_display_spec";
static NSString *const kAdIdToKey = @"ad_id_to";
static NSString *const kMaxDisplayCountDailyKey = @"max_display_count_daily";
static NSString *const kMaxDisplayCountTotalKey = @"max_display_count_total";
static NSString *const kInstalledAdDisplayFlgKey = @"installed_ad_display_flg";
static NSString *const kExternalAdDispMngEndDateKey = @"external_ad_disp_mng_end_date";
static NSString *const kAdDisplayDateKey = @"adDisplayDate";
static NSString *const kFrequencyNKey = @"frequency_n";
static NSString *const kFrequencyMKey = @"frequency_m";

// Format strings.
static NSString *const kIntegerFormat = @"%d";
static NSString *const kCountFormat = @"count_%@";
static NSString *const kFrequencyNFormat = @"frequency_n_%@";
static NSString *const kFrequencyMFormat = @"frequency_m_%@";

// Install-flag literal values, matched and returned as strings.
static NSString *const kInstallFlgOn = @"1";
static NSString *const kInstallFlgOff = @"0";

// Small literals.
static NSString *const kSchemeSeparator = @"://";
static NSString *const kJapanLocaleIdentifier = @"JP";
static NSString *const kJapanTimeZoneAbbreviation = @"JST";
static NSString *const kDateTimeFormat = @"yyyy-MM-dd HH:mm:ss";
static NSString *const kDateFormat = @"yyyy-MM-dd";

// Lottery-suppression messages, reported through the ApplilinkNetworkError user-info.
static NSString *const kInterstitialSpecListIsZeroMessage = @"interstitial_spec_list is zero";
static NSString *const kInterstitialSpecFrequencyIsZeroMessage =
    @"interstitial_spec_list.ad_display_spec frequency is zero";
static NSString *const kLotteryMissFormat =
    @"display lottery is miss. Indication frequency:%d/%d execute:%d/%d";

// Advert-type identifiers used by the lottery helpers.
enum {
    kRecommendAdTypeAppBanner = 1,
    kRecommendAdTypeLotteryBanner = 2,
    kRecommendAdTypeLotteryIcon = 3,
};

// The maximum number of lottery icons drawn per request.
static const int kMaxLotteryIconCount = 4;

// The end-date substring length compared as a plain integer year before falling back to a date
// comparison, and the sentinel year below which the comparison is skipped.
enum {
    kEndDateYearPrefixLength = 4,
    kEndDateComparableYear = 3000,
};

// Applilink error codes surfaced by the interstitial lottery.
enum {
    kApplilinkErrorInterstitialLotteryMiss = 0x40a,
    kApplilinkErrorInterstitialSpecInvalid = 0x40b,
};

@implementation RecommendAdData

#pragma mark - Archived payload accessors

+ (nullable id)unarchivedAllAdDataObjectForKey:(NSString *)key {
    NSData *data = [NSUserDefaults.standardUserDefaults dataForKey:kAllAdDataKey];
    if (data == nil) {
        return nil;
    }
    return [NSKeyedUnarchiver unarchiveObjectWithData:data][key];
}

+ (nullable NSArray *)getBannerDisplayStatusList {
    if (RecommendDebug.getDebugMode) {
        return RecommendDebug.bannerDisplayStatusList;
    }
    return [self unarchivedAllAdDataObjectForKey:kBannerDisplayStatusListKey];
}

+ (nullable NSArray *)getAdModelSettingList {
    if (RecommendDebug.getDebugMode) {
        return RecommendDebug.adModelSettingList;
    }
    return [self unarchivedAllAdDataObjectForKey:kAdModelSettingListKey];
}

+ (nullable NSArray *)getAdList {
    return [self unarchivedAllAdDataObjectForKey:kAdListKey];
}

+ (nullable NSDictionary *)getInterstitialSpecList {
    return [self unarchivedAllAdDataObjectForKey:kInterstitialSpecListKey];
}

#pragma mark - Narrowed record lookups

+ (int)getAdStatusByAdModel:(int)adModel {
    NSString *model = [NSString stringWithFormat:kIntegerFormat, adModel];
    NSArray *list = [ApplilinkUtilities narrowedListWithList:[self getBannerDisplayStatusList]
                                                      object:model
                                                      forKey:kAdModelKey];
    if (list.count == 0) {
        return 0;
    }
    id status = list[0][kStatusKey];
    if (![status isKindOfClass:NSString.class]) {
        return 0;
    }
    return [status intValue];
}

+ (nullable NSDictionary *)getAdDataByAdId:(int)adId {
    NSString *identifier = [NSString stringWithFormat:kIntegerFormat, adId];
    NSArray *list = [ApplilinkUtilities narrowedListWithList:[self getAdList]
                                                      object:identifier
                                                      forKey:kAdIdKey];
    if (list.count == 0) {
        return nil;
    }
    return list[0];
}

+ (nullable NSDictionary *)getAdDataWithAppliId:(nullable NSString *)appliId {
    NSArray *list = [ApplilinkUtilities narrowedListWithList:[self getAdList]
                                                      object:appliId
                                                      forKey:kAppliIdKey];
    for (NSDictionary *record in list) {
        if ([kInstallFlgOn isEqualToString:record[kPrimaryFlgKey]]) {
            return record;
        }
    }
    if (list.count == 0) {
        return nil;
    }
    return list[0];
}

+ (nullable NSArray *)getAdListByAdType:(int)adType {
    NSString *type = [NSString stringWithFormat:kIntegerFormat, adType];
    return [ApplilinkUtilities narrowedListWithList:[self getAdList] object:type forKey:kAdTypeKey];
}

#pragma mark - Application list builders

+ (nullable NSArray *)getAppBannerList {
    NSMutableArray *result = [NSMutableArray array];
    NSDictionary *bannerData = [self getLotteryBannerData];
    if (bannerData.count == 0) {
        return nil;
    }
    NSMutableDictionary *record = [NSMutableDictionary dictionaryWithCapacity:bannerData.count];
    for (id key in bannerData.allKeys) {
        record[key] = bannerData[key];
    }
    NSString *bannerUrl = record[kBannerUrlKey];
    if (![RecommendAdCache getBannerWithUrl:bannerUrl]) {
        return nil;
    }
    NSString *fileName = [ApplilinkUtilities geFileNameFromPath:bannerUrl];
    record[kBannerUrlKey] =
        [RecommendAdCache.getBannerCachePath stringByAppendingPathComponent:fileName];
    record[kCreativeIdKey] = fileName.lastPathComponent;
    [result addObject:record];
    return result;
}

+ (nullable NSArray *)getAppIconList {
    NSMutableArray *result = [NSMutableArray array];
    for (NSDictionary *iconData in [self getLotteryIconData]) {
        NSMutableDictionary *record = [NSMutableDictionary dictionaryWithCapacity:iconData.count];
        for (id key in iconData.allKeys) {
            record[key] = iconData[key];
        }
        NSString *fileName = [ApplilinkUtilities geFileNameFromPath:record[kBannerIconUrlKey]];
        record[kCreativeIdKey] = fileName.lastPathComponent;
        [result addObject:record];
    }
    return result;
}

+ (nullable NSArray *)getAppInterstitialList {
    NSMutableArray *result = [NSMutableArray array];
    NSDictionary *interstitialData = [self getLotteryInterstitialData];
    if (interstitialData == nil) {
        return nil;
    }
    NSMutableDictionary *record =
        [NSMutableDictionary dictionaryWithCapacity:interstitialData.count];
    for (id key in interstitialData.allKeys) {
        record[key] = interstitialData[key];
    }
    NSString *bannerUrl = record[kInterstitialBannerUrlKey];
    if (![RecommendAdCache getBannerWithUrl:bannerUrl]) {
        return nil;
    }
    NSString *fileName = [ApplilinkUtilities geFileNameFromPath:bannerUrl];
    record[kInterstitialBannerUrlKey] =
        [RecommendAdCache.getBannerCachePath stringByAppendingPathComponent:fileName];
    record[kCreativeIdKey] = fileName.lastPathComponent;
    record[kInstallFlgKey] = [self getInstallFlgWithAdData:record];
    [result addObject:record];
    return result;
}

#pragma mark - Lottery draws

+ (nullable NSDictionary *)getLotteryBannerData {
    NSArray *list = [self getAdListByAdType:kRecommendAdTypeLotteryBanner];
    if (list.count == 0) {
        return nil;
    }
    list = [self getAdListTermForList:list];
    if (list.count == 0) {
        return nil;
    }
    return list[arc4random() % list.count];
}

+ (nullable NSArray *)getLotteryIconData {
    NSArray *list = [self getAdListByAdType:kRecommendAdTypeLotteryIcon];
    if (list.count == 0) {
        return nil;
    }
    list = [self getAdListTermForList:list];
    if (list.count == 0) {
        return nil;
    }
    list = [self shuffled:list];
    NSUInteger count = list.count < kMaxLotteryIconCount ? list.count : kMaxLotteryIconCount;
    NSIndexSet *indexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, count)];
    return [list objectsAtIndexes:indexes];
}

+ (nullable NSDictionary *)getLotteryInterstitialData {
    NSArray *list = [self getInterstitialSpecList][kAdDisplaySpecKey];
    if (list.count == 0) {
        return nil;
    }
    list = [self getInterstitialSpecCountForAdDisplaySpecList:list];
    if (list.count == 0) {
        return nil;
    }
    list = [self getInterstitialSpecInstallForAdDisplaySpecList:list];
    if (list.count == 0) {
        return nil;
    }
    return [self getLotteryInterstitialDataWithList:list];
}

+ (nullable NSDictionary *)getLotteryInterstitialDataWithList:(nullable NSArray *)list {
    NSInteger totalPriority = 0;
    for (NSDictionary *record in list) {
        totalPriority += [[record valueForKeyPath:kPriorityKey] integerValue];
    }
    uint32_t draw = arc4random();
    // The draw is reduced modulo the total priority and mapped to the record whose cumulative
    // priority window contains it.
    NSInteger target = totalPriority == 0 ? (draw + 1) : ((draw % totalPriority) + 1);
    NSInteger cumulative = 0;
    for (NSDictionary *record in list) {
        cumulative += [[record valueForKeyPath:kPriorityKey] intValue];
        if (target <= cumulative) {
            return record;
        }
    }
    return nil;
}

#pragma mark - Interstitial specification filtering

+ (nullable NSArray *)getInterstitialSpecPriorityList {
    NSArray *specs = [self getInterstitialSpecList][kAdDisplaySpecKey];
    NSSortDescriptor *descriptor = [[NSSortDescriptor alloc] initWithKey:kPriorityKeyPath
                                                               ascending:NO];
    return [specs sortedArrayUsingDescriptors:@[ descriptor ]];
}

+ (nullable NSArray *)getInterstitialSpecCountForAdDisplaySpecList:(nullable NSArray *)list {
    NSMutableArray *result = [NSMutableArray array];
    NSDictionary *dailyCounts = [self getAdDisplayCountDailyDictionary];
    NSDictionary *totalCounts = [self getAdDisplayCountTotalDictionary];
    if (totalCounts == nil) {
        // The binary returns the unfiltered input list when there is no total-count record.
        return list;
    }
    for (NSDictionary *spec in list) {
        if (![spec isKindOfClass:NSDictionary.class]) {
            continue;
        }
        id adIdTo = spec[kAdIdToKey];
        // The binary messages -isKindOfClass: on the ad_id_to value and discards the result.
        (void)[adIdTo isKindOfClass:NSString.class];
        id maxDaily = spec[kMaxDisplayCountDailyKey];
        int maxDisplayCountDaily =
            [maxDaily isKindOfClass:NSString.class] ? [maxDaily intValue] : 0;
        id maxTotal = spec[kMaxDisplayCountTotalKey];
        int maxDisplayCountTotal =
            [maxTotal isKindOfClass:NSString.class] ? [maxTotal intValue] : 0;
        NSString *dailyKey = [NSString stringWithFormat:kCountFormat, adIdTo];
        NSString *totalKey = [NSString stringWithFormat:kCountFormat, adIdTo];
        NSNumber *daily = dailyCounts[dailyKey];
        NSNumber *total = totalCounts[totalKey];
        if (daily == nil) {
            daily = @0;
        }
        if (total == nil) {
            total = @0;
        }
        if (daily.intValue < maxDisplayCountDaily && total.intValue < maxDisplayCountTotal) {
            [result addObject:spec];
        }
    }
    return result;
}

+ (nullable NSArray *)getInterstitialSpecInstallForAdDisplaySpecList:(nullable NSArray *)list {
    NSMutableArray *result = [NSMutableArray array];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = kDateTimeFormat;
    formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:kJapanLocaleIdentifier];
    formatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:kJapanTimeZoneAbbreviation];
    NSDate *now = [NSDate date];
    for (NSDictionary *spec in list) {
        if (![spec isKindOfClass:NSDictionary.class]) {
            continue;
        }
        id adIdTo = spec[kAdIdToKey];
        int adId = [adIdTo isKindOfClass:NSString.class] ? [adIdTo intValue] : 0;
        id installedFlg = spec[kInstalledAdDisplayFlgKey];
        int installed = [installedFlg isKindOfClass:NSString.class] ? [installedFlg intValue] : 0;
        NSDictionary *adData = [self getAdDataByAdId:adId];
        if (adData == nil) {
            continue;
        }
        NSMutableDictionary *record = [NSMutableDictionary dictionaryWithCapacity:adData.count];
        for (id key in adData.allKeys) {
            record[key] = adData[key];
        }
        if (installed == 0 &&
            ![kInstallFlgOff isEqualToString:[self getInstallFlgWithAdData:adData]]) {
            continue;
        }
        NSString *endDate = [adData valueForKeyPath:kExternalAdDispMngEndDateKey];
        if ([[endDate substringToIndex:kEndDateYearPrefixLength] intValue] <
            kEndDateComparableYear) {
            NSDate *end = [formatter dateFromString:endDate];
            if ([end compare:now] == NSOrderedAscending) {
                continue;
            }
        }
        record[kPriorityKey] = spec[kPriorityKey];
        [result addObject:record];
    }
    return result;
}

+ (nullable NSArray *)getAdInterstitialUrlListTermForAdDisplaySpecList:(nullable NSArray *)list {
    NSMutableArray *result = [NSMutableArray array];
    for (NSDictionary *spec in list) {
        if (![spec isKindOfClass:NSDictionary.class]) {
            continue;
        }
        id adIdTo = spec[kAdIdToKey];
        int adId;
        if ([adIdTo isKindOfClass:NSString.class] || [adIdTo isKindOfClass:NSNumber.class]) {
            adId = [adIdTo intValue];
        } else {
            adId = 0;
        }
        NSDictionary *adData = [self getAdDataByAdId:adId];
        if ([adData[kInterstitialBannerUrlKey] isKindOfClass:NSString.class]) {
            NSString *bannerUrl = adData[kInterstitialBannerUrlKey];
            if (bannerUrl.length != 0) {
                [result addObject:adData];
            }
        }
    }
    return result;
}

+ (nullable NSArray *)getAdInterstitialUrlListTermForList:(nullable NSArray *)list {
    NSMutableArray *result = [NSMutableArray array];
    for (NSDictionary *record in list) {
        if (![record isKindOfClass:NSDictionary.class]) {
            continue;
        }
        NSString *bannerUrl = record[kInterstitialBannerUrlKey];
        if (bannerUrl.length != 0) {
            [result addObject:bannerUrl];
        }
    }
    return result;
}

#pragma mark - Display-count dictionaries

+ (nullable NSDictionary *)getAdDisplayCountDailyDictionary {
    NSData *data = [NSUserDefaults.standardUserDefaults dataForKey:kAdDisplayCountDailyKey];
    if (data == nil) {
        return nil;
    }
    NSDictionary *dictionary = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    NSDate *recordedDate = dictionary[kAdDisplayDateKey];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = kDateFormat;
    NSString *recordedDay = [formatter stringFromDate:recordedDate];
    NSString *today = [formatter stringFromDate:[NSDate date]];
    if ([recordedDay isEqualToString:today]) {
        return dictionary;
    }
    return nil;
}

+ (nullable NSDictionary *)getAdDisplayCountTotalDictionary {
    NSData *data = [NSUserDefaults.standardUserDefaults dataForKey:kAdDisplayCountTotalKey];
    if (data == nil) {
        return nil;
    }
    return [NSKeyedUnarchiver unarchiveObjectWithData:data];
}

#pragma mark - Advert type

+ (int)getAdTypeWithAdModel:(int)adModel adLocation:(nullable NSString *)adLocation {
    for (NSDictionary *setting in [self getAdModelSettingList]) {
        id location = setting[kAdLocationKey];
        if (![location isKindOfClass:NSString.class] || ![location isEqualToString:adLocation]) {
            continue;
        }
        id model = setting[kAdModelKey];
        if (![model isKindOfClass:NSString.class] || [model intValue] != adModel) {
            continue;
        }
        id type = setting[kAdTypeKey];
        if ([type isKindOfClass:NSString.class]) {
            return [type intValue];
        }
    }
    return kRecommendAdTypeAppBanner;
}

#pragma mark - List filters

+ (nullable NSArray *)getAdListTermForList:(nullable NSArray *)list {
    NSMutableArray *result = [NSMutableArray array];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = kDateTimeFormat;
    formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:kJapanLocaleIdentifier];
    formatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:kJapanTimeZoneAbbreviation];
    NSDate *now = [NSDate date];
    for (NSDictionary *record in list) {
        if (![record isKindOfClass:NSDictionary.class]) {
            continue;
        }
        NSDate *end = [formatter dateFromString:record[kExternalAdDispMngEndDateKey]];
        if ([end compare:now] != NSOrderedAscending) {
            [result addObject:record];
        }
    }
    return result;
}

+ (nullable NSArray *)getAdBannerListForList:(nullable NSArray *)list {
    NSMutableArray *result = [NSMutableArray array];
    for (NSDictionary *record in list) {
        if (![record isKindOfClass:NSDictionary.class]) {
            continue;
        }
        if ([record[kBannerUrlKey] isKindOfClass:NSString.class]) {
            NSString *bannerUrl = record[kBannerUrlKey];
            if (bannerUrl.length != 0) {
                [result addObject:bannerUrl];
            }
        }
    }
    return result;
}

+ (nullable NSArray *)shuffled:(nullable NSArray *)list {
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:list.count];
    for (id object in list) {
        NSUInteger index = arc4random() % (result.count + 1);
        [result insertObject:object atIndex:index];
    }
    return result;
}

#pragma mark - Interstitial frequency lottery

+ (nullable NSError *)lotteryInterstitialWithAdLocation:(nullable NSString *)adLocation {
    NSDictionary *specList = [self getInterstitialSpecList];
    if (specList.count == 0) {
        // The binary calls -dictionaryWithObjectsAndKeys: with a lone message string and no
        // terminating nil, yielding an empty user-info dictionary.
        NSDictionary *userInfo =
            [NSDictionary dictionaryWithObjectsAndKeys:kInterstitialSpecListIsZeroMessage, nil];
        return [ApplilinkNetworkError
            localizedApplilinkErrorWithCode:kApplilinkErrorInterstitialSpecInvalid
                                   userInfo:userInfo];
    }
    int frequencyN = 0;
    int frequencyM = 0;
    for (NSDictionary *spec in specList[kAdLocationDisplaySpecKey]) {
        if ([adLocation isEqualToString:spec[kAdLocationKey]]) {
            id n = spec[kFrequencyNKey];
            id m = spec[kFrequencyMKey];
            frequencyN = n == nil ? 0 : [n intValue];
            frequencyM = m == nil ? 0 : [m intValue];
            break;
        }
    }
    if (frequencyN == 0 || frequencyM == 0) {
        NSDictionary *userInfo = [NSDictionary
            dictionaryWithObjectsAndKeys:kInterstitialSpecFrequencyIsZeroMessage, nil];
        return [ApplilinkNetworkError
            localizedApplilinkErrorWithCode:kApplilinkErrorInterstitialSpecInvalid
                                   userInfo:userInfo];
    }

    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSData *data = [defaults dataForKey:kFrequencyKey];
    NSMutableDictionary *frequency;
    int recordedN = 0;
    int recordedM = 0;
    if (data == nil) {
        frequency = [NSMutableDictionary dictionary];
    } else {
        frequency = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        NSString *storedNKey = [NSString stringWithFormat:kFrequencyNFormat, adLocation];
        NSString *storedMKey = [NSString stringWithFormat:kFrequencyMFormat, adLocation];
        id storedN = frequency[storedNKey];
        id storedM = frequency[storedMKey];
        recordedN = storedN == nil ? 0 : [storedN intValue];
        recordedM = storedM == nil ? 0 : [storedM intValue];
    }
    if (frequencyN <= recordedN) {
        recordedN = 0;
        recordedM = 0;
    }
    int roll = arc4random() % (frequencyN - recordedN);
    int remaining = frequencyM - recordedM;
    if (roll < remaining) {
        ++recordedM;
    }
    if (frequencyN <= recordedN + 1) {
        recordedM = 0;
    }
    frequency[[NSString stringWithFormat:kFrequencyNFormat, adLocation]] = @(recordedN);
    frequency[[NSString stringWithFormat:kFrequencyMFormat, adLocation]] = @(recordedM);
    [defaults setObject:[NSKeyedArchiver archivedDataWithRootObject:frequency]
                 forKey:kFrequencyKey];
    [defaults synchronize];

    if (roll < remaining) {
        return nil;
    }
    NSString *message = [NSString
        stringWithFormat:kLotteryMissFormat, frequencyN, recordedN, frequencyM, recordedM];
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:message, nil];
    return [ApplilinkNetworkError
        localizedApplilinkErrorWithCode:kApplilinkErrorInterstitialLotteryMiss
                               userInfo:userInfo];
}

#pragma mark - Install flag

+ (nullable NSString *)getInstallFlgWithAdData:(nullable NSDictionary *)adData {
    if (adData == nil) {
        return kInstallFlgOff;
    }
    id installFlg = adData[kInstallFlgKey];
    if (![installFlg isKindOfClass:NSString.class]) {
        installFlg = kInstallFlgOff;
    }
    if ([installFlg isEqualToString:kInstallFlgOn]) {
        return kInstallFlgOn;
    }
    id scheme = adData[kDefaultSchemeKey];
    if (scheme == nil || [scheme isKindOfClass:NSNull.class]) {
        return kInstallFlgOff;
    }
    NSString *schemeString = scheme;
    if ([schemeString rangeOfString:kSchemeSeparator].location == NSNotFound) {
        schemeString = [schemeString stringByAppendingString:kSchemeSeparator];
    }
    NSURL *url = [NSURL URLWithString:schemeString];
    if ([UIApplication.sharedApplication canOpenURL:url]) {
        return kInstallFlgOn;
    }
    return kInstallFlgOff;
}

@end
