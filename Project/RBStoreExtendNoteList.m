/** @file
 * The extend-note catalogue list model implementation. It downloads the extend-note catalogue in
 * pages, resolves each entry against StoreKit, parses the server dictionary into
 * @c StoreExtendNoteInfo records, and reports load progress to its delegate.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c RBStoreExtendNoteList, image
 * base 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import "RBStoreExtendNoteList.h"

#import <StoreKit/StoreKit.h>

#import "AppDelegate.h"
#import "Downloader.h"
#import "RBUserSettingData.h"
#import "StoreExtendNoteInfo.h"
#import "StoreUtil.h"
#import "neEngineBridge.h"

// The number of catalogue items requested per page.
static const unsigned int kExtendNoteListPageSize = 12;

// initWithCapacity: hints for the record and product-identifier caches.
static const NSUInteger kExtendNoteInfoCapacity = 50;
static const NSUInteger kListProductIDCapacity = 50;
static const NSUInteger kMergeArrayCapacity = 10;
static const NSUInteger kProductIdentifierSetCapacity = 12;

// The purchase-limit type is stored as a signed setting; a value below this count is a real,
// player-chosen limit type that a month rollover resets to "unset" (0).
static const int kPurchaseLimitTypeCount = 3;

// The purchase-limit-type sentinel meaning "not yet chosen".
static const int kPurchaseLimitTypeUnset = 0;

// The running purchase total reset at a month rollover.
static const int kTotalPurchaseReset = 0;

// The options passed to -compare:options: to compare version strings numerically.
static const NSStringCompareOptions kVersionCompareOptions = NSNumericSearch;

// Server catalogue and response dictionary keys.
static NSString *const kKeyNoteList = @"NoteList";
static NSString *const kKeyPID = @"PID";
static NSString *const kKeyMusic = @"Music";
static NSString *const kKeyHasNext = @"HasNext";
static NSString *const kKeyVersion = @"Version";
static NSString *const kKeyDate = @"Date";
static NSString *const kKeyError = @"Error";

// The application bundle's version key.
static NSString *const kKeyCFBundleVersion = @"CFBundleVersion";

// The store-country code of the resolved StoreKit products, cached across list instances so the
// server request can be scoped to the player's storefront. It is a file-scope global in the
// binary, so it is modelled as one here.
static NSString *g_pStoreCountry = nil;

@implementation RBStoreExtendNoteList

#pragma mark - Store country

/** @ghidraAddress 0xbf024 */
+ (NSString *)storeCountry {
    if (g_pStoreCountry != nil) {
        return [NSString stringWithString:g_pStoreCountry];
    }
    return nil;
}

#pragma mark - Lifecycle

/** @ghidraAddress 0xbf064 */
- (instancetype)init {
    self = [super init];
    if (self != nil) {
        self.extendNoteListContinued = YES;
        self.arrayExtendNoteInfo =
            [[NSMutableArray alloc] initWithCapacity:kExtendNoteInfoCapacity];
        self.listProductID = [[NSMutableArray alloc] initWithCapacity:kListProductIDCapacity];
    }
    return self;
}

/** @ghidraAddress 0xc1014 */
- (void)dealloc {
    if (self.extendNotelistDownloader != nil) {
        [self.extendNotelistDownloader cancel];
    }
    self.extendNotelistDownloader = nil;
    if (self.productsRequest != nil) {
        [self.productsRequest setDelegate:nil];
        [self.productsRequest cancel];
    }
    self.productsRequest = nil;
}

#pragma mark - Record lookup

/** @ghidraAddress 0xbf50c */
- (NSMutableArray<StoreExtendNoteInfo *> *)extendMusicInfos {
    return self.arrayExtendNoteInfo;
}

/** @ghidraAddress 0xbf518 */
- (NSMutableArray<NSNumber *> *)extendNoteProductIDList {
    return self.listProductID;
}

/** @ghidraAddress 0xbf524 */
- (StoreExtendNoteInfo *)getExtendNoteInfoWithProductID:(int)productID {
    for (StoreExtendNoteInfo *info in self.arrayExtendNoteInfo) {
        if (info.pid == productID) {
            return info;
        }
    }
    return nil;
}

/** @ghidraAddress 0xbf684 */
- (StoreExtendNoteInfo *)addExtendNoteInfoFromProductID:(int)productID {
    StoreExtendNoteInfo *info = [self getExtendNoteInfoWithProductID:productID];
    if (info == nil) {
        info = [[StoreExtendNoteInfo alloc] initWithExtendNoteID:productID];
        [self.arrayExtendNoteInfo addObject:info];
    }
    return info;
}

#pragma mark - Fetch state

/** @ghidraAddress 0xbf488 */
- (BOOL)isFetching {
    if (self.extendNotelistDownloader != nil) {
        return YES;
    }
    return self.productsRequest != nil;
}

/** @ghidraAddress 0xbf1a0 */
- (BOOL)startFetching {
    if (self.isFetching) {
        return NO;
    }

    // The catalogue is one-based, so the next page starts at the fetched count plus one.
    NSURL *url = [StoreUtil extendNoteListURL:self.fetchedExtendNoteNum + 1
                                        limit:kExtendNoteListPageSize];
    if (self.extendNotelistDownloader != nil) {
        [self.extendNotelistDownloader cancel];
        self.extendNotelistDownloader = nil;
    }
    self.extendNotelistDownloader = [[Downloader alloc] initWithURL:url save:nil];
    [self.extendNotelistDownloader startDownloadingWithDelegate:self];
    return YES;
}

/** @ghidraAddress 0xc07f4 */
- (void)optionalProductsRequest {
    if ([[AppDelegate appDelegate] getPackIDForOpenStore] == nil) {
        return;
    }
    int productID = [[[AppDelegate appDelegate] getExtendNotePIDForOpenStore] intValue];
    if (productID <= 0 || [self getExtendNoteInfoWithProductID:productID] != nil) {
        return;
    }

    NSMutableSet *identifiers = [NSMutableSet setWithCapacity:kProductIdentifierSetCapacity];
    [identifiers addObject:[StoreUtil pidToProductID:productID]];
    if (identifiers.count == 0) {
        return;
    }

    if (self.productsRequest != nil) {
        [self.productsRequest cancel];
        [self.productsRequest setDelegate:nil];
        self.productsRequest = nil;
    }
    self.isOptionalProductRequest = YES;
    self.productsRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:identifiers];
    [self.productsRequest setDelegate:self];
    [self.productsRequest start];
}

/** @ghidraAddress 0xbf338 */
- (void)cancelFetching {
    if (self.extendNotelistDownloader != nil) {
        [self.extendNotelistDownloader cancel];
        self.extendNotelistDownloader = nil;
    }
    if (self.productsRequest != nil) {
        [self.productsRequest cancel];
        [self.productsRequest setDelegate:nil];
        self.productsRequest = nil;
    }
}

#pragma mark - Catalogue merge

/** @ghidraAddress 0xbf768 */
- (void)updateExtendNoteInfo:(NSDictionary *)dictionary
          SKProductsResponse:(SKProductsResponse *)response {
    // Wrap each resolved StoreKit product into a record, keyed by its numeric identifier.
    if (response != nil) {
        for (SKProduct *product in response.products) {
            int productID = [StoreUtil productIDToPid:product.productIdentifier];
            if ([self getExtendNoteInfoWithProductID:productID] == nil) {
                StoreExtendNoteInfo *info = [[StoreExtendNoteInfo alloc] initWithProduct:product];
                [self.arrayExtendNoteInfo addObject:info];
            }
        }
    }

    // Apply the server catalogue entries onto the matching records, collecting the product ids
    // that carry tune metadata.
    NSMutableArray<NSNumber *> *resolvedProductIDs =
        [[NSMutableArray alloc] initWithCapacity:kMergeArrayCapacity];
    for (NSDictionary *entry in dictionary[kKeyNoteList]) {
        int productID = [entry[kKeyPID] intValue];
        StoreExtendNoteInfo *info = [self getExtendNoteInfoWithProductID:productID];
        if (info != nil && entry[kKeyMusic] != nil) {
            [info setDictionary:entry];
            [resolvedProductIDs addObject:@(productID)];
        }
    }

    // A page fetch advances the paging cursor and records whether more pages remain; the
    // single-pack optional request does neither.
    if (!self.isOptionalProductRequest) {
        self.fetchedExtendNoteNum = self.fetchedExtendNoteNum + kExtendNoteListPageSize;
        self.extendNoteListContinued = [dictionary[kKeyHasNext] boolValue];
    }

    if (resolvedProductIDs.count == 0) {
        if (self.delegate != nil) {
            [self.delegate extendNoteListDownloadNothing:self];
        }
    } else {
        [self.listProductID addObjectsFromArray:resolvedProductIDs];
        if (self.delegate != nil) {
            [self.delegate extendNoteListDownloadSuccess:self];
        }
    }
}

#pragma mark - DownloaderDelegate

/** @ghidraAddress 0xc0768 */
- (void)downloaderProceed:(Downloader *)downloader {
    // Intentionally empty: catalogue progress is not surfaced.
}

/** @ghidraAddress 0xbfe24 */
- (void)downloaderFinished:(Downloader *)downloader {
    NSDictionary *json = [downloader getDataInJSON];
    NSString *requiredVersion = json[kKeyVersion];
    NSString *appVersion = [NSBundle mainBundle].infoDictionary[kKeyCFBundleVersion];

    // A month rollover resets the accumulated purchase total and any chosen purchase-limit type.
    int lastMonth = [RBUserSettingData sharedInstance].lastPurchaseMonth;
    NSNumber *serverMonth = json[kKeyDate];
    if (serverMonth != nil) {
        int month = [json[kKeyDate] intValue];
        if (lastMonth < month) {
            if ([RBUserSettingData sharedInstance].purchaseLimitType < kPurchaseLimitTypeCount) {
                [RBUserSettingData sharedInstance].purchaseLimitType = kPurchaseLimitTypeUnset;
            }
            [RBUserSettingData sharedInstance].totalPurchase = kTotalPurchaseReset;
        }
        [RBUserSettingData sharedInstance].lastPurchaseMonth = month;
    }
    [[RBUserSettingData sharedInstance] save];

    // Reject the catalogue when the app cannot read its own version, or when the server demands a
    // newer app version than the running one.
    if (appVersion == nil || (requiredVersion != nil &&
                              [appVersion compare:requiredVersion
                                          options:kVersionCompareOptions] == NSOrderedAscending)) {
        // The binary passes the format string as the only argument, leaving its positional
        // %1$@/%2$@ placeholders unsubstituted.
        NSString *message = [NSString stringWithFormat:g_pLocalizedUpdateRequiredFormat];
        [self.delegate extendNoteListDownloadError:self errorMessage:message];
        self.extendNotelistDownloader = nil;
        return;
    }

    NSArray *noteList = json[kKeyNoteList];
    if (noteList.count == 0) {
        NSString *errorMessage = json[kKeyError];
        if (errorMessage == nil) {
            errorMessage = g_pLocalizedServerNoData;
        }
        [self.delegate extendNoteListDownloadError:self errorMessage:errorMessage];
        self.extendNotelistDownloader = nil;
        return;
    }

    // Collect the product identifiers not yet resolved into StoreKit records.
    NSMutableSet *identifiers = [NSMutableSet setWithCapacity:kProductIdentifierSetCapacity];
    BOOL sawAnyPID = NO;
    for (NSDictionary *entry in noteList) {
        NSNumber *pid = entry[kKeyPID];
        if (pid != nil) {
            int productID = pid.intValue;
            if ([self getExtendNoteInfoWithProductID:productID] == nil) {
                [identifiers addObject:[StoreUtil pidToProductID:productID]];
            }
            sawAnyPID = YES;
        }
    }

    if (identifiers.count == 0) {
        if (sawAnyPID) {
            // Every listed product is already resolved; merge the catalogue directly.
            [self updateExtendNoteInfo:json SKProductsResponse:nil];
        } else {
            [self.delegate extendNoteListDownloadError:self errorMessage:g_pLocalizedServerNoData];
        }
    } else {
        // Hold the catalogue while its products resolve, then fire a StoreKit products request.
        self.tempExtendNoteList = [[NSDictionary alloc] initWithDictionary:json];
        if (self.productsRequest != nil) {
            [self.productsRequest cancel];
            [self.productsRequest setDelegate:nil];
            self.productsRequest = nil;
        }
        self.productsRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:identifiers];
        [self.productsRequest setDelegate:self];
        [self.productsRequest start];
    }

    self.extendNotelistDownloader = nil;
}

/** @ghidraAddress 0xc07f0 */
- (void)downloaderError:(Downloader *)downloader {
    [self.delegate extendNoteListDownloadError:self errorMessage:g_pLocalizedServerConnectFailed];
    self.extendNotelistDownloader = nil;
}

#pragma mark - SKProductsRequestDelegate

/** @ghidraAddress 0xc0b20 */
- (void)productsRequest:(SKProductsRequest *)request
     didReceiveResponse:(SKProductsResponse *)response {
    // Cache the storefront country of the resolved products for later scoping.
    if (response.products.count != 0) {
        NSString *country =
            [response.products.lastObject.priceLocale objectForKey:NSLocaleCountryCode];
        if (g_pStoreCountry == nil || ![g_pStoreCountry isEqualToString:country]) {
            g_pStoreCountry = [[NSString alloc] initWithString:country];
        }
    }

    [self updateExtendNoteInfo:self.tempExtendNoteList SKProductsResponse:response];
    self.productsRequest = nil;
    self.tempExtendNoteList = nil;

    if (self.isOptionalProductRequest) {
        self.isOptionalProductRequest = NO;
        // When the deep-linked pack is unavailable in this storefront, clear the queued pid so the
        // store does not try to open it.
        if (response.invalidProductIdentifiers != nil) {
            int queuedPID = [[[AppDelegate appDelegate] getExtendNotePIDForOpenStore] intValue];
            if ([response.invalidProductIdentifiers
                    containsObject:[StoreUtil pidToProductID:queuedPID]]) {
                [[AppDelegate appDelegate] setExtendNotePIDForOpenStore:nil];
                return;
            }
        }
        if ([self.delegate respondsToSelector:@selector(forceOpenExtendNoteView)]) {
            [self.delegate forceOpenExtendNoteView];
        }
    }
}

/** @ghidraAddress 0xc0f64 */
- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
    self.productsRequest = nil;
    self.tempExtendNoteList = nil;
    [self.delegate extendNoteListDownloadError:self errorMessage:g_pLocalizedServerConnectFailed];
    self.isOptionalProductRequest = NO;
}

@end
