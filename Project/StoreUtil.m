#import "StoreUtil.h"

#import <StoreKit/StoreKit.h>

#import "AppDelegate.h"
#import "NetworkUtil.h"
#import "deviceenvironment.h"
#import "enginecrypto.h"

// Source constant the receipt-check salt is carved out of; only a 27-character slice is used.
static NSString *const kReceiptSaltSource = @"2012 Konami Digital Entertainment";

static const NSUInteger kReceiptSaltLocation = 2;
static const NSUInteger kReceiptSaltLength = 27;

static NSString *const kReceiptCheckSecretV2 = @"d0dc0448e6c701c9bcfb5358945f4ede";

static NSString *const kPackProductIDPrefix = @"rbplus.pack";
static NSString *const kNoteProductIDPrefix = @"rbplus.note";
static NSString *const kProductIDFormat = @"%@%05d";

static NSString *const kReceiptCheckV2JSONFormat =
    @"{\"receiptdata\":\"%@\",\"target\":\"%@\",\"nonce\":\"%@\",\"products\":[%@],\"uuid\":\"%@\","
    @"\"device\":\"%@\",\"os\":\"%@\",\"locale\":\"%@\",\"version\":\"%@\",\"userid\":\"%@\","
    @"\"passwd\":\"%@\"}";
static NSString *const kReceiptCheckJSONFormat =
    @"{\"receipt_data\":\"%@\",\"client_info\":{\"uuid\":\"%@\",\"version\":\"%@\",\"device\":\"%@"
    @"\","
    @"\"os\":\"%@\",\"locale\":\"%@\"}}";
static NSString *const kCampaignListJSONFormat =
    @"{\"target\":\"%@\",\"head\":\"%d\",\"limit\":%d,\"userId\":\"%@\",\"passwd\":\"%@\"}";
static NSString *const kCampaignSerialCheckJSONFormat = @"{\"target\":\"%@\",\"userId\":\"%@\","
                                                        @"\"passwd\":\"%@\",\"code\":\"%@\","
                                                        @"\"campId\":\"%d\"}";
static NSString *const kCampaignItemInfoJSONFormat =
    @"{\"target\":\"%@\",\"userId\":\"%@\",\"passwd\":\"%@\",\"campId\":\"%d\"}";

// Every product-array element but the last carries a trailing comma.
static NSString *const kProductElementFormat = @"\"%@\"";
static NSString *const kProductElementWithCommaFormat = @"\"%@\",";

// The server-data credential array's element indices (getServerData returns [userId, passwd]).
static const NSUInteger kServerDataUserIdIndex = 0;
static const NSUInteger kServerDataPasswdIndex = 1;

static NSString *const kITunesHost = @"itunes.apple.com";
static NSString *const kAffiliateItemKey = @"i";
static NSString *const kAffiliateTokenKey = @"at";
static NSString *const kAffiliateCampaignKey = @"ct";

static NSString *const kITunesItemIDPattern = @"id([0-9]+)";

@implementation StoreUtil

+ (NSString *)createReceiptCheckDigest:(NSString *)jsonString {
    NSString *salt = [kReceiptSaltSource
        substringWithRange:NSMakeRange(kReceiptSaltLocation, kReceiptSaltLength)];
    NSString *seed = [NSString stringWithFormat:@"%@%@", salt, jsonString];
    return ComputeSha256HexString(seed.UTF8String);
}

+ (NSString *)createReceiptCheckDigestV2:(NSString *)jsonString withNonce:(NSString *)nonce {
    NSString *seed =
        [NSString stringWithFormat:@"%@%@%@", kReceiptCheckSecretV2, nonce, jsonString];
    return ComputeSha256HexString(seed.UTF8String);
}

/** @ghidraAddress 0x85cc0 */
+ (BOOL)isValidURL:(NSString *)urlString {
    if (urlString == nil || [urlString isEqual:[NSNull null]]) {
        return NO;
    }
    NSURL *url = [NSURL URLWithString:urlString];
    if (url == nil) {
        return NO;
    }
    return [url.scheme isEqualToString:@"http"] || [url.scheme isEqualToString:@"https"];
}

/** @ghidraAddress 0x8665c */
+ (NSString *)createNonce:(unsigned long long)length {
    return [NetworkUtil createNonce:length];
}

/** @ghidraAddress 0x85e54 */
+ (NSString *)createReceiptCheckJSON:(NSString *)receipt {
    return [NSString stringWithFormat:kReceiptCheckJSONFormat,
                                      receipt,
                                      [NetworkUtil identifierParams],
                                      GetBundleVersionString(),
                                      [NetworkUtil deviceName],
                                      GetSystemVersionString(),
                                      GetFormattedVersionString()];
}

/** @ghidraAddress 0x85fd4 */
+ (NSString *)createReceiptCheckJSONForV2:(NSString *)receipt
                               productIds:(NSArray *)productIds
                                    nonce:(NSString *)nonce {
    NSMutableString *products = [[NSMutableString alloc] initWithString:@""];
    for (NSUInteger i = 0; i < productIds.count; ++i) {
        NSString *element =
            i == productIds.count - 1 ?
                [NSString stringWithFormat:kProductElementFormat, productIds[i]] :
                [NSString stringWithFormat:kProductElementWithCommaFormat, productIds[i]];
        [products appendString:element];
    }
    NSArray *serverData = [AppDelegate getServerData];
    return [NSString stringWithFormat:kReceiptCheckV2JSONFormat,
                                      receipt,
                                      GetRegionCode(),
                                      nonce,
                                      products,
                                      [NetworkUtil identifierParams],
                                      [NetworkUtil deviceName],
                                      GetSystemVersionString(),
                                      GetFormattedVersionString(),
                                      GetBundleVersionString(),
                                      serverData[kServerDataUserIdIndex],
                                      serverData[kServerDataPasswdIndex]];
}

/** @ghidraAddress 0x85980 */
+ (NSURL *)receiptV3URL {
    return [NetworkUtil receiptV3URL];
}

/** @ghidraAddress 0x874a0 */
+ (NSString *)pidToProductID:(int)pid {
    if (pid > 0) {
        return [NSString stringWithFormat:kProductIDFormat, kNoteProductIDPrefix, pid];
    }
    return nil;
}

/** @ghidraAddress 0x8596c */
+ (NSURL *)musicInfoURL:(unsigned int)musicId {
    return [NetworkUtil musicInfoURL:musicId];
}

/** @ghidraAddress 0x85944 */
+ (NSURL *)packListURL:(unsigned int)offset limit:(unsigned int)limit genre:(unsigned int)genre {
    return [NetworkUtil packListURL:offset limit:limit genre:genre];
}

/** @ghidraAddress 0x85958 */
+ (NSURL *)packInfoURL:(unsigned int)packID UserOpen:(BOOL)userOpen {
    return [NetworkUtil packInfoURL:packID UserOpen:userOpen];
}

/** @ghidraAddress 0x8748c */
+ (NSURL *)extendNoteInfoURL:(unsigned int)extendNoteID UserOpen:(BOOL)userOpen {
    return [NetworkUtil extendNoteInfoURL:extendNoteID UserOpen:userOpen];
}

/** @ghidraAddress 0x859d0 */
+ (NSURL *)manageSortListURL {
    return [NetworkUtil manageSortListURL];
}

/** @ghidraAddress 0x874f4 */
+ (int)productIDToPid:(NSString *)productID {
    if (productID.length > kNoteProductIDPrefix.length &&
        [productID hasPrefix:kNoteProductIDPrefix]) {
        int pid = [productID substringFromIndex:kNoteProductIDPrefix.length].intValue;
        return pid < 1 ? -1 : pid;
    }
    return -1;
}

/** @ghidraAddress 0x87478 */
+ (NSURL *)extendNoteListURL:(unsigned int)offset limit:(unsigned int)limit {
    return [NetworkUtil extendNoteListURL:offset limit:limit];
}

/** @ghidraAddress 0x859e4 */
+ (NSURL *)userAgeURL {
    return [NetworkUtil userAgeURL];
}

/** @ghidraAddress 0x86b9c */
+ (NSDictionary *)affiliateParametersFromURL:(NSURL *)url {
    if (url == nil) {
        return nil;
    }
    if (![url.host isEqualToString:kITunesHost]) {
        return nil;
    }

    NSInteger itemID = 0;
    NSString *affiliateToken = nil;
    NSString *campaignToken = nil;

    NSArray *pairs = [url.query componentsSeparatedByString:@"&"];
    for (NSString *pair in pairs) {
        if (pair.length == 0) {
            continue;
        }
        NSArray *keyValue = [pair componentsSeparatedByString:@"="];
        if (keyValue.count != 2) {
            continue;
        }
        NSString *key = keyValue[0];
        if ([key isEqualToString:kAffiliateItemKey]) {
            itemID = [keyValue[1] integerValue];
        } else if ([key isEqualToString:kAffiliateTokenKey]) {
            affiliateToken = keyValue[1];
        } else if ([key isEqualToString:kAffiliateCampaignKey]) {
            campaignToken = keyValue[1];
        }
    }

    // A short affiliate link carries no query; recover the item id from the "idNNN" path token.
    if (itemID == 0) {
        NSError *error = nil;
        NSRegularExpression *expression =
            [NSRegularExpression regularExpressionWithPattern:kITunesItemIDPattern
                                                      options:NSRegularExpressionCaseInsensitive
                                                        error:&error];
        if (error == nil) {
            NSString *absolute = url.absoluteString;
            NSArray<NSTextCheckingResult *> *matches =
                [expression matchesInString:absolute
                                    options:0
                                      range:NSMakeRange(0, absolute.length)];
            if (matches.count == 1) {
                itemID = [absolute substringWithRange:[matches[0] rangeAtIndex:1]].intValue;
            }
        }
    }

    if (affiliateToken == nil || itemID <= 0) {
        return nil;
    }
    if (campaignToken == nil) {
        return @{
            SKStoreProductParameterITunesItemIdentifier : @(itemID),
            SKStoreProductParameterAffiliateToken : affiliateToken
        };
    }
    return @{
        SKStoreProductParameterITunesItemIdentifier : @(itemID),
        SKStoreProductParameterAffiliateToken : affiliateToken,
        SKStoreProductParameterCampaignToken : campaignToken
    };
}

/** @ghidraAddress 0x85a4c */
+ (int)packIDForProductID:(NSString *)productID {
    if (productID.length > kPackProductIDPrefix.length &&
        [productID hasPrefix:kPackProductIDPrefix]) {
        int packID = [productID substringFromIndex:kPackProductIDPrefix.length].intValue;
        return packID < 1 ? -1 : packID;
    }
    return -1;
}

/** @ghidraAddress 0x859f8 */
+ (NSString *)productIDForPackID:(int)packID {
    if (packID > 0) {
        return [NSString stringWithFormat:kProductIDFormat, kPackProductIDPrefix, packID];
    }
    return nil;
}

/** @ghidraAddress 0x85b4c */
+ (NSString *)priceString:(SKProduct *)product {
    return [StoreUtil priceString:product useCatalogPrice:NO];
}

/** @ghidraAddress 0x85b7c */
+ (NSString *)priceString:(SKProduct *)product useCatalogPrice:(BOOL)useCatalogPrice {
    // The flag is ignored; the price is always the StoreKit product's own localised price.
    (void)useCatalogPrice;
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.formatterBehavior = NSNumberFormatterBehavior10_4;
    formatter.numberStyle = NSNumberFormatterCurrencyStyle;
    formatter.locale = product.priceLocale;
    return [formatter stringFromNumber:product.price];
}

/** @ghidraAddress 0x85994 */
+ (NSURL *)campaignListURL {
    return [NetworkUtil campaignListURL];
}

/** @ghidraAddress 0x859a8 */
+ (NSURL *)campaignSerialCheckURL {
    return [NetworkUtil campaignSerialCheckURL];
}

/** @ghidraAddress 0x859bc */
+ (NSURL *)campaignItemInfoURL {
    return [NetworkUtil campaignItemInfoURL];
}

/** @ghidraAddress 0x8678c */
+ (NSString *)createCampaignListJSON:(int)offset limit:(int)limit {
    NSArray *serverData = [AppDelegate getServerData];
    return [NSString stringWithFormat:kCampaignListJSONFormat,
                                      GetRegionCode(),
                                      offset,
                                      limit,
                                      serverData[kServerDataUserIdIndex],
                                      serverData[kServerDataPasswdIndex]];
}

/** @ghidraAddress 0x868e4 */
+ (NSString *)createCampaignSerialCheckJSON:(int)campaignID code:(NSString *)code {
    NSArray *serverData = [AppDelegate getServerData];
    return [NSString stringWithFormat:kCampaignSerialCheckJSONFormat,
                                      GetRegionCode(),
                                      serverData[kServerDataUserIdIndex],
                                      serverData[kServerDataPasswdIndex],
                                      code,
                                      campaignID];
}

/** @ghidraAddress 0x86a54 */
+ (NSString *)createCampaignItemInfoJSON:(int)campaignID {
    NSArray *serverData = [AppDelegate getServerData];
    return [NSString stringWithFormat:kCampaignItemInfoJSONFormat,
                                      GetRegionCode(),
                                      serverData[kServerDataUserIdIndex],
                                      serverData[kServerDataPasswdIndex],
                                      campaignID];
}

@end
