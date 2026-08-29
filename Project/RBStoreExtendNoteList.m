#import "RBStoreExtendNoteList.h"

#import <StoreKit/StoreKit.h>

#import "AppDelegate.h"
#import "Downloader.h"
#import "RBUserSettingData.h"
#import "StoreExtendNoteInfo.h"
#import "StoreUtil.h"
#import "engineglobals.h"

static const unsigned int kExtendNoteListPageSize = 12;

static const NSUInteger kExtendNoteInfoCapacity = 50;
static const NSUInteger kListProductIDCapacity = 50;
static const NSUInteger kMergeArrayCapacity = 10;
static const NSUInteger kProductIdentifierSetCapacity = 12;

// A limit type below this count is a real, player-chosen one that a month rollover resets.
static const int kPurchaseLimitTypeCount = 3;

static const int kPurchaseLimitTypeUnset = 0;

static const int kTotalPurchaseReset = 0;

static const NSStringCompareOptions kVersionCompareOptions = NSNumericSearch;

static NSString *const kKeyNoteList = @"NoteList";
static NSString *const kKeyPID = @"PID";
static NSString *const kKeyMusic = @"Music";
static NSString *const kKeyHasNext = @"HasNext";
static NSString *const kKeyVersion = @"Version";
static NSString *const kKeyDate = @"Date";
static NSString *const kKeyError = @"Error";

static NSString *const kKeyCFBundleVersion = @"CFBundleVersion";

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
#ifdef ENABLE_PATCHES
    // The deep-linked extend note is free too, so this request would hang.
    return;
#else
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
#endif
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
    if (response != nil) {
        for (SKProduct *product in response.products) {
            int productID = [StoreUtil productIDToPid:product.productIdentifier];
            if ([self getExtendNoteInfoWithProductID:productID] == nil) {
                StoreExtendNoteInfo *info = [[StoreExtendNoteInfo alloc] initWithProduct:product];
                [self.arrayExtendNoteInfo addObject:info];
            }
        }
    }

    NSMutableArray<NSNumber *> *resolvedProductIDs =
        [[NSMutableArray alloc] initWithCapacity:kMergeArrayCapacity];
    for (NSDictionary *entry in dictionary[kKeyNoteList]) {
        int productID = [entry[kKeyPID] intValue];
        StoreExtendNoteInfo *info = [self getExtendNoteInfoWithProductID:productID];
#ifdef ENABLE_PATCHES
        // Without a StoreKit response nothing matches, so build the record from the entry itself.
        if (info == nil && entry[kKeyMusic] != nil) {
            info = [[StoreExtendNoteInfo alloc] initWithDictionary:entry];
            if (info != nil) {
                [self.arrayExtendNoteInfo addObject:info];
            }
        }
#endif
        if (info != nil && entry[kKeyMusic] != nil) {
            [info setDictionary:entry];
            [resolvedProductIDs addObject:@(productID)];
        }
    }

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

/** @ghidraAddress 0xc07f0 */
- (void)downloaderProceed:(Downloader *)downloader {
}

/** @ghidraAddress 0xbfe24 */
- (void)downloaderFinished:(Downloader *)downloader {
    NSDictionary *json = [downloader getDataInJSON];
    NSString *requiredVersion = json[kKeyVersion];
    NSString *appVersion = [NSBundle mainBundle].infoDictionary[kKeyCFBundleVersion];

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

    if (appVersion == nil || (requiredVersion != nil &&
                              [appVersion compare:requiredVersion
                                          options:kVersionCompareOptions] == NSOrderedAscending)) {
#ifdef ENABLE_PATCHES
        // Passed as an argument so its %1$@/%2$@ placeholders cannot read varargs never supplied.
        NSString *message = [NSString stringWithFormat:@"%@", g_pLocalizedUpdateRequiredFormat];
#else
        // The binary passes the format string itself, leaving its placeholders unsubstituted.
        NSString *message = [NSString stringWithFormat:g_pLocalizedUpdateRequiredFormat];
#endif
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

#ifdef ENABLE_PATCHES
    // Every extend note is free here, so an SKProductsRequest would never resolve; take the
    // direct-merge branch instead.
    [identifiers removeAllObjects];
#endif
    if (identifiers.count == 0) {
        if (sawAnyPID) {
            [self updateExtendNoteInfo:json SKProductsResponse:nil];
        } else {
            [self.delegate extendNoteListDownloadError:self errorMessage:g_pLocalizedServerNoData];
        }
    } else {
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

/** @ghidraAddress 0xc0768 */
- (void)downloaderError:(Downloader *)downloader {
    [self.delegate extendNoteListDownloadError:self errorMessage:g_pLocalizedServerConnectFailed];
    self.extendNotelistDownloader = nil;
}

#pragma mark - SKProductsRequestDelegate

/** @ghidraAddress 0xc0b20 */
- (void)productsRequest:(SKProductsRequest *)request
     didReceiveResponse:(SKProductsResponse *)response {
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
